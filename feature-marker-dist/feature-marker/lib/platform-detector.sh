#!/usr/bin/env bash
# platform-detector.sh - Git platform detection for feature-marker
set -euo pipefail

# Detect git platform from remote URL
detect_git_platform() {
  local remote_url
  remote_url=$(git remote get-url origin 2>/dev/null || echo "")

  if [[ -z "$remote_url" ]]; then
    echo "unknown"
    return
  fi

  case "$remote_url" in
    *github.com*)
      echo "github"
      ;;
    *dev.azure.com*|*visualstudio.com*)
      echo "azure"
      ;;
    *gitlab.com*)
      echo "gitlab"
      ;;
    *bitbucket.org*)
      echo "bitbucket"
      ;;
    *)
      echo "generic"
      ;;
  esac
}

# Get the appropriate PR skill for the detected platform
get_pr_skill_for_platform() {
  local platform="${1:-$(detect_git_platform)}"

  case "$platform" in
    github)
      echo "checking-pr"
      ;;
    azure)
      echo "azure-pr"
      ;;
    gitlab)
      echo "checking-pr"
      ;;
    bitbucket)
      echo "checking-pr"
      ;;
    *)
      echo "checking-pr"  # fallback
      ;;
  esac
}

# Check if a skill is available
is_skill_available() {
  local skill_name="$1"
  local skill_path="${HOME}/.claude/skills/${skill_name}/SKILL.md"

  [[ -f "$skill_path" ]]
}

# Get fallback skill (always checking-pr)
get_fallback_skill() {
  echo "checking-pr"
}

# Display platform detection info
show_platform_info() {
  local platform
  platform=$(detect_git_platform)

  echo "Git Platform Detection:"
  echo "  Platform: $platform"
  echo "  PR Skill: $(get_pr_skill_for_platform "$platform")"

  local skill
  skill=$(get_pr_skill_for_platform "$platform")
  if is_skill_available "$skill"; then
    echo "  Skill Status: Available"
  else
    echo "  Skill Status: Not installed"
    echo "  Fallback: $(get_fallback_skill)"
  fi
}

# Get remote URL
get_remote_url() {
  git remote get-url origin 2>/dev/null || echo ""
}

# Check if we can push to remote
can_push_to_remote() {
  local remote_url
  remote_url=$(get_remote_url)

  if [[ -z "$remote_url" ]]; then
    return 1
  fi

  # Try to check remote access (this is a basic check)
  git ls-remote --exit-code origin HEAD > /dev/null 2>&1
}
