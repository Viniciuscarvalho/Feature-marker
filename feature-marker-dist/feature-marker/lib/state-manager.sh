#!/usr/bin/env bash
# state-manager.sh - Checkpoint and state management for feature-marker
set -euo pipefail

STATE_PATH=".claude/feature-state"

# Initialize feature state directory
init_feature_state() {
  local feature_name="$1"
  local state_dir="${STATE_PATH}/${feature_name}"

  if [[ ! -d "$state_dir" ]]; then
    mkdir -p "$state_dir"
    echo "Created state directory: $state_dir"
  fi

  local checkpoint="${state_dir}/checkpoint.json"
  if [[ ! -f "$checkpoint" ]]; then
    cat > "$checkpoint" << EOF
{
  "version": "1.1.0",
  "feature_name": "${feature_name}",
  "project_path": "$(pwd)",
  "current_phase": 0,
  "phase_status": "pending",
  "phases": {
    "1": {"name": "Analysis & Planning", "status": "pending"},
    "2": {"name": "Implementation", "status": "pending"},
    "3": {"name": "Tests & Validation", "status": "pending"},
    "4": {"name": "Commit & PR", "status": "pending"}
  },
  "last_updated": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "paused": false,
  "error_state": null
}
EOF
    echo "Created checkpoint: $checkpoint"
  fi
}

# Load checkpoint for a feature
load_checkpoint() {
  local feature_name="$1"
  local checkpoint="${STATE_PATH}/${feature_name}/checkpoint.json"

  if [[ -f "$checkpoint" ]]; then
    cat "$checkpoint"
  else
    echo "{}"
  fi
}

# Check if checkpoint exists
checkpoint_exists() {
  local feature_name="$1"
  local checkpoint="${STATE_PATH}/${feature_name}/checkpoint.json"
  [[ -f "$checkpoint" ]]
}

# Get current phase from checkpoint
get_current_phase() {
  local feature_name="$1"
  local checkpoint="${STATE_PATH}/${feature_name}/checkpoint.json"

  if [[ -f "$checkpoint" ]]; then
    jq -r '.current_phase // 0' "$checkpoint"
  else
    echo "0"
  fi
}

# Get phase status
get_phase_status() {
  local feature_name="$1"
  local checkpoint="${STATE_PATH}/${feature_name}/checkpoint.json"

  if [[ -f "$checkpoint" ]]; then
    jq -r '.phase_status // "pending"' "$checkpoint"
  else
    echo "pending"
  fi
}

# Update phase in checkpoint
update_phase() {
  local feature_name="$1"
  local phase="$2"
  local status="$3"
  local checkpoint="${STATE_PATH}/${feature_name}/checkpoint.json"

  if [[ -f "$checkpoint" ]]; then
    local tmp=$(mktemp)
    jq --arg phase "$phase" --arg status "$status" --arg now "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" '
      .current_phase = ($phase | tonumber) |
      .phase_status = $status |
      .phases[$phase].status = $status |
      .last_updated = $now
    ' "$checkpoint" > "$tmp" && mv "$tmp" "$checkpoint"
    echo "Updated checkpoint: Phase $phase -> $status"
  fi
}

# Mark phase as completed
complete_phase() {
  local feature_name="$1"
  local phase="$2"
  local checkpoint="${STATE_PATH}/${feature_name}/checkpoint.json"

  if [[ -f "$checkpoint" ]]; then
    local tmp=$(mktemp)
    jq --arg phase "$phase" --arg now "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" '
      .phases[$phase].status = "completed" |
      .phases[$phase].completed_at = $now |
      .last_updated = $now
    ' "$checkpoint" > "$tmp" && mv "$tmp" "$checkpoint"
    echo "Completed phase $phase"
  fi
}

# Save error state
save_error_state() {
  local feature_name="$1"
  local error_message="$2"
  local checkpoint="${STATE_PATH}/${feature_name}/checkpoint.json"

  if [[ -f "$checkpoint" ]]; then
    local tmp=$(mktemp)
    jq --arg error "$error_message" --arg now "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" '
      .error_state = $error |
      .phase_status = "error" |
      .last_updated = $now
    ' "$checkpoint" > "$tmp" && mv "$tmp" "$checkpoint"
    echo "Saved error state: $error_message"
  fi
}

# Check if workflow is paused
is_paused() {
  local feature_name="$1"
  local checkpoint="${STATE_PATH}/${feature_name}/checkpoint.json"

  if [[ -f "$checkpoint" ]]; then
    local paused=$(jq -r '.paused // false' "$checkpoint")
    [[ "$paused" == "true" ]]
  else
    return 1
  fi
}

# Display checkpoint summary
show_checkpoint_summary() {
  local feature_name="$1"
  local checkpoint="${STATE_PATH}/${feature_name}/checkpoint.json"

  if [[ -f "$checkpoint" ]]; then
    echo "Checkpoint found for: $feature_name"
    echo "  Current phase: $(jq -r '.current_phase' "$checkpoint")"
    echo "  Status: $(jq -r '.phase_status' "$checkpoint")"
    echo "  Last updated: $(jq -r '.last_updated' "$checkpoint")"

    local error=$(jq -r '.error_state // empty' "$checkpoint")
    if [[ -n "$error" ]]; then
      echo "  Error: $error"
    fi
  else
    echo "No checkpoint found for: $feature_name"
  fi
}
