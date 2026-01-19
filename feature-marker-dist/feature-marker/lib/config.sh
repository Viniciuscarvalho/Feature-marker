#!/usr/bin/env bash
# config.sh - Project validation helpers for feature-marker
set -euo pipefail

# Default paths (can be overridden via .feature-marker.json)
DOCS_PATH="./docs/tasks"
STATE_PATH=".claude/feature-state"
TEMPLATES_PATH="./docs/specs"

# Load project-specific configuration if exists
load_config() {
  local config_file=".feature-marker.json"
  if [[ -f "$config_file" ]]; then
    DOCS_PATH=$(jq -r '.docs_path // "./docs/tasks"' "$config_file")
    STATE_PATH=$(jq -r '.state_path // ".claude/feature-state"' "$config_file")
    echo "Loaded configuration from $config_file"
  fi
}

# Validate that we're in a git repository
validate_git_repo() {
  if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo "ERROR: Not a git repository. Please initialize git first." >&2
    return 1
  fi
  return 0
}

# Validate required directories exist
validate_directories() {
  local feature_name="$1"
  local feature_path="${DOCS_PATH}/prd-${feature_name}"

  if [[ ! -d "./docs" ]]; then
    echo "Creating ./docs directory..."
    mkdir -p "./docs"
  fi

  if [[ ! -d "${DOCS_PATH}" ]]; then
    echo "Creating ${DOCS_PATH} directory..."
    mkdir -p "${DOCS_PATH}"
  fi

  if [[ ! -d "${feature_path}" ]]; then
    echo "Creating ${feature_path} directory..."
    mkdir -p "${feature_path}"
  fi

  return 0
}

# Check if required templates exist
validate_templates() {
  local missing=()

  [[ ! -f "./docs/specs/prd-template.md" ]] && missing+=("./docs/specs/prd-template.md")
  [[ ! -f "./docs/specs/techspec-template.md" ]] && missing+=("./docs/specs/techspec-template.md")
  [[ ! -f "./docs/tasks-template.md" ]] && missing+=("./docs/tasks-template.md")
  [[ ! -f "./docs/task-template.md" ]] && missing+=("./docs/task-template.md")

  if [[ ${#missing[@]} -gt 0 ]]; then
    echo "WARNING: Missing templates:" >&2
    for t in "${missing[@]}"; do
      echo "  - $t" >&2
    done
    return 1
  fi

  return 0
}

# Check if feature files exist
check_feature_files() {
  local feature_name="$1"
  local feature_path="${DOCS_PATH}/prd-${feature_name}"
  local status=0

  echo "Checking feature files in ${feature_path}..."

  if [[ -f "${feature_path}/prd.md" ]]; then
    echo "  ✓ prd.md exists"
  else
    echo "  ✗ prd.md missing"
    status=1
  fi

  if [[ -f "${feature_path}/techspec.md" ]]; then
    echo "  ✓ techspec.md exists"
  else
    echo "  ✗ techspec.md missing"
    status=1
  fi

  if [[ -f "${feature_path}/tasks.md" ]]; then
    echo "  ✓ tasks.md exists"
  else
    echo "  ✗ tasks.md missing"
    status=1
  fi

  return $status
}

# Get the path to a feature's docs directory
get_feature_path() {
  local feature_name="$1"
  echo "${DOCS_PATH}/prd-${feature_name}"
}

# Get the path to a feature's state directory
get_state_path() {
  local feature_name="$1"
  echo "${STATE_PATH}/${feature_name}"
}
