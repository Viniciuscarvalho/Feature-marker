#!/bin/bash
# lib/review.sh — Post-hoc code review agent (Phase E)
#
# Lightweight independent review before PR creation. Only invoked
# in full_auto mode when POSTHOC_REVIEW_TRIGGER matches.
#
# Cost: ~2,500 tokens per invocation

set -euo pipefail

REVIEW_AGENT_PATH="${REVIEW_AGENT_PATH:-feature-marker-dist/agents/review-agent.md}"
REVIEW_MAX_CYCLES="${REVIEW_MAX_CYCLES:-2}"

review_diff() {
  local feat_id="$1"
  local wt_path="$2"

  local review_report="$STATE_DIR/$feat_id/review-report.json"
  local diff_file="$STATE_DIR/$feat_id/logs/review-diff.patch"

  # Collect diff
  (cd "$wt_path" && git diff "${BASE_BRANCH:-main}...HEAD" --stat > "$diff_file.stat" 2>/dev/null || true)
  (cd "$wt_path" && git diff "${BASE_BRANCH:-main}...HEAD" | head -800 > "$diff_file" 2>/dev/null || true)

  # Load knowledge base checklist if available
  local checklist=""
  if [ -f "$KB_RULES_FILE" ]; then
    checklist=$(node -p "
      const rules = JSON.parse(require('fs').readFileSync('$KB_RULES_FILE','utf-8')).rules;
      rules.map(r => '- Check: ' + r.instruction).join('\\n')
    " 2>/dev/null || echo "")
  fi

  if command -v claude &>/dev/null && [ -f "$ROOT_DIR/$REVIEW_AGENT_PATH" ]; then
    local prompt="Review implementation diff for $feat_id before PR creation."
    prompt="$prompt Diff stats: $(cat "$diff_file.stat" 2>/dev/null || echo 'none')"
    [ -n "$checklist" ] && prompt="$prompt Additional checklist from knowledge base: $checklist"
    prompt="$prompt Write review to: $review_report"

    (cd "$wt_path" && claude --agent "$ROOT_DIR/$REVIEW_AGENT_PATH" "$prompt") 2>/dev/null || true
  fi

  # Fallback report
  if [ ! -f "$review_report" ]; then
    local file_count
    file_count=$(wc -l < "$diff_file.stat" 2>/dev/null || echo "0")
    node -e "
      require('fs').writeFileSync('$review_report', JSON.stringify({
        feature_id: '$feat_id',
        verdict: 'approve',
        issues: [],
        checklist_results: [],
        notes: 'Review agent not available — auto-approved with warning',
        generated_at: new Date().toISOString()
      }, null, 2));
    "
  fi

  echo "$review_report"
}

review_get_verdict() {
  local feat_id="$1"

  local review_report="$STATE_DIR/$feat_id/review-report.json"
  if [ ! -f "$review_report" ]; then
    echo "approve"
    return
  fi

  node -p "JSON.parse(require('fs').readFileSync('$review_report','utf-8')).verdict||'approve'" 2>/dev/null || echo "approve"
}

review_apply_fixes() {
  local feat_id="$1"
  local wt_path="$2"
  local review_report="$3"

  local cycle=0
  local max_cycles="${REVIEW_MAX_CYCLES:-2}"

  while [ "$cycle" -lt "$max_cycles" ]; do
    local verdict
    verdict=$(node -p "JSON.parse(require('fs').readFileSync('$review_report','utf-8')).verdict" 2>/dev/null || echo "approve")

    if [ "$verdict" = "approve" ]; then
      return 0
    fi

    cycle=$((cycle + 1))

    # Extract fix instructions
    local issues
    issues=$(node -p "
      const r = JSON.parse(require('fs').readFileSync('$review_report','utf-8'));
      (r.issues||[]).map(i => i.description || i).join('; ')
    " 2>/dev/null || echo "")

    if [ -z "$issues" ]; then
      return 0
    fi

    # Re-invoke implementation agent with fix instructions
    if command -v claude &>/dev/null; then
      local model_flag=""
      [ -n "${MODEL_DEFAULT:-}" ] && model_flag="--model $MODEL_DEFAULT"
      (cd "$wt_path" && claude $model_flag --skill feature-marker \
        "Fix review issues for prd-$feat_id: $issues") 2>/dev/null || true
    fi

    # Re-run review
    review_report=$(review_diff "$feat_id" "$wt_path")
  done

  # After max cycles, accept whatever state we're in
  return 0
}
