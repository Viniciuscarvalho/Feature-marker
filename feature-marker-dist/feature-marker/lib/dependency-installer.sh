#!/usr/bin/env bash
# dependency-installer.sh - Manages skills and commands installation
set -euo pipefail

# Check if product-manager skill exists, install if missing
ensure_product_manager_skill() {
  local skill_path="${HOME}/.claude/skills/product-manager/SKILL.md"

  if [[ -f "${skill_path}" ]]; then
    echo "✓ product-manager skill already installed"
    return 0
  fi

  echo "⚙️  Installing product-manager skill..."

  # Try to install via npx skills
  if command -v npx &> /dev/null; then
    if npx skills add https://github.com/aj-geddes/claude-code-bmad-skills --skill product-manager; then
      echo "✓ product-manager skill installed successfully"
      return 0
    else
      echo "⚠️  Failed to install product-manager skill via npx" >&2
      echo "   You can install it manually with:" >&2
      echo "   npx skills add https://github.com/aj-geddes/claude-code-bmad-skills --skill product-manager" >&2
      return 1
    fi
  else
    echo "⚠️  npx not found. Cannot auto-install product-manager skill" >&2
    echo "   Install Node.js/npm and run:" >&2
    echo "   npx skills add https://github.com/aj-geddes/claude-code-bmad-skills --skill product-manager" >&2
    return 1
  fi
}

# Check if commit command exists, install if missing
ensure_commit_command() {
  local user_commit_path="${HOME}/.claude/commands/commit.md"
  local bundled_commit_path

  # Try to find bundled commit.md in feature-marker installation
  if [[ -f "${HOME}/.claude/skills/feature-marker/resources/commit.md" ]]; then
    bundled_commit_path="${HOME}/.claude/skills/feature-marker/resources/commit.md"
  elif [[ -n "${FEATURE_MARKER_ROOT:-}" ]] && [[ -f "${FEATURE_MARKER_ROOT}/resources/commit.md" ]]; then
    bundled_commit_path="${FEATURE_MARKER_ROOT}/resources/commit.md"
  else
    bundled_commit_path=""
  fi

  # Check if user already has commit command
  if [[ -f "${user_commit_path}" ]]; then
    echo "✓ commit command already exists in ~/.claude/commands/"
    return 0
  fi

  # Install bundled commit command if available
  if [[ -n "${bundled_commit_path}" ]] && [[ -f "${bundled_commit_path}" ]]; then
    echo "⚙️  Installing commit command..."
    mkdir -p "$(dirname "${user_commit_path}")"

    if cp "${bundled_commit_path}" "${user_commit_path}"; then
      echo "✓ commit command installed successfully"
      return 0
    else
      echo "⚠️  Failed to copy commit command" >&2
      return 1
    fi
  else
    echo "⚠️  Bundled commit.md not found" >&2
    echo "   Expected location: ${HOME}/.claude/skills/feature-marker/resources/commit.md" >&2
    echo "   Using default commit behavior" >&2
    return 1
  fi
}

# Check if spec-workflow skills exist
check_spec_workflow_skills() {
  local skills_dir="${HOME}/.claude/skills"
  local required_skills=("spec-orchestrator" "spec-executor")

  for skill in "${required_skills[@]}"; do
    if [[ ! -f "${skills_dir}/${skill}/SKILL.md" ]]; then
      return 1
    fi
  done

  return 0
}

# Get bundled spec-workflow skills path
get_bundled_spec_workflow_path() {
  local bundled_path=""

  # Priority 1: Installed feature-marker skill location
  if [[ -d "${HOME}/.claude/skills/feature-marker/resources/spec-workflow/skills" ]]; then
    bundled_path="${HOME}/.claude/skills/feature-marker/resources/spec-workflow/skills"
  # Priority 2: FEATURE_MARKER_ROOT environment variable
  elif [[ -n "${FEATURE_MARKER_ROOT:-}" ]] && [[ -d "${FEATURE_MARKER_ROOT}/resources/spec-workflow/skills" ]]; then
    bundled_path="${FEATURE_MARKER_ROOT}/resources/spec-workflow/skills"
  # Priority 3: Script directory (for development)
  elif [[ -n "${BASH_SOURCE[0]:-}" ]]; then
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if [[ -d "${script_dir}/../resources/spec-workflow/skills" ]]; then
      bundled_path="${script_dir}/../resources/spec-workflow/skills"
    fi
  fi

  echo "$bundled_path"
}

# Install spec-workflow skills from bundled resources
ensure_spec_workflow_skills() {
  local target_dir="${HOME}/.claude/skills"
  local skills=("idea-explorer" "spec-writer" "spec-orchestrator" "spec-executor" "create-worktree" "spec-workflow-init")
  local installed=0

  # Check if already installed
  if check_spec_workflow_skills; then
    echo "✓ spec-workflow skills already installed"
    return 0
  fi

  # Get bundled path (from feature-marker installation)
  local source_dir
  source_dir="$(get_bundled_spec_workflow_path)"

  # Fallback to environment variable if set
  if [[ -z "$source_dir" ]] && [[ -n "${SPEC_WORKFLOW_SOURCE:-}" ]]; then
    source_dir="${SPEC_WORKFLOW_SOURCE}"
  fi

  # Check if source exists
  if [[ -z "$source_dir" ]] || [[ ! -d "$source_dir" ]]; then
    echo "⚠️  spec-workflow skills not found in bundled resources" >&2
    echo "   Expected location: ~/.claude/skills/feature-marker/resources/spec-workflow/skills" >&2
    echo "   Please reinstall feature-marker or set SPEC_WORKFLOW_SOURCE" >&2
    return 1
  fi

  echo "⚙️  Installing spec-workflow skills from bundled resources..."
  echo "   Source: ${source_dir}"
  mkdir -p "$target_dir"

  for skill in "${skills[@]}"; do
    if [[ -d "${source_dir}/${skill}" ]]; then
      if [[ ! -d "${target_dir}/${skill}" ]]; then
        if cp -r "${source_dir}/${skill}" "${target_dir}/"; then
          echo "  ✓ Installed: ${skill}"
          ((installed++)) || true
        else
          echo "  ⚠️  Failed to install: ${skill}" >&2
        fi
      else
        echo "  ✓ Already exists: ${skill}"
      fi
    else
      echo "  ⚠️  Not found in source: ${skill}" >&2
    fi
  done

  if [[ $installed -gt 0 ]] || check_spec_workflow_skills; then
    echo "✓ spec-workflow skills installation complete"
    return 0
  else
    echo "⚠️  Failed to install spec-workflow skills" >&2
    return 1
  fi
}

# Check both dependencies
check_all_dependencies() {
  local pm_ok=0
  local commit_ok=0

  ensure_product_manager_skill || pm_ok=$?
  ensure_commit_command || commit_ok=$?

  if [[ $pm_ok -eq 0 ]] && [[ $commit_ok -eq 0 ]]; then
    return 0
  else
    return 1
  fi
}

# Check all dependencies including spec-workflow (for spec-driven mode)
check_all_dependencies_with_spec_workflow() {
  local base_ok=0
  local spec_ok=0

  check_all_dependencies || base_ok=$?
  ensure_spec_workflow_skills || spec_ok=$?

  if [[ $base_ok -eq 0 ]] && [[ $spec_ok -eq 0 ]]; then
    return 0
  else
    return 1
  fi
}

# Export functions for use in other scripts
export -f ensure_product_manager_skill
export -f ensure_commit_command
export -f check_all_dependencies
export -f check_spec_workflow_skills
export -f ensure_spec_workflow_skills
export -f check_all_dependencies_with_spec_workflow
