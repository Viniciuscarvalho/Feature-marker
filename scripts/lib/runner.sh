#!/bin/bash
# lib/runner.sh — Core execution loop
#
# Handles backlog iteration, dependency checking, agent routing,
# Claude CLI invocation, PR creation, retry, and state tracking.

run_backlog() {
  local backlog_file="$1"
  local start_time
  start_time=$(date +%s)

  # Sort by priority, filter by status, check dependencies
  local items
  items=$(node -e "
    const items = JSON.parse(require('fs').readFileSync('$backlog_file', 'utf-8'));
    const PRIO = { high: 1, medium: 2, low: 3, none: 4 };
    const sorted = [...items].sort((a, b) => (PRIO[a.priority]||4) - (PRIO[b.priority]||4));
    const done = new Set(sorted.filter(i => i.status === 'done').map(i => i.id));
    const ready = [], blocked = [];
    for (const item of sorted) {
      if (item.status === 'done' && $SKIP_DONE) continue;
      if (item.status === 'blocked' && $SKIP_BLOCKED) continue;
      if (item.status !== 'backlog') continue;
      const unmet = (item.dependencies || []).filter(d => !done.has(d));
      if (unmet.length === 0) ready.push(item);
      else blocked.push({ ...item, _unmet: unmet });
    }
    console.log(JSON.stringify({ ready, blocked, total: items.length }));
  ")

  local ready_count blocked_count total_count
  ready_count=$(echo "$items" | node -p "JSON.parse(require('fs').readFileSync('/dev/stdin','utf-8')).ready.length")
  blocked_count=$(echo "$items" | node -p "JSON.parse(require('fs').readFileSync('/dev/stdin','utf-8')).blocked.length")
  total_count=$(echo "$items" | node -p "JSON.parse(require('fs').readFileSync('/dev/stdin','utf-8')).total")

  banner "Orchestrator — $ready_count ready, $blocked_count blocked, $total_count total"

  if [ "$ready_count" -eq 0 ]; then
    info "No actionable features. All done or blocked."
    return 0
  fi

  # Priority list
  echo "$items" | node -e "
    const d = JSON.parse(require('fs').readFileSync('/dev/stdin','utf-8'));
    d.ready.forEach((i, idx) => console.log('  ' + (idx+1) + '. [' + i.priority + '] ' + i.id + ': ' + i.title));
    if (d.blocked.length > 0) {
      console.log('');
      console.log('  Blocked:');
      d.blocked.forEach(i => console.log('    ' + i.id + ' (needs: ' + i._unmet.join(', ') + ')'));
    }
  "

  # Check dependencies
  echo "$items" | node -e "
    const d = JSON.parse(require('fs').readFileSync('/dev/stdin','utf-8'));
    const ids = d.ready.map(i => i.id);
    d.ready.forEach(i => {
      if (i.dependencies && i.dependencies.length > 0) {
        const inBatch = i.dependencies.filter(dep => ids.indexOf(dep) > ids.indexOf(i.id));
        if (inBatch.length > 0)
          console.log('  ! ' + i.id + ' depends on ' + inBatch.join(', ') + ' (ordering preserved)');
      }
    });
  " 2>/dev/null || true

  # Discover agents
  local agent_count=0
  local manifest_file="$CONFIG_DIR/agents-manifest.json"
  if [ -f "$manifest_file" ]; then
    agent_count=$(node -p "JSON.parse(require('fs').readFileSync('$manifest_file','utf-8')).agents.length" 2>/dev/null || echo "0")
  fi

  # Single-feature mode
  if [ -n "${OPT_FEATURE:-}" ]; then
    local single
    single=$(echo "$items" | node -e "
      const d = JSON.parse(require('fs').readFileSync('/dev/stdin','utf-8'));
      const f = d.ready.find(i => i.id === '$OPT_FEATURE');
      if (f) console.log(JSON.stringify(f)); else process.exit(1);
    " 2>/dev/null) || { err "Feature $OPT_FEATURE not found in ready list"; return 1; }
    info "Single-feature mode: $OPT_FEATURE"
    process_item "$single" 1 1
  else
    # Main loop
    local index=0
    echo "$items" | node -e "
      const d = JSON.parse(require('fs').readFileSync('/dev/stdin','utf-8'));
      d.ready.forEach(i => console.log(JSON.stringify(i)));
    " | while IFS= read -r item_json; do
      index=$((index + 1))
      process_item "$item_json" "$index" "$ready_count"
    done
  fi

  # Post-loop: cleanup
  if [ "$AUTO_CLEANUP" = "true" ]; then
    local cleaned
    cleaned=$(wt_cleanup)
    [ -n "$cleaned" ] && info "Cleaned:$cleaned"
  fi

  # Summary
  local end_time
  end_time=$(date +%s)
  local total_time=$((end_time - start_time))

  local done_n=0 pr_n=0 ready_n=0 failed_n=0
  for dir in "$STATE_DIR"/*/; do
    [ -d "$dir" ] || continue
    local fid
    fid=$(basename "$dir")
    [ -f "$dir/status.json" ] || continue
    local st
    st=$(wt_get_status "$fid")
    case "$st" in
      done) done_n=$((done_n+1)) ;;
      pr-created) pr_n=$((pr_n+1)) ;;
      ready) ready_n=$((ready_n+1)) ;;
      failed) failed_n=$((failed_n+1)) ;;
    esac
  done

  local processed=$((done_n + pr_n + ready_n + failed_n))
  display_summary "$done_n" "$pr_n" "$ready_n" "$failed_n" "$total_time" "$processed"

  echo ""
  log "Per-feature:"
  for dir in "$STATE_DIR"/*/; do
    [ -d "$dir" ] || continue
    display_feature_result "$(basename "$dir")"
  done

  # Status file for Kanban
  if [ -f "$LIB_DIR/../status-writer.js" ]; then
    ROOT_DIR="$ROOT_DIR" node "$LIB_DIR/../status-writer.js" --json > /dev/null 2>&1 || true
    info "Status: $CONFIG_DIR/status.json"
  fi
}

process_item() {
  local item_json="$1" index="$2" total="$3"

  # Extract fields
  local feat_id title body priority labels deps
  feat_id=$(echo "$item_json" | node -p "JSON.parse(require('fs').readFileSync('/dev/stdin','utf-8')).id")
  title=$(echo "$item_json" | node -p "JSON.parse(require('fs').readFileSync('/dev/stdin','utf-8')).title")
  body=$(echo "$item_json" | node -p "JSON.parse(require('fs').readFileSync('/dev/stdin','utf-8')).body")
  priority=$(echo "$item_json" | node -p "JSON.parse(require('fs').readFileSync('/dev/stdin','utf-8')).priority")
  labels=$(echo "$item_json" | node -p "JSON.parse(require('fs').readFileSync('/dev/stdin','utf-8')).labels.join(', ')")
  deps=$(echo "$item_json" | node -p "JSON.parse(require('fs').readFileSync('/dev/stdin','utf-8')).dependencies.join(', ')||'none'")

  run_feature "$feat_id" "$title" "$body" "$priority" "$labels" "$deps" "$index" "$total"
}

run_feature() {
  local feat_id="$1" title="$2" body="$3" priority="$4" labels="$5" deps="$6" index="$7" total="$8"

  banner "[$index/$total] $feat_id: $title [$priority]"

  # Skip if already completed
  local current
  current=$(wt_get_status "$feat_id")
  if [ "$current" = "done" ] || [ "$current" = "pr-created" ]; then
    info "Skipping $feat_id (status: $current)"
    return 0
  fi
  [ "$current" != "none" ] && info "Resuming $feat_id (status: $current)"

  # Mark as in progress
  wt_update_status "$feat_id" "in-progress" "analysis" 2>/dev/null || true

  # Create worktree (handles stale worktrees from crashed runs)
  info "Creating worktree..."
  local wt_path
  wt_path=$(wt_create "$feat_id" "$BASE_BRANCH")
  info "Worktree: $wt_path"

  # Seed PRD
  local task_dir="$wt_path/tasks/prd-$feat_id"
  mkdir -p "$task_dir"
  cat > "$task_dir/prd-seed.md" <<EOPRD
# $title

## Source
- ID: $feat_id
- Priority: $priority
- Labels: $labels
- Dependencies: $deps
- From: orchestrator backlog ($ADAPTER)

## Description
$body
EOPRD
  info "Seeded PRD"

  # Build context (memory layer 1 + error patterns)
  local context_file
  context_file=$(mem_build_context "$feat_id" "$title" "$priority" "$labels" "$deps" "$body" "$wt_path")
  cp "$context_file" "$wt_path/.orchestrator-context.md"
  info "Context injected"

  # Route tasks to agents (ADR-006)
  local routing_file="$STATE_DIR/$feat_id/routing.json"
  local manifest_file="$CONFIG_DIR/agents-manifest.json"
  local agent_count=0
  [ -f "$manifest_file" ] && agent_count=$(node -p "JSON.parse(require('fs').readFileSync('$manifest_file','utf-8')).agents.length" 2>/dev/null || echo "0")

  if [ "$ROUTING_PREFER" = "true" ] && [ "$agent_count" -gt 0 ]; then
    local tasks_file
    tasks_file=$(find "$wt_path" -name "tasks.md" -path "*/prd-*" 2>/dev/null | head -1)
    if [ -n "$tasks_file" ] && [ -f "$tasks_file" ]; then
      bash "$LIB_DIR/../route-tasks.sh" "$wt_path" "$manifest_file" "$tasks_file" > "$routing_file" 2>/dev/null || echo "[]" > "$routing_file"
      display_routing "$routing_file"
    else
      echo "[]" > "$routing_file"
      info "Tasks: will route after generation"
    fi
  else
    echo "[]" > "$routing_file"
  fi

  # Pipeline invocation
  wt_update_status "$feat_id" "in-progress" "implementation"
  local log_file="$STATE_DIR/$feat_id/logs/run-$(date -u +%Y%m%d-%H%M%S).log"
  local results_file="$STATE_DIR/$feat_id/results.json"
  local exit_code=0

  export ORCHESTRATOR_MODE=true FEATURE_ID="$feat_id"
  export CONTEXT_FILE="$context_file" RESULTS_FILE="$results_file"

  local feat_start
  feat_start=$(date +%s)

  # Invoke feature-marker via Claude Code
  if [ "$AUTONOMY" = "full_auto" ]; then
    info "Autonomy=full_auto — invoking pipeline..."
    if command -v claude &>/dev/null; then
      (cd "$wt_path" && claude --skill feature-marker "prd-$feat_id") 2>&1 | tee "$log_file" || exit_code=$?
    else
      info "Claude CLI not found — simulating pipeline"
      echo "full_auto: simulated pipeline for $feat_id" > "$log_file"
    fi
  elif [ "$AUTONOMY" = "checkpoint" ]; then
    info "Autonomy=checkpoint — pipeline ready, human reviews PR"
    echo "checkpoint: pipeline for $feat_id" > "$log_file"
  else
    info "Autonomy=supervised — paused for review"
    echo "supervised: paused for $feat_id" > "$log_file"
  fi

  local feat_end
  feat_end=$(date +%s)
  local duration=$((feat_end - feat_start))

  # Collect results
  cp "$log_file" "$RESULTS_DIR/${feat_id}_run.log" 2>/dev/null || true
  if [ ! -f "$results_file" ]; then
    node -e "
      require('fs').writeFileSync('$results_file', JSON.stringify({
        feature_id: '$feat_id',
        status: $exit_code === 0 ? 'completed' : ($exit_code === 10 ? 'paused' : 'failed'),
        title: $(printf '%s' "$title" | node -p "JSON.stringify(require('fs').readFileSync('/dev/stdin','utf-8').trim())"),
        pipeline: { prd: { status: 'completed' }, techspec: { status: 'pending' }, tasks: { status: 'pending' }, implementation: { status: 'pending' }, tests: { status: 'pending' }, review: { status: 'pending' } },
        context_generated: { files_created: [], files_modified: [], schema_changes: [], new_dependencies: [], breaking_changes: [] },
        pr_url: null, duration_seconds: $duration, errors: []
      }, null, 2));
    "
  fi

  # Safety guardrails
  if [ -f "$results_file" ]; then
    local has_breaking
    has_breaking=$(node -p "(JSON.parse(require('fs').readFileSync('$results_file','utf-8')).context_generated?.breaking_changes||[]).length>0" 2>/dev/null || echo "false")
    if [ "$has_breaking" = "true" ] && [ "$BREAKING_PAUSE" = "true" ]; then
      info "! BREAKING CHANGES in $feat_id — pausing"
      wt_update_status "$feat_id" "paused" "breaking-change-review"
      return 0
    fi

    local file_count
    file_count=$(node -p "const r=JSON.parse(require('fs').readFileSync('$results_file','utf-8'));(r.context_generated?.files_created||[]).length+(r.context_generated?.files_modified||[]).length" 2>/dev/null || echo "0")
    if [ "$file_count" -gt "$MAX_FILE_CHANGES" ]; then
      info "! $feat_id touched $file_count files (limit: $MAX_FILE_CHANGES) — pausing"
      wt_update_status "$feat_id" "paused" "max-files-review"
      return 0
    fi
  fi

  # Handle result
  if [ "$exit_code" -eq 0 ]; then
    if [ "$AUTONOMY" = "full_auto" ]; then
      # PR creation
      run_pr_creation "$feat_id" "$title" "$wt_path" "$results_file"
    else
      wt_update_status "$feat_id" "ready" "awaiting-pipeline"
      info "Ready: $feat_id"
    fi
  elif [ "$exit_code" -eq 10 ]; then
    wt_update_status "$feat_id" "paused" "awaiting-review"
    info "Paused: $feat_id (supervised mode)"
  else
    # Retry logic
    local retry_count=0
    [ -f "$STATE_DIR/$feat_id/retry-count" ] && retry_count=$(cat "$STATE_DIR/$feat_id/retry-count")
    if [ "$retry_count" -lt "$MAX_RETRIES" ]; then
      retry_count=$((retry_count + 1))
      echo "$retry_count" > "$STATE_DIR/$feat_id/retry-count"
      wt_update_status "$feat_id" "retrying" "retry-$retry_count"
      info "Retrying $feat_id ($retry_count/$MAX_RETRIES)"
      mem_record_error "$feat_id" "implementation" "exit code $exit_code"
    else
      wt_update_status "$feat_id" "failed" "pipeline-error"
      mem_record_error "$feat_id" "implementation" "FINAL FAILURE exit code $exit_code"
      err "$feat_id failed after $MAX_RETRIES attempts"
    fi
  fi

  # Feedback: context + env refresh
  mem_record_context "$feat_id" "$title" "$priority" "$labels" "$wt_path" "$results_file"
  mem_refresh_env

  info "Feature time: ${duration}s"
  echo ""
}

run_pr_creation() {
  local feat_id="$1" title="$2" wt_path="$3" results_file="$4"

  if [ "$PR_STRATEGY" = "none" ]; then
    wt_update_status "$feat_id" "done" "complete"
    info "Done: $feat_id (pr_strategy=none)"
    return 0
  fi

  if ! command -v gh &>/dev/null; then
    wt_update_status "$feat_id" "done" "complete"
    info "Done: $feat_id (no gh CLI — PR skipped)"
    return 0
  fi

  info "Creating PR for $feat_id..."
  (
    cd "$wt_path"
    git add -A 2>/dev/null || true
    git commit -m "feat: $title" --allow-empty >/dev/null 2>&1 || true
    git push origin "${BRANCH_PREFIX:-feat}/$feat_id" >/dev/null 2>&1 || true
  )

  local pr_flag=""
  [ "$PR_STRATEGY" = "draft" ] && pr_flag="--draft"

  local pr_url
  pr_url=$(gh pr create --base "$BASE_BRANCH" --head "${BRANCH_PREFIX:-feat}/$feat_id" \
    --title "feat: $title" \
    --body "Automated by feature-marker orchestrator." \
    $pr_flag 2>/dev/null) || pr_url=""

  if [ -n "$pr_url" ]; then
    wt_update_status "$feat_id" "pr-created" "complete"
    node -e "const fs=require('fs');const r=JSON.parse(fs.readFileSync('$results_file','utf-8'));r.pr_url='$pr_url';r.pipeline.review={status:'completed',pr_url:'$pr_url'};fs.writeFileSync('$results_file',JSON.stringify(r,null,2));" 2>/dev/null || true
    info "PR: $pr_url"
  else
    wt_update_status "$feat_id" "done" "complete"
    info "Done: $feat_id (PR creation failed — skipping)"
  fi
}
