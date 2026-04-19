#!/usr/bin/env bats
# tests/lib/router.bats — Unit tests for router functions (ADR-008 PR-B, ADR-009 PR-G)
#
# router_route_task and router_get_cached use node for JSON cache I/O and are
# tested via real temp files. Tests that trigger the fallback info message use
# `run --separate-stderr` to isolate stdout.
bats_require_minimum_version 1.5.0

setup() {
  TEST_TMP="$(mktemp -d)"
  export STATE_DIR="$TEST_TMP/state"
  export CONFIG_DIR="$TEST_TMP/config"
  export ROOT_DIR="$TEST_TMP"
  export AGENTS_DIR="$TEST_TMP/agents"
  export STACK_MAP_FILE="$CONFIG_DIR/stack-map.json"
  mkdir -p "$STATE_DIR" "$CONFIG_DIR" "$AGENTS_DIR"

  # Stub info to stderr so it does not pollute `run` stdout captures
  info() { echo "$*" >&2; }
  export -f info

  source /Users/bocato/development/fm-pr-b/scripts/lib/router.sh
}

teardown() {
  rm -rf "$TEST_TMP"
}

# ── router_detect_stack_from_paths ────────────────────────────────────────────

@test "router_detect_stack_from_paths returns unknown for empty input" {
  run router_detect_stack_from_paths ""
  [ "$status" -eq 0 ]
  [ "$output" = "unknown" ]
}

@test "router_detect_stack_from_paths detects ios from .swift files" {
  run router_detect_stack_from_paths "$TEST_TMP/a.swift:$TEST_TMP/b.swift"
  [ "$status" -eq 0 ]
  [ "$output" = "ios" ]
}

@test "router_detect_stack_from_paths detects node from .ts files" {
  run router_detect_stack_from_paths "$TEST_TMP/a.ts:$TEST_TMP/b.ts"
  [ "$status" -eq 0 ]
  [ "$output" = "node" ]
}

@test "router_detect_stack_from_paths detects node from .tsx files" {
  run router_detect_stack_from_paths "$TEST_TMP/a.tsx:$TEST_TMP/b.tsx"
  [ "$status" -eq 0 ]
  [ "$output" = "node" ]
}

@test "router_detect_stack_from_paths detects node from .js files" {
  run router_detect_stack_from_paths "$TEST_TMP/a.js:$TEST_TMP/b.js"
  [ "$status" -eq 0 ]
  [ "$output" = "node" ]
}

@test "router_detect_stack_from_paths detects python from .py files" {
  run router_detect_stack_from_paths "$TEST_TMP/a.py:$TEST_TMP/b.py"
  [ "$status" -eq 0 ]
  [ "$output" = "python" ]
}

@test "router_detect_stack_from_paths detects rust from .rs files" {
  run router_detect_stack_from_paths "$TEST_TMP/a.rs:$TEST_TMP/b.rs"
  [ "$status" -eq 0 ]
  [ "$output" = "rust" ]
}

@test "router_detect_stack_from_paths detects go from .go files" {
  run router_detect_stack_from_paths "$TEST_TMP/a.go:$TEST_TMP/b.go"
  [ "$status" -eq 0 ]
  [ "$output" = "go" ]
}

@test "router_detect_stack_from_paths returns majority stack for mixed paths" {
  # 1 swift + 3 ts => node wins
  run router_detect_stack_from_paths "$TEST_TMP/a.swift:$TEST_TMP/b.ts:$TEST_TMP/c.ts:$TEST_TMP/d.ts"
  [ "$status" -eq 0 ]
  [ "$output" = "node" ]
}

@test "router_detect_stack_from_paths returns unknown for unrecognised extensions" {
  run router_detect_stack_from_paths "$TEST_TMP/a.rb:$TEST_TMP/b.java"
  [ "$status" -eq 0 ]
  [ "$output" = "unknown" ]
}

# ── router_stack_to_agent ─────────────────────────────────────────────────────

@test "router_stack_to_agent maps ios to swift-expert" {
  run router_stack_to_agent "ios"
  [ "$status" -eq 0 ]
  [ "$output" = "swift-expert" ]
}

@test "router_stack_to_agent maps node to typescript-pro" {
  run router_stack_to_agent "node"
  [ "$status" -eq 0 ]
  [ "$output" = "typescript-pro" ]
}

@test "router_stack_to_agent maps python to python-pro" {
  run router_stack_to_agent "python"
  [ "$status" -eq 0 ]
  [ "$output" = "python-pro" ]
}

@test "router_stack_to_agent maps rust to rust-expert" {
  run router_stack_to_agent "rust"
  [ "$status" -eq 0 ]
  [ "$output" = "rust-expert" ]
}

@test "router_stack_to_agent maps go to go-expert" {
  run router_stack_to_agent "go"
  [ "$status" -eq 0 ]
  [ "$output" = "go-expert" ]
}

@test "router_stack_to_agent maps unknown to feature-marker" {
  run router_stack_to_agent "unknown"
  [ "$status" -eq 0 ]
  [ "$output" = "feature-marker" ]
}

@test "router_stack_to_agent maps unrecognised stack to feature-marker" {
  run router_stack_to_agent "cobol"
  [ "$status" -eq 0 ]
  [ "$output" = "feature-marker" ]
}

# ── router_agent_installed ────────────────────────────────────────────────────

@test "router_agent_installed returns 1 when agent has no file" {
  run router_agent_installed "no-such-agent"
  [ "$status" -eq 1 ]
}

@test "router_agent_installed returns 0 when .md file exists" {
  touch "$AGENTS_DIR/my-agent.md"
  run router_agent_installed "my-agent"
  [ "$status" -eq 0 ]
}

@test "router_agent_installed returns 0 when .yaml file exists" {
  touch "$AGENTS_DIR/my-agent.yaml"
  run router_agent_installed "my-agent"
  [ "$status" -eq 0 ]
}

@test "router_agent_installed returns 0 when .yml file exists" {
  touch "$AGENTS_DIR/my-agent.yml"
  run router_agent_installed "my-agent"
  [ "$status" -eq 0 ]
}

# ── router_init ───────────────────────────────────────────────────────────────

@test "router_init creates stack-map.json when it does not exist" {
  run router_init "feat-init"
  [ "$status" -eq 0 ]
  [ -f "$STACK_MAP_FILE" ]
}

@test "router_init does not overwrite existing stack-map.json" {
  echo '{"created_at":"existing","entries":{}}' > "$STACK_MAP_FILE"
  router_init "feat-init2"
  run node -p "JSON.parse(require('fs').readFileSync('$STACK_MAP_FILE','utf-8')).created_at"
  [ "$output" = "existing" ]
}

# ── router_route_task ─────────────────────────────────────────────────────────

@test "router_route_task returns feature-marker when preferred agent is not installed" {
  # No agent files → specialist falls back to feature-marker
  run --separate-stderr router_route_task "feat-1" "task-1" "$TEST_TMP/a.swift"
  [ "$status" -eq 0 ]
  [ "$output" = "feature-marker" ]
}

@test "router_route_task returns specialist agent when it is installed" {
  touch "$AGENTS_DIR/swift-expert.md"
  run --separate-stderr router_route_task "feat-2" "task-2" "$TEST_TMP/a.swift"
  [ "$status" -eq 0 ]
  [ "$output" = "swift-expert" ]
}

@test "router_route_task returns feature-marker for unknown stack" {
  run --separate-stderr router_route_task "feat-3" "task-3" "$TEST_TMP/a.rb"
  [ "$status" -eq 0 ]
  [ "$output" = "feature-marker" ]
}

@test "router_route_task caches result in stack-map.json" {
  touch "$AGENTS_DIR/typescript-pro.md"
  router_route_task "feat-4" "task-4" "$TEST_TMP/a.ts"
  run node -p "
    const d = JSON.parse(require('fs').readFileSync('$STACK_MAP_FILE','utf-8'));
    d.entries['feat-4::task-4'].resolved_agent;
  "
  [ "$status" -eq 0 ]
  [ "$output" = "typescript-pro" ]
}

@test "router_route_task uses cache on second call ignoring new agent install" {
  # Route once (no agent installed → feature-marker cached)
  router_route_task "feat-8" "task-8" "$TEST_TMP/a.swift"
  # Now install the agent — second call returns cached value, not new agent
  touch "$AGENTS_DIR/swift-expert.md"
  run --separate-stderr router_route_task "feat-8" "task-8" "$TEST_TMP/a.swift"
  [ "$status" -eq 0 ]
  [ "$output" = "feature-marker" ]
}

# ── router_get_cached ─────────────────────────────────────────────────────────

@test "router_get_cached returns empty when stack-map.json does not exist" {
  rm -f "$STACK_MAP_FILE"
  run router_get_cached "feat-5" "task-5"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "router_get_cached returns empty when entry is not in cache" {
  router_init "feat-6"
  run router_get_cached "feat-6" "task-6"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "router_get_cached returns cached agent after router_route_task" {
  touch "$AGENTS_DIR/python-pro.md"
  router_route_task "feat-7" "task-7" "$TEST_TMP/a.py"
  run router_get_cached "feat-7" "task-7"
  [ "$status" -eq 0 ]
  [ "$output" = "python-pro" ]
}
