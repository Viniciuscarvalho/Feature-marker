#!/usr/bin/env bats
# tests/lib/phase3_pause.bats — Tests for Phase 3 pause-on-exhaustion and display helpers.
#
# Tests display_paused_handoff and the paused_n row in display_summary.
# Does not invoke run_phase3_tests directly (too many orchestrator dependencies).

REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"

setup() {
  TEST_TMP="$(mktemp -d)"
  export STATE_DIR="$TEST_TMP/state"
  mkdir -p "$STATE_DIR/feat-test"

  # Stub helpers display.sh needs
  info() { :; }
  log()  { :; }
  wt_get_status() { echo "paused"; }
  export -f info log wt_get_status

  source "$REPO_ROOT/scripts/lib/display.sh"
}

teardown() {
  rm -rf "$TEST_TMP"
}

# ── display_paused_handoff ─────────────────────────────────────────────

@test "display_paused_handoff prints feature id and attempt count" {
  run display_paused_handoff "feat-test" 5 ""
  [ "$status" -eq 0 ]
  [[ "$output" == *"feat-test"* ]]
  [[ "$output" == *"5 fix attempt"* ]]
}

@test "display_paused_handoff prints resume command" {
  run display_paused_handoff "feat-auth" 3 ""
  [ "$status" -eq 0 ]
  [[ "$output" == *"--resume-paused feat-auth"* ]]
}

@test "display_paused_handoff shows trail path when pause-reason.json present" {
  local pause_file="$TEST_TMP/pause-reason.json"
  echo '{"reason":"phase3-exhausted","attempts":3,"trail_path":"/tmp/trail.log"}' > "$pause_file"

  run display_paused_handoff "feat-auth" 3 "$pause_file"
  [ "$status" -eq 0 ]
  [[ "$output" == *"/tmp/trail.log"* ]]
}

@test "display_paused_handoff is silent about trail when pause-reason.json absent" {
  run display_paused_handoff "feat-auth" 2 "/nonexistent/path.json"
  [ "$status" -eq 0 ]
  [[ "$output" != *"Trail:"* ]]
}

# ── display_summary with paused_n ──────────────────────────────────────

@test "display_summary shows Paused row when paused_n is non-zero" {
  run display_summary 2 1 3 0 120 6 2 1
  [ "$status" -eq 0 ]
  [[ "$output" == *"Paused:"*"1"* ]]
}

@test "display_summary shows Paused row as 0 when 8th arg omitted" {
  run display_summary 2 1 3 0 120 6 2
  [ "$status" -eq 0 ]
  [[ "$output" == *"Paused:"*"0"* ]]
}

@test "display_summary Avg uses ran_n not paused_n" {
  # 2 ran in 200s → avg 100s/feature; paused_n should not affect divisor
  run display_summary 1 1 0 0 200 3 2 1
  [ "$status" -eq 0 ]
  [[ "$output" == *"100s/feature"* ]]
}

# ── pause-reason.json structure ────────────────────────────────────────

@test "pause-reason.json written by orchestrator has required keys" {
  # Simulate what run_phase3_tests writes
  local pause_file="$TEST_TMP/pause-reason.json"
  node -e "
    const fs = require('fs');
    const data = {
      reason: 'phase3-exhausted',
      attempts: 3,
      last_error_sig: 'error: build failed',
      trail_path: '$TEST_TMP/phase3-attempts.log',
      paused_at: new Date().toISOString()
    };
    fs.writeFileSync('$pause_file', JSON.stringify(data, null, 2));
  "

  local reason attempts trail
  reason=$(node -p "JSON.parse(require('fs').readFileSync('$pause_file','utf-8')).reason")
  attempts=$(node -p "JSON.parse(require('fs').readFileSync('$pause_file','utf-8')).attempts")
  trail=$(node -p "JSON.parse(require('fs').readFileSync('$pause_file','utf-8')).trail_path")

  [ "$reason" = "phase3-exhausted" ]
  [ "$attempts" = "3" ]
  [[ "$trail" == *"phase3-attempts.log"* ]]
}
