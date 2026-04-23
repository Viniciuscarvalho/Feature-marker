#!/usr/bin/env bash
# feature-marker.sh - Setup helper for feature-marker skill (v7)
# The agent orchestrates the workflow; this script handles git/env validation,
# directory init, and platform detection caching.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "${SCRIPT_DIR}/lib/ui.sh"
source "${SCRIPT_DIR}/lib/config.sh"
source "${SCRIPT_DIR}/lib/state-manager.sh"
source "${SCRIPT_DIR}/lib/platform-detector.sh"

banner

FEATURE_NAME=""
SHOW_HELP=false
SHOW_STATUS=false

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
      echo "feature-marker v7.0.0"
      exit 0
      ;;
    --mode|-m)
      EXECUTION_MODE="$2"
      export EXECUTION_MODE
      shift 2
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
  echo "  -m, --mode <mode>   Execution mode: full | tasks-only | spec-driven | test-only"
  echo "  -V, --version       Show version"
  exit 0
fi

if [[ "${SHOW_STATUS}" == "true" ]]; then
  [[ -z "${FEATURE_NAME}" ]] && { error "Feature name required for --status"; exit 1; }
  show_checkpoint_summary "${FEATURE_NAME}"
  exit 0
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

if checkpoint_exists "${FEATURE_NAME}"; then
  show_checkpoint_summary "${FEATURE_NAME}"
else
  info "No checkpoint — ready to start."
fi

separator
show_platform_info
separator
