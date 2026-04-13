#!/usr/bin/env bash
# scripts/orchestrator.sh
# Main orchestrator — the loop controller.
# Reads backlog.json, creates worktrees per feature, and drives the
# feature-marker pipeline for each item.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
STATE_DIR="$ROOT_DIR/state"
WORKTREE_MGR="$SCRIPT_DIR/worktree-manager.sh"
BACKLOG_FILE="${1:-$ROOT_DIR/orchestration-backlog.json}"
BASE_BRANCH="${2:-main}"

# ── helpers ──────────────────────────────────────────────────────

log()    { echo "▶ [orchestrator] $*"; }
info()   { echo "  [orchestrator] $*"; }
err()    { echo "✗ [orchestrator] $*" >&2; }
banner() { echo ""; echo "═══════════════════════════════════════════════════"; echo "  $*"; echo "═══════════════════════════════════════════════════"; }

# ── pre-flight ───────────────────────────────────────────────────

if [ ! -f "$BACKLOG_FILE" ]; then
  err "Backlog file not found: $BACKLOG_FILE"
  err "Run an adapter first:  node scripts/adapters/markdown.js features.md"
  exit 1
fi

mkdir -p "$STATE_DIR"

# ── read backlog ─────────────────────────────────────────────────

# Extract actionable items (status=backlog, respecting dependency order)
ITEMS=$(node -e "
  const items = JSON.parse(require('fs').readFileSync('$BACKLOG_FILE', 'utf-8'));
  const actionable = items.filter(i => i.status === 'backlog');

  // Topological sort: items with no deps first
  const done = new Set(items.filter(i => i.status === 'done').map(i => i.id));
  const ready = [];
  const blocked = [];

  for (const item of actionable) {
    const unmet = (item.dependencies || []).filter(d => !done.has(d));
    if (unmet.length === 0) {
      ready.push(item);
    } else {
      blocked.push({ ...item, _unmet: unmet });
    }
  }

  // Output ready items as JSON array
  console.log(JSON.stringify(ready));
")

ITEM_COUNT=$(echo "$ITEMS" | node -e "
  const d = require('fs').readFileSync('/dev/stdin','utf-8');
  console.log(JSON.parse(d).length);
")

if [ "$ITEM_COUNT" -eq 0 ]; then
  info "No actionable backlog items found. All done or blocked."
  exit 0
fi

banner "Orchestrator starting — $ITEM_COUNT features to process"

# ── main loop ────────────────────────────────────────────────────

INDEX=0
echo "$ITEMS" | node -e "
  const items = JSON.parse(require('fs').readFileSync('/dev/stdin','utf-8'));
  items.forEach(i => console.log(JSON.stringify(i)));
" | while IFS= read -r ITEM_JSON; do
  INDEX=$((INDEX + 1))

  FEATURE_ID=$(echo "$ITEM_JSON" | node -e "
    const d=require('fs').readFileSync('/dev/stdin','utf-8');
    console.log(JSON.parse(d).id);
  ")
  FEATURE_TITLE=$(echo "$ITEM_JSON" | node -e "
    const d=require('fs').readFileSync('/dev/stdin','utf-8');
    console.log(JSON.parse(d).title);
  ")

  banner "[$INDEX/$ITEM_COUNT] $FEATURE_ID: $FEATURE_TITLE"

  # ── Step 1: Check if already processed ──
  if [ -f "$STATE_DIR/$FEATURE_ID/status.json" ]; then
    CURRENT_STATUS=$(node -e "
      const s=JSON.parse(require('fs').readFileSync('$STATE_DIR/$FEATURE_ID/status.json','utf-8'));
      console.log(s.status);
    ")
    if [ "$CURRENT_STATUS" = "done" ] || [ "$CURRENT_STATUS" = "pr-created" ]; then
      info "Skipping $FEATURE_ID (status: $CURRENT_STATUS)"
      continue
    fi
    info "Resuming $FEATURE_ID (status: $CURRENT_STATUS)"
  fi

  # ── Step 2: Create worktree ──
  info "Creating worktree for $FEATURE_ID..."
  WORKTREE_PATH=$("$WORKTREE_MGR" create "$FEATURE_ID" "$BASE_BRANCH")

  # ── Step 3: Update status to in-progress ──
  "$WORKTREE_MGR" update "$FEATURE_ID" "in-progress" "analysis"

  # ── Step 4: Write feature context for feature-marker ──
  FEATURE_BODY=$(echo "$ITEM_JSON" | node -e "
    const d=require('fs').readFileSync('/dev/stdin','utf-8');
    console.log(JSON.parse(d).body);
  ")

  # Create tasks directory in worktree
  TASK_DIR="$WORKTREE_PATH/tasks/prd-$FEATURE_ID"
  mkdir -p "$TASK_DIR"

  # Seed PRD with backlog body
  cat > "$TASK_DIR/prd-seed.md" <<EOF
# $FEATURE_TITLE

## Source
- ID: $FEATURE_ID
- From: orchestrator backlog

## Description
$FEATURE_BODY
EOF

  info "Seeded PRD at $TASK_DIR/prd-seed.md"

  # ── Step 5: Invoke feature-marker pipeline ──
  info "Invoking feature-marker pipeline in worktree..."
  "$WORKTREE_MGR" update "$FEATURE_ID" "in-progress" "implementation"

  # Log pipeline invocation
  LOG_FILE="$STATE_DIR/$FEATURE_ID/logs/run-$(date -u +%Y%m%d-%H%M%S).log"
  info "Pipeline log: $LOG_FILE"

  # The actual feature-marker invocation would go here:
  # (cd "$WORKTREE_PATH" && claude --skill feature-marker "prd-$FEATURE_ID") 2>&1 | tee "$LOG_FILE"
  #
  # For now, mark as ready for manual execution
  "$WORKTREE_MGR" update "$FEATURE_ID" "ready" "awaiting-pipeline"
  info "Worktree ready at: $WORKTREE_PATH"
  info "Run feature-marker manually:  cd $WORKTREE_PATH && /feature-marker prd-$FEATURE_ID"

  echo ""
done

banner "Orchestrator loop complete"

# ── summary ──────────────────────────────────────────────────────

log "Summary:"
for dir in "$STATE_DIR"/*/; do
  [ -d "$dir" ] || continue
  fid=$(basename "$dir")
  if [ -f "$dir/status.json" ]; then
    status=$(node -e "const s=JSON.parse(require('fs').readFileSync('$dir/status.json','utf-8'));console.log(s.status+' ('+s.phase+')');")
    info "  $fid: $status"
  fi
done
