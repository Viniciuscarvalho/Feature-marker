#!/usr/bin/env bash
# stack-detector.sh — Tech-stack detection engine for feature-marker
# Detects iOS, Node.js, Rust, Python, Go (and sub-types / monorepos)
# Outputs: platform-context.json in the given state directory
set -euo pipefail

# ─────────────────────────────────────────────────────────────
# Public API
# ─────────────────────────────────────────────────────────────

# detect_stack <project_root> <state_dir>
# Writes platform-context.json to <state_dir> and echoes primary platform
detect_stack() {
  local project_root="${1:-.}"
  local state_dir="${2:-.claude/feature-state/default}"

  mkdir -p "$state_dir"

  local platforms_json="[]"
  local primary_platform="unknown"
  local is_monorepo="false"
  local platform_count=0

  # ── iOS / Swift ───────────────────────────────────────────
  local ios_json
  ios_json=$(_detect_ios "$project_root")
  if [[ "$ios_json" != "null" ]]; then
    platforms_json=$(echo "$platforms_json" | _json_append "$ios_json")
    primary_platform="ios"
    platform_count=$((platform_count + 1))
  fi

  # ── Node.js ───────────────────────────────────────────────
  local node_json
  node_json=$(_detect_nodejs "$project_root")
  if [[ "$node_json" != "null" ]]; then
    platforms_json=$(echo "$platforms_json" | _json_append "$node_json")
    [[ "$primary_platform" == "unknown" ]] && primary_platform="nodejs"
    platform_count=$((platform_count + 1))
  fi

  # ── Rust ──────────────────────────────────────────────────
  local rust_json
  rust_json=$(_detect_rust "$project_root")
  if [[ "$rust_json" != "null" ]]; then
    platforms_json=$(echo "$platforms_json" | _json_append "$rust_json")
    [[ "$primary_platform" == "unknown" ]] && primary_platform="rust"
    platform_count=$((platform_count + 1))
  fi

  # ── Python ────────────────────────────────────────────────
  local python_json
  python_json=$(_detect_python "$project_root")
  if [[ "$python_json" != "null" ]]; then
    platforms_json=$(echo "$platforms_json" | _json_append "$python_json")
    [[ "$primary_platform" == "unknown" ]] && primary_platform="python"
    platform_count=$((platform_count + 1))
  fi

  # ── Go ────────────────────────────────────────────────────
  local go_json
  go_json=$(_detect_go "$project_root")
  if [[ "$go_json" != "null" ]]; then
    platforms_json=$(echo "$platforms_json" | _json_append "$go_json")
    [[ "$primary_platform" == "unknown" ]] && primary_platform="go"
    platform_count=$((platform_count + 1))
  fi

  [[ $platform_count -gt 1 ]] && is_monorepo="true"

  # Check for manual override in .feature-marker.json
  local config_file="${project_root}/.feature-marker.json"
  if [[ -f "$config_file" ]]; then
    local override
    override=$(python3 -c "import json,sys; d=json.load(open('$config_file')); print(d.get('platform',''))" 2>/dev/null || echo "")
    if [[ -n "$override" ]]; then
      primary_platform="$override"
    fi
  fi

  local timestamp
  timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || echo "unknown")

  # Write platform-context.json
  cat > "${state_dir}/platform-context.json" <<EOF
{
  "primary_platform": "$primary_platform",
  "platforms": $platforms_json,
  "is_monorepo": $is_monorepo,
  "detected_at": "$timestamp"
}
EOF

  echo "$primary_platform"
}

# get_platform_context <state_dir>
# Reads and echoes the platform-context.json content
get_platform_context() {
  local state_dir="${1:-.claude/feature-state/default}"
  local context_file="${state_dir}/platform-context.json"

  if [[ -f "$context_file" ]]; then
    cat "$context_file"
  else
    echo "{\"primary_platform\":\"unknown\",\"platforms\":[],\"is_monorepo\":false}"
  fi
}

# get_primary_platform <state_dir>
get_primary_platform() {
  local state_dir="${1:-.claude/feature-state/default}"
  get_platform_context "$state_dir" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('primary_platform','unknown'))" 2>/dev/null || echo "unknown"
}

# get_test_command <state_dir>
get_test_command() {
  local state_dir="${1:-.claude/feature-state/default}"
  get_platform_context "$state_dir" | python3 -c "
import json, sys
d = json.load(sys.stdin)
platforms = d.get('platforms', [])
primary = d.get('primary_platform', 'unknown')
for p in platforms:
    if p.get('type') == primary:
        print(p.get('test_command', ''))
        sys.exit(0)
print('')
" 2>/dev/null || echo ""
}

# get_lint_command <state_dir>
get_lint_command() {
  local state_dir="${1:-.claude/feature-state/default}"
  get_platform_context "$state_dir" | python3 -c "
import json, sys
d = json.load(sys.stdin)
platforms = d.get('platforms', [])
primary = d.get('primary_platform', 'unknown')
for p in platforms:
    if p.get('type') == primary:
        print(p.get('lint_command', ''))
        sys.exit(0)
print('')
" 2>/dev/null || echo ""
}

# ─────────────────────────────────────────────────────────────
# Detection helpers (private — prefix _detect_)
# ─────────────────────────────────────────────────────────────

_detect_ios() {
  local root="$1"
  local signals=()
  local subtype="unknown"
  local confidence="low"

  # Check signals
  local xcodeproj_count xcworkspace_count swift_count
  xcodeproj_count=$(find "$root" -maxdepth 3 -name "*.xcodeproj" 2>/dev/null | wc -l | tr -d ' ')
  xcworkspace_count=$(find "$root" -maxdepth 3 -name "*.xcworkspace" 2>/dev/null | wc -l | tr -d ' ')
  swift_count=$(find "$root" -maxdepth 5 -name "*.swift" 2>/dev/null | wc -l | tr -d ' ')

  [[ $xcodeproj_count -gt 0 ]] && signals+=("*.xcodeproj found")
  [[ $xcworkspace_count -gt 0 ]] && signals+=("*.xcworkspace found")
  [[ -f "${root}/Package.swift" ]] && signals+=("Package.swift found")
  [[ $swift_count -gt 0 ]] && signals+=(".swift files present (${swift_count})")

  [[ ${#signals[@]} -eq 0 ]] && { echo "null"; return; }

  # Determine subtype
  if [[ -f "${root}/Package.swift" && $xcodeproj_count -eq 0 ]]; then
    subtype="swift-package"
  elif [[ $xcworkspace_count -gt 0 ]]; then
    subtype="xcworkspace"
  elif [[ $xcodeproj_count -gt 0 ]]; then
    subtype="xcodeproj"
  fi

  # Confidence
  if [[ ${#signals[@]} -ge 3 ]]; then
    confidence="high"
  elif [[ ${#signals[@]} -ge 2 ]]; then
    confidence="medium"
  fi

  # Check for iOS specifically (vs macOS/watchOS)
  local is_ios="false"
  if grep -r "IPHONEOS_DEPLOYMENT_TARGET" "$root" --include="*.pbxproj" -l 2>/dev/null | grep -q .; then
    is_ios="true"
    signals+=("IPHONEOS_DEPLOYMENT_TARGET detected")
  elif grep -r "UIRequiredDeviceCapabilities" "$root" --include="*.plist" -l 2>/dev/null | grep -q .; then
    is_ios="true"
    signals+=("UIRequiredDeviceCapabilities in Info.plist")
  elif [[ $swift_count -gt 0 ]]; then
    # Assume iOS if Swift files present (most common case)
    is_ios="true"
  fi

  # Detect test runner (Swift Testing vs XCTest)
  local test_framework="swift-testing"
  if find "$root" -name "*Tests.swift" 2>/dev/null | xargs grep -l "import XCTest" 2>/dev/null | grep -q .; then
    if ! find "$root" -name "*Tests.swift" 2>/dev/null | xargs grep -l "import Testing" 2>/dev/null | grep -q .; then
      test_framework="xctest"
    fi
  fi

  # Detect available tools
  local swiftlint_available="false"
  local xcodebuildmcp_available="false"
  command -v swiftlint > /dev/null 2>&1 && swiftlint_available="true"
  [[ -f "${HOME}/.claude/skills/xcodebuildmcp/SKILL.md" ]] && xcodebuildmcp_available="true"

  # Build signals JSON array
  local signals_json
  signals_json=$(_array_to_json "${signals[@]:-}")

  cat <<EOF
{
  "type": "ios",
  "subtype": "$subtype",
  "path": ".",
  "confidence": "$confidence",
  "is_ios": $is_ios,
  "signals": $signals_json,
  "test_command": "swift test --parallel",
  "build_command": "xcodebuild build",
  "lint_command": "swiftlint",
  "test_framework": "$test_framework",
  "capabilities": {
    "swiftlint_available": $swiftlint_available,
    "xcodebuildmcp_available": $xcodebuildmcp_available,
    "swift_testing_available": true
  }
}
EOF
}

_detect_nodejs() {
  local root="$1"
  local signals=()

  [[ -f "${root}/package.json" ]] || { echo "null"; return; }
  signals+=("package.json found")
  [[ -d "${root}/node_modules" ]] && signals+=("node_modules present")
  [[ -f "${root}/.nvmrc" ]] && signals+=(".nvmrc found")

  # Detect subtype
  local subtype="node"
  if [[ -f "${root}/next.config.js" || -f "${root}/next.config.ts" || -f "${root}/next.config.mjs" ]]; then
    subtype="nextjs"
    signals+=("next.config found")
  elif grep -q '"react-native"' "${root}/package.json" 2>/dev/null; then
    subtype="react-native"
    signals+=("react-native in dependencies")
  elif [[ -f "${root}/nest-cli.json" ]]; then
    subtype="nestjs"
    signals+=("nest-cli.json found")
  fi

  # Detect package manager
  local pm="npm"
  local pm_lock=""
  if [[ -f "${root}/pnpm-lock.yaml" ]]; then
    pm="pnpm"; pm_lock="pnpm-lock.yaml"; signals+=("pnpm-lock.yaml found")
  elif [[ -f "${root}/yarn.lock" ]]; then
    pm="yarn"; pm_lock="yarn.lock"; signals+=("yarn.lock found")
  elif [[ -f "${root}/bun.lockb" ]]; then
    pm="bun"; pm_lock="bun.lockb"; signals+=("bun.lockb found")
  elif [[ -f "${root}/package-lock.json" ]]; then
    pm="npm"; pm_lock="package-lock.json"; signals+=("package-lock.json found")
  fi

  # Detect test runner
  local test_command="${pm} test"
  if grep -q '"jest"' "${root}/package.json" 2>/dev/null || [[ -f "${root}/jest.config.js" || -f "${root}/jest.config.ts" ]]; then
    test_command="jest"
    signals+=("jest detected")
  elif grep -q '"vitest"' "${root}/package.json" 2>/dev/null || [[ -f "${root}/vitest.config.ts" || -f "${root}/vitest.config.js" ]]; then
    test_command="vitest run"
    signals+=("vitest detected")
  fi

  local confidence="medium"
  [[ ${#signals[@]} -ge 3 ]] && confidence="high"

  local signals_json
  signals_json=$(_array_to_json "${signals[@]:-}")

  cat <<EOF
{
  "type": "nodejs",
  "subtype": "$subtype",
  "path": ".",
  "confidence": "$confidence",
  "signals": $signals_json,
  "package_manager": "$pm",
  "package_manager_lock": "$pm_lock",
  "test_command": "$test_command",
  "build_command": "${pm} run build",
  "lint_command": "${pm} run lint"
}
EOF
}

_detect_rust() {
  local root="$1"

  [[ -f "${root}/Cargo.toml" ]] || { echo "null"; return; }

  local signals=("Cargo.toml found")
  [[ -f "${root}/src/main.rs" ]] && signals+=("src/main.rs found")
  [[ -f "${root}/src/lib.rs" ]] && signals+=("src/lib.rs found")

  local confidence="medium"
  [[ ${#signals[@]} -ge 2 ]] && confidence="high"

  local signals_json
  signals_json=$(_array_to_json "${signals[@]:-}")

  cat <<EOF
{
  "type": "rust",
  "subtype": "cargo",
  "path": ".",
  "confidence": "$confidence",
  "signals": $signals_json,
  "test_command": "cargo test",
  "build_command": "cargo build",
  "lint_command": "cargo clippy -- -D warnings"
}
EOF
}

_detect_python() {
  local root="$1"

  local has_python=false
  local signals=()

  [[ -f "${root}/pyproject.toml" ]] && { has_python=true; signals+=("pyproject.toml found"); }
  [[ -f "${root}/setup.py" ]] && { has_python=true; signals+=("setup.py found"); }
  [[ -f "${root}/requirements.txt" ]] && { has_python=true; signals+=("requirements.txt found"); }

  [[ "$has_python" == "false" ]] && { echo "null"; return; }

  # Detect test runner
  local test_command="pytest"
  if grep -q "pytest" "${root}/pyproject.toml" 2>/dev/null; then
    signals+=("pytest in pyproject.toml")
  fi

  # Detect linter
  local lint_command="ruff check ."
  if ! command -v ruff > /dev/null 2>&1; then
    lint_command="flake8 ."
  fi

  local confidence="medium"
  [[ ${#signals[@]} -ge 2 ]] && confidence="high"

  local signals_json
  signals_json=$(_array_to_json "${signals[@]:-}")

  cat <<EOF
{
  "type": "python",
  "subtype": "python",
  "path": ".",
  "confidence": "$confidence",
  "signals": $signals_json,
  "test_command": "$test_command",
  "build_command": "python -m build",
  "lint_command": "$lint_command"
}
EOF
}

_detect_go() {
  local root="$1"

  [[ -f "${root}/go.mod" ]] || { echo "null"; return; }

  local signals=("go.mod found")
  [[ -f "${root}/go.sum" ]] && signals+=("go.sum found")

  local confidence="high"

  local signals_json
  signals_json=$(_array_to_json "${signals[@]:-}")

  cat <<EOF
{
  "type": "go",
  "subtype": "go",
  "path": ".",
  "confidence": "$confidence",
  "signals": $signals_json,
  "test_command": "go test ./...",
  "build_command": "go build ./...",
  "lint_command": "go vet ./..."
}
EOF
}

# ─────────────────────────────────────────────────────────────
# JSON utilities (minimal, no jq dependency)
# ─────────────────────────────────────────────────────────────

# _json_append: reads a JSON array from stdin, appends a new item
_json_append() {
  local item="$1"
  python3 -c "
import json, sys
arr = json.load(sys.stdin)
arr.append(json.loads('''$item'''))
print(json.dumps(arr, indent=2))
" 2>/dev/null || echo "[${item}]"
}

# _array_to_json: converts bash array to JSON array of strings
_array_to_json() {
  local arr=("$@")
  if [[ ${#arr[@]} -eq 0 ]]; then
    echo "[]"
    return
  fi
  python3 -c "
import json, sys
arr = sys.argv[1:]
print(json.dumps(arr))
" -- "${arr[@]}" 2>/dev/null || echo "[]"
}

# ─────────────────────────────────────────────────────────────
# CLI usage (when called directly)
# ─────────────────────────────────────────────────────────────
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  PROJECT_ROOT="${1:-.}"
  STATE_DIR="${2:-.claude/feature-state/default}"
  PRIMARY=$(detect_stack "$PROJECT_ROOT" "$STATE_DIR")
  echo "✅ Detected: $PRIMARY"
  echo "   platform-context.json written to: ${STATE_DIR}/platform-context.json"
fi
