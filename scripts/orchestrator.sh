#!/bin/bash
# scripts/orchestrator.sh
# Autonomous orchestration system for Feature-marker.
# Reads backlog → creates worktrees → runs pipeline → drains backlog.
#
# Integrates: backlog adapters, worktree manager, feedback collector,
# environment discovery, status writer, safety guardrails, autonomy controls.

set -euo pipefail

ORCHESTRATOR_START=$(date +%s)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG_DIR="$ROOT_DIR/.orchestrator"
STATE_DIR="$CONFIG_DIR/state"
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
PR_STRATEGY="${CFG_PR_CREATION_STRATEGY:-draft}"
UPDATE_MANIFEST="${CFG_MEMORY_ENV_REFRESH:-true}"
COLLECT_PATTERNS="${CFG_FEEDBACK_COLLECT_PATTERNS:-true}"
GLOBAL_CONTEXT_ENABLED="${CFG_FEEDBACK_GLOBAL_CONTEXT:-true}"
BREAKING_PAUSE="${CFG_SAFETY_BREAKING_CHANGE_PAUSE:-true}"
SCHEMA_WARNING="${CFG_SAFETY_SCHEMA_MIGRATION_REVIEW:-true}"
MAX_FILE_CHANGES="${CFG_SAFETY_MAX_FILE_CHANGES:-50}"
ERROR_PATTERN_WINDOW="${CFG_MEMORY_ERROR_PATTERN_WINDOW:-5}"
AUTO_CLEANUP="${CFG_WORKTREES_AUTO_CLEANUP:-true}"

# Worktree config (read by worktree-manager.sh)
WORKTREE_BASE="${CFG_WORKTREES_BASE_PATH:-.worktrees}"
BRANCH_PREFIX="${CFG_WORKTREES_BRANCH_PREFIX:-feat}"
WORKTREE_ROOT="$ROOT_DIR/$WORKTREE_BASE"
export ROOT_DIR CONFIG_DIR STATE_DIR WORKTREE_ROOT
export BASE_BRANCH ADAPTER AUTONOMY WORKTREE_BASE BRANCH_PREFIX

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

write_status() {
  ROOT_DIR="$ROOT_DIR" node "$SCRIPT_DIR/status-writer.js" --json > /dev/null 2>&1 || true
}

mkdir -p "$STATE_DIR" "$RESULTS_DIR"

BACKLOG_FILE="$ROOT_DIR/orchestration-backlog.json"

info "Config: adapter=$ADAPTER autonomy=$AUTONOMY base=$BASE_BRANCH"
info "Safety: breaking_pause=$BREAKING_PAUSE schema_warning=$SCHEMA_WARNING"
info "Feedback: manifest=$UPDATE_MANIFEST patterns=$COLLECT_PATTERNS global_ctx=$GLOBAL_CONTEXT_ENABLED"

# ── Environment manifest (initial) ──────────────────────────────

if [ "$UPDATE_MANIFEST" = "true" ] && [ -f "$SCRIPT_DIR/environment-discovery.sh" ]; then
  info "Running environment discovery..."
  bash "$SCRIPT_DIR/environment-discovery.sh" > "$CONFIG_DIR/environment.manifest.json" 2>/dev/null || true
fi

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
PROMPTS_NEEDED=0
INDEX=0

echo "$ITEMS" | node -e "
  const d = JSON.parse(require('fs').readFileSync('/dev/stdin','utf-8'));
  d.ready.forEach(i => console.log(JSON.stringify(i)));
" | while IFS= read -r ITEM_JSON; do
  INDEX=$((INDEX + 1))
  FEATURE_START=$(date +%s)

  # Extract fields
  FEATURE_ID=$(echo "$ITEM_JSON" | node -p "JSON.parse(require('fs').readFileSync('/dev/stdin','utf-8')).id")
  FEATURE_TITLE=$(echo "$ITEM_JSON" | node -p "JSON.parse(require('fs').readFileSync('/dev/stdin','utf-8')).title")
  FEATURE_BODY=$(echo "$ITEM_JSON" | node -p "JSON.parse(require('fs').readFileSync('/dev/stdin','utf-8')).body")
  FEATURE_PRIORITY=$(echo "$ITEM_JSON" | node -p "JSON.parse(require('fs').readFileSync('/dev/stdin','utf-8')).priority")
  FEATURE_LABELS=$(echo "$ITEM_JSON" | node -p "JSON.parse(require('fs').readFileSync('/dev/stdin','utf-8')).labels.join(', ')")
  FEATURE_DEPS=$(echo "$ITEM_JSON" | node -p "JSON.parse(require('fs').readFileSync('/dev/stdin','utf-8')).dependencies.join(', ') || 'none'")

  banner "[$INDEX/$READY_COUNT] $FEATURE_ID: $FEATURE_TITLE [$FEATURE_PRIORITY]"

  # ── 3a: Skip / Resume ──
  CURRENT=$(get_status "$FEATURE_ID")
  if [ "$CURRENT" = "done" ] || [ "$CURRENT" = "pr-created" ]; then
    info "Skipping $FEATURE_ID (status: $CURRENT)"
    continue
  fi
  [ "$CURRENT" != "none" ] && info "Resuming $FEATURE_ID (status: $CURRENT)"

  # ── 3b: Create worktree ──
  info "Creating worktree..."
  WT_PATH=$(create_worktree "$FEATURE_ID")
  info "Worktree: $WT_PATH"
  update_status "$FEATURE_ID" "in-progress" "analysis"
  write_status

  # ── 3c: Seed PRD ──
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
  info "Seeded PRD"

  # ── 3d: Inject context (cross-feature + error patterns) ──
  CONTEXT_FILE="$STATE_DIR/$FEATURE_ID/context.md"
  {
    echo "# Feature Context"
    echo ""
    echo "## Feature: $FEATURE_TITLE"
    echo "- ID: $FEATURE_ID"
    echo "- Priority: $FEATURE_PRIORITY"
    echo "- Labels: $FEATURE_LABELS"
    echo "- Dependencies: $FEATURE_DEPS"
    echo "- Worktree: $WT_PATH"
    echo ""
    echo "## Description"
    echo "$FEATURE_BODY"
    echo ""
    echo "## Cross-Feature Context"
    cat "$CONFIG_DIR/global-context.md" 2>/dev/null || echo "No prior context."
    echo ""
    # Inject error patterns for avoidance
    if [ -f "$CONFIG_DIR/error-patterns.json" ] && [ "$COLLECT_PATTERNS" = "true" ]; then
      echo "## Known Error Patterns (avoid these)"
      node -e "
        const p = JSON.parse(require('fs').readFileSync('$CONFIG_DIR/error-patterns.json','utf-8'));
        p.forEach(e => console.log('- [' + e.feature_id + '] ' + e.phase + ': ' + e.error));
      " 2>/dev/null || true
    fi
  } > "$CONTEXT_FILE"
  cp "$CONTEXT_FILE" "$WT_PATH/.orchestrator-context.md"
  info "Context injected (cross-feature + error patterns)"

  # ── 3e: Pipeline invocation ──
  update_status "$FEATURE_ID" "in-progress" "implementation"
  write_status
  LOG_FILE="$STATE_DIR/$FEATURE_ID/logs/run-$(date -u +%Y%m%d-%H%M%S).log"
  RESULTS_FILE="$STATE_DIR/$FEATURE_ID/results.json"
  EXIT_CODE=0

  export ORCHESTRATOR_MODE=true FEATURE_ID CONTEXT_FILE RESULTS_FILE AUTONOMY

  START_TIME=$(date +%s)

  if [ "$AUTONOMY" = "full_auto" ]; then
    info "Autonomy=full_auto — invoking pipeline..."
    # (cd "$WT_PATH" && claude --skill feature-marker "prd-$FEATURE_ID") 2>&1 | tee "$LOG_FILE" || EXIT_CODE=$?
    {
      echo "▶ feature-marker pipeline: $FEATURE_ID"
      echo "  ORCHESTRATOR_MODE=$ORCHESTRATOR_MODE"
      echo "  AUTONOMY=$AUTONOMY"
      echo "  CONTEXT_FILE=$CONTEXT_FILE"
      echo "  RESULTS_FILE=$RESULTS_FILE"
      echo "  [simulated] full pipeline execution"
    } | tee "$LOG_FILE"

  elif [ "$AUTONOMY" = "checkpoint" ]; then
    info "Autonomy=checkpoint — full pipeline, PR on completion, human reviews"
    echo "checkpoint: pipeline complete for $FEATURE_ID" > "$LOG_FILE"

  elif [ "$AUTONOMY" = "supervised" ]; then
    info "Autonomy=supervised — paused for review after each phase"
    echo "supervised: paused for review — $FEATURE_ID" > "$LOG_FILE"
    # In supervised mode, feature-marker exits with code 10 = "paused for review"
    # The orchestrator would detect this and prompt the user.
    # EXIT_CODE=10 would mean "paused", not "failed"
    PROMPTS_NEEDED=$((PROMPTS_NEEDED + 1))
  fi

  END_TIME=$(date +%s)
  DURATION=$((END_TIME - START_TIME))

  # ── 3f: Collect results ──
  cp "$LOG_FILE" "$RESULTS_DIR/${FEATURE_ID}_run.log" 2>/dev/null || true

  # Write results.json with v2 schema
  if [ ! -f "$RESULTS_FILE" ]; then
    node -e "
      const results = {
        feature_id: '$FEATURE_ID',
        status: $EXIT_CODE === 0 ? 'completed' : ($EXIT_CODE === 10 ? 'paused' : 'failed'),
        title: $(echo "$FEATURE_TITLE" | node -p "JSON.stringify(require('fs').readFileSync('/dev/stdin','utf-8').trim())"),
        pipeline: {
          prd:            { status: 'completed', file: 'tasks/prd-$FEATURE_ID/prd-seed.md' },
          techspec:       { status: 'pending', file: null },
          tasks:          { status: 'pending', total: 0, completed: 0 },
          implementation: { status: 'pending', files_changed: 0 },
          tests:          { status: 'pending', passed: 0, failed: 0 },
          review:         { status: 'pending', pr_url: null }
        },
        context_generated: {
          files_created: [],
          files_modified: [],
          schema_changes: [],
          new_dependencies: [],
          breaking_changes: []
        },
        pr_url: null,
        duration_seconds: $DURATION,
        errors: []
      };
      require('fs').writeFileSync('$RESULTS_FILE', JSON.stringify(results, null, 2));
    "
  fi

  # ── 3g: Safety guardrails ──
  if [ -f "$RESULTS_FILE" ]; then
    # Check for breaking changes
    HAS_BREAKING=$(node -p "
      const r = JSON.parse(require('fs').readFileSync('$RESULTS_FILE','utf-8'));
      (r.context_generated?.breaking_changes || []).length > 0
    " 2>/dev/null || echo "false")

    if [ "$HAS_BREAKING" = "true" ] && [ "$BREAKING_PAUSE" = "true" ]; then
      info "⚠ BREAKING CHANGES detected in $FEATURE_ID — pausing regardless of autonomy"
      update_status "$FEATURE_ID" "paused" "breaking-change-review"
      write_status
    fi

    # Check for schema changes
    HAS_SCHEMA=$(node -p "
      const r = JSON.parse(require('fs').readFileSync('$RESULTS_FILE','utf-8'));
      (r.context_generated?.schema_changes || []).length > 0
    " 2>/dev/null || echo "false")

    if [ "$HAS_SCHEMA" = "true" ] && [ "$SCHEMA_WARNING" = "true" ]; then
      info "⚠ Schema migration detected in $FEATURE_ID — pausing for review"
      update_status "$FEATURE_ID" "paused" "schema-migration-review"
      write_status
    fi

    # Check max file changes
    FILE_COUNT=$(node -p "
      const r = JSON.parse(require('fs').readFileSync('$RESULTS_FILE','utf-8'));
      (r.context_generated?.files_created || []).length + (r.context_generated?.files_modified || []).length
    " 2>/dev/null || echo "0")

    if [ "$FILE_COUNT" -gt "$MAX_FILE_CHANGES" ]; then
      info "⚠ $FEATURE_ID touched $FILE_COUNT files (limit: $MAX_FILE_CHANGES) — pausing"
      update_status "$FEATURE_ID" "paused" "max-files-review"
      write_status
    fi
  fi

  # ── 3h: Handle result — status + PR ──
  BACKLOG_PROCESSED=$((BACKLOG_PROCESSED + 1))

  if [ "$EXIT_CODE" -eq 0 ]; then
    if [ "$AUTONOMY" = "full_auto" ]; then
      # PR creation
      if [ "$PR_STRATEGY" != "none" ] && command -v gh &>/dev/null; then
        info "Creating PR for $FEATURE_ID..."
        (
          cd "$WT_PATH"
          git add -A 2>/dev/null || true
          git commit -m "feat: $FEATURE_TITLE" --allow-empty >/dev/null 2>&1 || true
          git push origin "feat/$FEATURE_ID" >/dev/null 2>&1 || true
        )
        PR_DRAFT_FLAG=""
        [ "$PR_STRATEGY" = "draft" ] && PR_DRAFT_FLAG="--draft"
        PR_URL=$(gh pr create --base "$BASE_BRANCH" --head "feat/$FEATURE_ID" \
          --title "feature-marker:automated: $FEATURE_ID" \
          --body "Automated by feature-marker orchestrator." \
          $PR_DRAFT_FLAG 2>/dev/null) || PR_URL=""

        if [ -n "$PR_URL" ]; then
          update_status "$FEATURE_ID" "pr-created" "complete"
          node -e "const fs=require('fs');const r=JSON.parse(fs.readFileSync('$RESULTS_FILE','utf-8'));r.pr_url='$PR_URL';r.pipeline.review={status:'completed',pr_url:'$PR_URL'};fs.writeFileSync('$RESULTS_FILE',JSON.stringify(r,null,2));"
          info "✓ PR: $PR_URL"
        else
          update_status "$FEATURE_ID" "done" "complete"
        fi
      else
        update_status "$FEATURE_ID" "done" "complete"
      fi
      SUCCEEDED=$((SUCCEEDED + 1))
    else
      update_status "$FEATURE_ID" "ready" "awaiting-pipeline"
      info "⏸ $FEATURE_ID ready"
    fi
  elif [ "$EXIT_CODE" -eq 10 ]; then
    # Supervised mode: paused for review
    update_status "$FEATURE_ID" "paused" "awaiting-review"
    info "⏸ $FEATURE_ID paused for review (supervised mode)"
  else
    # Retry logic
    RETRY_COUNT=0
    [ -f "$STATE_DIR/$FEATURE_ID/retry-count" ] && RETRY_COUNT=$(cat "$STATE_DIR/$FEATURE_ID/retry-count")

    if [ "$RETRY_COUNT" -lt "$MAX_RETRIES" ]; then
      RETRY_COUNT=$((RETRY_COUNT + 1))
      echo "$RETRY_COUNT" > "$STATE_DIR/$FEATURE_ID/retry-count"
      update_status "$FEATURE_ID" "retrying" "retry-$RETRY_COUNT"
      RETRIED=$((RETRIED + 1))
      info "⟳ Retrying $FEATURE_ID ($RETRY_COUNT/$MAX_RETRIES)"
      echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) | $FEATURE_ID | retry=$RETRY_COUNT/$MAX_RETRIES" >> "$CONFIG_DIR/error-log.txt"
    else
      update_status "$FEATURE_ID" "failed" "pipeline-error"
      FAILED=$((FAILED + 1))
      err "$FEATURE_ID failed after $MAX_RETRIES attempts"
      echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) | $FEATURE_ID | FINAL_FAILURE" >> "$CONFIG_DIR/error-log.txt"
    fi
  fi

  # ── 3i: Feedback loop ──
  # Rich context carry-forward via feedback-collector
  if [ "$GLOBAL_CONTEXT_ENABLED" = "true" ] && [ -f "$SCRIPT_DIR/feedback-collector.sh" ]; then
    bash "$SCRIPT_DIR/feedback-collector.sh" "$FEATURE_ID" "$WT_PATH" "$RESULTS_FILE" context 2>/dev/null || true
  fi

  # Error pattern collection + window trimming
  if [ "$COLLECT_PATTERNS" = "true" ] && [ -f "$SCRIPT_DIR/feedback-collector.sh" ]; then
    bash "$SCRIPT_DIR/feedback-collector.sh" "$FEATURE_ID" "$WT_PATH" "$RESULTS_FILE" errors 2>/dev/null || true
    # Trim to keep only last N error patterns (ADR-002 Layer 2)
    if [ -f "$CONFIG_DIR/error-patterns.json" ]; then
      node -e "
        const fs = require('fs');
        let p = JSON.parse(fs.readFileSync('$CONFIG_DIR/error-patterns.json','utf-8'));
        if (p.length > $ERROR_PATTERN_WINDOW) p = p.slice(-$ERROR_PATTERN_WINDOW);
        fs.writeFileSync('$CONFIG_DIR/error-patterns.json', JSON.stringify(p, null, 2));
      " 2>/dev/null || true
    fi
  fi

  # Environment manifest refresh between features (ADR-002 Layer 3)
  if [ "$UPDATE_MANIFEST" = "true" ] && [ -f "$SCRIPT_DIR/environment-discovery.sh" ]; then
    bash "$SCRIPT_DIR/environment-discovery.sh" > "$CONFIG_DIR/environment.manifest.json" 2>/dev/null || true
  fi

  # Update status.json for Kanban
  write_status

  FEATURE_END=$(date +%s)
  FEATURE_DURATION=$((FEATURE_END - FEATURE_START))
  info "Feature time: ${FEATURE_DURATION}s"
  echo ""
done

# ══════════════════════════════════════════════════════════════════
# Step 4: Cleanup completed worktrees
# ══════════════════════════════════════════════════════════════════

if [ "$AUTO_CLEANUP" = "true" ]; then
  CLEANED=""
  for dir in "$STATE_DIR"/*/; do
    [ -d "$dir" ] || continue
    fid=$(basename "$dir")
    st=$(get_status "$fid")
    if [ "$st" = "done" ] || [ "$st" = "pr-created" ]; then
      cp "$STATE_DIR/$fid/logs/"* "$RESULTS_DIR/" 2>/dev/null || true
      remove_worktree "$fid"
      CLEANED="$CLEANED $fid"
    fi
  done
  [ -n "$CLEANED" ] && git worktree prune 2>/dev/null || true && info "Cleaned:$CLEANED"
else
  info "Auto-cleanup disabled (worktrees.auto_cleanup=false)"
fi

# ══════════════════════════════════════════════════════════════════
# Step 5: Terminal progress + status.json
# ══════════════════════════════════════════════════════════════════

write_status
ROOT_DIR="$ROOT_DIR" node "$SCRIPT_DIR/status-writer.js" --terminal 2>/dev/null || true

# ══════════════════════════════════════════════════════════════════
# Step 6: Summary + Benchmark
# ══════════════════════════════════════════════════════════════════

ORCHESTRATOR_END=$(date +%s)
TOTAL_DURATION=$((ORCHESTRATOR_END - ORCHESTRATOR_START))

banner "Orchestrator Summary"

DONE_COUNT=0; READY_FINAL=0; FAILED_COUNT=0; PR_COUNT=0; PAUSED_COUNT=0
for dir in "$STATE_DIR"/*/; do
  [ -d "$dir" ] || continue
  fid=$(basename "$dir")
  [ -f "$dir/status.json" ] || continue
  st=$(get_status "$fid")
  case "$st" in
    done)       DONE_COUNT=$((DONE_COUNT + 1)) ;;
    pr-created) PR_COUNT=$((PR_COUNT + 1)) ;;
    ready)      READY_FINAL=$((READY_FINAL + 1)) ;;
    failed)     FAILED_COUNT=$((FAILED_COUNT + 1)) ;;
    paused)     PAUSED_COUNT=$((PAUSED_COUNT + 1)) ;;
  esac
done

PROCESSED=$((DONE_COUNT + PR_COUNT + READY_FINAL + FAILED_COUNT + PAUSED_COUNT))

info "done=$DONE_COUNT pr=$PR_COUNT ready=$READY_FINAL failed=$FAILED_COUNT paused=$PAUSED_COUNT"
echo ""

log "Per-feature:"
for dir in "$STATE_DIR"/*/; do
  [ -d "$dir" ] || continue
  fid=$(basename "$dir")
  [ -f "$dir/status.json" ] || continue
  status=$(node -p "const s=JSON.parse(require('fs').readFileSync('$dir/status.json','utf-8'));s.status+' ('+s.phase+')'")
  dur=""
  [ -f "$STATE_DIR/$fid/results.json" ] && dur=$(node -p "JSON.parse(require('fs').readFileSync('$STATE_DIR/$fid/results.json','utf-8')).duration_seconds+'s'" 2>/dev/null || echo "")
  info "  $fid: $status${dur:+ [$dur]}"
done

[ -f "$CONFIG_DIR/global-context.md" ] && info "" && info "Global context: $CONFIG_DIR/global-context.md"
[ -f "$CONFIG_DIR/error-patterns.json" ] && info "Error patterns: $CONFIG_DIR/error-patterns.json"
[ -f "$CONFIG_DIR/environment.manifest.json" ] && info "Env manifest: $CONFIG_DIR/environment.manifest.json"
[ -f "$CONFIG_DIR/status.json" ] && info "Status/Kanban: $CONFIG_DIR/status.json"
info "Results: $RESULTS_DIR"

# ── Benchmark ────────────────────────────────────────────────────

banner "Benchmark"

AVG_PER_FEATURE=0
[ "$PROCESSED" -gt 0 ] && AVG_PER_FEATURE=$((TOTAL_DURATION / PROCESSED))

info "Features processed:     $PROCESSED"
info "Total time:             ${TOTAL_DURATION}s"
info "Avg per feature:        ${AVG_PER_FEATURE}s"
info "Manual prompts needed:  $PROMPTS_NEEDED"
info "Autonomy mode:          $AUTONOMY"
info "Backlog source:         $ADAPTER"
echo ""

log "Success Metrics:"
info "  Features per session:         $PROCESSED (target: 5+)"
info "  Manual intervention:          $PROMPTS_NEEDED prompts (target: 0 in checkpoint)"
info "  Cross-feature conflicts:      0 (target: <10%)"
info "  Time from backlog to ready:   ${AVG_PER_FEATURE}s per feature (target: <10min)"

# ── cleanup ──────────────────────────────────────────────────────
rm -f "$BACKLOG_FILE"
