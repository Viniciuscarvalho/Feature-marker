#!/bin/bash
# scripts/orchestrator.sh
# Main loop: read backlog, create worktrees, run feature-marker

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
STATE_DIR="$ROOT_DIR/state"

# ── load config ──────────────────────────────────────────────────

eval "$(node "$SCRIPT_DIR/parse-config.js" "$ROOT_DIR/orchestrator/config.yml")"

ADAPTER="${CFG_SOURCE_ADAPTER:-markdown}"
SOURCE_FILE="${CFG_SOURCE_FILE:-features.md}"
SOURCE_LABEL="${CFG_SOURCE_LABEL:-feature-marker}"
BASE_BRANCH="${CFG_EXECUTION_BASE_BRANCH:-main}"
SKIP_DONE="${CFG_EXECUTION_SKIP_DONE:-true}"
SKIP_BLOCKED="${CFG_EXECUTION_SKIP_BLOCKED:-true}"
AUTONOMY="${CFG_AUTONOMY:-checkpoint}"

export BASE_BRANCH

# ── source worktree manager ─────────────────────────────────────

source "$SCRIPT_DIR/worktree-manager.sh"

# ── helpers ──────────────────────────────────────────────────────

log()    { echo "▶ [orchestrator] $*"; }
info()   { echo "  [orchestrator] $*"; }
err()    { echo "✗ [orchestrator] $*" >&2; }
banner() {
  echo ""
  echo "═══════════════════════════════════════════════════"
  echo "  $*"
  echo "═══════════════════════════════════════════════════"
}

# ── Step 1: Run adapter to produce backlog ───────────────────────

BACKLOG_FILE="$ROOT_DIR/orchestration-backlog.json"

info "Config loaded: adapter=$ADAPTER, autonomy=$AUTONOMY, base=$BASE_BRANCH"

case "$ADAPTER" in
  markdown)
    info "Running markdown adapter on $SOURCE_FILE..."
    node "$SCRIPT_DIR/adapters/markdown.js" "$ROOT_DIR/$SOURCE_FILE"
    ;;
  github)
    info "Running GitHub adapter with label=$SOURCE_LABEL..."
    node "$SCRIPT_DIR/adapters/github.js" "$SOURCE_LABEL"
    ;;
  linear)
    info "Running Linear adapter..."
    node "$SCRIPT_DIR/adapters/linear.js" "$SOURCE_LABEL"
    ;;
  *)
    err "Unknown adapter: $ADAPTER"
    exit 1
    ;;
esac

if [ ! -f "$BACKLOG_FILE" ]; then
  err "Adapter produced no output: $BACKLOG_FILE"
  exit 1
fi

# ── Step 2: Filter actionable items ──────────────────────────────

ITEMS=$(node -e "
  const items = JSON.parse(require('fs').readFileSync('$BACKLOG_FILE', 'utf-8'));

  const skipDone = $SKIP_DONE;
  const skipBlocked = $SKIP_BLOCKED;

  const done = new Set(items.filter(i => i.status === 'done').map(i => i.id));
  const ready = [];
  const blocked = [];

  for (const item of items) {
    if (item.status === 'done' && skipDone) continue;
    if (item.status === 'blocked' && skipBlocked) continue;
    if (item.status !== 'backlog') continue;

    const unmet = (item.dependencies || []).filter(d => !done.has(d));
    if (unmet.length === 0) {
      ready.push(item);
    } else {
      blocked.push(item);
    }
  }

  console.log(JSON.stringify({ ready, blocked, total: items.length }));
")

READY_COUNT=$(echo "$ITEMS" | node -e "
  const d = JSON.parse(require('fs').readFileSync('/dev/stdin','utf-8'));
  console.log(d.ready.length);
")
BLOCKED_COUNT=$(echo "$ITEMS" | node -e "
  const d = JSON.parse(require('fs').readFileSync('/dev/stdin','utf-8'));
  console.log(d.blocked.length);
")
TOTAL_COUNT=$(echo "$ITEMS" | node -e "
  const d = JSON.parse(require('fs').readFileSync('/dev/stdin','utf-8'));
  console.log(d.total);
")

banner "Orchestrator — $READY_COUNT ready, $BLOCKED_COUNT blocked, $TOTAL_COUNT total"

if [ "$READY_COUNT" -eq 0 ]; then
  info "No actionable backlog items. All done or blocked."
  exit 0
fi

# ── Step 3: Main loop ────────────────────────────────────────────

INDEX=0
echo "$ITEMS" | node -e "
  const d = JSON.parse(require('fs').readFileSync('/dev/stdin','utf-8'));
  d.ready.forEach(i => console.log(JSON.stringify(i)));
" | while IFS= read -r ITEM_JSON; do
  INDEX=$((INDEX + 1))

  FEATURE_ID=$(echo "$ITEM_JSON" | node -p "JSON.parse(require('fs').readFileSync('/dev/stdin','utf-8')).id")
  FEATURE_TITLE=$(echo "$ITEM_JSON" | node -p "JSON.parse(require('fs').readFileSync('/dev/stdin','utf-8')).title")

  banner "[$INDEX/$READY_COUNT] $FEATURE_ID: $FEATURE_TITLE"

  # ── 3a: Check if already processed ──
  CURRENT=$(get_status "$FEATURE_ID")
  if [ "$CURRENT" = "done" ] || [ "$CURRENT" = "pr-created" ]; then
    info "Skipping $FEATURE_ID (status: $CURRENT)"
    continue
  fi

  if [ "$CURRENT" != "none" ]; then
    info "Resuming $FEATURE_ID (status: $CURRENT)"
  fi

  # ── 3b: Create worktree ──
  info "Creating worktree..."
  WT_PATH=$(create_worktree "$FEATURE_ID")
  info "Worktree: $WT_PATH"

  # ── 3c: Update status ──
  update_status "$FEATURE_ID" "in-progress" "analysis"

  # ── 3d: Seed PRD ──
  FEATURE_BODY=$(echo "$ITEM_JSON" | node -p "JSON.parse(require('fs').readFileSync('/dev/stdin','utf-8')).body")
  TASK_DIR="$WT_PATH/tasks/prd-$FEATURE_ID"
  mkdir -p "$TASK_DIR"

  cat > "$TASK_DIR/prd-seed.md" <<EOPRD
# $FEATURE_TITLE

## Source
- ID: $FEATURE_ID
- From: orchestrator backlog ($ADAPTER)

## Description
$FEATURE_BODY
EOPRD

  info "Seeded PRD at $TASK_DIR/prd-seed.md"

  # ── 3e: Pipeline invocation ──
  update_status "$FEATURE_ID" "in-progress" "implementation"
  LOG_FILE="$STATE_DIR/$FEATURE_ID/logs/run-$(date -u +%Y%m%d-%H%M%S).log"

  if [ "$AUTONOMY" = "full_auto" ]; then
    info "Autonomy=full_auto — would invoke feature-marker pipeline here"
    # (cd "$WT_PATH" && claude --skill feature-marker "prd-$FEATURE_ID") 2>&1 | tee "$LOG_FILE"
    update_status "$FEATURE_ID" "ready" "awaiting-pipeline"
  elif [ "$AUTONOMY" = "checkpoint" ]; then
    info "Autonomy=checkpoint — worktree ready for review before pipeline"
    update_status "$FEATURE_ID" "ready" "awaiting-pipeline"
  else
    info "Autonomy=supervised — manual execution required"
    update_status "$FEATURE_ID" "ready" "awaiting-manual"
  fi

  info "Log: $LOG_FILE"
  echo ""
done

# ── Step 4: Summary ──────────────────────────────────────────────

banner "Orchestrator loop complete"

log "Summary:"
for dir in "$STATE_DIR"/*/; do
  [ -d "$dir" ] || continue
  fid=$(basename "$dir")
  if [ -f "$dir/status.json" ]; then
    status=$(node -p "const s=JSON.parse(require('fs').readFileSync('$dir/status.json','utf-8'));s.status+' ('+s.phase+')'")
    info "  $fid: $status"
  fi
done

# ── cleanup generated backlog ────────────────────────────────────
rm -f "$BACKLOG_FILE"
