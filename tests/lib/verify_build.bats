#!/usr/bin/env bats
# tests/lib/verify_build.bats — Unit tests for verify_build.sh (ADR-011 PR-E)
bats_require_minimum_version 1.5.0

REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
VERIFY_BUILD="$REPO_ROOT/scripts/verify_build.sh"
STUBS="$REPO_ROOT/tests/stubs"

setup() {
  TMPDIR_WT="$(mktemp -d)"
  mkdir -p "$TMPDIR_WT/.orchestrator"
}

teardown() {
  rm -rf "$TMPDIR_WT"
}

# ── no platform-context.json ──────────────────────────────────────────────────

@test "exits 2 (soft skip) when no platform-context.json exists" {
  run bash "$VERIFY_BUILD" "$TMPDIR_WT"
  [ "$status" -eq 2 ]
}

@test "exits 2 when platform-context.json has no build_command" {
  echo '{"stack":"unknown"}' > "$TMPDIR_WT/.orchestrator/platform-context.json"
  run bash "$VERIFY_BUILD" "$TMPDIR_WT"
  [ "$status" -eq 2 ]
}

@test "exits 0 (skip) for nonexistent worktree path" {
  run bash "$VERIFY_BUILD" "/tmp/no-such-dir-$$"
  [ "$status" -eq 2 ]
}

# ── successful build ──────────────────────────────────────────────────────────

@test "exits 0 when build command succeeds" {
  echo "{\"build_command\":\"$STUBS/swift-build-ok.sh\"}" \
    > "$TMPDIR_WT/.orchestrator/platform-context.json"
  run bash "$VERIFY_BUILD" "$TMPDIR_WT"
  [ "$status" -eq 0 ]
}

@test "prints build succeeded on success" {
  echo "{\"build_command\":\"$STUBS/swift-build-ok.sh\"}" \
    > "$TMPDIR_WT/.orchestrator/platform-context.json"
  run bash "$VERIFY_BUILD" "$TMPDIR_WT"
  [[ "$output" =~ "build succeeded" ]]
}

@test "creates verify-build.log on successful build" {
  echo "{\"build_command\":\"$STUBS/swift-build-ok.sh\"}" \
    > "$TMPDIR_WT/.orchestrator/platform-context.json"
  bash "$VERIFY_BUILD" "$TMPDIR_WT"
  [ -f "$TMPDIR_WT/.orchestrator/verify-build.log" ]
}

# ── failed build ──────────────────────────────────────────────────────────────

@test "exits 1 when build command fails" {
  echo "{\"build_command\":\"$STUBS/swift-build-fail.sh\"}" \
    > "$TMPDIR_WT/.orchestrator/platform-context.json"
  run bash "$VERIFY_BUILD" "$TMPDIR_WT"
  [ "$status" -eq 1 ]
}

@test "prints FAIL on build failure" {
  echo "{\"build_command\":\"$STUBS/swift-build-fail.sh\"}" \
    > "$TMPDIR_WT/.orchestrator/platform-context.json"
  run bash "$VERIFY_BUILD" "$TMPDIR_WT"
  [[ "$output" =~ "FAIL" ]]
}

@test "creates verify-build.log on failed build" {
  echo "{\"build_command\":\"$STUBS/swift-build-fail.sh\"}" \
    > "$TMPDIR_WT/.orchestrator/platform-context.json"
  bash "$VERIFY_BUILD" "$TMPDIR_WT" 2>/dev/null || true
  [ -f "$TMPDIR_WT/.orchestrator/verify-build.log" ]
}

@test "verify-build.log contains build output on failure" {
  echo "{\"build_command\":\"$STUBS/swift-build-fail.sh\"}" \
    > "$TMPDIR_WT/.orchestrator/platform-context.json"
  bash "$VERIFY_BUILD" "$TMPDIR_WT" 2>/dev/null || true
  run grep -q "error" "$TMPDIR_WT/.orchestrator/verify-build.log"
  [ "$status" -eq 0 ]
}

# ── alternate key names ───────────────────────────────────────────────────────

@test "reads PROJECT_BUILD_CMD key from platform-context.json" {
  echo "{\"PROJECT_BUILD_CMD\":\"$STUBS/swift-build-ok.sh\"}" \
    > "$TMPDIR_WT/.orchestrator/platform-context.json"
  run bash "$VERIFY_BUILD" "$TMPDIR_WT"
  [ "$status" -eq 0 ]
}
