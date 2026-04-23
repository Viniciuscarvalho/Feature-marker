#!/usr/bin/env bats
# tests/lib/stack_profile.bats — Unit tests for stack_profile.sh (ADR-011 PR-A)
bats_require_minimum_version 1.5.0

REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
LIB_DIR="$REPO_ROOT/scripts/lib"
SWIFT_FIXTURE="$REPO_ROOT/tests/fixtures/swift-sample"

setup() {
  TEST_TMP="$(mktemp -d)"
  export LIB_DIR
  source "$LIB_DIR/stack_profile.sh"
  unset PROJECT_STACK PROJECT_STACK_SUBTYPE PROJECT_BUILD_CMD PROJECT_TEST_CMD
  unset PROJECT_LINT_CMD PROJECT_MANIFEST PROJECT_SOURCE_DIRS PROJECT_PACKAGE_MANAGER
}

teardown() {
  rm -rf "$TEST_TMP"
}

# ── stack_profile_cache_path ──────────────────────────────────────────────────

@test "stack_profile_cache_path returns .orchestrator/platform-context.json path" {
  run stack_profile_cache_path "/some/wt"
  [ "$status" -eq 0 ]
  [ "$output" = "/some/wt/.orchestrator/platform-context.json" ]
}

# ── stack_profile_init — swift sample fixture ─────────────────────────────────

@test "stack_profile_init detects ios from Package.swift" {
  stack_profile_init "$SWIFT_FIXTURE"
  [ "$PROJECT_STACK" = "ios" ]
}

@test "stack_profile_init exports PROJECT_TEST_CMD for swift" {
  stack_profile_init "$SWIFT_FIXTURE"
  [ -n "$PROJECT_TEST_CMD" ]
  echo "$PROJECT_TEST_CMD" | grep -q "swift"
}

@test "stack_profile_init exports PROJECT_BUILD_CMD for swift" {
  stack_profile_init "$SWIFT_FIXTURE"
  [ -n "$PROJECT_BUILD_CMD" ]
}

@test "stack_profile_init exports PROJECT_MANIFEST=Package.swift for swift" {
  stack_profile_init "$SWIFT_FIXTURE"
  [ "$PROJECT_MANIFEST" = "Package.swift" ]
}

@test "stack_profile_init exports PROJECT_SOURCE_DIRS for swift" {
  stack_profile_init "$SWIFT_FIXTURE"
  [ -n "$PROJECT_SOURCE_DIRS" ]
}

@test "stack_profile_init creates platform-context.json in worktree .orchestrator" {
  stack_profile_init "$SWIFT_FIXTURE"
  [ -f "$SWIFT_FIXTURE/.orchestrator/platform-context.json" ]
}

# ── stack_profile_init — node fixture ────────────────────────────────────────

@test "stack_profile_init detects nodejs from package.json" {
  local wt="$TEST_TMP/node-proj"
  mkdir -p "$wt"
  echo '{"name":"test","scripts":{"test":"jest"}}' > "$wt/package.json"
  stack_profile_init "$wt"
  [ "$PROJECT_STACK" = "nodejs" ] || [ "$PROJECT_STACK" = "node" ]
}

@test "stack_profile_init exports PROJECT_MANIFEST=package.json for node" {
  local wt="$TEST_TMP/node-proj2"
  mkdir -p "$wt"
  echo '{"name":"test"}' > "$wt/package.json"
  stack_profile_init "$wt"
  [ "$PROJECT_MANIFEST" = "package.json" ]
}

# ── stack_profile_init — rust fixture ────────────────────────────────────────

@test "stack_profile_init detects rust from Cargo.toml" {
  local wt="$TEST_TMP/rust-proj"
  mkdir -p "$wt/src"
  printf '[package]\nname = "myapp"\nversion = "0.1.0"\n' > "$wt/Cargo.toml"
  touch "$wt/src/main.rs"
  stack_profile_init "$wt"
  [ "$PROJECT_STACK" = "rust" ]
}

# ── stack_profile_init — unknown ─────────────────────────────────────────────

@test "stack_profile_init exports PROJECT_STACK=unknown for empty directory" {
  stack_profile_init "$TEST_TMP"
  [ "$PROJECT_STACK" = "unknown" ]
}

# ── stack_profile_primary ─────────────────────────────────────────────────────

@test "stack_profile_primary returns unknown before init" {
  run stack_profile_primary
  [ "$status" -eq 0 ]
  [ "$output" = "unknown" ]
}

@test "stack_profile_primary returns ios after init on swift fixture" {
  stack_profile_init "$SWIFT_FIXTURE"
  run stack_profile_primary
  [ "$status" -eq 0 ]
  [ "$output" = "ios" ]
}

# ── cache cleanup ─────────────────────────────────────────────────────────────
teardown() {
  rm -rf "$TEST_TMP"
  rm -rf "$SWIFT_FIXTURE/.orchestrator"
}
