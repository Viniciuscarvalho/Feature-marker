#!/usr/bin/env bash
# discover-env.sh — Unified environment discovery for feature-marker
# Runs stack detection + MCP detection + CLI detection + CI detection
# Outputs: environment_manifest.json in the given state directory
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/../lib"

# Source detectors
source "${LIB_DIR}/stack-detector.sh"
source "${LIB_DIR}/mcp-detector.sh"

# ─────────────────────────────────────────────────────────────
# Main
# ─────────────────────────────────────────────────────────────

discover_environment() {
  local project_root="${1:-.}"
  local state_dir="${2:-.claude/feature-state/default}"

  mkdir -p "$state_dir"

  # ── Step 1: Stack detection ─────────────────────────────
  detect_stack "$project_root" "$state_dir" > /dev/null 2>&1
  local stack_json
  stack_json=$(get_platform_context "$state_dir")

  # ── Step 2: MCP detection ──────────────────────────────
  detect_mcps "$project_root" "$state_dir" > /dev/null 2>&1
  local mcp_json
  mcp_json=$(get_mcp_context "$state_dir")

  # ── Step 3: CLI detection ──────────────────────────────
  local clis_json
  clis_json=$(_detect_clis)

  # ── Step 4: CI detection ───────────────────────────────
  local ci_json
  ci_json=$(_detect_ci "$project_root")

  # ── Step 5: Merge into environment_manifest.json ───────
  local timestamp
  timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || echo "unknown")

  python3 -c "
import json, sys

stack = json.loads('''$stack_json''')
mcp = json.loads('''$mcp_json''')
clis = json.loads('''$clis_json''')
ci = json.loads('''$ci_json''')

manifest = {
    'version': '1.0',
    'detected_at': '$timestamp',
    'stack': stack,
    'mcps': mcp.get('mcps', []),
    'clis': clis,
    'ci': ci
}

print(json.dumps(manifest, indent=2))
" > "${state_dir}/environment_manifest.json" 2>/dev/null

  echo "${state_dir}/environment_manifest.json"
}

# ─────────────────────────────────────────────────────────────
# CLI detection
# ─────────────────────────────────────────────────────────────

_detect_clis() {
  local clis=()
  local cli_names=(docker gh swiftlint ruff cargo-clippy flutter xcbeautify pod fastlane eslint prettier)

  for cli in "${cli_names[@]}"; do
    if command -v "$cli" > /dev/null 2>&1; then
      clis+=("{\"name\":\"$cli\",\"available\":true}")
    else
      clis+=("{\"name\":\"$cli\",\"available\":false}")
    fi
  done

  python3 -c "
import json, sys
items = []
for arg in sys.argv[1:]:
    items.append(json.loads(arg))
print(json.dumps(items))
" -- "${clis[@]}" 2>/dev/null || echo "[]"
}

# ─────────────────────────────────────────────────────────────
# CI detection
# ─────────────────────────────────────────────────────────────

_detect_ci() {
  local root="$1"

  # GitHub Actions
  if [[ -d "${root}/.github/workflows" ]]; then
    echo '{"detected":true,"type":"github-actions","config_path":".github/workflows/"}'
    return
  fi

  # GitLab CI
  if [[ -f "${root}/.gitlab-ci.yml" ]]; then
    echo '{"detected":true,"type":"gitlab-ci","config_path":".gitlab-ci.yml"}'
    return
  fi

  # Azure Pipelines
  if [[ -f "${root}/azure-pipelines.yml" ]]; then
    echo '{"detected":true,"type":"azure-pipelines","config_path":"azure-pipelines.yml"}'
    return
  fi

  # CircleCI
  if [[ -d "${root}/.circleci" ]]; then
    echo '{"detected":true,"type":"circleci","config_path":".circleci/"}'
    return
  fi

  # Jenkins
  if [[ -f "${root}/Jenkinsfile" ]]; then
    echo '{"detected":true,"type":"jenkins","config_path":"Jenkinsfile"}'
    return
  fi

  echo '{"detected":false,"type":null,"config_path":null}'
}

# ─────────────────────────────────────────────────────────────
# CLI usage (when called directly)
# ─────────────────────────────────────────────────────────────
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  PROJECT_ROOT="${1:-.}"
  STATE_DIR="${2:-.claude/feature-state/default}"
  OUTPUT=$(discover_environment "$PROJECT_ROOT" "$STATE_DIR")
  echo "✅ Environment manifest written to: ${OUTPUT}"
  echo ""
  python3 -c "
import json
with open('$OUTPUT') as f:
    d = json.load(f)
print(f'  Stack: {d[\"stack\"].get(\"primary_platform\", \"unknown\")}')
print(f'  MCPs:  {len(d.get(\"mcps\", []))} detected')
avail = [c[\"name\"] for c in d.get(\"clis\", []) if c.get(\"available\")]
print(f'  CLIs:  {len(avail)} available ({', '.join(avail[:5])}{'...' if len(avail)>5 else ''})')
ci = d.get('ci', {})
print(f'  CI:    {ci.get(\"type\", \"none\")}')
" 2>/dev/null || true
fi
