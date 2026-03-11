#!/usr/bin/env bash
# mcp-detector.sh — MCP server detection engine for feature-marker
# Scans agent config files for configured MCP servers
# Outputs: mcp-context.json in the given state directory
set -euo pipefail

# ─────────────────────────────────────────────────────────────
# Public API
# ─────────────────────────────────────────────────────────────

# detect_mcps <project_root> <state_dir>
# Scans config files for MCP servers, writes mcp-context.json to <state_dir>
detect_mcps() {
  local project_root="${1:-.}"
  local state_dir="${2:-.claude/feature-state/default}"

  mkdir -p "$state_dir"

  local all_mcps="[]"

  # ── Scan each config source ─────────────────────────────
  local claude_project="${project_root}/.claude/settings.json"
  local claude_global="${HOME}/.claude/settings.json"
  local cursor_config="${project_root}/.cursor/mcp.json"
  local claude_desktop="${HOME}/Library/Application Support/Claude/claude_desktop_config.json"
  local vscode_settings="${project_root}/.vscode/settings.json"
  local kiro_settings="${project_root}/.kiro/settings/mcp.json"
  local codex_config="${project_root}/.codex/config.toml"

  # Claude Code project settings
  if [[ -f "$claude_project" ]]; then
    local result
    result=$(_extract_mcp_servers "$claude_project" "mcpServers" ".claude/settings.json (project)")
    if [[ "$result" != "[]" ]]; then
      all_mcps=$(_merge_mcp_arrays "$all_mcps" "$result")
    fi
  fi

  # Claude Code global settings
  if [[ -f "$claude_global" ]]; then
    local result
    result=$(_extract_mcp_servers "$claude_global" "mcpServers" "~/.claude/settings.json (global)")
    if [[ "$result" != "[]" ]]; then
      all_mcps=$(_merge_mcp_arrays "$all_mcps" "$result")
    fi
  fi

  # Cursor MCP config
  if [[ -f "$cursor_config" ]]; then
    local result
    result=$(_extract_mcp_servers "$cursor_config" "mcpServers" ".cursor/mcp.json")
    if [[ "$result" != "[]" ]]; then
      all_mcps=$(_merge_mcp_arrays "$all_mcps" "$result")
    fi
  fi

  # Claude Desktop config
  if [[ -f "$claude_desktop" ]]; then
    local result
    result=$(_extract_mcp_servers "$claude_desktop" "mcpServers" "claude_desktop_config.json")
    if [[ "$result" != "[]" ]]; then
      all_mcps=$(_merge_mcp_arrays "$all_mcps" "$result")
    fi
  fi

  # VS Code MCP extension settings
  if [[ -f "$vscode_settings" ]]; then
    local result
    result=$(_extract_vscode_mcp "$vscode_settings")
    if [[ "$result" != "[]" ]]; then
      all_mcps=$(_merge_mcp_arrays "$all_mcps" "$result")
    fi
  fi

  # Kiro MCP settings
  if [[ -f "$kiro_settings" ]]; then
    local result
    result=$(_extract_mcp_servers "$kiro_settings" "mcpServers" ".kiro/settings/mcp.json")
    if [[ "$result" != "[]" ]]; then
      all_mcps=$(_merge_mcp_arrays "$all_mcps" "$result")
    fi
  fi

  # Codex config (TOML)
  if [[ -f "$codex_config" ]]; then
    local result
    result=$(_extract_codex_mcp "$codex_config")
    if [[ "$result" != "[]" ]]; then
      all_mcps=$(_merge_mcp_arrays "$all_mcps" "$result")
    fi
  fi

  # Deduplicate by server_key
  all_mcps=$(_deduplicate_mcps "$all_mcps")

  # Classify each MCP with category and adapter
  all_mcps=$(_classify_mcps "$all_mcps")

  local timestamp
  timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || echo "unknown")

  # Write mcp-context.json
  python3 -c "
import json, sys
mcps = json.loads('''$all_mcps''')
output = {
    'mcps': mcps,
    'mcp_count': len(mcps),
    'detected_at': '$timestamp'
}
print(json.dumps(output, indent=2))
" > "${state_dir}/mcp-context.json" 2>/dev/null

  echo "${state_dir}/mcp-context.json"
}

# get_mcp_context <state_dir>
# Reads and echoes the mcp-context.json content
get_mcp_context() {
  local state_dir="${1:-.claude/feature-state/default}"
  local context_file="${state_dir}/mcp-context.json"

  if [[ -f "$context_file" ]]; then
    cat "$context_file"
  else
    echo '{"mcps":[],"mcp_count":0}'
  fi
}

# ─────────────────────────────────────────────────────────────
# Detection helpers (private — prefix _)
# ─────────────────────────────────────────────────────────────

# _extract_mcp_servers <config_file> <json_key> <source_label>
# Extracts MCP server names from a JSON config file
_extract_mcp_servers() {
  local config_file="$1"
  local json_key="$2"
  local source_label="$3"

  python3 -c "
import json, sys
try:
    with open('$config_file', 'r') as f:
        data = json.load(f)
    servers = data.get('$json_key', {})
    if not isinstance(servers, dict):
        print('[]')
        sys.exit(0)
    result = []
    for key, val in servers.items():
        entry = {
            'server_key': key,
            'name': key,
            'source': '$source_label',
            'category': 'unknown',
            'adapter': None,
            'tools_hint': []
        }
        # Try to extract command info for better naming
        if isinstance(val, dict):
            cmd = val.get('command', '')
            args = val.get('args', [])
            if isinstance(args, list) and args:
                # Use last arg as potential name hint
                entry['_command'] = cmd
        result.append(entry)
    print(json.dumps(result))
except Exception:
    print('[]')
" 2>/dev/null || echo "[]"
}

# _extract_vscode_mcp <settings_file>
# Extracts MCP servers from VS Code's mcp.servers key
_extract_vscode_mcp() {
  local settings_file="$1"

  python3 -c "
import json, sys
try:
    with open('$settings_file', 'r') as f:
        data = json.load(f)
    servers = data.get('mcp', {}).get('servers', {})
    if not isinstance(servers, dict):
        print('[]')
        sys.exit(0)
    result = []
    for key, val in servers.items():
        entry = {
            'server_key': key,
            'name': key,
            'source': '.vscode/settings.json',
            'category': 'unknown',
            'adapter': None,
            'tools_hint': []
        }
        result.append(entry)
    print(json.dumps(result))
except Exception:
    print('[]')
" 2>/dev/null || echo "[]"
}

# _extract_codex_mcp <config_file>
# Extracts MCP servers from Codex TOML config
_extract_codex_mcp() {
  local config_file="$1"

  python3 -c "
import sys
try:
    import tomllib
except ImportError:
    try:
        import tomli as tomllib
    except ImportError:
        print('[]')
        sys.exit(0)
import json
try:
    with open('$config_file', 'rb') as f:
        data = tomllib.load(f)
    servers = data.get('mcp_servers', {})
    if not isinstance(servers, dict):
        print('[]')
        sys.exit(0)
    result = []
    for key, val in servers.items():
        entry = {
            'server_key': key,
            'name': key,
            'source': '.codex/config.toml',
            'category': 'unknown',
            'adapter': None,
            'tools_hint': []
        }
        result.append(entry)
    print(json.dumps(result))
except Exception:
    print('[]')
" 2>/dev/null || echo "[]"
}

# _merge_mcp_arrays <arr1_json> <arr2_json>
_merge_mcp_arrays() {
  python3 -c "
import json, sys
a = json.loads('''$1''')
b = json.loads('''$2''')
print(json.dumps(a + b))
" 2>/dev/null || echo "$1"
}

# _deduplicate_mcps <mcps_json>
# Deduplicates by server_key, keeping the first occurrence
_deduplicate_mcps() {
  python3 -c "
import json, sys
mcps = json.loads('''$1''')
seen = set()
result = []
for m in mcps:
    key = m.get('server_key', '').lower()
    if key not in seen:
        seen.add(key)
        result.append(m)
print(json.dumps(result))
" 2>/dev/null || echo "$1"
}

# _classify_mcps <mcps_json>
# Assigns category and adapter based on known MCP registry
_classify_mcps() {
  python3 -c "
import json, re, sys

REGISTRY = [
    {
        'patterns': [r'xcodebuild', r'xcbuild', r'xcode.?build'],
        'category': 'build',
        'adapter': 'references/mcp-adapters/xcodebuild.md',
        'tools_hint': ['discover_projs', 'session_set_defaults', 'build_run_sim']
    },
    {
        'patterns': [r'playwright'],
        'category': 'test',
        'adapter': 'references/mcp-adapters/playwright.md',
        'tools_hint': ['browser_navigate', 'browser_click', 'browser_screenshot']
    },
    {
        'patterns': [r'postgres', r'supabase'],
        'category': 'database',
        'adapter': None,
        'tools_hint': []
    },
    {
        'patterns': [r'docker'],
        'category': 'deployment',
        'adapter': 'references/mcp-adapters/docker.md',
        'tools_hint': ['docker_build', 'docker_run']
    },
    {
        'patterns': [r'github'],
        'category': 'project-mgmt',
        'adapter': None,
        'tools_hint': []
    },
    {
        'patterns': [r'linear'],
        'category': 'project-mgmt',
        'adapter': None,
        'tools_hint': []
    },
]

mcps = json.loads('''$1''')
for m in mcps:
    key = m.get('server_key', '').lower().replace('-', '').replace('_', '')
    name = m.get('name', '').lower().replace('-', '').replace('_', '')
    matched = False
    for reg in REGISTRY:
        for pat in reg['patterns']:
            if re.search(pat, key) or re.search(pat, name):
                m['category'] = reg['category']
                m['adapter'] = reg['adapter']
                m['tools_hint'] = reg['tools_hint']
                matched = True
                break
        if matched:
            break
print(json.dumps(mcps))
" 2>/dev/null || echo "$1"
}

# ─────────────────────────────────────────────────────────────
# CLI usage (when called directly)
# ─────────────────────────────────────────────────────────────
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  PROJECT_ROOT="${1:-.}"
  STATE_DIR="${2:-.claude/feature-state/default}"
  OUTPUT=$(detect_mcps "$PROJECT_ROOT" "$STATE_DIR")
  MCP_COUNT=$(python3 -c "import json; d=json.load(open('$OUTPUT')); print(d.get('mcp_count', 0))" 2>/dev/null || echo "0")
  echo "✅ Detected ${MCP_COUNT} MCP server(s)"
  echo "   mcp-context.json written to: ${OUTPUT}"
fi
