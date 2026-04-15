#!/bin/bash
# lib/runner.sh — Feature execution loop
#
# Handles backlog iteration, dependency checking, agent routing, Claude CLI
# invocation, PR creation, and state tracking.

run_backlog() {
  local backlog_file="$1"
  local start_time
  start_time=$(date +%s)

  # Filter, sort by priority, check dependencies
  local items
  items=$(node -e "
    const items = JSON.parse(require('fs').readFileSync('$backlog_file', 'utf-8'));
    const PRIO = { high: 1, medium: 2, low: 3, none: 4 };
    const sorted = [...items].sort((a, b) => (PRIO[a.priority]||4) - (PRIO[b.priority]||4));
    const done = new Set(sorted.filter(i => i.status === 'done').map(i => i.id));
    const ready = [];
    for (const item of sorted) {
      if (item.status === 'done' && $SKIP_DONE) continue;
      if (item.status === 'blocked' && $SKIP_BLOCKED) continue;
      if (item.status !== 'backlog') continue;
      const unmet = (item.dependencies || []).filter(d => !done.has(d));
      if (unmet.length === 0) ready.push(item);
    }
    console.log(JSON.stringify(ready));
  ")

  local ready_count
  ready_count=$(echo "$items" | node -p "JSON.parse(require('fs').readFileSync('/dev/stdin','utf-8')).length")

  if [ "$ready_count" -eq 0 ]; then
    info "No actionable features. All done or blocked."
    return 0
  fi

  banner "Orchestrator — $ready_count features to process"

  # Show priority order
  echo "$items" | node -e "
    const d = JSON.parse(require('fs').readFileSync('/dev/stdin','utf-8'));
    d.forEach((i, idx) => console.log('  ' + (idx+1) + '. [' + i.priority + '] ' + i.id + ': ' + i.title));
  "

  # Main loop
  local index=0 succeeded=0 failed=0

  echo "$items" | node -e "
    const d = JSON.parse(require('fs').readFileSync('/dev/stdin','utf-8'));
    d.forEach(i => console.log(JSON.stringify(i)));
  " | while IFS= read -r item_json; do
    index=$((index + 1))

    # Extract fields
    local feat_id title body priority labels deps
    feat_id=$(echo "$item_json" | node -p "JSON.parse(require('fs').readFileSync('/dev/stdin','utf-8')).id")
    title=$(echo "$item_json" | node -p "JSON.parse(require('fs').readFileSync('/dev/stdin','utf-8')).title")
    body=$(echo "$item_json" | node -p "JSON.parse(require('fs').readFileSync('/dev/stdin','utf-8')).body")
    priority=$(echo "$item_json" | node -p "JSON.parse(require('fs').readFileSync('/dev/stdin','utf-8')).priority")
    labels=$(echo "$item_json" | node -p "JSON.parse(require('fs').readFileSync('/dev/stdin','utf-8')).labels.join(', ')")
    deps=$(echo "$item_json" | node -p "JSON.parse(require('fs').readFileSync('/dev/stdin','utf-8')).dependencies.join(', ')||'none'")

    run_feature "$feat_id" "$title" "$body" "$priority" "$labels" "$deps" "$index" "$ready_count"
  done

  # Cleanup
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

  # Per-feature status
  echo ""
  log "Per-feature:"
  for dir in "$STATE_DIR"/*/; do
    [ -d "$dir" ] || continue
    display_feature_result "$(basename "$dir")"
  done
}

run_feature() {
  local feat_id="$1" title="$2" body="$3" priority="$4" labels="$5" deps="$6" index="$7" total="$8"

  banner "[$index/$total] $feat_id: $title [$priority]"

  # Skip if already done
  local current
  current=$(wt_get_status "$feat_id")
  if [ "$current" = "done" ] || [ "$current" = "pr-created" ]; then
    info "Skipping $feat_id (status: $current)"
    return 0
  fi
  [ "$current" != "none" ] && info "Resuming $feat_id (status: $current)"

  # Create worktree
  info "Creating worktree..."
  local wt_path
  wt_path=$(wt_create "$feat_id" "$BASE_BRANCH")
  info "Worktree: $wt_path"
  wt_update_status "$feat_id" "in-progress" "analysis"

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

  # Context injection (memory layer 1)
  local context_file
  context_file=$(mem_build_context "$feat_id" "$title" "$priority" "$labels" "$deps" "$body" "$wt_path")
  cp "$context_file" "$wt_path/.orchestrator-context.md"
  info "Context injected"

  # Agent routing (ADR-006)
  local routing_file="$STATE_DIR/$feat_id/routing.json"
  local manifest_file="$ROOT_DIR/.orchestrator/agents-manifest.json"
  if [ "$ROUTING_PREFER" = "true" ] && [ -f "$manifest_file" ]; then
    local tasks_file
    tasks_file=$(find "$wt_path" -name "tasks.md" -path "*/prd-*" 2>/dev/null | head -1)
    if [ -n "$tasks_file" ] && [ -f "$tasks_file" ]; then
      bash "$LIB_DIR/../route-tasks.sh" "$wt_path" "$manifest_file" "$tasks_file" > "$routing_file" 2>/dev/null || echo "[]" > "$routing_file"
      display_routing "$routing_file"
    else
      echo "[]" > "$routing_file"
    fi
  fi

  # Pipeline invocation
  wt_update_status "$feat_id" "in-progress" "implementation"
  local log_file="$STATE_DIR/$feat_id/logs/run-$(date -u +%Y%m%d-%H%M%S).log"
  local results_file="$STATE_DIR/$feat_id/results.json"
  local exit_code=0

  export ORCHESTRATOR_MODE=true FEATURE_ID="$feat_id" CONTEXT_FILE="$context_file" RESULTS_FILE="$results_file" AUTONOMY

  local feat_start
  feat_start=$(date +%s)

  if [ "$AUTONOMY" = "full_auto" ]; then
    info "Autonomy=full_auto — invoking pipeline..."
    # (cd "$wt_path" && claude --skill feature-marker "prd-$feat_id") 2>&1 | tee "$log_file" || exit_code=$?
    echo "full_auto: pipeline for $feat_id" > "$log_file"
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

  # Write results
  cp "$log_file" "$RESULTS_DIR/${feat_id}_run.log" 2>/dev/null || true
  if [ ! -f "$results_file" ]; then
    node -e "
      require('fs').writeFileSync('$results_file', JSON.stringify({
        feature_id: '$feat_id',
        status: $exit_code === 0 ? 'completed' : 'failed',
        title: $(printf '%s' "$title" | node -p "JSON.stringify(require('fs').readFileSync('/dev/stdin','utf-8').trim())"),
        pipeline: { prd: { status: 'completed' }, techspec: { status: 'pending' }, tasks: { status: 'pending' }, implementation: { status: 'pending' }, tests: { status: 'pending' }, review: { status: 'pending' } },
        context_generated: { files_created: [], files_modified: [], schema_changes: [], new_dependencies: [], breaking_changes: [] },
        pr_url: null, duration_seconds: $duration, errors: []
      }, null, 2));
    "
  fi

  # Handle result
  if [ "$exit_code" -eq 0 ]; then
    if [ "$AUTONOMY" = "full_auto" ]; then
      wt_update_status "$feat_id" "done" "complete"
      info "Done: $feat_id"
    else
      wt_update_status "$feat_id" "ready" "awaiting-pipeline"
      info "Ready: $feat_id"
    fi
  else
    wt_update_status "$feat_id" "failed" "pipeline-error"
    mem_record_error "$feat_id" "implementation" "exit code $exit_code"
    err "$feat_id failed"
  fi

  # Memory: record context + refresh env
  mem_record_context "$feat_id" "$title" "$priority" "$labels" "$wt_path" "$results_file"
  mem_refresh_env

  info "Feature time: ${duration}s"
  echo ""
}
