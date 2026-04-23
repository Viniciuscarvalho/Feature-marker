#!/usr/bin/env bats
# tests/lib/project_inventory.bats — Unit tests for project_inventory.sh (ADR-011 PR-D)
bats_require_minimum_version 1.5.0

REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
INVENTORY="$REPO_ROOT/scripts/project_inventory.sh"
SWIFT_FIXTURE="$REPO_ROOT/tests/fixtures/swift-sample"

setup() {
  TMPDIR_WT="$(mktemp -d)"
}

teardown() {
  rm -rf "$TMPDIR_WT"
}

# ── swift fixture ─────────────────────────────────────────────────────────────

@test "scan creates .orchestrator/inventory.json for swift fixture" {
  run bash "$INVENTORY" scan "$SWIFT_FIXTURE"
  [ "$status" -eq 0 ]
  [ -f "$SWIFT_FIXTURE/.orchestrator/inventory.json" ]
}

@test "inventory.json is valid JSON for swift fixture" {
  bash "$INVENTORY" scan "$SWIFT_FIXTURE"
  run python3 -m json.tool "$SWIFT_FIXTURE/.orchestrator/inventory.json"
  [ "$status" -eq 0 ]
}

@test "swift fixture inventory detects ios stack" {
  bash "$INVENTORY" scan "$SWIFT_FIXTURE"
  run python3 -c "import json,sys; d=json.load(open(sys.argv[1])); sys.exit(0 if d['stack']=='ios' else 1)" "$SWIFT_FIXTURE/.orchestrator/inventory.json"
  [ "$status" -eq 0 ]
}

@test "swift fixture inventory enumerates .swift files" {
  bash "$INVENTORY" scan "$SWIFT_FIXTURE"
  run python3 -c "
import json,sys
d=json.load(open(sys.argv[1]))
swift_files=[f for f in d['files'] if f.endswith('.swift')]
sys.exit(0 if len(swift_files)>0 else 1)
" "$SWIFT_FIXTURE/.orchestrator/inventory.json"
  [ "$status" -eq 0 ]
}

@test "swift fixture inventory parses Package.swift targets" {
  bash "$INVENTORY" scan "$SWIFT_FIXTURE"
  run python3 -c "
import json,sys
d=json.load(open(sys.argv[1]))
targets=d.get('manifest',{}).get('targets',[])
sys.exit(0 if 'App' in targets and 'SampleLib' in targets else 1)
" "$SWIFT_FIXTURE/.orchestrator/inventory.json"
  [ "$status" -eq 0 ]
}

@test "swift fixture inventory extracts symbols" {
  bash "$INVENTORY" scan "$SWIFT_FIXTURE"
  run python3 -c "
import json,sys
d=json.load(open(sys.argv[1]))
symbols=d.get('symbols',[])
sys.exit(0 if 'SampleApp' in symbols and 'Greeter' in symbols else 1)
" "$SWIFT_FIXTURE/.orchestrator/inventory.json"
  [ "$status" -eq 0 ]
}

@test "swift fixture inventory includes Package.swift in files" {
  bash "$INVENTORY" scan "$SWIFT_FIXTURE"
  run python3 -c "
import json,sys
d=json.load(open(sys.argv[1]))
sys.exit(0 if 'Package.swift' in d['files'] else 1)
" "$SWIFT_FIXTURE/.orchestrator/inventory.json"
  [ "$status" -eq 0 ]
}

@test "swift fixture inventory excludes .build directory" {
  bash "$INVENTORY" scan "$SWIFT_FIXTURE"
  run python3 -c "
import json,sys
d=json.load(open(sys.argv[1]))
build_files=[f for f in d['files'] if '.build/' in f]
sys.exit(0 if len(build_files)==0 else 1)
" "$SWIFT_FIXTURE/.orchestrator/inventory.json"
  [ "$status" -eq 0 ]
}

@test "swift fixture inventory excludes .orchestrator directory" {
  bash "$INVENTORY" scan "$SWIFT_FIXTURE"
  run python3 -c "
import json,sys
d=json.load(open(sys.argv[1]))
orch_files=[f for f in d['files'] if '.orchestrator/' in f]
sys.exit(0 if len(orch_files)==0 else 1)
" "$SWIFT_FIXTURE/.orchestrator/inventory.json"
  [ "$status" -eq 0 ]
}

# ── nodejs fixture ────────────────────────────────────────────────────────────

@test "scan detects nodejs stack from package.json" {
  echo '{"name":"test-app","scripts":{"test":"jest","build":"tsc"},"dependencies":{"express":"4.x"}}' \
    > "$TMPDIR_WT/package.json"
  run bash "$INVENTORY" scan "$TMPDIR_WT"
  [ "$status" -eq 0 ]
  run python3 -c "import json,sys; d=json.load(open(sys.argv[1])); sys.exit(0 if d['stack']=='nodejs' else 1)" "$TMPDIR_WT/.orchestrator/inventory.json"
  [ "$status" -eq 0 ]
}

@test "nodejs inventory parses package.json scripts" {
  echo '{"name":"test-app","scripts":{"test":"jest","build":"tsc"},"dependencies":{"express":"4.x"}}' \
    > "$TMPDIR_WT/package.json"
  bash "$INVENTORY" scan "$TMPDIR_WT"
  run python3 -c "
import json,sys
d=json.load(open(sys.argv[1]))
scripts=d.get('manifest',{}).get('scripts',[])
sys.exit(0 if 'test' in scripts and 'build' in scripts else 1)
" "$TMPDIR_WT/.orchestrator/inventory.json"
  [ "$status" -eq 0 ]
}

# ── rust fixture ──────────────────────────────────────────────────────────────

@test "scan detects rust stack from Cargo.toml" {
  cat > "$TMPDIR_WT/Cargo.toml" <<'EOF'
[package]
name = "my-crate"
version = "0.1.0"
edition = "2021"

[dependencies]
serde = "1.0"
EOF
  run bash "$INVENTORY" scan "$TMPDIR_WT"
  [ "$status" -eq 0 ]
  run python3 -c "import json,sys; d=json.load(open(sys.argv[1])); sys.exit(0 if d['stack']=='rust' else 1)" "$TMPDIR_WT/.orchestrator/inventory.json"
  [ "$status" -eq 0 ]
}

# ── unknown stack ─────────────────────────────────────────────────────────────

@test "scan produces valid JSON for empty directory" {
  run bash "$INVENTORY" scan "$TMPDIR_WT"
  [ "$status" -eq 0 ]
  run python3 -m json.tool "$TMPDIR_WT/.orchestrator/inventory.json"
  [ "$status" -eq 0 ]
}

@test "empty directory inventory has unknown stack" {
  bash "$INVENTORY" scan "$TMPDIR_WT"
  run python3 -c "import json,sys; d=json.load(open(sys.argv[1])); sys.exit(0 if d['stack']=='unknown' else 1)" "$TMPDIR_WT/.orchestrator/inventory.json"
  [ "$status" -eq 0 ]
}
