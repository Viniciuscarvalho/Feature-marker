#!/usr/bin/env bash
# scripts/worktree-manager.sh
# Worktree lifecycle management for the orchestrator.
# Can be sourced as a library or invoked directly.
# STATE_DIR and WORKTREE_ROOT can be set before sourcing.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BASE_BRANCH="${BASE_BRANCH:-main}"
WORKTREE_ROOT="${WORKTREE_ROOT:-$ROOT_DIR/.worktrees}"
STATE_DIR="${STATE_DIR:-$ROOT_DIR/.orchestrator/state}"

mkdir -p "$WORKTREE_ROOT" "$STATE_DIR"

create_worktree() {
  local feat_id="$1"
  local wt_path="$WORKTREE_ROOT/$feat_id"

  if [ -d "$wt_path" ]; then
    git worktree remove "$wt_path" --force >/dev/null 2>&1 || true
    git branch -D "feat/$feat_id" >/dev/null 2>&1 || true
  fi

  git worktree add "$wt_path" -b "feat/$feat_id" "$BASE_BRANCH" >&2

  # Persist state
  mkdir -p "$STATE_DIR/$feat_id/logs"
  echo "$wt_path" > "$STATE_DIR/$feat_id/worktree-path.txt"

  cat > "$STATE_DIR/$feat_id/status.json" <<EOJSON
{
  "feature_id": "$feat_id",
  "status": "created",
  "worktree": "$wt_path",
  "branch": "feat/$feat_id",
  "created_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "updated_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "phase": "pending"
}
EOJSON

  echo "$wt_path"
}

remove_worktree() {
  local feat_id="$1"
  local wt_path="$WORKTREE_ROOT/$feat_id"

  if [ -d "$wt_path" ]; then
    git worktree remove "$wt_path" --force >/dev/null 2>&1 || true
    git branch -D "feat/$feat_id" >/dev/null 2>&1 || true
  fi
}

update_status() {
  local feat_id="$1"
  local new_status="$2"
  local new_phase="${3:-}"
  local status_file="$STATE_DIR/$feat_id/status.json"

  if [ ! -f "$status_file" ]; then
    echo "✗ No state found for $feat_id" >&2
    return 1
  fi

  local tmp
  tmp=$(mktemp)

  node -e "
    const fs = require('fs');
    const s = JSON.parse(fs.readFileSync('$status_file', 'utf-8'));
    s.status = '$new_status';
    s.updated_at = new Date().toISOString();
    if ('$new_phase') s.phase = '$new_phase';
    fs.writeFileSync('$tmp', JSON.stringify(s, null, 2));
  "
  mv "$tmp" "$status_file"
}

get_status() {
  local feat_id="$1"
  local status_file="$STATE_DIR/$feat_id/status.json"

  if [ ! -f "$status_file" ]; then
    echo "none"
    return
  fi

  node -e "
    const s = JSON.parse(require('fs').readFileSync('$status_file', 'utf-8'));
    console.log(s.status);
  "
}

cleanup() {
  local completed_branches=""

  for wt in "$WORKTREE_ROOT"/*/; do
    [ -d "$wt" ] || continue
    local fid
    fid=$(basename "$wt")
    local st
    st=$(get_status "$fid")
    if [ "$st" = "done" ] || [ "$st" = "pr-created" ] || [ "$st" = "cleaned" ]; then
      remove_worktree "$fid"
      completed_branches="$completed_branches $fid"
    fi
  done

  git worktree prune 2>/dev/null || true
  echo "Cleaned:$completed_branches"
}

list_worktrees() {
  git worktree list --porcelain | grep "worktree" | grep "$WORKTREE_ROOT" 2>/dev/null | sed 's/worktree //' || true
}

# Only dispatch if executed directly (not sourced)
(return 0 2>/dev/null) || "$@"
