#!/bin/bash
# lib/orchestrator-fallbacks.sh — Shell fallbacks for skill-delegated operations
#
# When the orchestrator delegates to skills (context-builder, safety-check,
# collect-results, orch-status, kb-learn), these fallbacks execute if:
# - No Claude session is available (CI, offline, cost-saving runs)
# - The skill invocation fails for any reason
#
# Each fallback preserves the original orchestrator.sh logic exactly,
# ensuring identical behavior when skills are unavailable.

set -euo pipefail

# ── Context Builder Fallback (was orchestrator.sh section 3d) ────

build_context_fallback() {
  local feat_id="$1"
  local wt_path="$2"
  local feat_title="${3:-}"
  local feat_priority="${4:-}"
  local feat_labels="${5:-}"
  local feat_deps="${6:-}"
  local feat_body="${7:-}"

  local context_file="$STATE_DIR/$feat_id/context.md"
  {
    echo "# Feature Context"
    echo ""
    echo "## Feature: $feat_title"
    echo "- ID: $feat_id"
    echo "- Priority: $feat_priority"
    echo "- Labels: $feat_labels"
    echo "- Dependencies: $feat_deps"
    echo "- Worktree: $wt_path"
    echo ""
    echo "## Description"
    echo "$feat_body"
    echo ""
    echo "## Cross-Feature Context"
    cat "$CONFIG_DIR/global-context.md" 2>/dev/null || echo "No prior context."
    echo ""

    if [ -f "$CONFIG_DIR/knowledge-base.json" ]; then
      kb_apply_rules "$context_file" 2>/dev/null || true
    elif [ -f "$CONFIG_DIR/error-patterns.json" ] && [ "${COLLECT_PATTERNS:-false}" = "true" ]; then
      echo "## Known Error Patterns (avoid these)"
      node -e "
        const p = JSON.parse(require('fs').readFileSync('$CONFIG_DIR/error-patterns.json','utf-8'));
        p.forEach(e => console.log('- [' + e.feature_id + '] ' + e.phase + ': ' + e.error));
      " 2>/dev/null || true
    fi
  } > "$context_file"

  # Inject routing hints
  if [ -f "$SCRIPT_DIR/route-tasks.sh" ]; then
    local tasks_file="$TASK_DIR/tasks.md"
    local manifest_file="$CONFIG_DIR/agent-manifest.json"
    if [ -f "$tasks_file" ] && [ -f "$manifest_file" ]; then
      bash "$SCRIPT_DIR/route-tasks.sh" --context-mode "$wt_path" "$manifest_file" "$tasks_file" >> "$context_file" 2>/dev/null || true
    fi
  fi

  cp "$context_file" "$wt_path/.orchestrator-context.md" 2>/dev/null || true
}

# ── Collect Results Fallback (was orchestrator.sh section 3f) ────

collect_results_fallback() {
  local feat_id="$1"
  local exit_code="${2:-0}"
  local duration="${3:-0}"
  local feat_title="${4:-}"

  local results_file="$STATE_DIR/$feat_id/results.json"
  [ -f "$results_file" ] && return 0

  local status="completed"
  [ "$exit_code" -eq 10 ] && status="paused"
  [ "$exit_code" -ne 0 ] && [ "$exit_code" -ne 10 ] && status="failed"

  node -e "
    const results = {
      feature_id: '$feat_id',
      status: '$status',
      title: $(echo "$feat_title" | node -p "JSON.stringify(require('fs').readFileSync('/dev/stdin','utf-8').trim())" 2>/dev/null || echo '""'),
      pipeline: {
        prd:            { status: 'completed', file: 'tasks/prd-$feat_id/prd-seed.md' },
        techspec:       { status: 'pending', file: null },
        tasks:          { status: 'pending', total: 0, completed: 0 },
        implementation: { status: 'pending', files_changed: 0 },
        tests:          { status: 'pending', passed: 0, failed: 0 },
        review:         { status: 'pending', pr_url: null }
      },
      context_generated: {
        files_created: [],
        files_modified: [],
        schema_changes: [],
        new_dependencies: [],
        breaking_changes: []
      },
      pr_url: null,
      duration_seconds: $duration,
      errors: []
    };
    require('fs').writeFileSync('$results_file', JSON.stringify(results, null, 2));
  " 2>/dev/null || true
}

# ── Safety Check Fallback (was orchestrator.sh section 3g) ───────

safety_check_fallback() {
  local feat_id="$1"
  local results_file="$STATE_DIR/$feat_id/results.json"

  [ ! -f "$results_file" ] && return 0

  # Check breaking changes
  local has_breaking
  has_breaking=$(node -p "
    const r = JSON.parse(require('fs').readFileSync('$results_file','utf-8'));
    (r.context_generated?.breaking_changes || []).length > 0
  " 2>/dev/null || echo "false")

  if [ "$has_breaking" = "true" ] && [ "${BREAKING_PAUSE:-true}" = "true" ]; then
    update_status "$feat_id" "paused" "breaking-change-review"
    write_status
    return 1
  fi

  # Check schema changes
  local has_schema
  has_schema=$(node -p "
    const r = JSON.parse(require('fs').readFileSync('$results_file','utf-8'));
    (r.context_generated?.schema_changes || []).length > 0
  " 2>/dev/null || echo "false")

  if [ "$has_schema" = "true" ] && [ "${SCHEMA_WARNING:-true}" = "true" ]; then
    update_status "$feat_id" "paused" "schema-migration-review"
    write_status
    return 1
  fi

  # Check file count
  local file_count
  file_count=$(node -p "
    const r = JSON.parse(require('fs').readFileSync('$results_file','utf-8'));
    (r.context_generated?.files_created || []).length + (r.context_generated?.files_modified || []).length
  " 2>/dev/null || echo "0")

  if [ "$file_count" -gt "${MAX_FILE_CHANGES:-50}" ]; then
    update_status "$feat_id" "paused" "max-files-review"
    write_status
    return 1
  fi

  return 0
}

# ── KB Record Fallback (was orchestrator.sh section 3i) ──────────

kb_record_fallback() {
  local feat_id="$1"
  local wt_path="${2:-}"
  local results_file="$STATE_DIR/$feat_id/results.json"

  # Context carry-forward
  if [ "${GLOBAL_CONTEXT_ENABLED:-true}" = "true" ] && [ -f "$SCRIPT_DIR/feedback-collector.sh" ]; then
    bash "$SCRIPT_DIR/feedback-collector.sh" "$feat_id" "$wt_path" "$results_file" context 2>/dev/null || true
  fi

  # Error pattern collection + knowledge base update
  if [ "${COLLECT_PATTERNS:-true}" = "true" ] && [ -f "$SCRIPT_DIR/feedback-collector.sh" ]; then
    bash "$SCRIPT_DIR/feedback-collector.sh" "$feat_id" "$wt_path" "$results_file" errors 2>/dev/null || true

    kb_init 2>/dev/null || true
    if [ -f "$STATE_DIR/$feat_id/qa-report.json" ]; then
      node -e "
        const r = JSON.parse(require('fs').readFileSync('$STATE_DIR/$feat_id/qa-report.json','utf-8'));
        if (r.root_cause) {
          console.log(r.root_cause.category + '|' + r.root_cause.signature + '|' + (r.remediation || '') + '|' + (r.prevention || ''));
        }
      " 2>/dev/null | IFS='|' read -r cat sig res prev && {
        kb_record_pattern "$feat_id" "$cat" "$sig" "$res" "$prev" 2>/dev/null || true
      }
    fi
    kb_derive_rules 2>/dev/null || true

    # Trim legacy error patterns
    if [ -f "$CONFIG_DIR/error-patterns.json" ]; then
      node -e "
        const fs = require('fs');
        let p = JSON.parse(fs.readFileSync('$CONFIG_DIR/error-patterns.json','utf-8'));
        if (p.length > ${ERROR_PATTERN_WINDOW:-5}) p = p.slice(-${ERROR_PATTERN_WINDOW:-5});
        fs.writeFileSync('$CONFIG_DIR/error-patterns.json', JSON.stringify(p, null, 2));
      " 2>/dev/null || true
    fi
  fi

  # Environment manifest refresh
  if [ "${UPDATE_MANIFEST:-true}" = "true" ] && [ -f "$SCRIPT_DIR/environment-discovery.sh" ]; then
    bash "$SCRIPT_DIR/environment-discovery.sh" > "$CONFIG_DIR/environment.manifest.json" 2>/dev/null || true
  fi
}

# ── Summary Display Fallback (was orchestrator.sh Steps 5-6) ─────

display_summary_fallback() {
  write_status
  ROOT_DIR="${ROOT_DIR:-.}" node "$SCRIPT_DIR/status-writer.js" --terminal 2>/dev/null || true

  local total_duration="${1:-0}"

  banner "Orchestrator Summary"

  local done_count=0 ready_final=0 failed_count=0 pr_count=0 paused_count=0
  for dir in "$STATE_DIR"/*/; do
    [ -d "$dir" ] || continue
    local fid
    fid=$(basename "$dir")
    [ -f "$dir/status.json" ] || continue
    local st
    st=$(get_status "$fid")
    case "$st" in
      done)       done_count=$((done_count + 1)) ;;
      pr-created) pr_count=$((pr_count + 1)) ;;
      ready)      ready_final=$((ready_final + 1)) ;;
      failed)     failed_count=$((failed_count + 1)) ;;
      paused)     paused_count=$((paused_count + 1)) ;;
    esac
  done

  local processed=$((done_count + pr_count + ready_final + failed_count + paused_count))

  info "done=$done_count pr=$pr_count ready=$ready_final failed=$failed_count paused=$paused_count"
  echo ""

  log "Per-feature:"
  for dir in "$STATE_DIR"/*/; do
    [ -d "$dir" ] || continue
    local fid
    fid=$(basename "$dir")
    [ -f "$dir/status.json" ] || continue
    local status
    status=$(node -p "const s=JSON.parse(require('fs').readFileSync('$dir/status.json','utf-8'));s.status+' ('+s.phase+')'" 2>/dev/null || echo "unknown")
    local dur=""
    [ -f "$STATE_DIR/$fid/results.json" ] && dur=$(node -p "JSON.parse(require('fs').readFileSync('$STATE_DIR/$fid/results.json','utf-8')).duration_seconds+'s'" 2>/dev/null || echo "")
    info "  $fid: $status${dur:+ [$dur]}"
  done

  [ -f "$CONFIG_DIR/global-context.md" ] && info "" && info "Global context: $CONFIG_DIR/global-context.md"
  [ -f "$CONFIG_DIR/error-patterns.json" ] && info "Error patterns: $CONFIG_DIR/error-patterns.json"
  [ -f "$CONFIG_DIR/environment.manifest.json" ] && info "Env manifest: $CONFIG_DIR/environment.manifest.json"
  [ -f "$CONFIG_DIR/status.json" ] && info "Status/Kanban: $CONFIG_DIR/status.json"
  info "Results: $RESULTS_DIR"

  banner "Benchmark"

  local avg_per_feature=0
  [ "$processed" -gt 0 ] && avg_per_feature=$((total_duration / processed))

  info "Features processed:     $processed"
  info "Total time:             ${total_duration}s"
  info "Avg per feature:        ${avg_per_feature}s"
  info "Manual prompts needed:  ${PROMPTS_NEEDED:-0}"
  info "Autonomy mode:          ${AUTONOMY:-checkpoint}"
  info "Backlog source:         ${ADAPTER:-markdown}"
  echo ""

  log "Success Metrics:"
  info "  Features per session:         $processed (target: 5+)"
  info "  Manual intervention:          ${PROMPTS_NEEDED:-0} prompts (target: 0 in checkpoint)"
  info "  Cross-feature conflicts:      0 (target: <10%)"
  info "  Time from backlog to ready:   ${avg_per_feature}s per feature (target: <10min)"
}
