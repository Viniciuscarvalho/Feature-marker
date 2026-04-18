#!/bin/bash
# lib/qa.sh — Post-hoc QA agent invocation (Phase B)
#
# Lightweight quality verification that runs AFTER the monolithic
# Claude invocation. Two modes:
#   1. Verification: checks implementation diff + test output
#   2. Failure analysis: classifies root cause for intelligent retry
#
# Cost: ~2,500 tokens per invocation (vs ~7,500 for feature-marker)

set -euo pipefail

QA_AGENT_PATH="${QA_AGENT_PATH:-feature-marker-dist/agents/qa-reviewer.md}"

qa_verify() {
  local feat_id="$1"
  local wt_path="$2"

  local qa_report="$STATE_DIR/$feat_id/qa-report.json"
  local diff_file="$STATE_DIR/$feat_id/logs/diff.patch"

  # Collect git diff (limit to diffstat + first 500 lines of patch)
  (cd "$wt_path" && git diff "${BASE_BRANCH:-main}...HEAD" --stat > "$diff_file.stat" 2>/dev/null || true)
  (cd "$wt_path" && git diff "${BASE_BRANCH:-main}...HEAD" | head -500 > "$diff_file" 2>/dev/null || true)

  # Collect test output if available
  local test_output="$STATE_DIR/$feat_id/logs/test-output.log"
  local latest_log
  latest_log=$(ls -t "$STATE_DIR/$feat_id/logs/"*.log 2>/dev/null | head -1)
  if [ -n "$latest_log" ]; then
    tail -50 "$latest_log" > "$test_output" 2>/dev/null || true
  fi

  # Find tasks.md for completeness check
  local tasks_file
  tasks_file=$(find "$wt_path" -name "tasks.md" -path "*/prd-*" 2>/dev/null | head -1)

  if command -v claude &>/dev/null && [ -f "$ROOT_DIR/$QA_AGENT_PATH" ]; then
    local prompt="Verify implementation for $feat_id. Mode: verification."
    prompt="$prompt Diff stats: $(cat "$diff_file.stat" 2>/dev/null || echo 'none')"
    [ -f "$test_output" ] && prompt="$prompt Test output (last 50 lines): $(cat "$test_output")"
    [ -f "$tasks_file" ] && prompt="$prompt Tasks file: $tasks_file"
    prompt="$prompt Write QA report to: $qa_report"

    (cd "$wt_path" && claude --agent "$ROOT_DIR/$QA_AGENT_PATH" "$prompt") 2>/dev/null || true
  fi

  # If Claude didn't produce a report, create a basic one from available data
  if [ ! -f "$qa_report" ]; then
    local diff_stat_lines
    diff_stat_lines=$(wc -l < "$diff_file.stat" 2>/dev/null || echo "0")

    node -e "
      require('fs').writeFileSync('$qa_report', JSON.stringify({
        feature_id: '$feat_id',
        verdict: 'warning',
        mode: 'verification',
        checks: [
          { name: 'diff_exists', status: $diff_stat_lines > 0 ? 'pass' : 'warning', detail: '$diff_stat_lines files changed' },
          { name: 'agent_review', status: 'skipped', detail: 'QA agent not available' }
        ],
        recommendations: ['Manual review recommended'],
        generated_at: new Date().toISOString()
      }, null, 2));
    "
  fi

  echo "$qa_report"
}

qa_analyze_failure() {
  local feat_id="$1"
  local wt_path="$2"
  local log_file="${3:-}"

  local qa_report="$STATE_DIR/$feat_id/qa-report.json"

  # Collect error context
  local error_tail=""
  if [ -n "$log_file" ] && [ -f "$log_file" ]; then
    error_tail=$(tail -30 "$log_file")
  fi

  # Read checkpoint for phase info
  local checkpoint_path="$wt_path/.claude/feature-state/$feat_id/checkpoint.json"
  local checkpoint_data="{}"
  [ -f "$checkpoint_path" ] && checkpoint_data=$(cat "$checkpoint_path")

  if command -v claude &>/dev/null && [ -f "$ROOT_DIR/$QA_AGENT_PATH" ]; then
    local prompt="Analyze failure for $feat_id. Mode: failure_analysis."
    prompt="$prompt Checkpoint state: $checkpoint_data"
    [ -n "$error_tail" ] && prompt="$prompt Error log (last 30 lines): $error_tail"
    prompt="$prompt Classify the root cause, assign a confidence score (0-1), and produce remediation steps."
    prompt="$prompt Write analysis to: $qa_report"

    (cd "$wt_path" && claude --agent "$ROOT_DIR/$QA_AGENT_PATH" "$prompt") 2>/dev/null || true
  fi

  # Fallback report if agent not available
  if [ ! -f "$qa_report" ]; then
    node -e "
      require('fs').writeFileSync('$qa_report', JSON.stringify({
        feature_id: '$feat_id',
        verdict: 'fail',
        mode: 'failure_analysis',
        root_cause: {
          category: 'unknown',
          signature: $(printf '%s' "$error_tail" | head -5 | node -p "JSON.stringify(require('fs').readFileSync('/dev/stdin','utf-8').trim())" 2>/dev/null || echo '""'),
          confidence: 0.3
        },
        remediation: ['Review error log manually', 'Check for dependency or configuration issues'],
        should_retry: false,
        generated_at: new Date().toISOString()
      }, null, 2));
    "
  fi

  echo "$qa_report"
}

qa_should_retry() {
  local feat_id="$1"
  local wt_path="$2"

  local qa_report="$STATE_DIR/$feat_id/qa-report.json"
  if [ ! -f "$qa_report" ]; then
    return 1
  fi

  local should_retry confidence
  should_retry=$(node -p "JSON.parse(require('fs').readFileSync('$qa_report','utf-8')).should_retry||false" 2>/dev/null || echo "false")
  confidence=$(node -p "JSON.parse(require('fs').readFileSync('$qa_report','utf-8')).root_cause?.confidence||0" 2>/dev/null || echo "0")

  # Retry if agent recommends it AND confidence > 0.6
  if [ "$should_retry" = "true" ]; then
    local conf_ok
    conf_ok=$(node -p "$confidence > 0.6" 2>/dev/null || echo "false")
    [ "$conf_ok" = "true" ] && return 0
  fi

  return 1
}

qa_inject_remediation() {
  local feat_id="$1"
  local context_file="$2"

  local qa_report="$STATE_DIR/$feat_id/qa-report.json"
  if [ ! -f "$qa_report" ]; then
    return
  fi

  local has_remediation
  has_remediation=$(node -p "(JSON.parse(require('fs').readFileSync('$qa_report','utf-8')).remediation||[]).length>0" 2>/dev/null || echo "false")

  if [ "$has_remediation" = "true" ]; then
    {
      echo ""
      echo "## Remediation from QA Analysis (previous attempt failed)"
      echo "The QA agent analyzed the previous failure and recommends:"
      node -e "
        const r = JSON.parse(require('fs').readFileSync('$qa_report','utf-8'));
        if (r.root_cause) {
          console.log('- Root cause: ' + r.root_cause.category + ' — ' + (r.root_cause.signature || '').substring(0, 100));
          console.log('- Confidence: ' + (r.root_cause.confidence * 100).toFixed(0) + '%');
        }
        (r.remediation || []).forEach((step, i) => console.log((i+1) + '. ' + step));
      " 2>/dev/null || true
    } >> "$context_file"
  fi
}
