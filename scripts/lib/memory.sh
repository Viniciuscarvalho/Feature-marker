#!/bin/bash
# lib/memory.sh — Session-scoped memory (ADR-002)
#
# Layer 1: Context carry-forward (global-context.md) — what changed
# Layer 2: Error patterns (errors.log) — what failed and why
# Layer 3: Environment refresh — re-run discovery between features

CONTEXT_DIR="${CONTEXT_DIR:-$ROOT_DIR/.orchestrator}"

# ── Layer 1: Build context file for a feature ────────────────────

mem_build_context() {
  local feat_id="$1"
  local title="$2"
  local priority="$3"
  local labels="$4"
  local deps="$5"
  local body="$6"
  local wt_path="$7"

  local context_file="$CONTEXT_DIR/state/$feat_id/context.md"

  {
    echo "# Feature Context"
    echo ""
    echo "## Feature: $title"
    echo "- ID: $feat_id"
    echo "- Priority: $priority"
    echo "- Labels: $labels"
    echo "- Dependencies: $deps"
    echo "- Worktree: $wt_path"
    echo ""
    echo "## Description"
    echo "$body"
    echo ""
    echo "## Cross-Feature Context"
    if [ -f "$CONTEXT_DIR/global-context.md" ]; then
      # ADR-011 PR-B: sanitize each chunk from global-context before injecting
      if declare -f sanitize_context_chunk &>/dev/null; then
        sanitize_context_chunk "$(cat "$CONTEXT_DIR/global-context.md")" 50 2>/dev/null \
          || cat "$CONTEXT_DIR/global-context.md"
      else
        cat "$CONTEXT_DIR/global-context.md"
      fi
    else
      echo "No prior context."
    fi
    echo ""
    # Inject error patterns for avoidance — migrated from node -e to python3 + sanitize
    if [ -f "$CONTEXT_DIR/error-patterns.json" ]; then
      local count
      count=$(python3 -c "import json,sys; print(len(json.load(open(sys.argv[1]))))" \
        "$CONTEXT_DIR/error-patterns.json" 2>/dev/null || echo "0")
      if [ "$count" -gt 0 ]; then
        echo "## Known Error Patterns (avoid these)"
        local raw_patterns
        raw_patterns=$(python3 -c "
import json, sys
for e in json.load(open(sys.argv[1])):
    print('- [' + str(e.get('feature_id','')) + '] ' + str(e.get('phase','')) + ': ' + str(e.get('error','')))
" "$CONTEXT_DIR/error-patterns.json" 2>/dev/null || true)
        if declare -f sanitize_context_chunk &>/dev/null; then
          sanitize_context_chunk "$raw_patterns" 20 2>/dev/null || echo "$raw_patterns"
        else
          echo "$raw_patterns"
        fi
      fi
    fi
  } > "$context_file"

  echo "$context_file"
}

# ── Layer 1: Record completed feature context ────────────────────

mem_record_context() {
  local feat_id="$1"
  local title="$2"
  local priority="$3"
  local labels="$4"
  local wt_path="$5"
  local results_file="$6"

  local files_created="none" files_modified="none"
  local schema_changes="none" new_deps="none" breaking="none"

  if [ -f "$results_file" ]; then
    files_created=$(node -p "(JSON.parse(require('fs').readFileSync('$results_file','utf-8')).context_generated?.files_created||[]).join(', ')||'none'" 2>/dev/null || echo "none")
    files_modified=$(node -p "(JSON.parse(require('fs').readFileSync('$results_file','utf-8')).context_generated?.files_modified||[]).join(', ')||'none'" 2>/dev/null || echo "none")
    schema_changes=$(node -p "(JSON.parse(require('fs').readFileSync('$results_file','utf-8')).context_generated?.schema_changes||[]).join(', ')||'none'" 2>/dev/null || echo "none")
    new_deps=$(node -p "(JSON.parse(require('fs').readFileSync('$results_file','utf-8')).context_generated?.new_dependencies||[]).join(', ')||'none'" 2>/dev/null || echo "none")
    breaking=$(node -p "(JSON.parse(require('fs').readFileSync('$results_file','utf-8')).context_generated?.breaking_changes||[]).join(', ')||'none'" 2>/dev/null || echo "none")
  fi

  cat >> "$CONTEXT_DIR/global-context.md" <<EOCTX

### $feat_id — $title ($(wt_get_status "$feat_id"))
- Branch: ${BRANCH_PREFIX:-feat}/$feat_id
- Files created: $files_created
- Files modified: $files_modified
- Schema changes: $schema_changes
- New dependencies: $new_deps
- Breaking changes: $breaking
EOCTX
}

# ── Layer 2: Record error pattern ────────────────────────────────

mem_record_error() {
  local feat_id="$1"
  local phase="$2"
  local error_msg="$3"

  local patterns_file="$CONTEXT_DIR/error-patterns.json"
  [ ! -f "$patterns_file" ] && echo '[]' > "$patterns_file"

  node -e "
    const fs = require('fs');
    const p = JSON.parse(fs.readFileSync('$patterns_file', 'utf-8'));
    p.push({
      feature_id: '$feat_id',
      timestamp: new Date().toISOString(),
      phase: '$phase',
      error: $(printf '%s' "$error_msg" | node -p "JSON.stringify(require('fs').readFileSync('/dev/stdin','utf-8').trim())" 2>/dev/null || echo '""')
    });
    // Keep only last N entries (error_pattern_window)
    const trimmed = p.slice(-${ERROR_WINDOW:-5});
    fs.writeFileSync('$patterns_file', JSON.stringify(trimmed, null, 2));
  " 2>/dev/null || true
}

# ── Layer 3: Refresh environment ─────────────────────────────────

mem_refresh_env() {
  if [ "${ENV_REFRESH:-true}" = "true" ] && [ -f "$LIB_DIR/../environment-discovery.sh" ]; then
    bash "$LIB_DIR/../environment-discovery.sh" > "$CONTEXT_DIR/environment.manifest.json" 2>/dev/null || true
  fi
}

# ── Utility: Reset all accumulated state ─────────────────────────

mem_reset() {
  rm -f "$CONTEXT_DIR/global-context.md"
  rm -f "$CONTEXT_DIR/error-patterns.json"
  rm -f "$CONTEXT_DIR/environment.manifest.json"
  echo "Memory cleared"
}
