#!/usr/bin/env bats
# tests/lib/phases.bats — Tests for scripts/lib/phases.sh phase detection.

REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"

setup() {
  source "$REPO_ROOT/scripts/lib/phases.sh"
}

# ── fm_phase_for_file: planning artifacts ─────────────────────────

@test "prd.md maps to phase 1" {
  [ "$(fm_phase_for_file "prd.md")" = "1" ]
}

@test "tasks.md maps to phase 1" {
  [ "$(fm_phase_for_file "tasks.md")" = "1" ]
}

@test "techspec.md maps to phase 1" {
  [ "$(fm_phase_for_file "techspec.md")" = "1" ]
}

@test "full path to prd.md maps to phase 1" {
  [ "$(fm_phase_for_file "/tmp/project/tasks/prd-feat/prd.md")" = "1" ]
}

# ── fm_phase_for_file: source code ───────────────────────────────

@test "TypeScript file maps to phase 2" {
  [ "$(fm_phase_for_file "src/main.ts")" = "2" ]
}

@test "Python file maps to phase 2" {
  [ "$(fm_phase_for_file "app/models.py")" = "2" ]
}

@test "Swift file maps to phase 2" {
  [ "$(fm_phase_for_file "Sources/App.swift")" = "2" ]
}

@test "Go file maps to phase 2" {
  [ "$(fm_phase_for_file "cmd/server.go")" = "2" ]
}

@test "shell script maps to phase 2" {
  [ "$(fm_phase_for_file "scripts/deploy.sh")" = "2" ]
}

# ── fm_phase_for_file: test files ────────────────────────────────

@test "bats file maps to phase 3" {
  [ "$(fm_phase_for_file "tests/lib/foo.bats")" = "3" ]
}

@test ".test.ts file maps to phase 3" {
  [ "$(fm_phase_for_file "src/auth.test.ts")" = "3" ]
}

@test ".spec.ts file maps to phase 3" {
  [ "$(fm_phase_for_file "src/auth.spec.ts")" = "3" ]
}

@test "file under tests/ directory maps to phase 3" {
  [ "$(fm_phase_for_file "/project/tests/integration/foo.py")" = "3" ]
}

@test "file under __tests__/ directory maps to phase 3" {
  [ "$(fm_phase_for_file "src/__tests__/util.js")" = "3" ]
}

# ── fm_phase_for_file: commit artifacts ──────────────────────────

@test "CHANGELOG.md maps to phase 4" {
  [ "$(fm_phase_for_file "CHANGELOG.md")" = "4" ]
}

# ── fm_phase_for_file: unknown ────────────────────────────────────

@test "unknown file type returns empty string" {
  [ "$(fm_phase_for_file "README.txt")" = "" ]
}

@test "markdown file that is not prd/tasks returns empty" {
  [ "$(fm_phase_for_file "DESIGN.md")" = "" ]
}

# ── fm_phase_label ────────────────────────────────────────────────

@test "phase 1 label is Plan" {
  [ "$(fm_phase_label 1)" = "Plan" ]
}

@test "phase 2 label is Execute" {
  [ "$(fm_phase_label 2)" = "Execute" ]
}

@test "phase 3 label is Test" {
  [ "$(fm_phase_label 3)" = "Test" ]
}

@test "phase 4 label is Commit" {
  [ "$(fm_phase_label 4)" = "Commit" ]
}

@test "unknown phase label is ?" {
  [ "$(fm_phase_label 99)" = "?" ]
}

# ── fm_phase_for_file: CHANGELOG priority over code extension ─────

@test "CHANGELOG.md is phase 4 not phase 2 despite .md" {
  # CHANGELOG.md must map to 4 (checked before source code extensions)
  [ "$(fm_phase_for_file "CHANGELOG.md")" = "4" ]
}

@test "test file in tests/ beats .ts extension (phase 3 wins)" {
  [ "$(fm_phase_for_file "tests/unit/auth.ts")" = "3" ]
}
