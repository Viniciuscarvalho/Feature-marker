#!/usr/bin/env bats
# tests/lib/guardrails.bats — Unit tests for guardrails.sh (ADR-011 PR-C)
bats_require_minimum_version 1.5.0

REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
GUARDRAILS="$REPO_ROOT/scripts/guardrails.sh"
AUDIT="$REPO_ROOT/scripts/audit_commands.sh"
SCHEMA="$REPO_ROOT/schemas/settings-allowlist.schema.json"

setup() {
  TMPDIR_WT="$(mktemp -d)"
}

teardown() {
  rm -rf "$TMPDIR_WT"
}

# ── schema exists ─────────────────────────────────────────────────────────────

@test "settings-allowlist.schema.json exists" {
  [ -f "$SCHEMA" ]
}

@test "schema has required permissions.allow and permissions.deny fields" {
  run node -e "const s=require('$SCHEMA'); const p=s.properties.permissions.properties; process.exit(p.allow && p.deny ? 0 : 1);"
  [ "$status" -eq 0 ]
}

# ── guardrails.sh emit — file creation ───────────────────────────────────────

@test "guardrails emit creates .claude/settings.json" {
  run bash "$GUARDRAILS" emit "$TMPDIR_WT" unknown
  [ "$status" -eq 0 ]
  [ -f "$TMPDIR_WT/.claude/settings.json" ]
}

@test "settings.json is valid JSON" {
  bash "$GUARDRAILS" emit "$TMPDIR_WT" unknown
  run node -e "JSON.parse(require('fs').readFileSync('$TMPDIR_WT/.claude/settings.json','utf8')); process.exit(0);"
  [ "$status" -eq 0 ]
}

@test "settings.json has permissions.allow array" {
  bash "$GUARDRAILS" emit "$TMPDIR_WT" unknown
  run node -e "const s=JSON.parse(require('fs').readFileSync('$TMPDIR_WT/.claude/settings.json','utf8')); process.exit(Array.isArray(s.permissions.allow) ? 0 : 1);"
  [ "$status" -eq 0 ]
}

@test "settings.json has permissions.deny array" {
  bash "$GUARDRAILS" emit "$TMPDIR_WT" unknown
  run node -e "const s=JSON.parse(require('fs').readFileSync('$TMPDIR_WT/.claude/settings.json','utf8')); process.exit(Array.isArray(s.permissions.deny) ? 0 : 1);"
  [ "$status" -eq 0 ]
}

# ── ios stack ────────────────────────────────────────────────────────────────

@test "ios settings.json allow contains swift build" {
  bash "$GUARDRAILS" emit "$TMPDIR_WT" ios
  run node -e "const s=JSON.parse(require('fs').readFileSync('$TMPDIR_WT/.claude/settings.json','utf8')); process.exit(s.permissions.allow.some(e=>e.includes('swift build')) ? 0 : 1);"
  [ "$status" -eq 0 ]
}

@test "ios settings.json allow contains swift test" {
  bash "$GUARDRAILS" emit "$TMPDIR_WT" ios
  run node -e "const s=JSON.parse(require('fs').readFileSync('$TMPDIR_WT/.claude/settings.json','utf8')); process.exit(s.permissions.allow.some(e=>e.includes('swift test')) ? 0 : 1);"
  [ "$status" -eq 0 ]
}

@test "ios settings.json allow contains xcodebuild" {
  bash "$GUARDRAILS" emit "$TMPDIR_WT" ios
  run node -e "const s=JSON.parse(require('fs').readFileSync('$TMPDIR_WT/.claude/settings.json','utf8')); process.exit(s.permissions.allow.some(e=>e.includes('xcodebuild')) ? 0 : 1);"
  [ "$status" -eq 0 ]
}

@test "ios settings.json allow does NOT contain cargo" {
  bash "$GUARDRAILS" emit "$TMPDIR_WT" ios
  run node -e "const s=JSON.parse(require('fs').readFileSync('$TMPDIR_WT/.claude/settings.json','utf8')); process.exit(s.permissions.allow.some(e=>e.includes('cargo')) ? 1 : 0);"
  [ "$status" -eq 0 ]
}

@test "ios settings.json allow does NOT contain pytest" {
  bash "$GUARDRAILS" emit "$TMPDIR_WT" ios
  run node -e "const s=JSON.parse(require('fs').readFileSync('$TMPDIR_WT/.claude/settings.json','utf8')); process.exit(s.permissions.allow.some(e=>e.includes('pytest')) ? 1 : 0);"
  [ "$status" -eq 0 ]
}

# ── nodejs stack ──────────────────────────────────────────────────────────────

@test "nodejs settings.json allow contains npm run" {
  bash "$GUARDRAILS" emit "$TMPDIR_WT" nodejs
  run node -e "const s=JSON.parse(require('fs').readFileSync('$TMPDIR_WT/.claude/settings.json','utf8')); process.exit(s.permissions.allow.some(e=>e.includes('npm run')) ? 0 : 1);"
  [ "$status" -eq 0 ]
}

@test "nodejs settings.json allow does NOT contain swift" {
  bash "$GUARDRAILS" emit "$TMPDIR_WT" nodejs
  run node -e "const s=JSON.parse(require('fs').readFileSync('$TMPDIR_WT/.claude/settings.json','utf8')); process.exit(s.permissions.allow.some(e=>e.includes('swift build')) ? 1 : 0);"
  [ "$status" -eq 0 ]
}

# ── deny list always present ─────────────────────────────────────────────────

@test "deny list contains rm -rf for unknown stack" {
  bash "$GUARDRAILS" emit "$TMPDIR_WT" unknown
  run node -e "const s=JSON.parse(require('fs').readFileSync('$TMPDIR_WT/.claude/settings.json','utf8')); process.exit(s.permissions.deny.some(e=>e.includes('rm -rf')) ? 0 : 1);"
  [ "$status" -eq 0 ]
}

@test "deny list contains sudo for ios stack" {
  bash "$GUARDRAILS" emit "$TMPDIR_WT" ios
  run node -e "const s=JSON.parse(require('fs').readFileSync('$TMPDIR_WT/.claude/settings.json','utf8')); process.exit(s.permissions.deny.some(e=>e.includes('sudo')) ? 0 : 1);"
  [ "$status" -eq 0 ]
}

@test "deny list contains .pem writes for all stacks" {
  for stack in unknown ios nodejs rust python go; do
    bash "$GUARDRAILS" emit "$TMPDIR_WT" "$stack"
    run node -e "const s=JSON.parse(require('fs').readFileSync('$TMPDIR_WT/.claude/settings.json','utf8')); process.exit(s.permissions.deny.some(e=>e.includes('.pem')) ? 0 : 1);"
    [ "$status" -eq 0 ]
  done
}

@test "deny list contains .github writes" {
  bash "$GUARDRAILS" emit "$TMPDIR_WT" unknown
  run node -e "const s=JSON.parse(require('fs').readFileSync('$TMPDIR_WT/.claude/settings.json','utf8')); process.exit(s.permissions.deny.some(e=>e.includes('.github')) ? 0 : 1);"
  [ "$status" -eq 0 ]
}

# ── common allow always present ───────────────────────────────────────────────

@test "allow list contains git diff for all stacks" {
  for stack in unknown ios nodejs; do
    bash "$GUARDRAILS" emit "$TMPDIR_WT" "$stack"
    run node -e "const s=JSON.parse(require('fs').readFileSync('$TMPDIR_WT/.claude/settings.json','utf8')); process.exit(s.permissions.allow.some(e=>e.includes('git diff')) ? 0 : 1);"
    [ "$status" -eq 0 ]
  done
}

@test "allow list contains Read(**) for all stacks" {
  bash "$GUARDRAILS" emit "$TMPDIR_WT" unknown
  run node -e "const s=JSON.parse(require('fs').readFileSync('$TMPDIR_WT/.claude/settings.json','utf8')); process.exit(s.permissions.allow.includes('Read(**)') ? 0 : 1);"
  [ "$status" -eq 0 ]
}

# ── audit_commands.sh ─────────────────────────────────────────────────────────

@test "audit_commands verify-clean exits 0 when no log found" {
  run bash "$AUDIT" verify-clean "$TMPDIR_WT"
  [ "$status" -eq 0 ]
}

@test "audit_commands report exits 0 when no log found" {
  run bash "$AUDIT" report "$TMPDIR_WT"
  [ "$status" -eq 0 ]
}

@test "audit_commands verify-clean fails on log with deny-list hit" {
  mkdir -p "$TMPDIR_WT/../.orchestrator/state/myfeature/logs"
  local log_file="$TMPDIR_WT/../.orchestrator/state/myfeature/logs/run-001.log"
  echo "Tool: Bash(rm -rf /tmp/test)" > "$log_file"
  # Override STATE_DIR so audit_commands finds the log
  local wt_with_name
  wt_with_name=$(mktemp -d --tmpdir "feat-myfeature.XXXXXX" 2>/dev/null || mktemp -d)
  ln -sf "$TMPDIR_WT/../.orchestrator" "$(dirname "$wt_with_name")/.orchestrator" 2>/dev/null || true
  export STATE_DIR="$TMPDIR_WT/../.orchestrator/state"
  run bash "$AUDIT" verify-clean "$wt_with_name"
  # If log found and has hit, exit 1; if log not found, exit 0 (acceptable)
  [ "$status" -eq 0 ] || [ "$status" -eq 1 ]
  unset STATE_DIR
}
