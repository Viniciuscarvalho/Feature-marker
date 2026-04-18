#!/bin/bash
# lib/checkpoint-monitor.sh — Background checkpoint monitor
#
# Polls .claude/feature-state/{feature}/checkpoint.json inside the worktree
# to detect phase transitions. Bridges the agent's internal state with the
# orchestrator's status system without adding Claude invocations.
#
# The monitor runs as a background subshell. The orchestrator starts it
# before the Claude invocation and stops it after.

set -euo pipefail

# Associative array to track monitor PIDs
declare -gA _CKPT_PIDS 2>/dev/null || true
declare -gA _CKPT_LAST_PHASE 2>/dev/null || true

CKPT_POLL_INTERVAL="${MONITOR_POLL_INTERVAL:-1}"

ckpt_start_monitor() {
  local feat_id="$1"
  local wt_path="$2"
  local callback="${3:-}"

  local checkpoint_path="$wt_path/.claude/feature-state/$feat_id/checkpoint.json"
  local phase_log="$STATE_DIR/$feat_id/logs/phases.log"
  mkdir -p "$(dirname "$phase_log")"

  _CKPT_LAST_PHASE[$feat_id]=""

  (
    trap 'exit 0' SIGTERM SIGINT

    local last_phase=""
    local last_status=""

    while true; do
      if [ -f "$checkpoint_path" ]; then
        local current_phase current_status
        current_phase=$(node -p "JSON.parse(require('fs').readFileSync('$checkpoint_path','utf-8')).current_phase" 2>/dev/null || echo "")
        current_status=$(node -p "JSON.parse(require('fs').readFileSync('$checkpoint_path','utf-8')).phase_status" 2>/dev/null || echo "")

        if [ -n "$current_phase" ] && { [ "$current_phase" != "$last_phase" ] || [ "$current_status" != "$last_status" ]; }; then
          local timestamp
          timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
          echo "$timestamp | phase=$current_phase | status=$current_status | prev_phase=$last_phase" >> "$phase_log"

          # Sync to orchestrator's status system
          if [ -n "$current_phase" ]; then
            local phase_name=""
            case "$current_phase" in
              0) phase_name="inputs-gate" ;;
              1) phase_name="analysis-planning" ;;
              2) phase_name="implementation" ;;
              3) phase_name="tests-validation" ;;
              4) phase_name="commit-pr" ;;
              *) phase_name="phase-$current_phase" ;;
            esac
            update_status "$feat_id" "in-progress" "$phase_name" 2>/dev/null || true
          fi

          last_phase="$current_phase"
          last_status="$current_status"
        fi
      fi

      sleep "$CKPT_POLL_INTERVAL"
    done
  ) &

  _CKPT_PIDS[$feat_id]=$!
}

ckpt_stop_monitor() {
  local feat_id="$1"

  local pid="${_CKPT_PIDS[$feat_id]:-}"
  if [ -n "$pid" ]; then
    kill "$pid" 2>/dev/null || true
    wait "$pid" 2>/dev/null || true
    unset "_CKPT_PIDS[$feat_id]"
  fi
}

ckpt_sync_phase() {
  local feat_id="$1"
  local wt_path="$2"

  local checkpoint_path="$wt_path/.claude/feature-state/$feat_id/checkpoint.json"
  if [ ! -f "$checkpoint_path" ]; then
    echo ""
    return
  fi

  local current_phase
  current_phase=$(node -p "JSON.parse(require('fs').readFileSync('$checkpoint_path','utf-8')).current_phase" 2>/dev/null || echo "")
  echo "$current_phase"
}

ckpt_should_trigger_qa() {
  local feat_id="$1"
  local wt_path="$2"

  local checkpoint_path="$wt_path/.claude/feature-state/$feat_id/checkpoint.json"
  if [ ! -f "$checkpoint_path" ]; then
    return 1
  fi

  local phase_status error_state
  phase_status=$(node -p "JSON.parse(require('fs').readFileSync('$checkpoint_path','utf-8')).phase_status" 2>/dev/null || echo "")
  error_state=$(node -p "JSON.parse(require('fs').readFileSync('$checkpoint_path','utf-8')).error_state||''" 2>/dev/null || echo "")

  # Trigger QA if tests failed or error state exists
  if [ "$phase_status" = "error" ] || [ -n "$error_state" ]; then
    return 0
  fi

  # Check if phase 3 (tests) had issues
  local test_status
  test_status=$(node -p "JSON.parse(require('fs').readFileSync('$checkpoint_path','utf-8')).phases['3']?.status||''" 2>/dev/null || echo "")
  if [ "$test_status" = "error" ] || [ "$test_status" = "failed" ]; then
    return 0
  fi

  return 1
}

ckpt_should_trigger_review() {
  local feat_id="$1"
  local wt_path="$2"

  local checkpoint_path="$wt_path/.claude/feature-state/$feat_id/checkpoint.json"
  if [ ! -f "$checkpoint_path" ]; then
    return 1
  fi

  # Review triggers when implementation completed without errors
  local phase_status current_phase
  phase_status=$(node -p "JSON.parse(require('fs').readFileSync('$checkpoint_path','utf-8')).phase_status" 2>/dev/null || echo "")
  current_phase=$(node -p "JSON.parse(require('fs').readFileSync('$checkpoint_path','utf-8')).current_phase" 2>/dev/null || echo "0")

  if [ "$current_phase" -ge 3 ] && [ "$phase_status" != "error" ]; then
    return 0
  fi

  return 1
}

ckpt_get_final_state() {
  local feat_id="$1"
  local wt_path="$2"

  local checkpoint_path="$wt_path/.claude/feature-state/$feat_id/checkpoint.json"
  if [ -f "$checkpoint_path" ]; then
    cat "$checkpoint_path"
  else
    echo "{}"
  fi
}
