#!/usr/bin/env bash
# scripts/worktree-manager.sh
# Worktree lifecycle management for the orchestrator.
# Creates, lists, and cleans up isolated git worktrees per feature.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
STATE_DIR="$ROOT_DIR/state"

# ── helpers ──────────────────────────────────────────────────────

log()  { echo "  [worktree] $*"; }
err()  { echo "✗ [worktree] $*" >&2; }

ensure_state_dir() {
  local feature_id="$1"
  mkdir -p "$STATE_DIR/$feature_id/logs"
}

# ── create ───────────────────────────────────────────────────────

worktree_create() {
  local feature_id="$1"
  local base_branch="${2:-main}"
  local branch_name="feat/$feature_id"
  local worktree_path="$ROOT_DIR/.worktrees/$feature_id"

  if [ -d "$worktree_path" ]; then
    log "Worktree already exists: $worktree_path"
    echo "$worktree_path"
    return 0
  fi

  ensure_state_dir "$feature_id"

  # Create branch if it doesn't exist
  if ! git rev-parse --verify "$branch_name" >/dev/null 2>&1; then
    git branch "$branch_name" "$base_branch"
  fi

  git worktree add "$worktree_path" "$branch_name" >&2

  # Persist worktree path in state
  echo "$worktree_path" > "$STATE_DIR/$feature_id/worktree-path.txt"

  # Initialize status
  cat > "$STATE_DIR/$feature_id/status.json" <<EOF
{
  "feature_id": "$feature_id",
  "status": "created",
  "worktree": "$worktree_path",
  "branch": "$branch_name",
  "created_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "updated_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "phase": "pending"
}
EOF

  log "Created worktree: $worktree_path (branch: $branch_name)"
  echo "$worktree_path"
}

# ── status ───────────────────────────────────────────────────────

worktree_status() {
  local feature_id="$1"
  local status_file="$STATE_DIR/$feature_id/status.json"

  if [ ! -f "$status_file" ]; then
    err "No state found for $feature_id"
    return 1
  fi

  cat "$status_file"
}

worktree_update_status() {
  local feature_id="$1"
  local new_status="$2"
  local new_phase="${3:-}"
  local status_file="$STATE_DIR/$feature_id/status.json"

  if [ ! -f "$status_file" ]; then
    err "No state found for $feature_id"
    return 1
  fi

  local tmp
  tmp=$(mktemp)

  # Update status and updated_at using node (no external deps)
  node -e "
    const fs = require('fs');
    const s = JSON.parse(fs.readFileSync('$status_file', 'utf-8'));
    s.status = '$new_status';
    s.updated_at = new Date().toISOString();
    if ('$new_phase') s.phase = '$new_phase';
    fs.writeFileSync('$tmp', JSON.stringify(s, null, 2));
  "
  mv "$tmp" "$status_file"

  log "Updated $feature_id → status=$new_status${new_phase:+ phase=$new_phase}"
}

# ── list ─────────────────────────────────────────────────────────

worktree_list() {
  git worktree list --porcelain | while read -r line; do
    case "$line" in
      worktree\ *) echo "${line#worktree }" ;;
    esac
  done
}

# ── cleanup ──────────────────────────────────────────────────────

worktree_remove() {
  local feature_id="$1"
  local worktree_path="$ROOT_DIR/.worktrees/$feature_id"

  if [ -d "$worktree_path" ]; then
    git worktree remove "$worktree_path" --force 2>/dev/null || true
    log "Removed worktree: $worktree_path"
  fi

  # Update status
  if [ -f "$STATE_DIR/$feature_id/status.json" ]; then
    worktree_update_status "$feature_id" "cleaned"
  fi
}

worktree_prune() {
  git worktree prune
  log "Pruned stale worktrees"
}

# ── CLI dispatch ─────────────────────────────────────────────────

case "${1:-help}" in
  create)  worktree_create "${2:?feature_id required}" "${3:-main}" ;;
  status)  worktree_status "${2:?feature_id required}" ;;
  update)  worktree_update_status "${2:?feature_id required}" "${3:?status required}" "${4:-}" ;;
  list)    worktree_list ;;
  remove)  worktree_remove "${2:?feature_id required}" ;;
  prune)   worktree_prune ;;
  help)
    echo "Usage: worktree-manager.sh <command> [args]"
    echo ""
    echo "Commands:"
    echo "  create <feature_id> [base_branch]  Create isolated worktree"
    echo "  status <feature_id>                Show feature status"
    echo "  update <feature_id> <status> [phase] Update status"
    echo "  list                               List all worktrees"
    echo "  remove <feature_id>                Remove worktree"
    echo "  prune                              Prune stale worktrees"
    ;;
  *)
    err "Unknown command: $1"
    exit 1
    ;;
esac
