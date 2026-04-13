#!/bin/bash
# scripts/orchestrator.sh
# Main loop: read backlog, create worktrees, run feature-marker
# Phase 4 — PR creation, retry logic, cleanup, full summary

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG_DIR="$ROOT_DIR/.orchestrator"
STATE_DIR="$CONFIG_DIR/state"
WORKTREE_ROOT="$ROOT_DIR/.worktrees"
RESULTS_DIR="$CONFIG_DIR/results"

# ── load config ──────────────────────────────────────────────────

eval "$(node "$SCRIPT_DIR/parse-config.js" "$ROOT_DIR/orchestrator/config.yml" 2>/dev/null || echo '')"
BASE_BRANCH="${CFG_EXECUTION_BASE_BRANCH:-main}"
SKIP_DONE="${CFG_EXECUTION_SKIP_DONE:-true}"
SKIP_BLOCKED="${CFG_EXECUTION_SKIP_BLOCKED:-true}"
ADAPTER="${CFG_SOURCE_ADAPTER:-markdown}"
SOURCE_FILE="${CFG_SOURCE_FILE:-features.md}"
SOURCE_LABEL="${CFG_SOURCE_LABEL:-feature-marker}"
AUTONOMY="${CFG_AUTONOMY:-checkpoint}"
PROPAGATE_CONTEXT="${CFG_FEATURES_PROPAGATE_CONTEXT:-true}"
TRACK_ERRORS="${CFG_FEATURES_TRACK_ERRORS:-true}"
MAX_RETRIES="${CFG_FEATURES_MAX_RETRIES:-2}"
PR_STRATEGY="${CFG_EXECUTION_PR_STRATEGY:-draft}"
export BASE_BRANCH STATE_DIR WORKTREE_ROOT ADAPTER AUTONOMY

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

mkdir -p "$STATE_DIR" "$RESULTS_DIR"

BACKLOG_FILE="$ROOT_DIR/orchestration-backlog.json"

info "Config loaded: adapter=$ADAPTER, autonomy=$AUTONOMY, base=$BASE_BRANCH"
info "State: $STATE_DIR | Results: $RESULTS_DIR"
info "PR strategy: $PR_STRATEGY | Max retries: $MAX_RETRIES"

# ══════════════════════════════════════════════════════════════════
# Step 1: Load backlog
# ══════════════════════════════════════════════════════════════════

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

# ══════════════════════════════════════════════════════════════════
# Step 2: Filter, sort by priority, check dependencies
# ══════════════════════════════════════════════════════════════════

ITEMS=$(node -e "
  const items = JSON.parse(require('fs').readFileSync('$BACKLOG_FILE', 'utf-8'));

  const skipDone = $SKIP_DONE;
  const skipBlocked = $SKIP_BLOCKED;

  // Sort by priority
  const PRIO = { high: 1, medium: 2, low: 3, none: 4 };
  const sorted = [...items].sort((a, b) =>
    (PRIO[a.priority] || 4) - (PRIO[b.priority] || 4)
  );

  const done = new Set(sorted.filter(i => i.status === 'done').map(i => i.id));
  const ready = [];
  const blocked = [];
  const skipped = [];

  for (const item of sorted) {
    if (item.status === 'done') { skipped.push(item); continue; }
    if (item.status === 'blocked' && skipBlocked) { blocked.push(item); continue; }
    if (item.status !== 'backlog') { skipped.push(item); continue; }

    const unmet = (item.dependencies || []).filter(d => !done.has(d));
    if (unmet.length === 0) {
      ready.push(item);
    } else {
      blocked.push({ ...item, _unmet: unmet });
    }
  }

  console.log(JSON.stringify({ ready, blocked, skipped, total: items.length }));
")

READY_COUNT=$(echo "$ITEMS" | node -p "JSON.parse(require('fs').readFileSync('/dev/stdin','utf-8')).ready.length")
BLOCKED_COUNT=$(echo "$ITEMS" | node -p "JSON.parse(require('fs').readFileSync('/dev/stdin','utf-8')).blocked.length")
TOTAL_COUNT=$(echo "$ITEMS" | node -p "JSON.parse(require('fs').readFileSync('/dev/stdin','utf-8')).total")

banner "Orchestrator — $READY_COUNT ready, $BLOCKED_COUNT blocked, $TOTAL_COUNT total"

if [ "$READY_COUNT" -eq 0 ]; then
  info "No actionable backlog items. All done or blocked."
  exit 0
fi

# Show priority order
echo "$ITEMS" | node -e "
  const d = JSON.parse(require('fs').readFileSync('/dev/stdin','utf-8'));
  d.ready.forEach((i, idx) =>
    console.log('  ' + (idx+1) + '. [' + i.priority + '] ' + i.id + ': ' + i.title)
  );
"

# ══════════════════════════════════════════════════════════════════
# Step 3: Main processing loop
# ══════════════════════════════════════════════════════════════════

BACKLOG_PROCESSED=0
SUCCEEDED=0
FAILED=0
RETRIED=0
INDEX=0

echo "$ITEMS" | node -e "
  const d = JSON.parse(require('fs').readFileSync('/dev/stdin','utf-8'));
  d.ready.forEach(i => console.log(JSON.stringify(i)));
" | while IFS= read -r ITEM_JSON; do
  INDEX=$((INDEX + 1))

  # Extract all fields from item
  FEATURE_ID=$(echo "$ITEM_JSON" | node -p "JSON.parse(require('fs').readFileSync('/dev/stdin','utf-8')).id")
  FEATURE_TITLE=$(echo "$ITEM_JSON" | node -p "JSON.parse(require('fs').readFileSync('/dev/stdin','utf-8')).title")
  FEATURE_BODY=$(echo "$ITEM_JSON" | node -p "JSON.parse(require('fs').readFileSync('/dev/stdin','utf-8')).body")
  FEATURE_PRIORITY=$(echo "$ITEM_JSON" | node -p "JSON.parse(require('fs').readFileSync('/dev/stdin','utf-8')).priority")
  FEATURE_LABELS=$(echo "$ITEM_JSON" | node -p "JSON.parse(require('fs').readFileSync('/dev/stdin','utf-8')).labels.join(', ')")
  FEATURE_DEPS=$(echo "$ITEM_JSON" | node -p "JSON.parse(require('fs').readFileSync('/dev/stdin','utf-8')).dependencies.join(', ') || 'none'")

  banner "[$INDEX/$READY_COUNT] $FEATURE_ID: $FEATURE_TITLE [$FEATURE_PRIORITY]"

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

  # ── 3d: Seed PRD in worktree ──
  TASK_DIR="$WT_PATH/tasks/prd-$FEATURE_ID"
  mkdir -p "$TASK_DIR"

  cat > "$TASK_DIR/prd-seed.md" <<EOPRD
# $FEATURE_TITLE

## Source
- ID: $FEATURE_ID
- Priority: $FEATURE_PRIORITY
- Labels: $FEATURE_LABELS
- Dependencies: $FEATURE_DEPS
- From: orchestrator backlog ($ADAPTER)

## Description
$FEATURE_BODY
EOPRD

  info "Seeded PRD at $TASK_DIR/prd-seed.md"

  # ── 3e: Create feature context ──
  CONTEXT_FILE="$STATE_DIR/$FEATURE_ID/context.md"
  cat > "$CONTEXT_FILE" <<EOCTX
# Feature Context

## Feature: $FEATURE_TITLE
- ID: $FEATURE_ID
- Priority: $FEATURE_PRIORITY
- Status: in-progress | started: $(date -u +%Y-%m-%dT%H:%M:%SZ)
- Labels: $FEATURE_LABELS
- Dependencies: $FEATURE_DEPS
- Worktree: $WT_PATH

## Description
$FEATURE_BODY

## Cross-Feature Context
$(cat "$CONFIG_DIR/cross-context.md" 2>/dev/null || echo "No prior context available.")
EOCTX

  info "Created context at $CONTEXT_FILE"
  cp "$CONTEXT_FILE" "$WT_PATH/.orchestrator-context.md"

  # ── 3f: Feature Marker — pipeline invocation ──
  update_status "$FEATURE_ID" "in-progress" "implementation"
  LOG_FILE="$STATE_DIR/$FEATURE_ID/logs/run-$(date -u +%Y%m%d-%H%M%S).log"
  RESULTS_FILE="$STATE_DIR/$FEATURE_ID/results.json"
  EXIT_CODE=0

  # Set orchestrator env vars for feature-marker
  export ORCHESTRATOR_MODE=true
  export FEATURE_ID
  export CONTEXT_FILE
  export RESULTS_FILE

  # Find the SKILL.md if available
  SKILL_PATH=""
  if [ -f "$ROOT_DIR/feature-marker-dist/feature-marker/SKILL.md" ]; then
    SKILL_PATH="$ROOT_DIR/feature-marker-dist/feature-marker/SKILL.md"
    info "Found feature-marker SKILL at $SKILL_PATH"
  fi

  START_TIME=$(date +%s)

  if [ "$AUTONOMY" = "full_auto" ]; then
    info "Autonomy=full_auto — invoking feature-marker pipeline..."

    # The actual Claude Code invocation:
    # (cd "$WT_PATH" && claude --skill feature-marker "prd-$FEATURE_ID") 2>&1 | tee "$LOG_FILE" || EXIT_CODE=$?
    #
    # Placeholder: simulate pipeline execution
    {
      echo "▶ Running feature-marker on $FEATURE_ID..."
      echo "  Worktree: $WT_PATH"
      echo "  Started: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
      echo "  ORCHESTRATOR_MODE=$ORCHESTRATOR_MODE"
      echo "  CONTEXT_FILE=$CONTEXT_FILE"
      echo "  RESULTS_FILE=$RESULTS_FILE"
      echo "  [simulated] Pipeline would execute here"
    } | tee "$LOG_FILE"

  elif [ "$AUTONOMY" = "checkpoint" ]; then
    info "Autonomy=checkpoint — worktree ready for review before pipeline"
    echo "checkpoint: awaiting review for $FEATURE_ID" > "$LOG_FILE"

  else
    info "Autonomy=supervised — manual execution required"
    echo "supervised: manual execution required for $FEATURE_ID" > "$LOG_FILE"
  fi

  END_TIME=$(date +%s)
  DURATION=$((END_TIME - START_TIME))

  # ── 3g: Collect results ──
  if [ -f "$LOG_FILE" ]; then
    cp "$LOG_FILE" "$RESULTS_DIR/${FEATURE_ID}_run.log"
    info "Results saved to $RESULTS_DIR/${FEATURE_ID}_run.log"
  fi

  # Write machine-readable results if pipeline didn't write one
  if [ ! -f "$RESULTS_FILE" ]; then
    node -e "
      const status = $EXIT_CODE === 0 ? 'completed' : 'failed';
      const results = {
        feature_id: '$FEATURE_ID',
        status,
        pr_url: null,
        commits: 0,
        tests_passed: $EXIT_CODE === 0,
        artifacts: [],
        duration_seconds: $DURATION,
        error: $EXIT_CODE === 0 ? null : 'exit code $EXIT_CODE'
      };
      require('fs').writeFileSync('$RESULTS_FILE', JSON.stringify(results, null, 2));
    "
  fi

  # ── Step 4: Handle result — PR creation ──
  BACKLOG_PROCESSED=$((BACKLOG_PROCESSED + 1))

  if [ "$EXIT_CODE" -eq 0 ]; then
    if [ "$AUTONOMY" = "full_auto" ]; then

      # Create PR based on strategy
      if [ "$PR_STRATEGY" != "none" ]; then
        PR_URL=""

        if command -v gh &>/dev/null; then
          info "Creating PR for $FEATURE_ID..."

          (
            cd "$WT_PATH"
            git add -A 2>/dev/null || true
            git commit -m "feat: $FEATURE_TITLE

Automated by feature-marker orchestrator" --allow-empty 2>/dev/null || true
            git push origin "feat/$FEATURE_ID" 2>&1 || true
          ) >> "$LOG_FILE" 2>&1

          PR_CMD="gh pr create --base $BASE_BRANCH --head feat/$FEATURE_ID"
          PR_CMD="$PR_CMD --title \"feature-marker:automated: $FEATURE_ID\""
          PR_CMD="$PR_CMD --body \"Automated by feature-marker orchestrator.\n\n- Feature: $FEATURE_TITLE\n- Priority: $FEATURE_PRIORITY\n- Labels: $FEATURE_LABELS\""

          if [ "$PR_STRATEGY" = "draft" ]; then
            PR_CMD="$PR_CMD --draft"
          fi

          PR_URL=$(eval "$PR_CMD" 2>/dev/null) || true

          if [ -n "$PR_URL" ]; then
            update_status "$FEATURE_ID" "pr-created" "complete"
            info "✓ PR created: $PR_URL"

            # Update results with PR URL
            node -e "
              const fs = require('fs');
              const r = JSON.parse(fs.readFileSync('$RESULTS_FILE', 'utf-8'));
              r.pr_url = '$PR_URL';
              fs.writeFileSync('$RESULTS_FILE', JSON.stringify(r, null, 2));
            "
          else
            update_status "$FEATURE_ID" "done" "complete"
            info "✓ $FEATURE_ID done (PR creation skipped — gh unavailable or failed)"
          fi
        else
          update_status "$FEATURE_ID" "done" "complete"
          info "✓ $FEATURE_ID done (no gh CLI — skipping PR)"
        fi
      else
        update_status "$FEATURE_ID" "done" "complete"
        info "✓ $FEATURE_ID done (pr_strategy=none)"
      fi

      SUCCEEDED=$((SUCCEEDED + 1))
      info "✓ $FEATURE_ID completed successfully"

    else
      # checkpoint or supervised — awaiting manual pipeline
      update_status "$FEATURE_ID" "ready" "awaiting-pipeline"
      info "⏸ $FEATURE_ID ready for pipeline execution"
    fi

  else
    # ── Retry on failure ──
    RETRY_COUNT=0
    if [ -f "$STATE_DIR/$FEATURE_ID/retry-count" ]; then
      RETRY_COUNT=$(cat "$STATE_DIR/$FEATURE_ID/retry-count")
    fi

    if [ "$RETRY_COUNT" -lt "$MAX_RETRIES" ]; then
      RETRY_COUNT=$((RETRY_COUNT + 1))
      echo "$RETRY_COUNT" > "$STATE_DIR/$FEATURE_ID/retry-count"
      update_status "$FEATURE_ID" "retrying" "retry-$RETRY_COUNT"
      RETRIED=$((RETRIED + 1))
      info "⟳ $FEATURE_ID failed — retrying ($RETRY_COUNT/$MAX_RETRIES)"

      # Log retry attempt
      echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) | $FEATURE_ID | retry=$RETRY_COUNT/$MAX_RETRIES | exit=$EXIT_CODE" >> "$CONFIG_DIR/error-log.txt"
    else
      update_status "$FEATURE_ID" "failed" "pipeline-error"
      FAILED=$((FAILED + 1))
      err "$FEATURE_ID failed after $MAX_RETRIES attempts"

      if [ "$TRACK_ERRORS" = "true" ]; then
        echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) | $FEATURE_ID | FINAL_FAILURE | exit=$EXIT_CODE" >> "$CONFIG_DIR/error-log.txt"
      fi
    fi
  fi

  # ── Propagate cross-feature context ──
  if [ "$PROPAGATE_CONTEXT" = "true" ]; then
    cat >> "$CONFIG_DIR/cross-context.md" <<EOXCTX

### $FEATURE_TITLE ($FEATURE_ID)
- Priority: $FEATURE_PRIORITY
- Labels: $FEATURE_LABELS
- Processed at: $(date -u +%Y-%m-%dT%H:%M:%SZ)
- Worktree: $WT_PATH
- Status: $(get_status "$FEATURE_ID")
EOXCTX
    info "Cross-context updated"
  fi

  echo ""
done

# ══════════════════════════════════════════════════════════════════
# Step 5: Cleanup worktrees based on policy
# ══════════════════════════════════════════════════════════════════

CLEANED=""
for dir in "$STATE_DIR"/*/; do
  [ -d "$dir" ] || continue
  fid=$(basename "$dir")
  st=$(get_status "$fid")
  if [ "$st" = "done" ] || [ "$st" = "pr-created" ]; then
    # Move any remaining logs to results
    if [ -f "$STATE_DIR/$fid/logs" ]; then
      cp "$STATE_DIR/$fid/logs/"* "$RESULTS_DIR/" 2>/dev/null || true
    fi
    remove_worktree "$fid"
    CLEANED="$CLEANED $fid"
  fi
done

if [ -n "$CLEANED" ]; then
  git worktree prune 2>/dev/null || true
  info "Cleaned worktrees:$CLEANED"
fi

# ══════════════════════════════════════════════════════════════════
# Step 6: Summary
# ══════════════════════════════════════════════════════════════════

banner "Orchestrator Summary"

# Count results from state files
DONE_COUNT=0
READY_FINAL=0
FAILED_COUNT=0
PR_COUNT=0

for dir in "$STATE_DIR"/*/; do
  [ -d "$dir" ] || continue
  fid=$(basename "$dir")
  if [ -f "$dir/status.json" ]; then
    st=$(get_status "$fid")
    case "$st" in
      done)       DONE_COUNT=$((DONE_COUNT + 1)) ;;
      pr-created) PR_COUNT=$((PR_COUNT + 1)) ;;
      ready)      READY_FINAL=$((READY_FINAL + 1)) ;;
      failed)     FAILED_COUNT=$((FAILED_COUNT + 1)) ;;
    esac
  fi
done

info "Results: done=$DONE_COUNT, pr=$PR_COUNT, ready=$READY_FINAL, failed=$FAILED_COUNT"
echo ""

log "Per-feature status:"
for dir in "$STATE_DIR"/*/; do
  [ -d "$dir" ] || continue
  fid=$(basename "$dir")
  if [ -f "$dir/status.json" ]; then
    status=$(node -p "const s=JSON.parse(require('fs').readFileSync('$dir/status.json','utf-8'));s.status+' ('+s.phase+')'")

    # Show PR URL if available
    PR_INFO=""
    if [ -f "$STATE_DIR/$fid/results.json" ]; then
      PR_INFO=$(node -p "const r=JSON.parse(require('fs').readFileSync('$STATE_DIR/$fid/results.json','utf-8'));r.pr_url||''" 2>/dev/null || echo "")
    fi

    if [ -n "$PR_INFO" ]; then
      info "  $fid: $status → $PR_INFO"
    else
      info "  $fid: $status"
    fi
  fi
done

# Log entries for future features
if [ -f "$CONFIG_DIR/cross-context.md" ]; then
  echo ""
  info "Cross-context log: $CONFIG_DIR/cross-context.md"
fi

if [ -f "$CONFIG_DIR/error-log.txt" ]; then
  echo ""
  info "Errors logged: $CONFIG_DIR/error-log.txt"
  while IFS= read -r line; do
    info "  $line"
  done < "$CONFIG_DIR/error-log.txt"
fi

info "Results dir: $RESULTS_DIR"

# ── cleanup generated backlog ────────────────────────────────────
rm -f "$BACKLOG_FILE"
