#!/usr/bin/env bats
# tests/lib/global_context.bats
#
# Unit tests for gc_append_feature_summary() in scripts/lib/learning.sh.
#
# Prerequisites: bats-core >= 1.7
#   brew install bats-core       # macOS
#   apt-get install bats         # Ubuntu/Debian
#
# Run:
#   bats tests/lib/global_context.bats

REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"

setup() {
  # Isolated temp environment for each test
  TEST_TMP="$(mktemp -d)"
  export STATE_DIR="$TEST_TMP/state"
  export ROOT_DIR="$TEST_TMP"
  export CONTEXT_DIR="$TEST_TMP/.orchestrator"
  mkdir -p "$STATE_DIR"

  # Source the library under test; stub out functions that gc_append_feature_summary
  # does NOT use (info, err) so that sourcing the file doesn't fail if display.sh
  # isn't on the path.
  info()  { :; }
  err()   { :; }
  export -f info err

  # shellcheck source=scripts/lib/learning.sh
  source "$REPO_ROOT/scripts/lib/learning.sh"
}

teardown() {
  rm -rf "$TEST_TMP"
}

# ── File creation ─────────────────────────────────────────────────────

@test "creates global-context.md with a header when the file does not exist" {
  run gc_append_feature_summary "feat-001" "feat/my-feature" "done" ""

  [ "$status" -eq 0 ]
  local gc_file="$CONTEXT_DIR/global-context.md"
  [ -f "$gc_file" ]
  grep -q "# Global Orchestration Context" "$gc_file"
}

# ── Entry appended ────────────────────────────────────────────────────

@test "appends feat_id to the file after calling the function" {
  run gc_append_feature_summary "feat-001" "feat/my-feature" "done" ""

  [ "$status" -eq 0 ]
  local gc_file="$CONTEXT_DIR/global-context.md"
  grep -q "feat-001" "$gc_file"
}

@test "appended entry contains branch name" {
  run gc_append_feature_summary "feat-001" "feat/my-feature" "done" ""

  [ "$status" -eq 0 ]
  local gc_file="$CONTEXT_DIR/global-context.md"
  grep -q "feat/my-feature" "$gc_file"
}

@test "appended entry contains status" {
  run gc_append_feature_summary "feat-001" "feat/my-feature" "pr-created" ""

  [ "$status" -eq 0 ]
  local gc_file="$CONTEXT_DIR/global-context.md"
  grep -q "pr-created" "$gc_file"
}

# ── Idempotency ───────────────────────────────────────────────────────

@test "calling the function twice with the same feat_id does not duplicate the entry" {
  gc_append_feature_summary "feat-001" "feat/my-feature" "done" ""
  gc_append_feature_summary "feat-001" "feat/my-feature" "done" ""

  local gc_file="$CONTEXT_DIR/global-context.md"
  local count
  count=$(grep -c "## feat-001 " "$gc_file")
  [ "$count" -eq 1 ]
}

# ── Cost included when available ──────────────────────────────────────

@test "includes cost line when cost.json exists with cumulative_tokens" {
  mkdir -p "$STATE_DIR/feat-002"
  echo '{"cumulative_tokens": 42000}' > "$STATE_DIR/feat-002/cost.json"

  run gc_append_feature_summary "feat-002" "feat/costly-feature" "done" ""

  [ "$status" -eq 0 ]
  local gc_file="$CONTEXT_DIR/global-context.md"
  grep -q "42000 tokens" "$gc_file"
}

# ── Cost omitted when missing ─────────────────────────────────────────

@test "still writes the entry when cost.json does not exist" {
  run gc_append_feature_summary "feat-003" "feat/cheap-feature" "done" ""

  [ "$status" -eq 0 ]
  local gc_file="$CONTEXT_DIR/global-context.md"
  grep -q "feat-003" "$gc_file"
}

@test "does not include a cost line when cost.json is absent" {
  run gc_append_feature_summary "feat-003" "feat/cheap-feature" "done" ""

  [ "$status" -eq 0 ]
  local gc_file="$CONTEXT_DIR/global-context.md"
  # Should not have a cost line
  run grep "Cost:" "$gc_file"
  [ "$status" -ne 0 ]
}

# ── PR URL included ───────────────────────────────────────────────────

@test "includes PR URL in entry when pr_url argument is provided" {
  run gc_append_feature_summary "feat-004" "feat/pr-feature" "pr-created" \
    "https://github.com/org/repo/pull/99"

  [ "$status" -eq 0 ]
  local gc_file="$CONTEXT_DIR/global-context.md"
  grep -q "https://github.com/org/repo/pull/99" "$gc_file"
}

# ── PR URL omitted gracefully ─────────────────────────────────────────

@test "writes completed-successfully outcome when pr_url is empty" {
  run gc_append_feature_summary "feat-005" "feat/no-pr-feature" "done" ""

  [ "$status" -eq 0 ]
  local gc_file="$CONTEXT_DIR/global-context.md"
  grep -q "completed successfully" "$gc_file"
}
