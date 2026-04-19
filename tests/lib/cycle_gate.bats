#!/usr/bin/env bats
# tests/lib/cycle_gate.bats — Unit tests for cycle_gate_check and cycle_gate_report

setup() {
  TEST_TMP="$(mktemp -d)"
  export STATE_DIR="$TEST_TMP/state"
  mkdir -p "$STATE_DIR"

  # Stub info to echo so report output is assertable
  info() { echo "$*"; }
  export -f info

  source /Users/bocato/development/fm-pr-b/scripts/lib/cycle_gate.sh
}

teardown() {
  rm -rf "$TEST_TMP"
}

# ── helpers ───────────────────────────────────────────────────────────────────

make_complete_checkpoint() {
  local feat_id="$1"
  local dir="$STATE_DIR/$feat_id"
  mkdir -p "$dir"
  node -e "
    require('fs').writeFileSync('$dir/checkpoint.json', JSON.stringify({
      phase0: { status: 'complete' },
      phase1: { status: 'complete' },
      phase2: { status: 'complete' },
      phase3: { status: 'complete' },
      phase4: { status: 'complete' }
    }, null, 2));
  "
}

make_results_clean() {
  local feat_id="$1"
  local dir="$STATE_DIR/$feat_id"
  mkdir -p "$dir"
  node -e "
    require('fs').writeFileSync('$dir/results.json', JSON.stringify({
      pr_url: 'https://github.com/example/repo/pull/1',
      tasks: [
        { id: 'task-1', fix_attempts: 0 },
        { id: 'task-2', fix_attempts: 0 }
      ]
    }, null, 2));
  "
}

make_results_with_fix_attempts() {
  local feat_id="$1"
  local dir="$STATE_DIR/$feat_id"
  mkdir -p "$dir"
  node -e "
    require('fs').writeFileSync('$dir/results.json', JSON.stringify({
      pr_url: 'https://github.com/example/repo/pull/2',
      tasks: [
        { id: 'task-1', fix_attempts: 0 },
        { id: 'task-2', fix_attempts: 2 }
      ]
    }, null, 2));
  "
}

# ── cycle_gate_check ──────────────────────────────────────────────────────────

@test "cycle_gate_check returns 0 when no checkpoint file exists" {
  run cycle_gate_check "feat-no-checkpoint"
  [ "$status" -eq 0 ]
}

@test "cycle_gate_check returns 0 when OPT_SKIP_CYCLE_CHECK=true" {
  export OPT_SKIP_CYCLE_CHECK=true
  make_complete_checkpoint "feat-skip"
  run cycle_gate_check "feat-skip"
  [ "$status" -eq 0 ]
  unset OPT_SKIP_CYCLE_CHECK
}

@test "cycle_gate_check returns 0 for a fully complete cycle" {
  make_complete_checkpoint "feat-ok"
  make_results_clean "feat-ok"
  run cycle_gate_check "feat-ok"
  [ "$status" -eq 0 ]
}

@test "cycle_gate_check returns 1 when a phase is not complete" {
  local feat_id="feat-incomplete-phase"
  local dir="$STATE_DIR/$feat_id"
  mkdir -p "$dir"
  node -e "
    require('fs').writeFileSync('$dir/checkpoint.json', JSON.stringify({
      phase0: { status: 'complete' },
      phase1: { status: 'complete' },
      phase2: { status: 'in_progress' },
      phase3: { status: 'complete' },
      phase4: { status: 'complete' }
    }, null, 2));
  "
  make_results_clean "$feat_id"
  run cycle_gate_check "$feat_id"
  [ "$status" -eq 1 ]
}

@test "cycle_gate_check returns 1 when results.json is missing" {
  make_complete_checkpoint "feat-no-results"
  run cycle_gate_check "feat-no-results"
  [ "$status" -eq 1 ]
}

@test "cycle_gate_check returns 1 when pr_url is empty" {
  local feat_id="feat-no-pr"
  make_complete_checkpoint "$feat_id"
  local dir="$STATE_DIR/$feat_id"
  node -e "
    require('fs').writeFileSync('$dir/results.json', JSON.stringify({
      pr_url: '',
      tasks: []
    }, null, 2));
  "
  run cycle_gate_check "$feat_id"
  [ "$status" -eq 1 ]
}

@test "cycle_gate_check returns 1 when any task has fix_attempts > 0" {
  make_complete_checkpoint "feat-fix"
  make_results_with_fix_attempts "feat-fix"
  run cycle_gate_check "feat-fix"
  [ "$status" -eq 1 ]
}

@test "cycle_gate_check returns 1 when checkpoint is missing some phases" {
  local feat_id="feat-missing-phases"
  local dir="$STATE_DIR/$feat_id"
  mkdir -p "$dir"
  node -e "
    require('fs').writeFileSync('$dir/checkpoint.json', JSON.stringify({
      phase0: { status: 'complete' },
      phase1: { status: 'complete' }
    }, null, 2));
  "
  make_results_clean "$feat_id"
  run cycle_gate_check "$feat_id"
  [ "$status" -eq 1 ]
}

# ── cycle_gate_report ─────────────────────────────────────────────────────────

@test "cycle_gate_report runs without error for a feature with no checkpoint" {
  run cycle_gate_report "feat-no-cp"
  [ "$status" -eq 0 ]
}

@test "cycle_gate_report runs without error for a complete feature" {
  make_complete_checkpoint "feat-report"
  make_results_clean "feat-report"
  run cycle_gate_report "feat-report"
  [ "$status" -eq 0 ]
}

@test "cycle_gate_report shows ok for all phases when complete" {
  make_complete_checkpoint "feat-ok-report"
  make_results_clean "feat-ok-report"
  run cycle_gate_report "feat-ok-report"
  [ "$status" -eq 0 ]
  [[ "$output" == *"[ok]"* ]]
}

@test "cycle_gate_report shows INCOMPLETE for partial checkpoint" {
  local feat_id="feat-partial-report"
  local dir="$STATE_DIR/$feat_id"
  mkdir -p "$dir"
  node -e "
    require('fs').writeFileSync('$dir/checkpoint.json', JSON.stringify({
      phase0: { status: 'complete' },
      phase1: { status: 'in_progress' },
      phase2: { status: 'missing' },
      phase3: { status: 'complete' },
      phase4: { status: 'complete' }
    }, null, 2));
  "
  make_results_clean "$feat_id"
  run cycle_gate_report "$feat_id"
  [ "$status" -eq 0 ]
  [[ "$output" == *"INCOMPLETE"* ]]
}

@test "cycle_gate_report mentions not found when results.json is absent" {
  make_complete_checkpoint "feat-no-res-report"
  run cycle_gate_report "feat-no-res-report"
  [ "$status" -eq 0 ]
  [[ "$output" == *"not found"* ]]
}
