#!/bin/bash
# lib/ingest.sh — Phase 4.5 review-ingest step (ADR-009 PR-G)
#
# Triggered after a feature PR is merged to the base branch.
# Fetches PR review comments and post-merge CI failure logs, runs
# local_model::summarize over each, and writes high-confidence fixes
# into the project-tier learning store.
#
# Confidence threshold: only fixes >= 0.7 are written to the store.
# Fixes below threshold are logged to .orchestrator/state/{feat_id}.log.
#
# Public functions:
#   ingest_reviews <feat_id>          — full review-ingest pass
#   ingest_trigger_if_merged <feat_id> — trigger only if PR is merged (used by runner)

INGEST_CONFIDENCE_THRESHOLD="${INGEST_CONFIDENCE_THRESHOLD:-0.7}"

# ── ingest_reviews ────────────────────────────────────────────────────
# Usage: ingest_reviews <feat_id>
# Runs the full review-ingest pipeline for a feature.
# Records a review_ingest entry in .orchestrator/state/{feat_id}/ingest.json.

ingest_reviews() {
  local feat_id="$1"

  if [ "${LOCAL_MODEL_ENABLED:-false}" != "true" ]; then
    info "Ingest: local model disabled — skipping review-ingest for $feat_id"
    return 0
  fi

  local results_file="$STATE_DIR/$feat_id/results.json"
  if [ ! -f "$results_file" ]; then
    err "Ingest: no results.json for $feat_id — cannot determine PR URL"
    return 1
  fi

  local pr_url
  pr_url=$(node -p "
    try {
      JSON.parse(require('fs').readFileSync('$results_file','utf-8')).pr_url || '';
    } catch(e) { ''; }
  " 2>/dev/null || echo "")

  if [ -z "$pr_url" ]; then
    info "Ingest: no PR URL recorded for $feat_id — skipping"
    return 0
  fi

  local pr_num
  pr_num=$(echo "$pr_url" | sed 's|.*/||')

  info "Ingest: processing $feat_id (PR #$pr_num)"

  local total_written=0

  # Source 1: PR review comments
  local review_text=""
  if command -v gh &>/dev/null; then
    review_text=$(gh pr view "$pr_num" --comments 2>/dev/null || echo "")
  fi

  if [ -n "$review_text" ]; then
    local review_fixes
    review_fixes=$(local_model::summarize "$review_text")
    total_written=$((total_written + $(ingest_write_fixes "$feat_id" "$review_fixes" "pr_review")))
  fi

  # Source 2: post-merge CI failure logs (first failed run after merge)
  local ci_log=""
  if command -v gh &>/dev/null; then
    local failed_run_id
    failed_run_id=$(gh run list --limit 5 --json status,databaseId \
      --jq '.[] | select(.status=="failure") | .databaseId' 2>/dev/null | head -1 || echo "")
    if [ -n "$failed_run_id" ]; then
      ci_log=$(gh run view "$failed_run_id" --log-failed 2>/dev/null | head -200 || echo "")
    fi
  fi

  if [ -n "$ci_log" ]; then
    local ci_fixes
    ci_fixes=$(local_model::summarize "$ci_log")
    total_written=$((total_written + $(ingest_write_fixes "$feat_id" "$ci_fixes" "ci_failure")))
  fi

  # Record ingest run
  local ingest_record="$STATE_DIR/$feat_id/ingest.json"
  node -e "
    const fs = require('fs');
    let records;
    try { records = JSON.parse(fs.readFileSync('${ingest_record}','utf-8')); } catch(e) { records = []; }
    records.push({
      type: 'review_ingest',
      feat_id: '${feat_id}',
      pr_url: '${pr_url}',
      ran_at: new Date().toISOString(),
      fixes_written: ${total_written}
    });
    fs.writeFileSync('${ingest_record}', JSON.stringify(records, null, 2));
  " 2>/dev/null || true

  info "Ingest: wrote $total_written fix(es) to project learning store (feat: $feat_id)"
}

# ── ingest_write_fixes ────────────────────────────────────────────────
# Internal: write fixes from summarizer JSON to the project learning store.
# Only writes fixes with confidence >= INGEST_CONFIDENCE_THRESHOLD.
# Usage: ingest_write_fixes <feat_id> <summarizer_json> <source_label>
# Prints number of entries written to stdout.

ingest_write_fixes() {
  local feat_id="$1"
  local summarizer_json="$2"
  local source_label="$3"

  local project_path="$ROOT_DIR/.claude/feature-state/learned.json"
  local log_file="$STATE_DIR/$feat_id/$(date -u +%Y%m%d-%H%M%S)-ingest.log"

  local written=0

  # Parse and write each fix
  written=$(echo "$summarizer_json" | node -e "
    const fs = require('fs');
    let input = '';
    process.stdin.on('data', d => input += d);
    process.stdin.on('end', () => {
      let data;
      try { data = JSON.parse(input); } catch(e) { process.stdout.write('0'); return; }

      const fixes = data.fixes || [];
      const globalConf = data.confidence || 0;
      const threshold = ${INGEST_CONFIDENCE_THRESHOLD};
      const projectPath = '${project_path}';
      const logPath = '${log_file}';
      const source = '${source_label}';

      let store;
      try { store = JSON.parse(fs.readFileSync(projectPath, 'utf-8')); } catch(e) { store = []; }

      let written = 0;
      const skipped = [];

      fixes.forEach(fix => {
        const conf = fix.confidence !== undefined ? fix.confidence : globalConf;
        if (!fix.pattern || !fix.fix) return;

        if (conf < threshold) {
          skipped.push({ pattern: fix.pattern, confidence: conf });
          return;
        }

        const existing = store.find(e => !e.archived && e.pattern === fix.pattern);
        const now = new Date().toISOString();
        if (existing) {
          existing.hits = (existing.hits || 0) + 1;
          existing.last_seen = now;
        } else {
          const rand = Math.random().toString(16).slice(2, 10);
          store.push({
            id: 'learn-' + rand,
            pattern: fix.pattern,
            fix: fix.fix,
            tier: 'project',
            source: source,
            created_at: now,
            last_seen: now,
            hits: 1,
            success_count: 0,
            failure_count: 0,
            confidence: null,
            ttl_days: 90,
            archived: false,
            promotion_candidate: false
          });
          written++;
        }
      });

      const dir = require('path').dirname(projectPath);
      require('fs').mkdirSync(dir, { recursive: true });
      fs.writeFileSync(projectPath, JSON.stringify(store, null, 2));

      if (skipped.length > 0) {
        const logDir = require('path').dirname(logPath);
        require('fs').mkdirSync(logDir, { recursive: true });
        fs.writeFileSync(logPath, JSON.stringify({
          source, skipped_reason: 'confidence below threshold',
          threshold: ${INGEST_CONFIDENCE_THRESHOLD}, skipped
        }, null, 2));
      }

      process.stdout.write(String(written));
    });
  " 2>/dev/null || echo "0")

  echo "${written:-0}"
}

# ── ingest_trigger_if_merged ──────────────────────────────────────────
# Usage: ingest_trigger_if_merged <feat_id>
# Called by runner.sh after merge detection (ADR-008 D8).
# Runs ingest_reviews in the background so Phase 4 does not block.

ingest_trigger_if_merged() {
  local feat_id="$1"

  [ "${LOCAL_MODEL_ENABLED:-false}" != "true" ] && return 0

  local results_file="$STATE_DIR/$feat_id/results.json"
  [ ! -f "$results_file" ] && return 0

  local pr_url
  pr_url=$(node -p "
    try { JSON.parse(require('fs').readFileSync('$results_file','utf-8')).pr_url || ''; }
    catch(e) { ''; }
  " 2>/dev/null || echo "")

  [ -z "$pr_url" ] && return 0

  # Background: do not block Phase 4
  (ingest_reviews "$feat_id" >> "$STATE_DIR/$feat_id/ingest-bg.log" 2>&1) &
  info "Ingest: background review-ingest triggered for $feat_id (PID $!)"
}
