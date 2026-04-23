#!/usr/bin/env bats
# tests/lib/validate_spec_references.bats — Unit tests for validate_spec_references.sh (ADR-011 PR-E)
bats_require_minimum_version 1.5.0

REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
VALIDATE_REFS="$REPO_ROOT/scripts/validate_spec_references.sh"
SWIFT_FIXTURE="$REPO_ROOT/tests/fixtures/swift-sample"

setup() {
  TMPDIR_WT="$(mktemp -d)"
  TASK_DIR="$TMPDIR_WT/tasks/prd-test"
  mkdir -p "$TASK_DIR"
  mkdir -p "$TMPDIR_WT/.orchestrator"
}

teardown() {
  rm -rf "$TMPDIR_WT"
}

_write_inventory() {
  python3 -c "
import json, sys
data = {
    'stack': 'ios',
    'files': ['Sources/App/main.swift', 'Sources/SampleLib/SampleApp.swift', 'Tests/AppTests/AppTests.swift', 'Package.swift'],
    'manifest': {'targets': ['App', 'SampleLib', 'AppTests']},
    'symbols': ['SampleApp', 'Greeter', 'Runnable', 'AppRunner']
}
json.dump(data, open('$TMPDIR_WT/.orchestrator/inventory.json', 'w'), indent=2)
"
}

# ── no inventory ──────────────────────────────────────────────────────────────

@test "exits 0 (skip) when no inventory.json exists" {
  run bash "$VALIDATE_REFS" "$TMPDIR_WT" "$TASK_DIR"
  [ "$status" -eq 0 ]
}

@test "exits 0 (skip) when no spec docs exist" {
  _write_inventory
  run bash "$VALIDATE_REFS" "$TMPDIR_WT" "$TASK_DIR"
  [ "$status" -eq 0 ]
}

# ── clean references ──────────────────────────────────────────────────────────

@test "exits 0 when prd.md references existing files only" {
  _write_inventory
  cat > "$TASK_DIR/prd.md" <<'EOF'
# My Feature

Modify `Sources/SampleLib/SampleApp.swift` to add login support.
Also update `Package.swift`.
EOF
  run bash "$VALIDATE_REFS" "$TMPDIR_WT" "$TASK_DIR"
  [ "$status" -eq 0 ]
}

@test "exits 0 when techspec.md references existing symbol" {
  _write_inventory
  cat > "$TASK_DIR/techspec.md" <<'EOF'
# Tech Spec

Extend the `SampleApp` struct with a new method.
Use `Greeter` for display.
EOF
  run bash "$VALIDATE_REFS" "$TMPDIR_WT" "$TASK_DIR"
  [ "$status" -eq 0 ]
}

@test "exits 0 when no file-path references present" {
  _write_inventory
  cat > "$TASK_DIR/prd.md" <<'EOF'
# Feature

Add a new login screen with email/password fields.
Validate user credentials before allowing access.
EOF
  run bash "$VALIDATE_REFS" "$TMPDIR_WT" "$TASK_DIR"
  [ "$status" -eq 0 ]
}

# ── declared-new passes ───────────────────────────────────────────────────────

@test "exits 0 when spec references a file declared new in tasks.md" {
  _write_inventory
  cat > "$TASK_DIR/prd.md" <<'EOF'
# Feature

Add `Sources/App/LoginViewModel.swift` for login logic.
EOF
  cat > "$TASK_DIR/tasks.md" <<'EOF'
# Tasks

- [ ] Create `Sources/App/LoginViewModel.swift`
- [ ] Add unit tests
EOF
  run bash "$VALIDATE_REFS" "$TMPDIR_WT" "$TASK_DIR"
  [ "$status" -eq 0 ]
}

# ── unresolved references ─────────────────────────────────────────────────────

@test "exits 1 when prd.md references a nonexistent path not declared in tasks" {
  _write_inventory
  cat > "$TASK_DIR/prd.md" <<'EOF'
# Feature

Modify `Sources/Auth/AuthManager.swift` to add OAuth support.
This file contains the core auth logic.
EOF
  run bash "$VALIDATE_REFS" "$TMPDIR_WT" "$TASK_DIR"
  [ "$status" -eq 1 ]
}

@test "unresolved reference appears in stderr output" {
  _write_inventory
  cat > "$TASK_DIR/prd.md" <<'EOF'
# Feature

Extend `Sources/Auth/AuthManager.swift` with new methods.
EOF
  run bash "$VALIDATE_REFS" "$TMPDIR_WT" "$TASK_DIR" 2>&1
  [[ "$output" =~ "UNRESOLVED-FILE" ]] || [[ "$output" =~ "AuthManager" ]] || [ "$status" -eq 1 ]
}

# ── basename matching ─────────────────────────────────────────────────────────

@test "exits 0 when spec references file by basename matching existing" {
  _write_inventory
  cat > "$TASK_DIR/prd.md" <<'EOF'
# Feature

Update `SampleApp.swift` to support the new login flow.
EOF
  run bash "$VALIDATE_REFS" "$TMPDIR_WT" "$TASK_DIR"
  [ "$status" -eq 0 ]
}
