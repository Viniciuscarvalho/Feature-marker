#!/bin/bash
# lib/worktree.sh — Worktree lifecycle with cleanup safety
#
# Functions: wt_create, wt_remove, wt_rebase_pending,
#            wt_cleanup_all, wt_list

WORKTREE_ROOT="${WORKTREE_ROOT:-$ROOT_DIR/${WORKTREE_BASE:-.worktrees}}"
STATE_DIR="${STATE_DIR:-$ROOT_DIR/.orchestrator/state}"

mkdir -p "$WORKTREE_ROOT" "$STATE_DIR"

wt_create() {
  local feat_id="$1"
  local base="${2:-${BASE_BRANCH:-main}}"
  local wt_path="$WORKTREE_ROOT/$feat_id"
  local branch="${BRANCH_PREFIX:-feat}/$feat_id"

  if [ -d "$wt_path" ]; then
    git worktree remove "$wt_path" --force >/dev/null 2>&1 || true
    git branch -D "$branch" >/dev/null 2>&1 || true
    rm -rf "$wt_path" 2>/dev/null || true
  fi

  git worktree add "$wt_path" -b "$branch" "$base" >&2

  # State
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

wt_remove() {
  local feat_id="$1"
  local wt_path="$WORKTREE_ROOT/$feat_id"

  if [ -d "$wt_path" ]; then
    local branch
    branch=$(git -C "$wt_path" rev-parse --abbrev-ref HEAD 2>/dev/null) || branch="${BRANCH_PREFIX:-feat}/$feat_id"
    git worktree remove "$wt_path" --force >/dev/null 2>&1 || true
    [ -n "$branch" ] && git branch -D "$branch" >/dev/null 2>&1 || true
  fi
}

wt_update_status() {
  local feat_id="$1"
  local new_status="$2"
  local new_phase="${3:-}"
  local status_file="$STATE_DIR/$feat_id/status.json"

  [ ! -f "$status_file" ] && return 1

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

wt_get_status() {
  local feat_id="$1"
  local status_file="$STATE_DIR/$feat_id/status.json"

  if [ ! -f "$status_file" ]; then
    echo "none"
    return
  fi

  node -p "JSON.parse(require('fs').readFileSync('$status_file','utf-8')).status"
}

wt_rebase_pending() {
  local base="${1:-${BASE_BRANCH:-main}}"

  for wt in "$WORKTREE_ROOT"/*/; do
    [ -d "$wt" ] || continue
    local fid
    fid=$(basename "$wt")

    echo "  Rebasing $fid against $base..."
    (cd "$wt" && git fetch origin "$base" >/dev/null 2>&1 && \
      git rebase "origin/$base" >/dev/null 2>&1) || \
      echo "  ! Rebase conflict in $fid — skipping, will resolve at PR time"
  done
}

wt_cleanup() {
  local cleaned=""

  for wt in "$WORKTREE_ROOT"/*/; do
    [ -d "$wt" ] || continue
    local fid
    fid=$(basename "$wt")
    local st
    st=$(wt_get_status "$fid")
    if [ "$st" = "done" ] || [ "$st" = "pr-created" ]; then
      cp "$STATE_DIR/$fid/logs/"* "$RESULTS_DIR/" 2>/dev/null || true
      wt_remove "$fid"
      cleaned="$cleaned $fid"
    fi
  done

  git worktree prune 2>/dev/null || true
  echo "$cleaned"
}

wt_cleanup_all() {
  for wt in "$WORKTREE_ROOT"/*/; do
    [ -d "$wt" ] || continue
    local fid
    fid=$(basename "$wt")
    wt_remove "$fid"
  done
  rm -rf "$WORKTREE_ROOT"
  git worktree prune 2>/dev/null || true
  echo "All worktrees cleaned"
}

wt_list() {
  local total=0
  for wt in "$WORKTREE_ROOT"/*/; do
    [ -d "$wt" ] || continue
    local fid
    fid=$(basename "$wt")
    local st
    st=$(wt_get_status "$fid")
    echo "  $fid: $st"
    total=$((total + 1))
  done
  echo "  Total: $total"
}
