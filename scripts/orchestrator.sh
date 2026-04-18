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

# ── load .env secrets (ADR-005: never in config.yml) ─────────────

if [ -f "$ROOT_DIR/.env" ]; then
  set -a
  source "$ROOT_DIR/.env" 2>/dev/null || true
  set +a
fi

# ── load config ──────────────────────────────────────────────────

eval "$(node "$SCRIPT_DIR/parse-config.js" "$ROOT_DIR/orchestrator/config.yml" 2>/dev/null || echo '')"

# Source config — provider-agnostic (ADR-005)
ADAPTER="${CFG_SOURCE_ADAPTER:-markdown}"
BACKLOG_OUTPUT="${CFG_SOURCE_OUTPUT:-orchestration-backlog.json}"

# Per-adapter config (only the active adapter's section is used)
SOURCE_FILE="${CFG_SOURCE_MARKDOWN_FILE:-features.md}"
SOURCE_LABEL="${CFG_SOURCE_GITHUB_LABEL:-feature-marker}"
SOURCE_STATE="${CFG_SOURCE_GITHUB_STATE:-open}"
SOURCE_TEAM="${CFG_SOURCE_LINEAR_TEAM:-ENG}"

# Core config
BASE_BRANCH="${CFG_EXECUTION_BASE_BRANCH:-main}"
SKIP_DONE="${CFG_EXECUTION_SKIP_DONE:-true}"
SKIP_BLOCKED="${CFG_EXECUTION_SKIP_BLOCKED:-true}"
AUTONOMY="${CFG_AUTONOMY:-checkpoint}"
MAX_RETRIES="${CFG_FEATURES_MAX_RETRIES:-2}"
PR_STRATEGY="${CFG_PR_CREATION_STRATEGY:-draft}"

# Memory (ADR-002)
UPDATE_MANIFEST="${CFG_MEMORY_ENV_REFRESH:-true}"
ERROR_PATTERN_WINDOW="${CFG_MEMORY_ERROR_PATTERN_WINDOW:-5}"
GLOBAL_CONTEXT_ENABLED="${CFG_MEMORY_CARRY_FORWARD_FROM:+true}"
COLLECT_PATTERNS="${CFG_FEATURES_TRACK_ERRORS:-true}"

# Safety
BREAKING_PAUSE="${CFG_SAFETY_BREAKING_CHANGE_PAUSE:-true}"
SCHEMA_WARNING="${CFG_SAFETY_SCHEMA_MIGRATION_REVIEW:-true}"
MAX_FILE_CHANGES="${CFG_SAFETY_MAX_FILE_CHANGES:-50}"
AUTO_CLEANUP="${CFG_WORKTREES_AUTO_CLEANUP:-true}"

# Worktree config
WORKTREE_BASE="${CFG_WORKTREES_BASE_PATH:-.worktrees}"
BRANCH_PREFIX="${CFG_WORKTREES_BRANCH_PREFIX:-feat}"
WORKTREE_ROOT="$ROOT_DIR/$WORKTREE_BASE"
export ROOT_DIR CONFIG_DIR STATE_DIR WORKTREE_ROOT
export BASE_BRANCH ADAPTER AUTONOMY WORKTREE_BASE BRANCH_PREFIX

# ── Monitoring & Post-hoc config ────────────────────────────────

MONITOR_ENABLED="${CFG_MONITORING_ENABLED:-true}"
MONITOR_POLL="${CFG_MONITORING_POLL_INTERVAL_SECONDS:-1}"
POSTHOC_QA="${CFG_POSTHOC_QA_REVIEW:-conditional}"
POSTHOC_QA_TRIGGER="${CFG_POSTHOC_QA_TRIGGER:-test_failure}"
POSTHOC_REVIEW="${CFG_POSTHOC_REVIEW_TRIGGER:-full_auto}"
POSTHOC_MAX="${CFG_POSTHOC_MAX_POSTHOC_PER_FEATURE:-2}"
REVIEW_MAX_CYCLES="${CFG_REVIEW_MAX_CYCLES:-2}"

# ── source modules ──────────────────────────────────────────────

source "$SCRIPT_DIR/worktree-manager.sh"
source "$SCRIPT_DIR/lib/checkpoint-monitor.sh"
source "$SCRIPT_DIR/lib/knowledge.sh"
source "$SCRIPT_DIR/lib/qa.sh"
source "$SCRIPT_DIR/lib/review.sh"
source "$SCRIPT_DIR/lib/orchestrator-fallbacks.sh"

# Detect if Claude CLI is available for skill delegation
CLAUDE_AVAILABLE=false
if command -v claude &>/dev/null; then
  CLAUDE_AVAILABLE=true
fi

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

BACKLOG_FILE="$ROOT_DIR/$BACKLOG_OUTPUT"

info "Config: adapter=$ADAPTER autonomy=$AUTONOMY base=$BASE_BRANCH"
info "Safety: breaking_pause=$BREAKING_PAUSE schema_warning=$SCHEMA_WARNING max_files=$MAX_FILE_CHANGES"
info "Memory: env_refresh=$UPDATE_MANIFEST error_window=$ERROR_PATTERN_WINDOW"

# ── Environment manifest (initial) ──────────────────────────────

if [ "$UPDATE_MANIFEST" = "true" ] && [ -f "$SCRIPT_DIR/environment-discovery.sh" ]; then
  info "Running environment discovery..."
  bash "$SCRIPT_DIR/environment-discovery.sh" > "$CONFIG_DIR/environment.manifest.json" 2>/dev/null || true
fi

# ══════════════════════════════════════════════════════════════════
# Step 1: Load backlog — provider-agnostic adapter resolution (ADR-005)
# ══════════════════════════════════════════════════════════════════

ADAPTER_SCRIPT="$SCRIPT_DIR/adapters/${ADAPTER}.js"

if [ ! -f "$ADAPTER_SCRIPT" ]; then
  err "No adapter found for source.adapter: $ADAPTER"
  err "Expected: $ADAPTER_SCRIPT"
  err "Available: $(ls "$SCRIPT_DIR/adapters/"*.js 2>/dev/null | xargs -I{} basename {} .js | tr '\n' ', ')"
  exit 1
fi

# Each adapter reads its own config section + env vars.
# The orchestrator only passes provider-specific parameters.
run_adapter() {
  case "$ADAPTER" in
    markdown)
      info "Running markdown adapter on $SOURCE_FILE..."
      node "$ADAPTER_SCRIPT" "$ROOT_DIR/$SOURCE_FILE"
      ;;
    github)
      # gh CLI handles auth — verify it's logged in
      if ! command -v gh &>/dev/null; then
        err "gh CLI not installed. Install: https://cli.github.com"
        exit 1
      fi
      gh auth status >/dev/null 2>&1 || {
        err "gh is not authenticated. Run: gh auth login"
        exit 1
      }
      info "Running GitHub adapter (label=$SOURCE_LABEL, state=$SOURCE_STATE)..."
      node "$ADAPTER_SCRIPT" "$SOURCE_LABEL"
      ;;
    linear)
      # LINEAR_API_KEY from .env
      if [ -z "${LINEAR_API_KEY:-}" ]; then
        err "LINEAR_API_KEY not set. Add it to .env (see .env.example)"
        exit 1
      fi
      info "Running Linear adapter (team=$SOURCE_TEAM)..."
      node "$ADAPTER_SCRIPT" "$SOURCE_TEAM"
      ;;
    *)
      # Future adapters: try generic invocation
      info "Running $ADAPTER adapter..."
      node "$ADAPTER_SCRIPT" 2>&1 || {
        err "Adapter $ADAPTER failed"
        exit 1
      }
      ;;
  esac
}

run_adapter

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

  if [ "$CLAUDE_AVAILABLE" = "true" ]; then
    claude --skill context-builder "$FEATURE_ID --worktree-path $WT_PATH --include-rules --include-routing" 2>/dev/null \
      || build_context_fallback "$FEATURE_ID" "$WT_PATH" "$FEATURE_TITLE" "$FEATURE_PRIORITY" "$FEATURE_LABELS" "$FEATURE_DEPS" "$FEATURE_BODY"
  else
    build_context_fallback "$FEATURE_ID" "$WT_PATH" "$FEATURE_TITLE" "$FEATURE_PRIORITY" "$FEATURE_LABELS" "$FEATURE_DEPS" "$FEATURE_BODY"
  fi

  info "Context injected (cross-feature + behavioral rules + routing hints)"

  # ── 3e: Pipeline invocation ──
  update_status "$FEATURE_ID" "in-progress" "implementation"
  write_status
  LOG_FILE="$STATE_DIR/$FEATURE_ID/logs/run-$(date -u +%Y%m%d-%H%M%S).log"
  RESULTS_FILE="$STATE_DIR/$FEATURE_ID/results.json"
  EXIT_CODE=0

  export ORCHESTRATOR_MODE=true FEATURE_ID CONTEXT_FILE RESULTS_FILE AUTONOMY

  # Start checkpoint monitor (background, reads checkpoint.json for phase transitions)
  if [ "$MONITOR_ENABLED" = "true" ]; then
    ckpt_start_monitor "$FEATURE_ID" "$WT_PATH"
  fi

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
    PROMPTS_NEEDED=$((PROMPTS_NEEDED + 1))
  fi

  END_TIME=$(date +%s)
  DURATION=$((END_TIME - START_TIME))

  # Stop checkpoint monitor
  if [ "$MONITOR_ENABLED" = "true" ]; then
    ckpt_stop_monitor "$FEATURE_ID"
    ckpt_sync_phase "$FEATURE_ID" "$WT_PATH"
  fi

  # ── 3e.1: Post-hoc QA (conditional, lightweight ~2,500 tokens) ──
  POSTHOC_COUNT=0
  if [ "$EXIT_CODE" -eq 0 ] && [ "$POSTHOC_COUNT" -lt "$POSTHOC_MAX" ]; then
    RUN_QA=false
    case "$POSTHOC_QA" in
      always)      RUN_QA=true ;;
      conditional)
        if [ "$POSTHOC_QA_TRIGGER" = "test_failure" ] && ckpt_should_trigger_qa "$FEATURE_ID" "$WT_PATH" 2>/dev/null; then
          RUN_QA=true
        elif [ "$POSTHOC_QA_TRIGGER" = "breaking_change" ] && [ "$HAS_BREAKING" = "true" ] 2>/dev/null; then
          RUN_QA=true
        fi
        ;;
      never) ;;
    esac

    if [ "$RUN_QA" = "true" ]; then
      info "Running post-hoc QA verification..."
      qa_verify "$FEATURE_ID" "$WT_PATH" 2>/dev/null || true
      POSTHOC_COUNT=$((POSTHOC_COUNT + 1))
    fi
  fi

  # ── 3f: Collect results ──
  cp "$LOG_FILE" "$RESULTS_DIR/${FEATURE_ID}_run.log" 2>/dev/null || true

  if [ ! -f "$RESULTS_FILE" ]; then
    if [ "$CLAUDE_AVAILABLE" = "true" ]; then
      claude --skill collect-results "$FEATURE_ID --worktree-path $WT_PATH --exit-code $EXIT_CODE" 2>/dev/null \
        || collect_results_fallback "$FEATURE_ID" "$EXIT_CODE" "$DURATION" "$FEATURE_TITLE"
    else
      collect_results_fallback "$FEATURE_ID" "$EXIT_CODE" "$DURATION" "$FEATURE_TITLE"
    fi
  fi

  # ── 3g: Safety guardrails ──
  if [ -f "$RESULTS_FILE" ]; then
    SAFETY_PAUSED=false

    if [ "$CLAUDE_AVAILABLE" = "true" ]; then
      SAFETY_VERDICT=$(claude --skill safety-check "$FEATURE_ID" 2>/dev/null || echo '{"should_pause":false}')
      if echo "$SAFETY_VERDICT" | node -p "JSON.parse(require('fs').readFileSync('/dev/stdin','utf-8')).should_pause" 2>/dev/null | grep -q true; then
        info "⚠ Safety check flagged $FEATURE_ID — pausing for review"
        update_status "$FEATURE_ID" "paused" "safety-review"
        write_status
        SAFETY_PAUSED=true
      fi
    else
      safety_check_fallback "$FEATURE_ID" || SAFETY_PAUSED=true
    fi
  fi

  # ── 3h: Handle result — status + PR ──
  BACKLOG_PROCESSED=$((BACKLOG_PROCESSED + 1))

  if [ "$EXIT_CODE" -eq 0 ]; then
    if [ "$AUTONOMY" = "full_auto" ]; then
      # Post-hoc review gate (lightweight, before PR creation)
      REVIEW_PASS=true
      if [ "$POSTHOC_REVIEW" = "always" ] || [ "$POSTHOC_REVIEW" = "full_auto" ]; then
        if [ "$POSTHOC_COUNT" -lt "$POSTHOC_MAX" ]; then
          info "Running post-hoc review..."
          REVIEW_CYCLE=0
          while [ "$REVIEW_CYCLE" -lt "$REVIEW_MAX_CYCLES" ]; do
            if review_diff "$FEATURE_ID" "$WT_PATH" 2>/dev/null; then
              info "Review passed"
              break
            else
              REVIEW_CYCLE=$((REVIEW_CYCLE + 1))
              if [ "$REVIEW_CYCLE" -lt "$REVIEW_MAX_CYCLES" ]; then
                info "Review requested changes (cycle $REVIEW_CYCLE/$REVIEW_MAX_CYCLES)"
                review_apply_fixes "$FEATURE_ID" "$WT_PATH" 2>/dev/null || true
              else
                info "Review: max cycles reached, proceeding"
              fi
            fi
          done
          POSTHOC_COUNT=$((POSTHOC_COUNT + 1))
        fi
      fi

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
    update_status "$FEATURE_ID" "paused" "awaiting-review"
    info "⏸ $FEATURE_ID paused for review (supervised mode)"
  else
    # Intelligent retry: QA agent analyzes failure before retrying
    RETRY_COUNT=0
    [ -f "$STATE_DIR/$FEATURE_ID/retry-count" ] && RETRY_COUNT=$(cat "$STATE_DIR/$FEATURE_ID/retry-count")

    if [ "$RETRY_COUNT" -lt "$MAX_RETRIES" ]; then
      # Analyze failure with QA agent (adds ~2,500 tokens, but dramatically improves retry)
      SHOULD_RETRY=true
      if [ "$POSTHOC_QA" != "never" ]; then
        info "Analyzing failure with QA agent..."
        qa_analyze_failure "$FEATURE_ID" "$WT_PATH" "$LOG_FILE" 2>/dev/null || true
        if ! qa_should_retry "$FEATURE_ID" "$WT_PATH" 2>/dev/null; then
          SHOULD_RETRY=false
          info "QA agent: low confidence in retry — escalating"
        fi
      fi

      if [ "$SHOULD_RETRY" = "true" ]; then
        RETRY_COUNT=$((RETRY_COUNT + 1))
        echo "$RETRY_COUNT" > "$STATE_DIR/$FEATURE_ID/retry-count"
        update_status "$FEATURE_ID" "retrying" "retry-$RETRY_COUNT"
        RETRIED=$((RETRIED + 1))
        info "⟳ Retrying $FEATURE_ID ($RETRY_COUNT/$MAX_RETRIES) with enriched context"
        echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) | $FEATURE_ID | retry=$RETRY_COUNT/$MAX_RETRIES" >> "$CONFIG_DIR/error-log.txt"
      else
        update_status "$FEATURE_ID" "failed" "qa-escalated"
        FAILED=$((FAILED + 1))
        err "$FEATURE_ID — QA agent escalated (not retrying)"
        echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) | $FEATURE_ID | QA_ESCALATED" >> "$CONFIG_DIR/error-log.txt"
      fi
    else
      update_status "$FEATURE_ID" "failed" "pipeline-error"
      FAILED=$((FAILED + 1))
      err "$FEATURE_ID failed after $MAX_RETRIES attempts"
      echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) | $FEATURE_ID | FINAL_FAILURE" >> "$CONFIG_DIR/error-log.txt"
    fi
  fi

  # ── 3i: Feedback loop ──
  if [ "$CLAUDE_AVAILABLE" = "true" ]; then
    claude --skill kb-learn "--from-qa $FEATURE_ID" 2>/dev/null \
      || kb_record_fallback "$FEATURE_ID" "$WT_PATH"
  else
    kb_record_fallback "$FEATURE_ID" "$WT_PATH"
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
# Step 5-6: Summary, Benchmark, Status
# ══════════════════════════════════════════════════════════════════

ORCHESTRATOR_END=$(date +%s)
TOTAL_DURATION=$((ORCHESTRATOR_END - ORCHESTRATOR_START))

if [ "$CLAUDE_AVAILABLE" = "true" ]; then
  claude --skill orch-status 2>/dev/null \
    || display_summary_fallback "$TOTAL_DURATION"
else
  display_summary_fallback "$TOTAL_DURATION"
fi

# ── cleanup ──────────────────────────────────────────────────────
rm -f "$BACKLOG_FILE"
