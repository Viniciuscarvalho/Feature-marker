#!/usr/bin/env bash
# feature-marker.sh - Entry point script for feature-marker skill
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source library files
source "${SCRIPT_DIR}/lib/ui.sh"
source "${SCRIPT_DIR}/lib/config.sh"
source "${SCRIPT_DIR}/lib/state-manager.sh"
source "${SCRIPT_DIR}/lib/platform-detector.sh"
source "${SCRIPT_DIR}/lib/menu.sh"

# Show banner
banner

# Parse arguments
FEATURE_NAME=""
SHOW_HELP=false
SHOW_STATUS=false
INTERACTIVE_MODE=false

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
      echo "feature-marker v1.1.0"
      exit 0
      ;;
    --interactive|-i)
      INTERACTIVE_MODE=true
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

# Show help
if [[ "${SHOW_HELP}" == "true" ]]; then
  echo "Usage: feature-marker.sh [OPTIONS] <feature-slug>"
  echo ""
  echo "Automates feature development with a 4-phase workflow:"
  echo "  1. Inputs Gate - Validates/generates PRD, TechSpec, Tasks"
  echo "  2. Analysis & Planning - Creates implementation plan"
  echo "  3. Implementation - Executes tasks with progress tracking"
  echo "  4. Tests & Validation - Runs tests, validates build"
  echo "  5. Commit & PR - Commits and creates Pull Request"
  echo ""
  echo "Options:"
  echo "  -h, --help         Show this help message"
  echo "  -s, --status       Show status of a feature workflow"
  echo "  -p, --platform     Show detected git platform info"
  echo "  -i, --interactive  Launch interactive menu panel"
  echo "  -V, --version      Show version"
  echo ""
  echo "Examples:"
  echo "  feature-marker.sh prd-user-authentication"
  echo "  feature-marker.sh --interactive prd-user-authentication"
  echo "  feature-marker.sh --status prd-user-authentication"
  echo ""
  echo "Note: This script is meant to be invoked via Claude Code skill:"
  echo "  /feature-marker prd-user-authentication"
  echo "  /feature-marker --interactive prd-user-authentication"
  echo ""
  exit 0
fi

# Show status
if [[ "${SHOW_STATUS}" == "true" ]]; then
  if [[ -z "${FEATURE_NAME}" ]]; then
    error "Feature name required for --status"
    exit 1
  fi

  show_checkpoint_summary "${FEATURE_NAME}"
  exit 0
fi

# Validate feature name
if [[ -z "${FEATURE_NAME}" ]]; then
  error "Feature name required"
  echo ""
  echo "Usage: feature-marker.sh <feature-slug>"
  echo "Example: feature-marker.sh prd-user-authentication"
  echo ""
  echo "Or invoke via Claude Code skill:"
  echo "  /feature-marker prd-user-authentication"
  exit 1
fi

# Load configuration
load_config

# Validate git repo
if ! validate_git_repo; then
  exit 1
fi

# Show interactive menu if requested
if [[ "${INTERACTIVE_MODE}" == "true" ]]; then
  select_execution_mode "${FEATURE_NAME}"

  # Store selected mode
  SELECTED_MODE=$(get_execution_mode)

  clear
  banner
fi

header "Feature: ${FEATURE_NAME}"

# Display execution mode if interactive
if [[ "${INTERACTIVE_MODE}" == "true" ]]; then
  case "${SELECTED_MODE}" in
    full)
      info "Mode: Full Workflow (Generate + Execute)"
      ;;
    tasks-only)
      info "Mode: Tasks Only (Execute existing)"
      ;;
    ralph-loop)
      info "Mode: Ralph Loop (Autonomous)"
      ;;
  esac
  separator
fi

# Check for existing checkpoint
if checkpoint_exists "${FEATURE_NAME}"; then
  echo ""
  show_checkpoint_summary "${FEATURE_NAME}"
  echo ""

  current_phase=$(get_current_phase "${FEATURE_NAME}")
  phase_status=$(get_phase_status "${FEATURE_NAME}")

  if [[ "$phase_status" == "in_progress" || "$phase_status" == "error" ]]; then
    info "A checkpoint exists for this feature."
    echo ""
    echo "To resume this workflow, use the Claude Code skill:"
    echo "  /feature-marker ${FEATURE_NAME}"
    echo ""
  fi
else
  info "No checkpoint found. Starting new workflow."
fi

# Validate directories
validate_directories "${FEATURE_NAME}"

# Check feature files (skip if tasks-only mode)
separator
header "Inputs Gate"

if [[ "${INTERACTIVE_MODE}" == "true" ]] && is_tasks_only_mode; then
  success "All required files exist (validated in menu)"
  info "Skipping file generation - proceeding to implementation"
elif [[ "${INTERACTIVE_MODE}" == "true" ]] && is_ralph_loop_mode; then
  info "Ralph Loop Mode - File validation will be handled by loop"
else
  if check_feature_files "${FEATURE_NAME}"; then
    success "All required files exist"
  else
    warning "Some files are missing"
    echo ""
    echo "Missing files will be generated when you run:"
    echo "  /feature-marker ${FEATURE_NAME}"
  fi
fi

# Show platform info
separator
show_platform_info

separator
echo ""

# Show next steps based on mode
if [[ "${INTERACTIVE_MODE}" == "true" ]]; then
  if is_ralph_loop_mode; then
    info "Starting Ralph Loop Mode..."
    echo ""
    echo "To begin autonomous execution:"
    echo "  The agent will use ralph-wiggum skill for continuous iteration"
    echo ""
  elif is_tasks_only_mode; then
    info "Ready for implementation phase"
    echo ""
    echo "To execute tasks:"
    echo "  The agent will skip to Phase 2 (Implementation)"
    echo ""
  else
    info "Ready to start Full Workflow"
    echo ""
    echo "To begin:"
    echo "  The agent will execute all 4 phases with file generation"
    echo ""
  fi
else
  info "To start/continue this workflow, use Claude Code:"
  echo "  /feature-marker ${FEATURE_NAME}"
  echo "  /feature-marker --interactive ${FEATURE_NAME}  # For interactive mode"
  echo ""
fi
