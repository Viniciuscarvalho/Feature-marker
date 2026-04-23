#!/usr/bin/env bash
# scripts/project_inventory.sh — Project file inventory for grounding (ADR-011 PR-D)
#
# Writes $wt_path/.orchestrator/inventory.json with:
#   files[]     — all source file paths (relative to wt_path)
#   manifest    — parsed targets/scripts from the project manifest
#   symbols     — best-effort symbol list per stack (functions/classes/structs)
#
# Usage:
#   bash scripts/project_inventory.sh scan <wt_path> [stack]
#
# The inventory is used by validate_spec_references.sh (PR-E) to verify that
# Claude's generated specs reference real symbols, not hallucinated ones.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

_scan_files() {
  local wt_path="$1"
  # Enumerate source files, excluding .git, .build, node_modules, .orchestrator
  find "$wt_path" -type f \
    -not -path "*/.git/*" \
    -not -path "*/.build/*" \
    -not -path "*/node_modules/*" \
    -not -path "*/.orchestrator/*" \
    -not -path "*/.gradle/*" \
    -not -path "*/.cache/*" \
    -not -name "*.o" \
    -not -name "*.a" \
    -not -name "*.dylib" \
    -not -name "*.so" \
    2>/dev/null \
  | sed "s|^$wt_path/||" \
  | sort
}

_parse_manifest_swift() {
  local wt_path="$1"
  local manifest="$wt_path/Package.swift"
  [ -f "$manifest" ] || { echo "{}"; return; }
  python3 - "$manifest" <<'PYEOF'
import sys, re, json

text = open(sys.argv[1]).read()

# Extract target names from .target(..., name: "Foo", ...)
targets = re.findall(r'\.(?:target|testTarget|executableTarget)\s*\(\s*name\s*:\s*"([^"]+)"', text)

# Extract product names
products = re.findall(r'\.(?:library|executable)\s*\(\s*name\s*:\s*"([^"]+)"', text)

# Extract dependencies (external)
deps = re.findall(r'\.package\s*\([^)]*url\s*:\s*"([^"]+)"', text)

print(json.dumps({"targets": targets, "products": products, "external_dependencies": deps}))
PYEOF
}

_parse_manifest_node() {
  local wt_path="$1"
  local manifest="$wt_path/package.json"
  [ -f "$manifest" ] || { echo "{}"; return; }
  python3 - "$manifest" <<'PYEOF'
import sys, json

data = json.load(open(sys.argv[1]))
scripts = list(data.get("scripts", {}).keys())
deps = list(data.get("dependencies", {}).keys())
dev_deps = list(data.get("devDependencies", {}).keys())
print(json.dumps({"name": data.get("name",""), "scripts": scripts, "dependencies": deps, "devDependencies": dev_deps}))
PYEOF
}

_parse_manifest_rust() {
  local wt_path="$1"
  local manifest="$wt_path/Cargo.toml"
  [ -f "$manifest" ] || { echo "{}"; return; }
  python3 - "$manifest" <<'PYEOF'
import sys, re, json

text = open(sys.argv[1]).read()

# Extract [package] name and version
pkg_name = re.search(r'\[package\][^\[]*name\s*=\s*"([^"]+)"', text, re.S)
pkg_ver  = re.search(r'\[package\][^\[]*version\s*=\s*"([^"]+)"', text, re.S)

# Extract [[bin]] / [[lib]] names
members = re.findall(r'\[\[(?:bin|lib)\]\][^\[]*name\s*=\s*"([^"]+)"', text, re.S)

# Workspace members
ws_members = re.findall(r'members\s*=\s*\[([^\]]+)\]', text)
ws = []
if ws_members:
    ws = [m.strip().strip('"') for m in ws_members[0].split(',') if m.strip().strip('"')]

deps = re.findall(r'^([a-zA-Z0-9_-]+)\s*=', text, re.M)

print(json.dumps({
    "name": pkg_name.group(1) if pkg_name else "",
    "version": pkg_ver.group(1) if pkg_ver else "",
    "members": members,
    "workspace_members": ws,
    "dependencies": deps[:20]
}))
PYEOF
}

_parse_manifest_python() {
  local wt_path="$1"
  # Try pyproject.toml first, then setup.py
  if [ -f "$wt_path/pyproject.toml" ]; then
    python3 - "$wt_path/pyproject.toml" <<'PYEOF'
import sys, re, json

text = open(sys.argv[1]).read()
name = re.search(r'name\s*=\s*"([^"]+)"', text)
deps = re.findall(r'"([a-zA-Z0-9_-]+)[>=<!]', text)
print(json.dumps({"name": name.group(1) if name else "", "dependencies": list(set(deps))}))
PYEOF
  else
    echo "{}"
  fi
}

_parse_manifest_go() {
  local wt_path="$1"
  local manifest="$wt_path/go.mod"
  [ -f "$manifest" ] || { echo "{}"; return; }
  python3 - "$manifest" <<'PYEOF'
import sys, re, json

text = open(sys.argv[1]).read()
module = re.search(r'^module\s+(\S+)', text, re.M)
go_ver = re.search(r'^go\s+(\S+)', text, re.M)
requires = re.findall(r'^\s+(\S+)\s+v[\d.]+', text, re.M)
print(json.dumps({
    "module": module.group(1) if module else "",
    "go_version": go_ver.group(1) if go_ver else "",
    "dependencies": requires
}))
PYEOF
}

_extract_symbols_swift() {
  local wt_path="$1"
  find "$wt_path/Sources" "$wt_path/Tests" -name "*.swift" 2>/dev/null \
  | while IFS= read -r f; do
      grep -E "^(public |open |internal |private |fileprivate )?(class|struct|enum|protocol|func|typealias) " "$f" 2>/dev/null \
        | sed -E 's/.*(class|struct|enum|protocol|func|typealias) ([a-zA-Z_][a-zA-Z0-9_]*).*/\2/'
    done \
  | sort -u | head -200
}

_detect_stack() {
  local wt_path="$1"
  if [ -f "$wt_path/Package.swift" ]; then echo "ios"; return; fi
  if [ -f "$wt_path/package.json" ]; then echo "nodejs"; return; fi
  if [ -f "$wt_path/Cargo.toml" ]; then echo "rust"; return; fi
  if [ -f "$wt_path/pyproject.toml" ] || [ -f "$wt_path/setup.py" ]; then echo "python"; return; fi
  if [ -f "$wt_path/go.mod" ]; then echo "go"; return; fi
  echo "unknown"
}

_scan_inventory() {
  local wt_path="$1"
  local stack="${2:-}"

  if [ -z "$stack" ] || [ "$stack" = "unknown" ]; then
    stack=$(_detect_stack "$wt_path")
  fi

  local out_dir="$wt_path/.orchestrator"
  mkdir -p "$out_dir"
  local out="$out_dir/inventory.json"

  # Collect files as JSON array
  local files_json
  files_json=$(python3 - "$wt_path" <<'PYEOF'
import sys, json, os, subprocess

wt = sys.argv[1]
result = subprocess.run(
    ['find', wt, '-type', 'f',
     '-not', '-path', '*/.git/*',
     '-not', '-path', '*/.build/*',
     '-not', '-path', '*/node_modules/*',
     '-not', '-path', '*/.orchestrator/*',
     '-not', '-path', '*/.gradle/*',
     '-not', '-path', '*/.cache/*'],
    capture_output=True, text=True
)
files = [
    f[len(wt)+1:] for f in result.stdout.strip().split('\n')
    if f and not f.endswith(('.o', '.a', '.dylib', '.so'))
]
files.sort()
print(json.dumps(files))
PYEOF
)

  # Parse manifest
  local manifest_json="{}"
  case "$stack" in
    ios)    manifest_json=$(_parse_manifest_swift "$wt_path") ;;
    nodejs) manifest_json=$(_parse_manifest_node "$wt_path") ;;
    rust)   manifest_json=$(_parse_manifest_rust "$wt_path") ;;
    python) manifest_json=$(_parse_manifest_python "$wt_path") ;;
    go)     manifest_json=$(_parse_manifest_go "$wt_path") ;;
  esac

  # Extract symbols (swift only for now)
  local symbols_json="[]"
  if [ "$stack" = "ios" ]; then
    symbols_json=$(python3 -c "
import json, subprocess, sys

wt = sys.argv[1]
proc = subprocess.run(
    ['find', wt + '/Sources', wt + '/Tests', '-name', '*.swift'],
    capture_output=True, text=True
)
files = [f for f in proc.stdout.strip().split('\n') if f]
symbols = set()
import re
for f in files:
    try:
        for line in open(f):
            m = re.search(r'\b(class|struct|enum|protocol|func|typealias)\s+([a-zA-Z_]\w*)', line)
            if m:
                symbols.add(m.group(2))
    except Exception:
        pass
print(json.dumps(sorted(symbols)[:200]))
" "$wt_path" 2>/dev/null) || symbols_json="[]"
  fi

  # Write inventory.json
  python3 - "$out" "$stack" <<PYEOF
import sys, json

out_path = sys.argv[1]
stack = sys.argv[2]
files = $files_json
manifest = $manifest_json
symbols = $symbols_json

data = {
    "stack": stack,
    "files": files,
    "manifest": manifest,
    "symbols": symbols
}
with open(out_path + ".tmp." + str(__import__("os").getpid()), "w") as f:
    json.dump(data, f, indent=2)
__import__("os").replace(out_path + ".tmp." + str(__import__("os").getpid()), out_path)
PYEOF

  echo "project_inventory: wrote $out (stack=$stack, files=$(echo "$files_json" | python3 -c 'import json,sys; print(len(json.load(sys.stdin)))' 2>/dev/null || echo "?"))"
}

# ── main ─────────────────────────────────────────────────────────────────────
case "${1:-help}" in
  scan)
    shift
    _scan_inventory "$@"
    ;;
  *)
    echo "Usage: project_inventory.sh scan <wt_path> [stack]"
    exit 1
    ;;
esac
