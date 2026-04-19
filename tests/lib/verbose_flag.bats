#!/usr/bin/env bats
# tests/lib/verbose_flag.bats
#
# Unit tests for the --verbose / -v flag added in feat/verbose-flag:
#
#   1. orchestrate.sh flag parsing (subprocess tests)
#      - --help output mentions -v, --verbose
#      - -v before the subcommand is accepted (flag before subcommand)
#      - unknown subcommand still shows usage
#
#   2. local_model.sh debug-output gating
#      - VERBOSE=false → debug message absent from output
#      - VERBOSE=true  → debug message present in output
#
# Prerequisites: bats-core >= 1.7
#
# Run:
#   bats tests/lib/verbose_flag.bats

REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"

setup() {
  TEST_TMP="$(mktemp -d)"
  export STUBS_DIR="$BATS_TEST_DIRNAME/../stubs"

  # Stubs ahead of real binaries
  export PATH="$STUBS_DIR:$PATH"

  # Needed by local_model.sh defaults
  export STATE_DIR="$TEST_TMP/state"
  mkdir -p "$STATE_DIR"
}

teardown() {
  rm -rf "$TEST_TMP"
  unset CURL_STUB_MODE NODE_HEALTH_REACHABLE VERBOSE \
        CFG_LOCAL_MODEL_ENABLED CFG_LOCAL_MODEL_PROVIDER CFG_LOCAL_MODEL_ENDPOINT \
        LOCAL_MODEL_ENABLED LOCAL_MODEL_PROVIDER LOCAL_MODEL_ENDPOINT \
        LOCAL_MODEL_HEALTH_FILE
}

# ═══════════════════════════════════════════════════════════════════
# 1. orchestrate.sh flag parsing (subprocess)
# ═══════════════════════════════════════════════════════════════════

@test "orchestrate.sh --help lists -v, --verbose flag" {
  # Run from the repo root so git rev-parse succeeds
  run bash -c "cd '$REPO_ROOT' && bash scripts/orchestrate.sh --help"
  [ "$status" -eq 0 ]
  [[ "$output" == *"-v, --verbose"* ]]
}

@test "orchestrate.sh -v --help is accepted (verbose flag before subcommand)" {
  # -v before --help should not cause an error; help should still print
  run bash -c "cd '$REPO_ROOT' && bash scripts/orchestrate.sh -v --help"
  [ "$status" -eq 0 ]
  [[ "$output" == *"-v, --verbose"* ]]
}

@test "orchestrate.sh with unknown subcommand prints usage hint and exits non-zero" {
  run bash -c "cd '$REPO_ROOT' && bash scripts/orchestrate.sh not-a-real-subcommand 2>&1"
  [ "$status" -ne 0 ]
  [[ "$output" == *"--help"* ]]
}

# ═══════════════════════════════════════════════════════════════════
# 2. local_model.sh debug-output gating
# ═══════════════════════════════════════════════════════════════════

# Helper: define the log helpers that local_model.sh expects from its caller,
# then source the library under test.
_source_local_model() {
  # Minimal stand-ins for the orchestrate.sh log helpers
  info() { echo "  [orchestrate] $*"; }
  err()  { echo "✗ [orchestrate] $*" >&2; }
  export -f info err

  # Put the health file somewhere writable
  export LOCAL_MODEL_HEALTH_FILE="$STATE_DIR/local_model_health.json"

  # shellcheck source=scripts/lib/local_model.sh
  source "$REPO_ROOT/scripts/lib/local_model.sh"
}

@test "local_model_health_check: debug message absent when VERBOSE=false (default)" {
  export CURL_STUB_MODE="reachable"
  # Use CFG_ vars so local_model.sh initialisation picks them up at source time
  export CFG_LOCAL_MODEL_ENABLED="true"
  export CFG_LOCAL_MODEL_PROVIDER="ollama"
  export CFG_LOCAL_MODEL_ENDPOINT="http://localhost:11434"
  export VERBOSE="false"

  _source_local_model

  run local_model_health_check

  [ "$status" -eq 0 ]
  # The debug "reachable at" message must NOT appear when VERBOSE is false
  [[ "$output" != *"reachable at"* ]]
}

@test "local_model_health_check: debug message present when VERBOSE=true" {
  export CURL_STUB_MODE="reachable"
  # Use CFG_ vars so local_model.sh initialisation picks them up at source time
  export CFG_LOCAL_MODEL_ENABLED="true"
  export CFG_LOCAL_MODEL_PROVIDER="ollama"
  export CFG_LOCAL_MODEL_ENDPOINT="http://localhost:11434"
  export VERBOSE="true"

  _source_local_model

  run local_model_health_check

  [ "$status" -eq 0 ]
  # The info message must appear when VERBOSE=true and the endpoint is reachable
  [[ "$output" == *"reachable at"* ]]
  [[ "$output" == *"ollama"* ]]
}

@test "local_model_health_check: disabled — returns 0 and no debug output regardless of VERBOSE" {
  export CFG_LOCAL_MODEL_ENABLED="false"
  export VERBOSE="true"

  _source_local_model

  run local_model_health_check

  [ "$status" -eq 0 ]
  # When disabled the function returns immediately; no reachable message
  [[ "$output" != *"reachable at"* ]]
}
