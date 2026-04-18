#!/bin/bash
# lib/cycle_gate.sh — Cycle-completion gate (ADR-008 PR-D)
#
# Asserts that a feature has completed its full execution cycle before the
# orchestrator advances to the next feature.
#
# A complete cycle requires:
#   1. All 5 phase checkpoints marked "complete" in checkpoint.json
#   2. A PR URL recorded in results.json
#   3. fix_attempts = 0 across all tasks in results.json
#
# Bypass with: OPT_SKIP_CYCLE_CHECK=true (set by --skip-cycle-check flag)

# Phase identifiers expected in checkpoint.json
CYCLE_PHASES="phase0 phase1 phase2 phase3 phase4"

# ── cycle_gate_check ──────────────────────────────────────────────────
# Usage: cycle_gate_check <feat_id>
# Returns 0 if the feature completed a full cycle; 1 if incomplete.
# If OPT_SKIP_CYCLE_CHECK=true, always returns 0.

cycle_gate_check() {
  local feat_id="$1"

  if [ "${OPT_SKIP_CYCLE_CHECK:-false}" = "true" ]; then
    return 0
  fi

  local checkpoint_file="$STATE_DIR/$feat_id/checkpoint.json"
  local results_file="$STATE_DIR/$feat_id/results.json"

  # If no checkpoint file exists the feature has not started — not a blocker
  if [ ! -f "$checkpoint_file" ]; then
    return 0
  fi

  local incomplete=0

  # Check: all 5 phases marked complete
  local phases_ok
  phases_ok=$(node -p "
    try {
      const cp = JSON.parse(require('fs').readFileSync('$checkpoint_file','utf-8'));
      const phases = ['phase0','phase1','phase2','phase3','phase4'];
      const allDone = phases.every(p => cp[p] && cp[p].status === 'complete');
      allDone ? 'true' : 'false';
    } catch(e) { 'false'; }
  " 2>/dev/null || echo "false")

  [ "$phases_ok" != "true" ] && incomplete=1

  # Check: PR URL recorded
  if [ -f "$results_file" ]; then
    local has_pr
    has_pr=$(node -p "
      try {
        const r = JSON.parse(require('fs').readFileSync('$results_file','utf-8'));
        (r.pr_url && r.pr_url.length > 0) ? 'true' : 'false';
      } catch(e) { 'false'; }
    " 2>/dev/null || echo "false")

    [ "$has_pr" != "true" ] && incomplete=1

    # Check: fix_attempts = 0 across all tasks
    local has_fix_attempts
    has_fix_attempts=$(node -p "
      try {
        const r = JSON.parse(require('fs').readFileSync('$results_file','utf-8'));
        const tasks = r.tasks || [];
        const anyFix = tasks.some(t => (t.fix_attempts || 0) > 0);
        anyFix ? 'true' : 'false';
      } catch(e) { 'false'; }
    " 2>/dev/null || echo "false")

    [ "$has_fix_attempts" = "true" ] && incomplete=1
  else
    # No results file means the cycle is not complete
    incomplete=1
  fi

  return $incomplete
}

# ── cycle_gate_report ─────────────────────────────────────────────────
# Usage: cycle_gate_report <feat_id>
# Prints a diagnostic of what is incomplete for the feature's cycle.

cycle_gate_report() {
  local feat_id="$1"

  local checkpoint_file="$STATE_DIR/$feat_id/checkpoint.json"
  local results_file="$STATE_DIR/$feat_id/results.json"

  info "Cycle gate report for $feat_id:"

  if [ ! -f "$checkpoint_file" ]; then
    info "  checkpoint.json: not found (feature may not have started)"
    return
  fi

  # Phase checkpoint status
  node -e "
    const fs = require('fs');
    let cp;
    try { cp = JSON.parse(fs.readFileSync('$checkpoint_file','utf-8')); } catch(e) { cp = {}; }
    const phases = ['phase0','phase1','phase2','phase3','phase4'];
    phases.forEach(p => {
      const entry = cp[p] || {};
      const status = entry.status || 'missing';
      const ok = status === 'complete' ? '[ok]' : '[INCOMPLETE]';
      console.log('  ' + ok + ' ' + p + ': ' + status);
    });
  " 2>/dev/null || info "  Could not read checkpoint.json"

  if [ ! -f "$results_file" ]; then
    info "  results.json   : not found"
    return
  fi

  # PR URL
  node -e "
    const fs = require('fs');
    let r;
    try { r = JSON.parse(fs.readFileSync('$results_file','utf-8')); } catch(e) { r = {}; }
    const prUrl = r.pr_url || '';
    const ok = prUrl.length > 0 ? '[ok]' : '[INCOMPLETE]';
    console.log('  ' + ok + ' pr_url: ' + (prUrl || 'not recorded'));

    const tasks = r.tasks || [];
    const withFix = tasks.filter(t => (t.fix_attempts || 0) > 0);
    if (withFix.length > 0) {
      console.log('  [INCOMPLETE] fix_attempts > 0 on tasks: ' + withFix.map(t => t.id).join(', '));
    } else {
      console.log('  [ok] fix_attempts = 0 on all tasks');
    }
  " 2>/dev/null || info "  Could not read results.json"
}
