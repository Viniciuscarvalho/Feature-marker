#!/usr/bin/env bash
# feature-marker.sh - Setup helper for feature-marker skill (v7)
# The agent orchestrates the workflow; this script handles git/env validation,
# directory init, and platform detection caching.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "${SCRIPT_DIR}/lib/ui.sh"
source "${SCRIPT_DIR}/lib/config.sh"
source "${SCRIPT_DIR}/lib/modes.sh"
source "${SCRIPT_DIR}/lib/state-manager.sh"
source "${SCRIPT_DIR}/lib/platform-detector.sh"

banner

FEATURE_NAME=""
SHOW_HELP=false
SHOW_STATUS=false
MENU_REQUESTED=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --help|-h)
      SHOW_HELP=true
      shift
      ;;
    --status|-s)
      SHOW_STATUS=true
      shift
      ;;
    --platform|-p)
      show_platform_info
      exit 0
      ;;
    --version|-V)
      echo "feature-marker v7.8.1"
      exit 0
      ;;
    --mode|-m)
      EXECUTION_MODE="$2"
      export EXECUTION_MODE
      shift 2
      ;;
    --menu|-i)
      MENU_REQUESTED=true
      shift
      ;;
    -*)
      error "Unknown option: $1"
      exit 1
      ;;
    *)
      FEATURE_NAME="$1"
      shift
      ;;
  esac
done

if [[ "${SHOW_HELP}" == "true" ]]; then
  echo "Usage: feature-marker.sh [OPTIONS] <feature-slug>"
  echo ""
  echo "Setup helper for the feature-marker skill. Invoke via Claude Code:"
  echo "  /feature-marker <feature-slug>"
  echo ""
  echo "Options:"
  echo "  -h, --help          Show this help"
  echo "  -s, --status        Show checkpoint status for a feature"
  echo "  -p, --platform      Show detected platform info"
  echo "  -m, --mode <mode>   Execution mode: $(get_modes_help_string)"
  echo "  -i, --menu          Open interactive mode-selection menu (requires TTY)"
  echo "  -V, --version       Show version"
  exit 0
fi

if [[ "${SHOW_STATUS}" == "true" ]]; then
  [[ -z "${FEATURE_NAME}" ]] && { error "Feature name required for --status"; exit 1; }
  show_checkpoint_summary "${FEATURE_NAME}"
  exit 0
fi

if [[ "${MENU_REQUESTED}" == "true" ]]; then
  [[ -z "${FEATURE_NAME}" ]] && { error "Feature name required for --menu"; exit 1; }
  source "${SCRIPT_DIR}/lib/menu.sh"
  select_execution_mode "${FEATURE_NAME}"
fi

if [[ -z "${FEATURE_NAME}" ]]; then
  error "Feature name required"
  echo "Usage: feature-marker.sh <feature-slug>"
  echo "Example: /feature-marker prd-user-authentication"
  exit 1
fi

load_config

validate_git_repo || exit 1

header "Feature: ${FEATURE_NAME}"
separator

validate_directories "${FEATURE_NAME}"
init_feature_state "${FEATURE_NAME}"

# If no --mode flag was passed, fall back to the mode stored in the checkpoint.
if [[ -z "${EXECUTION_MODE:-}" ]] && checkpoint_exists "${FEATURE_NAME}"; then
  stored_mode="$(get_checkpoint_mode "${FEATURE_NAME}")"
  if [[ -n "$stored_mode" ]]; then
    export EXECUTION_MODE="$stored_mode"
    info "Resuming with checkpoint mode: ${EXECUTION_MODE}"
  fi
fi

# Validate and persist the resolved mode.
if [[ -n "${EXECUTION_MODE:-}" ]]; then
  assert_valid_mode "${EXECUTION_MODE}"
  validate_mode_requirements "${EXECUTION_MODE}"
  set_checkpoint_mode "${FEATURE_NAME}" "${EXECUTION_MODE}"
fi

if checkpoint_exists "${FEATURE_NAME}"; then
  show_checkpoint_summary "${FEATURE_NAME}"
else
  info "No checkpoint — ready to start."
fi

separator
show_platform_info
export PR_SKILL="$(get_pr_skill_for_platform)"
separator
