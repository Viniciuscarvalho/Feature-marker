#!/usr/bin/env bats
# tests/lib/ingest.bats
#
# Unit tests for scripts/lib/ingest.sh covering the two issues fixed in
# feat/adr-010-skill-pluggability:
#
#   1. Collapsed pid-file reads  (ingest_reap_stale / ingest_status)
#      — each pid file is now read with a single node call that returns
#        pid, feat_id, and started_at tab-separated.
#
#   2. JS-interpolation removal  (all node -e/-p sites)
#      — shell vars no longer appear inside JS string literals; values
#        pass via process.argv instead.
#
# Prerequisites: bats-core >= 1.7, node >= 16 in PATH
#
# Run:
#   bats tests/lib/ingest.bats

REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"

# ── helpers ───────────────────────────────────────────────────────────

# Write a valid pid-file JSON for a given feat_id and pid.
_write_pid_file() {
  local pid_file="$1" pid="$2" feat_id="$3" started_at="${4:-2026-04-19T00:00:00.000Z}"
  mkdir -p "$(dirname "$pid_file")"
  printf '{"pid":%s,"feat_id":"%s","started_at":"%s"}\n' \
    "$pid" "$feat_id" "$started_at" > "$pid_file"
}

# Write a minimal results.json with a pr_url.
_write_results() {
  local file="$1" pr_url="$2"
  mkdir -p "$(dirname "$file")"
  printf '{"pr_url":"%s"}\n' "$pr_url" > "$file"
}

# Source ingest.sh with the minimal environment it needs.
_source_ingest() {
  info()  { echo "[info] $*"; }
  err()   { echo "[err] $*" >&2; }
  export -f info err

  export LOCAL_MODEL_ENABLED="${LOCAL_MODEL_ENABLED:-false}"
  export INGEST_CONFIDENCE_THRESHOLD="${INGEST_CONFIDENCE_THRESHOLD:-0.7}"

  # shellcheck source=scripts/lib/ingest.sh
  source "$REPO_ROOT/scripts/lib/ingest.sh"
}

# ── setup / teardown ──────────────────────────────────────────────────

setup() {
  TEST_TMP="$(mktemp -d)"
  export STATE_DIR="$TEST_TMP/state"
  export ROOT_DIR="$TEST_TMP"
  mkdir -p "$STATE_DIR"

  # Put stubs ahead of real binaries so gh/git are controlled;
  # real node is used for all ingest calls (stub passes through argv-based calls).
  export STUBS_DIR="$BATS_TEST_DIRNAME/../stubs"
  export PATH="$STUBS_DIR:$PATH"
}

teardown() {
  rm -rf "$TEST_TMP"
  unset STATE_DIR ROOT_DIR LOCAL_MODEL_ENABLED INGEST_CONFIDENCE_THRESHOLD
}

# ═══════════════════════════════════════════════════════════════════════
# 1. ingest_status — collapsed pid-file reads
# ═══════════════════════════════════════════════════════════════════════

@test "ingest_status: no state directory → reports no active jobs" {
  rm -rf "$STATE_DIR"
  _source_ingest

  run ingest_status

  [ "$status" -eq 0 ]
  [[ "$output" == *"No state directory"* ]]
}

@test "ingest_status: no pid files → reports no active jobs" {
  _source_ingest

  run ingest_status

  [ "$status" -eq 0 ]
  [[ "$output" == *"No active background ingest jobs"* ]]
}

@test "ingest_status: pid file present — all three fields (pid, feat_id, started_at) appear in output" {
  _write_pid_file "$STATE_DIR/my-feat/ingest.pid" 12345 "my-feat" "2026-04-19T10:00:00.000Z"
  _source_ingest

  run ingest_status

  [ "$status" -eq 0 ]
  [[ "$output" == *"my-feat"* ]]
  [[ "$output" == *"12345"* ]]
  [[ "$output" == *"2026-04-19T10:00:00.000Z"* ]]
}

@test "ingest_status: process not running → shows zombie status" {
  # PID 99999 is virtually guaranteed to not be a live process
  _write_pid_file "$STATE_DIR/z-feat/ingest.pid" 99999 "z-feat"
  _source_ingest

  run ingest_status

  [ "$status" -eq 0 ]
  [[ "$output" == *"zombie"* ]]
}

@test "ingest_status: corrupt pid file → returns 0 without crashing" {
  mkdir -p "$STATE_DIR/bad-feat"
  echo "not json at all" > "$STATE_DIR/bad-feat/ingest.pid"
  _source_ingest

  run ingest_status

  [ "$status" -eq 0 ]
}

# ═══════════════════════════════════════════════════════════════════════
# 2. ingest_reap_stale — collapsed pid-file reads + cleanup logic
# ═══════════════════════════════════════════════════════════════════════

@test "ingest_reap_stale: no state directory → returns 0" {
  rm -rf "$STATE_DIR"
  _source_ingest

  run ingest_reap_stale

  [ "$status" -eq 0 ]
}

@test "ingest_reap_stale: pid=0 in pid file → file removed immediately" {
  local pid_file="$STATE_DIR/zero-feat/ingest.pid"
  _write_pid_file "$pid_file" 0 "zero-feat"
  _source_ingest

  run ingest_reap_stale

  [ "$status" -eq 0 ]
  [ ! -f "$pid_file" ]
}

@test "ingest_reap_stale: dead pid → pid file removed and feat_id logged" {
  local pid_file="$STATE_DIR/dead-feat/ingest.pid"
  _write_pid_file "$pid_file" 99999 "dead-feat"
  _source_ingest

  run ingest_reap_stale

  [ "$status" -eq 0 ]
  [ ! -f "$pid_file" ]
  [[ "$output" == *"dead-feat"* ]]
}

@test "ingest_reap_stale: live pid → pid file kept" {
  # Use the current test process as a guaranteed live PID
  local pid_file="$STATE_DIR/live-feat/ingest.pid"
  _write_pid_file "$pid_file" $$ "live-feat"
  _source_ingest

  run ingest_reap_stale

  [ "$status" -eq 0 ]
  [ -f "$pid_file" ]
}

@test "ingest_reap_stale: corrupt pid file → returns 0 without crashing" {
  mkdir -p "$STATE_DIR/corrupt-feat"
  echo "{ bad json" > "$STATE_DIR/corrupt-feat/ingest.pid"
  _source_ingest

  run ingest_reap_stale

  [ "$status" -eq 0 ]
}

# ═══════════════════════════════════════════════════════════════════════
# 3. ingest_trigger_if_merged — injection safety (argv-based pid write)
# ═══════════════════════════════════════════════════════════════════════

@test "ingest_trigger_if_merged: pid file contains literal feat_id (no JS injection)" {
  # feat_id with a single-quote would break the old interpolated pattern
  local feat_id="it's-a-tricky-feat"
  local results_file="$STATE_DIR/$feat_id/results.json"
  _write_results "$results_file" "https://github.com/org/repo/pull/42"

  export LOCAL_MODEL_ENABLED="true"
  _source_ingest

  # Run the function; it tries to background ingest_reviews which may not be
  # available — that's fine, we only care about the pid file write.
  ingest_trigger_if_merged "$feat_id" 2>/dev/null || true

  local pid_file="$STATE_DIR/$feat_id/ingest.pid"
  [ -f "$pid_file" ]

  # The stored feat_id must be the literal string, not an execution artefact
  local stored_feat_id
  stored_feat_id=$(node -p "JSON.parse(require('fs').readFileSync(process.argv[1],'utf-8')).feat_id" "$pid_file")
  [ "$stored_feat_id" = "$feat_id" ]
}

@test "ingest_trigger_if_merged: pid file contains numeric pid" {
  local feat_id="numeric-pid-feat"
  _write_results "$STATE_DIR/$feat_id/results.json" "https://github.com/org/repo/pull/1"

  export LOCAL_MODEL_ENABLED="true"
  _source_ingest

  ingest_trigger_if_merged "$feat_id" 2>/dev/null || true

  local pid_file="$STATE_DIR/$feat_id/ingest.pid"
  [ -f "$pid_file" ]

  local stored_pid
  stored_pid=$(node -p "typeof JSON.parse(require('fs').readFileSync(process.argv[1],'utf-8')).pid" "$pid_file")
  [ "$stored_pid" = "number" ]
}

@test "ingest_trigger_if_merged: returns 0 when LOCAL_MODEL_ENABLED is false" {
  export LOCAL_MODEL_ENABLED="false"
  _source_ingest

  run ingest_trigger_if_merged "any-feat"

  [ "$status" -eq 0 ]
}

@test "ingest_trigger_if_merged: returns 0 when results.json absent" {
  export LOCAL_MODEL_ENABLED="true"
  _source_ingest

  run ingest_trigger_if_merged "no-results-feat"

  [ "$status" -eq 0 ]
}

# ═══════════════════════════════════════════════════════════════════════
# 4. ingest_write_fixes — argv-based threshold + path passing
# ═══════════════════════════════════════════════════════════════════════

@test "ingest_write_fixes: writes fix above threshold to learned.json" {
  export ROOT_DIR="$TEST_TMP"
  local feat_id="threshold-feat"
  export INGEST_CONFIDENCE_THRESHOLD="0.5"

  local summarizer_json='{"confidence":0.9,"fixes":[{"pattern":"missing null check","fix":"add null guard","confidence":0.9}]}'

  _source_ingest

  run ingest_write_fixes "$feat_id" "$summarizer_json" "pr_review"

  [ "$status" -eq 0 ]
  [ "$output" -eq 1 ]  # one fix written

  local store="$TEST_TMP/.claude/feature-state/learned.json"
  [ -f "$store" ]
  local count
  count=$(node -p "JSON.parse(require('fs').readFileSync(process.argv[1],'utf-8')).length" "$store")
  [ "$count" -eq 1 ]
}

@test "ingest_write_fixes: skips fix below threshold and writes 0" {
  export ROOT_DIR="$TEST_TMP"
  local feat_id="low-conf-feat"
  export INGEST_CONFIDENCE_THRESHOLD="0.8"

  local summarizer_json='{"confidence":0.3,"fixes":[{"pattern":"low confidence fix","fix":"maybe do this","confidence":0.3}]}'

  _source_ingest

  run ingest_write_fixes "$feat_id" "$summarizer_json" "pr_review"

  [ "$status" -eq 0 ]
  [ "$output" -eq 0 ]  # nothing written
}

@test "ingest_write_fixes: invalid JSON from summarizer → writes 0, does not crash" {
  export ROOT_DIR="$TEST_TMP"
  _source_ingest

  run ingest_write_fixes "bad-json-feat" "not json" "ci_failure"

  [ "$status" -eq 0 ]
  [ "$output" -eq 0 ]
}
