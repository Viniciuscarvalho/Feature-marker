#!/usr/bin/env bash
# scripts/feedback-collector.sh
# Collects execution data from completed features:
# - Appends rich context to global-context.md
# - Tracks error patterns in error-patterns.json
# - Refreshes environment manifest if configured
#
# Usage: feedback-collector.sh <feature_id> <worktree_path> <results_file>

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG_DIR="${CONFIG_DIR:-$ROOT_DIR/.orchestrator}"
STATE_DIR="${STATE_DIR:-$CONFIG_DIR/state}"

FEATURE_ID="${1:?feature_id required}"
WT_PATH="${2:?worktree_path required}"
RESULTS_FILE="${3:-$STATE_DIR/$FEATURE_ID/results.json}"
GLOBAL_CONTEXT="$CONFIG_DIR/global-context.md"
ERROR_PATTERNS="$CONFIG_DIR/error-patterns.json"

# ── 3.1 Context Carry-Forward ────────────────────────────────────

collect_context() {
  local feat_id="$1"
  local wt_path="$2"
  local results="$3"

  # Read results if available
  local title="" branch="" status_val=""
  local files_created="" files_modified=""
  local schema_changes="" new_deps="" breaking=""

  if [ -f "$results" ]; then
    title=$(node -p "JSON.parse(require('fs').readFileSync('$results','utf-8')).title || ''" 2>/dev/null || echo "")
    status_val=$(node -p "JSON.parse(require('fs').readFileSync('$results','utf-8')).status || 'unknown'" 2>/dev/null || echo "unknown")

    # Extract context_generated fields
    files_created=$(node -p "
      const r = JSON.parse(require('fs').readFileSync('$results','utf-8'));
      (r.context_generated?.files_created || []).join(', ') || 'none'
    " 2>/dev/null || echo "none")

    files_modified=$(node -p "
      const r = JSON.parse(require('fs').readFileSync('$results','utf-8'));
      (r.context_generated?.files_modified || []).join(', ') || 'none'
    " 2>/dev/null || echo "none")

    schema_changes=$(node -p "
      const r = JSON.parse(require('fs').readFileSync('$results','utf-8'));
      (r.context_generated?.schema_changes || []).join(', ') || 'none'
    " 2>/dev/null || echo "none")

    new_deps=$(node -p "
      const r = JSON.parse(require('fs').readFileSync('$results','utf-8'));
      (r.context_generated?.new_dependencies || []).join(', ') || 'none'
    " 2>/dev/null || echo "none")

    breaking=$(node -p "
      const r = JSON.parse(require('fs').readFileSync('$results','utf-8'));
      (r.context_generated?.breaking_changes || []).join(', ') || 'none'
    " 2>/dev/null || echo "none")
  fi

  branch="feat/$feat_id"
  [ -z "$title" ] && title="$feat_id"

  # If worktree exists, collect git diff stats
  local diff_stats=""
  if [ -d "$wt_path/.git" ] || [ -f "$wt_path/.git" ]; then
    diff_stats=$(cd "$wt_path" && git diff --stat HEAD~1 2>/dev/null || echo "no diff available")
  fi

  # Append to global-context.md
  cat >> "$GLOBAL_CONTEXT" <<EOGCTX

### $feat_id — $title ($status_val)
- Branch: $branch
- Files created: $files_created
- Files modified: $files_modified
- Schema changes: $schema_changes
- New dependencies: $new_deps
- Breaking changes: $breaking
EOGCTX

  echo "[feedback] Context carry-forward recorded for $feat_id"
}

# ── 3.2 Error Pattern Tracking ───────────────────────────────────

collect_error_pattern() {
  local feat_id="$1"
  local results="$2"
  local log_dir="$STATE_DIR/$feat_id/logs"

  # Only collect if feature failed
  local status_val=""
  if [ -f "$results" ]; then
    status_val=$(node -p "JSON.parse(require('fs').readFileSync('$results','utf-8')).status" 2>/dev/null || echo "")
  fi

  if [ "$status_val" != "failed" ]; then
    return 0
  fi

  # Extract errors from results
  local errors=""
  errors=$(node -p "
    const r = JSON.parse(require('fs').readFileSync('$results','utf-8'));
    (r.errors || []).join('\\n') || 'unknown error'
  " 2>/dev/null || echo "unknown error")

  # Get phase info from status
  local phase="unknown"
  if [ -f "$STATE_DIR/$feat_id/status.json" ]; then
    phase=$(node -p "JSON.parse(require('fs').readFileSync('$STATE_DIR/$feat_id/status.json','utf-8')).phase" 2>/dev/null || echo "unknown")
  fi

  # Collect last log lines for context
  local log_tail=""
  local latest_log
  latest_log=$(ls -t "$log_dir"/*.log 2>/dev/null | head -1)
  if [ -n "$latest_log" ] && [ -f "$latest_log" ]; then
    log_tail=$(tail -5 "$latest_log")
  fi

  # Append structured error to patterns file
  local timestamp
  timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)

  # Initialize error-patterns.json if not exists
  if [ ! -f "$ERROR_PATTERNS" ]; then
    echo '[]' > "$ERROR_PATTERNS"
  fi

  node -e "
    const fs = require('fs');
    const patterns = JSON.parse(fs.readFileSync('$ERROR_PATTERNS', 'utf-8'));
    patterns.push({
      feature_id: '$feat_id',
      timestamp: '$timestamp',
      phase: '$phase',
      error: $(echo "$errors" | node -p "JSON.stringify(require('fs').readFileSync('/dev/stdin','utf-8').trim())"),
      log_tail: $(echo "$log_tail" | node -p "JSON.stringify(require('fs').readFileSync('/dev/stdin','utf-8').trim())"),
      suggestion: 'Review error and check for cross-feature conflicts'
    });
    fs.writeFileSync('$ERROR_PATTERNS', JSON.stringify(patterns, null, 2));
  "

  echo "[feedback] Error pattern logged for $feat_id (phase: $phase)"
}

# ── 3.3 Environment Manifest Refresh ─────────────────────────────

refresh_environment_manifest() {
  local manifest="$CONFIG_DIR/environment.manifest.json"

  if [ -f "$SCRIPT_DIR/environment-discovery.sh" ]; then
    bash "$SCRIPT_DIR/environment-discovery.sh" > "$manifest"
    echo "[feedback] Environment manifest refreshed: $manifest"
  else
    echo "[feedback] No environment-discovery.sh found — skipping manifest refresh"
  fi
}

# ── CLI dispatch ──────────────────────────────────────────────────

case "${4:-all}" in
  context)     collect_context "$FEATURE_ID" "$WT_PATH" "$RESULTS_FILE" ;;
  errors)      collect_error_pattern "$FEATURE_ID" "$RESULTS_FILE" ;;
  environment) refresh_environment_manifest ;;
  all)
    collect_context "$FEATURE_ID" "$WT_PATH" "$RESULTS_FILE"
    collect_error_pattern "$FEATURE_ID" "$RESULTS_FILE"
    ;;
  *)
    echo "Usage: feedback-collector.sh <feature_id> <worktree_path> [results_file] [context|errors|environment|all]"
    exit 1
    ;;
esac
