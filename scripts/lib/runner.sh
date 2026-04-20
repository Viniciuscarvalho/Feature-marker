#!/bin/bash
# lib/runner.sh — Core execution loop
#
# Handles backlog iteration, dependency checking, agent routing,
# Claude CLI invocation, PR creation, retry, and state tracking.
#
# ADR-008 additions:
#   - Phase 0 optimisation: skip Claude when artifacts already exist
#   - run_phase3_tests(): scripted test runner with max 2 fix attempts
#   - dep_check_merge_state(): hard-block dependency polling via git platform CLI
#   - cost_record() calls at each phase boundary (cost.sh)
#   - learning_read() / learning_write() for Phase 3 fix hints (learning.sh)
#   - router_route_task() for stack-aware agent selection (router.sh)
#   - cycle_gate_check() before advancing to next feature (cycle_gate.sh)

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
    # Main loop — ADR-008: check hard-block deps + cycle gate per item
    # ADR-010: process substitution replaces pipe so break/continue work in parent shell
    local index=0
    while IFS= read -r item_json; do
      index=$((index + 1))

      # ADR-008 PR-C: hard-block dependency check
      local feat_id_check
      feat_id_check=$(echo "$item_json" | node -p "JSON.parse(require('fs').readFileSync('/dev/stdin','utf-8')).id")
      local deps_check
      deps_check=$(echo "$item_json" | node -p "JSON.parse(require('fs').readFileSync('/dev/stdin','utf-8')).dependencies.join(',')||''")

      if [ -n "$deps_check" ]; then
        if ! dep_check_merge_state "$feat_id_check" "$deps_check"; then
          info "Skipping $feat_id_check — unmerged dependencies (hard-block)"
          continue
        fi
      fi

      process_item "$item_json" "$index" "$ready_count"

      # ADR-008 PR-D: cycle gate — assert previous feature completed full cycle
      if [ "${OPT_SKIP_CYCLE_CHECK:-false}" != "true" ]; then
        if ! cycle_gate_check "$feat_id_check"; then
          info "Cycle gate: $feat_id_check did not complete full cycle"
          cycle_gate_report "$feat_id_check"
          info "Use --skip-cycle-check to bypass. Stopping backlog loop."
          break
        fi
      fi
    done < <(echo "$items" | node -e "
      const d = JSON.parse(require('fs').readFileSync('/dev/stdin','utf-8'));
      d.ready.forEach(i => console.log(JSON.stringify(i)));
    ")
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

  # ADR-008 PR-A: initialise cost accumulator
  cost_init "$feat_id"

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

  # ── ADR-008 PR-A: Phase 0 optimisation ──────────────────────────
  # If all three artifacts already exist, skip Claude invocation for Phase 0.
  local phase0_cost=0
  if [ -f "$task_dir/prd.md" ] && [ -f "$task_dir/techspec.md" ] && [ -f "$task_dir/tasks.md" ]; then
    info "Phase 0: artifacts exist, skipping generation (cost: 0)"
  else
    info "Phase 0: artifacts missing — Claude will generate them (cost: $COST_PHASE_1_PLANNING)"
    phase0_cost="$COST_PHASE_1_PLANNING"
  fi
  cost_record "$feat_id" "phase0" "$phase0_cost"

  # ── ADR-008 PR-D: feature-sizing gate ───────────────────────────
  # Only run if tasks.md exists (post-generation check on subsequent runs)
  if [ -f "$task_dir/tasks.md" ]; then
    if ! size_gate_check "$feat_id" "$wt_path"; then
      local exceeded_str="${SIZE_EXCEEDED_CRITERIA:+$SIZE_EXCEEDED_CRITERIA }${SIZE_EXCEEDED_TASKS:+$SIZE_EXCEEDED_TASKS }${SIZE_EXCEEDED_FILES:+$SIZE_EXCEEDED_FILES}"
      if ! size_gate_signal "$feat_id" "$AUTONOMY" "$exceeded_str"; then
        wt_update_status "$feat_id" "paused" "size-gate"
        _runner_record_pause "$feat_id" "human" "size-gate"
        return 0
      fi
    fi
  fi

  # Build context (memory layer 1 + error patterns)
  local context_file
  context_file=$(mem_build_context "$feat_id" "$title" "$priority" "$labels" "$deps" "$body" "$wt_path")
  cp "$context_file" "$wt_path/.orchestrator-context.md"
  info "Context injected"

  # ── ADR-008 PR-B: stack detection + agent routing ────────────────
  router_init "$feat_id"

  # Detect stack from worktree file structure
  local wt_file_paths
  wt_file_paths=$(find "$wt_path" -type f \( -name "*.swift" -o -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.py" -o -name "*.rs" -o -name "*.go" \) 2>/dev/null | head -20 | tr '\n' ':')

  local detected_stack="unknown"
  local routed_agent="${ROUTING_FALLBACK:-feature-marker}"

  if [ -n "$wt_file_paths" ]; then
    detected_stack=$(router_detect_stack_from_paths "$wt_file_paths")
    routed_agent=$(router_route_task "$feat_id" "feature" "$wt_file_paths")
    info "Stack: $detected_stack → agent: $routed_agent"
  fi

  export ROUTED_AGENT="$routed_agent"

  # Route tasks via ADR-006 manifest (existing behaviour preserved)
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

  # ADR-008 PR-A: Phase 1 cost record
  cost_record "$feat_id" "phase1" "$COST_PHASE_1_PLANNING"

  # Determine task count and agent type for Phase 2 cost
  local task_count=1
  if [ -f "$task_dir/tasks.md" ]; then
    task_count=$(grep -c "^\- \[" "$task_dir/tasks.md" 2>/dev/null || echo "1")
    [ "$task_count" -eq 0 ] && task_count=1
  fi
  local agent_type="generic"
  [ "$routed_agent" != "feature-marker" ] && agent_type="specialist"
  local phase2_cost
  phase2_cost=$(cost_estimate_phase "2" "$task_count" "$agent_type")
  cost_record "$feat_id" "phase2" "$phase2_cost"

  # Invoke feature-marker via Claude Code
  # All three autonomy modes run the full pipeline; supervised adds --interactive.
  local skill_arg="feature-marker"
  [ "$routed_agent" != "feature-marker" ] && skill_arg="$routed_agent"

  # --interactive flag for supervised mode; empty string otherwise (safe with set -u)
  local interactive_flag=""
  [ "$AUTONOMY" = "supervised" ] && interactive_flag="--interactive"

  # ADR-009 PR-H: quality-warning banner when local generator replacement is active
  if [ "${LOCAL_MODEL_ENABLED:-false}" = "true" ] && [ -n "${LOCAL_MODEL_GENERATOR_MODEL:-}" ]; then
    echo ""
    echo "  ! LOCAL GENERATOR ACTIVE (experimental)"
    echo "    Phase 2/3 code generation via local model: ${LOCAL_MODEL_GENERATOR_MODEL}"
    echo "    Quality tradeoffs apply — see ADR-009 Decision #8."
    echo ""
  fi

  info "Autonomy=$AUTONOMY — invoking pipeline (model: ${MODEL_DEFAULT:-default}, agent: $skill_arg)..."
  (cd "$wt_path" && op_timeout "${SKILL_TIMEOUT_SECONDS:-1800}" \
    claude --skill "$skill_arg" ${interactive_flag:+$interactive_flag} "prd-$feat_id") 2>&1 \
    | tee "$log_file" || exit_code=$?

  # ── ADR-008 PR-A: Phase 3 scripted tests ────────────────────────
  # supervised handles tests interactively inside the Claude session; skip scripted runner.
  if [ "$exit_code" -eq 0 ] && [ "$AUTONOMY" != "supervised" ]; then
    local phase3_fix_attempts=0
    run_phase3_tests "$feat_id" "$wt_path"
    local phase3_exit=$?
    phase3_fix_attempts=$(cat "$STATE_DIR/$feat_id/phase3-fix-attempts" 2>/dev/null || echo "0")
    local phase3_cost
    phase3_cost=$(cost_estimate_phase "3" "$phase3_fix_attempts" "generic")
    cost_record "$feat_id" "phase3" "$phase3_cost"
    [ "$phase3_exit" -ne 0 ] && exit_code="$phase3_exit"
  fi

  # ADR-008 PR-A: Phase 4 cost record
  cost_record "$feat_id" "phase4" "$COST_PHASE_4_COMMIT_PR"

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
        pr_url: null, duration_seconds: $duration, errors: [], tasks: []
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
      _runner_record_pause "$feat_id" "human" "breaking-change-review"
      return 0
    fi

    local file_count
    file_count=$(node -p "const r=JSON.parse(require('fs').readFileSync('$results_file','utf-8'));(r.context_generated?.files_created||[]).length+(r.context_generated?.files_modified||[]).length" 2>/dev/null || echo "0")
    if [ "$file_count" -gt "$MAX_FILE_CHANGES" ]; then
      info "! $feat_id touched $file_count files (limit: $MAX_FILE_CHANGES) — pausing"
      wt_update_status "$feat_id" "paused" "max-files-review"
      _runner_record_pause "$feat_id" "human" "max-files-review"
      return 0
    fi
  fi

  # Handle result
  if [ "$exit_code" -eq 0 ]; then
    if [ "$AUTONOMY" = "full_auto" ] || [ "$AUTONOMY" = "checkpoint" ]; then
      # full_auto: PR with auto-merge configured; checkpoint: draft PR for human review
      run_pr_creation "$feat_id" "$title" "$wt_path" "$results_file"
    else
      # supervised — the interactive session handled Phase 4; mark complete
      wt_update_status "$feat_id" "done" "complete"
      info "Done: $feat_id (supervised)"
    fi
  elif [ "$exit_code" -eq 10 ]; then
    wt_update_status "$feat_id" "paused" "awaiting-review"
    _runner_record_pause "$feat_id" "human" "supervised-checkpoint"
    info "Paused: $feat_id (supervised mode)"
  else
    # Retry logic — transient failures get retried with backoff
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
      _runner_record_pause "$feat_id" "transient" "max-retries-exceeded"
      mem_record_error "$feat_id" "implementation" "FINAL FAILURE exit code $exit_code"
      err "$feat_id failed after $MAX_RETRIES attempts"
    fi
  fi

  # ADR-008 PR-A: print cost summary
  cost_summary "$feat_id"

  # Feedback: context + env refresh
  mem_record_context "$feat_id" "$title" "$priority" "$labels" "$wt_path" "$results_file"
  mem_refresh_env

  # Auto-update global-context.md with a compact summary entry
  local final_status
  final_status=$(wt_get_status "$feat_id")
  if [ "$final_status" = "done" ] || [ "$final_status" = "pr-created" ]; then
    local final_pr_url=""
    [ -f "$results_file" ] && final_pr_url=$(node -p "
      try { JSON.parse(require('fs').readFileSync('$results_file','utf-8')).pr_url || ''; }
      catch(e) { ''; }
    " 2>/dev/null || echo "")
    local final_branch="${BRANCH_PREFIX:-feat}/$feat_id"
    gc_append_feature_summary "$feat_id" "$final_branch" "$final_status" "$final_pr_url"
  fi

  info "Feature time: ${duration}s"
  echo ""
}

# ── run_phase3_tests ──────────────────────────────────────────────────
# ADR-008 PR-A: Scripted test runner for Phase 3.
# Detects stack, runs the appropriate test command.
# On failure, invokes Claude for a fix (max 2 attempts).
# Captures successful fixes to the learning store.
# Writes fix attempt count to $STATE_DIR/$feat_id/phase3-fix-attempts.
# Returns 0 on success (tests pass), 1 on persistent failure.

run_phase3_tests() {
  local feat_id="$1"
  local wt_path="$2"

  local fix_attempts=0
  echo "$fix_attempts" > "$STATE_DIR/$feat_id/phase3-fix-attempts"

  # Detect stack from worktree
  local wt_file_paths
  wt_file_paths=$(find "$wt_path" -type f \( -name "*.swift" -o -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.py" -o -name "*.rs" -o -name "*.go" \) 2>/dev/null | head -20 | tr '\n' ':')
  local stack="unknown"
  [ -n "$wt_file_paths" ] && stack=$(router_detect_stack_from_paths "$wt_file_paths")

  # Map stack to test command
  local test_cmd=""
  case "$stack" in
    ios)    test_cmd="swift test" ;;
    node)   test_cmd="jest" ;;
    rust)   test_cmd="cargo test" ;;
    python) test_cmd="pytest" ;;
    go)     test_cmd="go test ./..." ;;
    *)
      info "Phase 3: unknown stack — skipping scripted tests"
      return 0
      ;;
  esac

  info "Phase 3: running tests ($stack): $test_cmd"

  local test_output
  local test_exit=0

  (cd "$wt_path" && eval "$test_cmd" >/tmp/phase3-test-output-$$.txt 2>&1) || test_exit=$?

  if [ "$test_exit" -eq 0 ]; then
    info "Phase 3: tests passed"
    return 0
  fi

  test_output=$(cat /tmp/phase3-test-output-$$.txt 2>/dev/null || echo "test output unavailable")
  rm -f /tmp/phase3-test-output-$$.txt

  # Fix loop — max 2 attempts
  local max_fix_attempts=2

  while [ "$fix_attempts" -lt "$max_fix_attempts" ]; do
    fix_attempts=$((fix_attempts + 1))
    echo "$fix_attempts" > "$STATE_DIR/$feat_id/phase3-fix-attempts"

    info "Phase 3: fix attempt $fix_attempts/$max_fix_attempts"

    # ADR-008 PR-C: check learning store for a known fix
    local error_sig
    error_sig=$(echo "$test_output" | head -5 | tr '\n' ' ' | sed 's/  */ /g')
    local learned_fix
    learned_fix=$(learning_read "$feat_id" "$error_sig")

    local fix_prompt="Fix the failing tests. Test output:\n$test_output"
    if [ -n "$learned_fix" ] && [ "$learned_fix" != "null" ]; then
      local hint
      hint=$(echo "$learned_fix" | node -p "JSON.parse(require('fs').readFileSync('/dev/stdin','utf-8')).fix" 2>/dev/null || echo "")
      if [ -n "$hint" ]; then
        info "Phase 3: applying learned fix hint"
        fix_prompt="$fix_prompt\n\nKnown fix hint: $hint"
      fi
    fi

    local model_flag=""
    [ -n "${MODEL_DEFAULT:-}" ] && model_flag="--model $MODEL_DEFAULT"

    local fix_exit=0
    if command -v claude &>/dev/null; then
      (cd "$wt_path" && printf '%b' "$fix_prompt" | claude $model_flag --print) 2>/dev/null || fix_exit=$?
    else
      info "Phase 3: Claude CLI not found — cannot attempt fix"
      return 1
    fi

    # Re-run tests
    test_exit=0
    (cd "$wt_path" && eval "$test_cmd" >/tmp/phase3-test-output-$$.txt 2>&1) || test_exit=$?

    if [ "$test_exit" -eq 0 ]; then
      info "Phase 3: tests passed after fix attempt $fix_attempts"

      # ADR-008 PR-C: capture successful fix to learning store
      local fix_description
      fix_description=$(printf '%b' "$fix_prompt" | head -3 | tr '\n' ' ')
      learning_write "$feat_id" "$error_sig" "$fix_description"

      # Verify the learning entry
      local project_path
      project_path="$ROOT_DIR/.claude/feature-state/learned.json"
      if [ -f "$project_path" ]; then
        local learn_id
        learn_id=$(node -p "
          try {
            const entries = JSON.parse(require('fs').readFileSync('$project_path','utf-8'));
            const match = entries.find(e => !e.archived && e.pattern === $(node -p "JSON.stringify('$error_sig')" 2>/dev/null || echo "''"));
            match ? match.id : '';
          } catch(e) { ''; }
        " 2>/dev/null || echo "")
        [ -n "$learn_id" ] && learning_verify "$learn_id" "true" "$project_path"
      fi

      rm -f /tmp/phase3-test-output-$$.txt
      return 0
    fi

    test_output=$(cat /tmp/phase3-test-output-$$.txt 2>/dev/null || echo "test output unavailable")
    rm -f /tmp/phase3-test-output-$$.txt
    mem_record_error "$feat_id" "phase3" "fix attempt $fix_attempts failed: $test_cmd"
  done

  err "Phase 3: tests still failing after $max_fix_attempts fix attempts"
  return 1
}

# ── dep_check_merge_state ─────────────────────────────────────────────
# ADR-008 PR-C: Hard-block dependency check.
# For each dependency ID, looks up the parent PR number from its results.json,
# then queries the git platform CLI to confirm the PR is merged.
# Returns 0 if all deps are merged (or have no PR data); 1 if any dep is unmerged.

dep_check_merge_state() {
  local feat_id="$1"
  local deps_csv="$2"  # comma-separated list of dependency feature IDs

  [ -z "$deps_csv" ] && return 0

  # Determine platform (uses ADAPTER already loaded by config.sh)
  local platform="github"
  case "${ADAPTER:-markdown}" in
    github)   platform="github" ;;
    linear)   platform="github" ;;  # assume GitHub for PR checks
    *)        platform="github" ;;
  esac

  # Check if az or glab CLI present to override platform detection
  if command -v glab &>/dev/null; then
    platform="gitlab"
  elif command -v az &>/dev/null; then
    platform="azure"
  fi

  local all_merged=0
  local IFS_ORIG="$IFS"
  IFS=","
  for dep_id in $deps_csv; do
    IFS="$IFS_ORIG"
    dep_id=$(echo "$dep_id" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
    [ -z "$dep_id" ] && continue

    local dep_results="$STATE_DIR/$dep_id/results.json"
    if [ ! -f "$dep_results" ]; then
      info "Dep $dep_id: no results.json — assuming not yet run (allowing)"
      IFS=","
      continue
    fi

    local pr_url
    pr_url=$(node -p "
      try {
        const r = JSON.parse(require('fs').readFileSync('$dep_results','utf-8'));
        r.pr_url || '';
      } catch(e) { ''; }
    " 2>/dev/null || echo "")

    if [ -z "$pr_url" ]; then
      info "Dep $dep_id: no PR URL recorded — assuming not complete (blocking)"
      all_merged=1
      IFS=","
      continue
    fi

    # Extract PR number from URL
    local pr_num
    pr_num=$(echo "$pr_url" | sed 's|.*/||')

    local is_merged=false
    case "$platform" in
      github)
        if command -v gh &>/dev/null; then
          local gh_state
          gh_state=$(gh pr view "$pr_num" --json state,mergedAt 2>/dev/null || echo '{}')
          is_merged=$(echo "$gh_state" | node -p "
            try {
              const d = JSON.parse(require('fs').readFileSync('/dev/stdin','utf-8'));
              (d.state === 'MERGED' || (d.mergedAt && d.mergedAt.length > 0)) ? 'true' : 'false';
            } catch(e) { 'false'; }
          " 2>/dev/null || echo "false")
        else
          info "Dep $dep_id: gh CLI not available — assuming merged (allowing)"
          is_merged="true"
        fi
        ;;
      azure)
        if command -v az &>/dev/null; then
          local az_state
          az_state=$(az repos pr show --id "$pr_num" 2>/dev/null || echo '{}')
          is_merged=$(echo "$az_state" | node -p "
            try {
              const d = JSON.parse(require('fs').readFileSync('/dev/stdin','utf-8'));
              d.status === 'completed' ? 'true' : 'false';
            } catch(e) { 'false'; }
          " 2>/dev/null || echo "false")
        else
          info "Dep $dep_id: az CLI not available — assuming merged (allowing)"
          is_merged="true"
        fi
        ;;
      gitlab)
        if command -v glab &>/dev/null; then
          local glab_out
          glab_out=$(glab mr view "$pr_num" 2>/dev/null || echo "state: open")
          echo "$glab_out" | grep -qi "merged" && is_merged="true" || is_merged="false"
        else
          info "Dep $dep_id: glab CLI not available — assuming merged (allowing)"
          is_merged="true"
        fi
        ;;
    esac

    if [ "$is_merged" != "true" ]; then
      info "Dep $dep_id: PR #$pr_num not yet merged (state: unmerged)"
      all_merged=1
    else
      info "Dep $dep_id: PR #$pr_num merged — OK"
    fi

    IFS=","
  done
  IFS="$IFS_ORIG"

  return $all_merged
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
    # ADR-009 PR-G / ADR-010: trigger background review-ingest when available
    if declare -f ingest_trigger_if_merged &>/dev/null; then
      ingest_trigger_if_merged "$feat_id"
    fi
  else
    wt_update_status "$feat_id" "done" "complete"
    info "Done: $feat_id (PR creation failed — skipping)"
  fi
}

# ── _runner_record_pause ──────────────────────────────────────────────
# Internal: write pause taxonomy record to .orchestrator/state/{feat_id}/pause.json
# pause_kind: "human" (operator must --ack) | "transient" (auto-retry on next run)

_runner_record_pause() {
  local feat_id="$1"
  local pause_kind="$2"  # human | transient
  local reason="$3"

  local pause_file="$STATE_DIR/$feat_id/pause.json"
  mkdir -p "$STATE_DIR/$feat_id"
  node -e "
    const fs = require('fs');
    fs.writeFileSync('$pause_file', JSON.stringify({
      feat_id: '$feat_id',
      pause_kind: '$pause_kind',
      reason: '$reason',
      paused_at: new Date().toISOString()
    }, null, 2));
  " 2>/dev/null || true
}

# ── runner_clear_sentinels ────────────────────────────────────────────
# Usage: runner_clear_sentinels <feat_id> <class>
# class: "transient" — removes retry-count and phase3-fix-attempts
#        "all"       — also removes pause.json (use with --ack)

runner_clear_sentinels() {
  local feat_id="$1"
  local class="${2:-transient}"

  local state_dir="$STATE_DIR/$feat_id"
  [ ! -d "$state_dir" ] && return 0

  rm -f "$state_dir/retry-count"
  rm -f "$state_dir/phase3-fix-attempts"
  info "Sentinels cleared (transient) for $feat_id"

  if [ "$class" = "all" ]; then
    rm -f "$state_dir/pause.json"
    info "Sentinels cleared (human) for $feat_id"
  fi
}

# ── run_feature_resume ────────────────────────────────────────────────
# Usage: run_feature_resume <feat_id> [--ack]
# Re-enters a paused feature from its checkpoint.
# --ack required for human-class pauses.

run_feature_resume() {
  local feat_id="$1"
  local ack=false
  [ "${2:-}" = "--ack" ] && ack=true

  local pause_file="$STATE_DIR/$feat_id/pause.json"
  local results_file="$STATE_DIR/$feat_id/results.json"

  if [ ! -f "$results_file" ]; then
    err "resume: no results.json for $feat_id — has it run at all?"
    return 1
  fi

  local pause_kind="transient"
  local reason=""
  if [ -f "$pause_file" ]; then
    pause_kind=$(node -p "try{JSON.parse(require('fs').readFileSync('$pause_file','utf-8')).pause_kind||'transient'}catch(e){'transient'}" 2>/dev/null || echo "transient")
    reason=$(node -p "try{JSON.parse(require('fs').readFileSync('$pause_file','utf-8')).reason||''}catch(e){''}" 2>/dev/null || echo "")
  fi

  if [ "$pause_kind" = "human" ] && [ "$ack" != "true" ]; then
    err "resume: $feat_id is paused with pause_kind=human (reason: $reason)"
    err "Use --resume-paused $feat_id --ack to acknowledge and resume."
    return 1
  fi

  info "Resuming $feat_id (pause_kind: $pause_kind, reason: $reason)"
  runner_clear_sentinels "$feat_id" "$( [ "$pause_kind" = "human" ] && echo all || echo transient )"

  # Re-enter from the saved checkpoint phase or from the beginning
  local checkpoint_file="$STATE_DIR/$feat_id/checkpoint.json"
  local resume_phase="phase0"
  if [ -f "$checkpoint_file" ]; then
    resume_phase=$(node -e "
      const cp = JSON.parse(require('fs').readFileSync('$checkpoint_file','utf-8'));
      const phases = ['phase0','phase1','phase2','phase3','phase4'];
      const last = phases.slice().reverse().find(p => cp[p] && cp[p].status === 'complete');
      const next = last ? phases[phases.indexOf(last)+1] : phases[0];
      console.log(next || 'done');
    " 2>/dev/null || echo "phase0")
  fi

  if [ "$resume_phase" = "done" ]; then
    info "$feat_id appears complete (all phases done). Nothing to resume."
    return 0
  fi

  info "Resuming $feat_id from $resume_phase"

  # Extract title from results.json and re-invoke run_feature
  local title
  title=$(node -p "try{JSON.parse(require('fs').readFileSync('$results_file','utf-8')).title||'$feat_id'}catch(e){'$feat_id'}" 2>/dev/null || echo "$feat_id")

  # Re-enter run_feature with sentinel context set to resume
  export RUNNER_RESUME_FROM="$resume_phase"
  run_feature "$feat_id" "$title" "" "medium" "" "" "1" "1"
  unset RUNNER_RESUME_FROM
}
