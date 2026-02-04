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

# Export functions for use in other scripts
export -f ensure_product_manager_skill
export -f ensure_commit_command
export -f check_all_dependencies
