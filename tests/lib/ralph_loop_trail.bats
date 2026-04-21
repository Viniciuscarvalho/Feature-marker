#!/usr/bin/env bats
# tests/lib/ralph_loop_trail.bats — Tests for Phase 3 cross-attempt trail accumulation.
#
# Tests the trail file format and that learning_write is called with failure markers.
# Sources learning.sh directly; does not invoke run_phase3_tests (too many deps).

REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"

setup() {
  TEST_TMP="$(mktemp -d)"
  export STATE_DIR="$TEST_TMP/state"
  export ROOT_DIR="$TEST_TMP"
  mkdir -p "$STATE_DIR/feat-test"
  mkdir -p "$ROOT_DIR/.claude/feature-state"

  info() { :; }
  log()  { :; }
  export -f info log

  source "$REPO_ROOT/scripts/lib/learning.sh"
}

teardown() {
  rm -rf "$TEST_TMP"
}

# ── attempt trail file format ──────────────────────────────────────────

@test "trail file accumulates one stanza per failed attempt" {
  local trail="$STATE_DIR/feat-test/phase3-attempts.log"

  # Simulate two failed attempts writing to the trail
  for attempt in 1 2; do
    {
      echo "=== Attempt $attempt/5 ==="
      echo "Error: test output $attempt"
      echo "Fix tried: fix attempt $attempt"
      echo "Result: still broken"
      echo ""
    } >> "$trail"
  done

  local stanza_count
  stanza_count=$(grep -c "^=== Attempt" "$trail")
  [ "$stanza_count" -eq 2 ]
}

@test "trail file header includes attempt number and max" {
  local trail="$STATE_DIR/feat-test/phase3-attempts.log"
  {
    echo "=== Attempt 1/5 ==="
    echo "Error: something broke"
    echo "Fix tried: tried to fix it"
    echo "Result: still broken"
    echo ""
  } >> "$trail"

  grep -q "=== Attempt 1/5 ===" "$trail"
}

@test "trail trim keeps file under 60 lines after overflow" {
  local trail="$STATE_DIR/feat-test/phase3-attempts.log"

  # Write 70 lines to the trail
  for i in $(seq 1 14); do
    {
      echo "=== Attempt $i/20 ==="
      echo "Error: error $i"
      echo "Fix tried: fix $i"
      echo "Result: failed $i"
      echo ""
    } >> "$trail"
  done

  # Simulate the trim logic from run_phase3_tests
  if [ "$(wc -l < "$trail")" -gt 60 ]; then
    tail -60 "$trail" > "${trail}.tmp" && mv "${trail}.tmp" "$trail"
  fi

  local line_count
  line_count=$(wc -l < "$trail")
  [ "$line_count" -le 60 ]
}

# ── learning_write failure marker ──────────────────────────────────────
# Note: do not pre-create learned.json — _learning_ensure_file exits non-zero
# when the file already exists ([ ! -f ] && echo pattern). Let learning_write
# create it fresh from an empty state directory.

@test "learning_write records FAILED marker in project store" {
  local project_path="$ROOT_DIR/.claude/feature-state/learned.json"

  local error_sig="error: test failed line 42"
  learning_write "feat-test" "$error_sig" "FAILED[attempt 1]: tried fix A | result: still failing"

  local recorded_fix
  recorded_fix=$(node -p "
    const e = JSON.parse(require('fs').readFileSync('$project_path','utf-8'));
    const m = e.find(x => x.pattern === '$error_sig');
    m ? m.fix : 'NOT_FOUND';
  ")

  [[ "$recorded_fix" == FAILED* ]]
}

@test "learning_write updates existing entry on second failed attempt" {
  local project_path="$ROOT_DIR/.claude/feature-state/learned.json"

  local error_sig="error: recurring failure"
  learning_write "feat-test" "$error_sig" "FAILED[attempt 1]: fix A"
  learning_write "feat-test" "$error_sig" "FAILED[attempt 2]: fix B"

  local entry_count
  entry_count=$(node -p "
    JSON.parse(require('fs').readFileSync('$project_path','utf-8'))
      .filter(e => e.pattern === '$error_sig').length
  ")
  [ "$entry_count" -eq 1 ]

  local hits
  hits=$(node -p "
    const e = JSON.parse(require('fs').readFileSync('$project_path','utf-8'));
    const m = e.find(x => x.pattern === '$error_sig');
    m ? m.hits : 0;
  ")
  [ "$hits" -eq 2 ]
}

# ── learning_verify confidence decay ──────────────────────────────────

@test "learning_verify false decreases confidence after repeated failures" {
  local project_path="$ROOT_DIR/.claude/feature-state/learned.json"

  learning_write "feat-test" "error pattern" "some fix"
  local learn_id
  learn_id=$(node -p "
    JSON.parse(require('fs').readFileSync('$project_path','utf-8'))[0].id
  ")

  learning_verify "$learn_id" "false" "$project_path"
  learning_verify "$learn_id" "false" "$project_path"
  learning_verify "$learn_id" "false" "$project_path"

  local confidence
  confidence=$(node -p "
    const e = JSON.parse(require('fs').readFileSync('$project_path','utf-8'));
    const m = e.find(x => x.id === '$learn_id');
    m ? m.confidence : -1;
  ")

  # 0 successes, 3 failures → confidence = 0
  [ "$confidence" = "0" ]
}

@test "learning_verify true increases confidence" {
  local project_path="$ROOT_DIR/.claude/feature-state/learned.json"

  learning_write "feat-test" "error pattern" "some fix"
  local learn_id
  learn_id=$(node -p "
    JSON.parse(require('fs').readFileSync('$project_path','utf-8'))[0].id
  ")

  learning_verify "$learn_id" "true" "$project_path"
  learning_verify "$learn_id" "true" "$project_path"

  local confidence
  confidence=$(node -p "
    const e = JSON.parse(require('fs').readFileSync('$project_path','utf-8'));
    const m = e.find(x => x.id === '$learn_id');
    m ? m.confidence : -1;
  ")

  # 2 successes, 0 failures → confidence = 1
  [ "$confidence" = "1" ]
}
