#!/bin/bash
# scripts/worktree-manager.sh
# Manages git worktree lifecycle for the orchestrator.
# Usage: source this file, then call functions directly
#   source scripts/worktree-manager.sh
#   create_worktree feat-001

set -euo pipefail

WORKTREE_BASE="${WORKTREE_BASE:-$PWD/.worktrees}"
BRANCH_PREFIX="${BRANCH_PREFIX:-feat}"
STATE_DIR="${STATE_DIR:-$PWD/.orchestrator/state}"

mkdir -p "$WORKTREE_BASE"

create_worktree() {
  local feat_id="$1"
  local base="${2:-${BASE_BRANCH:-main}}"
  local wt_path="$WORKTREE_BASE/$feat_id"
  local branch="$BRANCH_PREFIX/$feat_id"

  if [ -d "$wt_path" ]; then
    # Worktree exists — remove and recreate
    if git worktree list | grep -q "$wt_path"; then
      git worktree remove "$wt_path" --force >/dev/null 2>&1 || true
    fi
    git branch -D "$branch" >/dev/null 2>&1 || true
    rm -rf "$wt_path" 2>/dev/null || true
  fi

  git worktree add "$wt_path" -b "$branch" "$base" >&2

  # Persist state
  mkdir -p "$STATE_DIR/$feat_id/logs"
  echo "$wt_path" > "$STATE_DIR/$feat_id/worktree-path.txt"

  cat > "$STATE_DIR/$feat_id/status.json" <<EOJSON
{
  "feature_id": "$feat_id",
  "status": "created",
  "worktree": "$wt_path",
  "branch": "$branch",
  "created_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "updated_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "phase": "pending"
}
EOJSON

  echo "$wt_path"
}

remove_worktree() {
  local feat_id="$1"
  local wt_path="$WORKTREE_BASE/$feat_id"

  if [ -d "$wt_path" ]; then
    local branch
    branch=$(git -C "$wt_path" rev-parse --abbrev-ref HEAD 2>/dev/null) || branch="$BRANCH_PREFIX/$feat_id"
    git worktree remove "$wt_path" --force >/dev/null 2>&1 || true
    [ -n "$branch" ] && git branch -D "$branch" >/dev/null 2>&1 || true
  fi
}

update_status() {
  local feat_id="$1"
  local new_status="$2"
  local new_phase="${3:-}"
  local status_file="$STATE_DIR/$feat_id/status.json"

  if [ ! -f "$status_file" ]; then
    echo "\u2717 No state found for $feat_id" >&2
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

rebase_pending() {
  local base="${1:-${BASE_BRANCH:-main}}"

  for wt in "$WORKTREE_BASE"/*/; do
    [ -d "$wt" ] || continue
    local fid
    fid=$(basename "$wt")

    echo "  Rebasing $fid against $base..."
    (cd "$wt" && git fetch origin "$base" >/dev/null 2>&1 && \
      git rebase "origin/$base" >/dev/null 2>&1) || \
      echo "  \u26a0 Rebase conflict in $fid — skipping, will resolve at PR time"
  done
}

cleanup() {
  local completed_branches=""

  for wt in "$WORKTREE_BASE"/*/; do
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

clean_all() {
  for wt in "$WORKTREE_BASE"/*/; do
    [ -d "$wt" ] || continue
    local fid
    fid=$(basename "$wt")
    remove_worktree "$fid"
  done
  rm -rf "$WORKTREE_BASE"
  git worktree prune 2>/dev/null || true
  echo "\u2713 All worktrees cleaned"
}

list_worktrees() {
  git worktree list --porcelain | grep "worktree" | grep "$WORKTREE_BASE" 2>/dev/null | sed 's/worktree //' || true
}

# Only dispatch if executed directly (not sourced)
(return 0 2>/dev/null) || "$@"
