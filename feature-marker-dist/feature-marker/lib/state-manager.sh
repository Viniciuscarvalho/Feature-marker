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
  "version": "7.8.1",
  "feature_name": "${feature_name}",
  "project_path": "$(pwd)",
  "mode": null,
  "current_phase": "plan",
  "phase_status": "pending",
  "spec_driven": false,
  "phases": {
    "plan":      {"status": "pending"},
    "implement": {"status": "pending"},
    "test":      {"status": "pending"},
    "pr":        {"status": "pending"}
  },
  "last_updated": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "error_state": null
}
EOF
    echo "Created checkpoint: $checkpoint"
  fi
}

# Set the execution mode in checkpoint (called when mode is first established)
set_checkpoint_mode() {
  local feature_name="$1"
  local mode="$2"
  local checkpoint="${STATE_PATH}/${feature_name}/checkpoint.json"

  if [[ -f "$checkpoint" ]]; then
    local tmp=$(mktemp)
    jq --arg mode "$mode" --arg now "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" '
      .mode = $mode |
      .last_updated = $now
    ' "$checkpoint" > "$tmp" && mv "$tmp" "$checkpoint"
  fi
}

# Get the execution mode stored in checkpoint (empty string if not set)
get_checkpoint_mode() {
  local feature_name="$1"
  local checkpoint="${STATE_PATH}/${feature_name}/checkpoint.json"

  if [[ -f "$checkpoint" ]]; then
    jq -r '.mode // empty' "$checkpoint"
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
    jq -r '.current_phase // "plan"' "$checkpoint"
  else
    echo "plan"
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

# Update phase in checkpoint (phase is one of: plan, implement, test, pr)
update_phase() {
  local feature_name="$1"
  local phase="$2"
  local status="$3"
  local checkpoint="${STATE_PATH}/${feature_name}/checkpoint.json"

  if [[ -f "$checkpoint" ]]; then
    local tmp=$(mktemp)
    jq --arg phase "$phase" --arg status "$status" --arg now "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" '
      .current_phase = $phase |
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

# Check if workflow has an error state
has_error_state() {
  local feature_name="$1"
  local checkpoint="${STATE_PATH}/${feature_name}/checkpoint.json"

  if [[ -f "$checkpoint" ]]; then
    local error=$(jq -r '.error_state // empty' "$checkpoint")
    [[ -n "$error" ]]
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
    local mode=$(jq -r '.mode // empty' "$checkpoint")
    [[ -n "$mode" ]] && echo "  Mode: $mode"
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
