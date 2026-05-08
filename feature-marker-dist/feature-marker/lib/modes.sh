#!/usr/bin/env bash
# modes.sh - Single source of truth for execution mode metadata.
# Reads lib/modes.json; all mode logic routes through here.
set -euo pipefail

MODES_JSON="${SCRIPT_DIR}/lib/modes.json"

# Print newline-separated list of valid mode IDs.
get_valid_modes() {
  jq -r '.[].id' "$MODES_JSON"
}

# Print pipe-separated mode IDs for help text (e.g. "full | tasks-only | ...").
get_modes_help_string() {
  jq -r '[.[].id] | join(" | ")' "$MODES_JSON"
}

# Exit 1 with error if the given mode ID is not in modes.json.
assert_valid_mode() {
  local mode="$1"
  local match
  match=$(jq -r --arg m "$mode" '.[] | select(.id == $m) | .id' "$MODES_JSON")
  if [[ -z "$match" ]]; then
    error "Unknown mode: '${mode}'"
    echo "  Valid modes: $(get_modes_help_string)"
    exit 1
  fi
}

# Validate that required files exist for the given mode.
# Reads the 'requires' array from modes.json.
# Exits 1 with a clear error if any file is missing.
validate_mode_requirements() {
  local mode="$1"
  local feature_path="${DOCS_PATH:-./tasks}/${FEATURE_NAME:-}"

  local missing=()
  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    [[ ! -f "${feature_path}/${f}" ]] && missing+=("$f")
  done < <(jq -r --arg m "$mode" '.[] | select(.id == $m) | .requires[]' "$MODES_JSON" 2>/dev/null)

  if [[ ${#missing[@]} -gt 0 ]]; then
    error "Mode '${mode}' requires files that don't exist in ${feature_path}/:"
    for f in "${missing[@]}"; do
      echo "  • ${f}"
    done
    echo ""
    echo "Run with --mode full to generate missing files first."
    return 1
  fi
}

# Read a single field from the mode entry (e.g. get_mode_field tasks-only entry → "implement").
get_mode_field() {
  local mode="$1"
  local field="$2"
  jq -r --arg m "$mode" --arg f "$field" '.[] | select(.id == $m) | .[$f] // empty' "$MODES_JSON"
}
