#!/usr/bin/env bash
# menu.sh - Interactive menu for feature-marker
set -euo pipefail

# Display main menu panel
show_main_menu() {
  local feature_name="$1"

  echo ""
  echo -e "${BOLD}┌──────────────────────────────────────────────────────┐${NC}"
  echo -e "${BOLD}│         🚀 Feature Marker - Execution Mode           │${NC}"
  echo -e "${BOLD}└──────────────────────────────────────────────────────┘${NC}"
  echo ""
  echo -e "  ${BOLD}Feature:${NC} ${BLUE}${feature_name}${NC}"
  echo ""
  echo -e "  ${BOLD}Select execution mode:${NC}"
  echo ""
  echo -e "  ${GREEN}1)${NC} ${BOLD}Full Workflow${NC} - Generate PRD/TechSpec/Tasks + Implementation"
  echo -e "     ${BLUE}→${NC} Creates missing files and executes all phases"
  echo ""
  echo -e "  ${GREEN}2)${NC} ${BOLD}Execute Tasks Only${NC} - Skip generation, run implementation"
  echo -e "     ${BLUE}→${NC} Use existing PRD/TechSpec/Tasks (must exist)"
  echo ""
  echo -e "  ${GREEN}3)${NC} ${BOLD}Ralph Loop Mode${NC} - Autonomous loop execution"
  echo -e "     ${BLUE}→${NC} Uses ralph-claude-code for continuous iteration"
  echo ""
  echo -e "  ${YELLOW}0)${NC} Exit"
  echo ""
}

# Display execution mode confirmation
confirm_mode() {
  local mode="$1"
  local feature_name="$2"

  echo ""
  case "$mode" in
    1)
      echo -e "${BOLD}📋 Full Workflow Mode${NC}"
      echo "  • Validates existing files"
      echo "  • Generates missing PRD/TechSpec/Tasks"
      echo "  • Executes all 4 phases"
      ;;
    2)
      echo -e "${BOLD}⚡ Execute Tasks Only Mode${NC}"
      echo "  • Skips file generation"
      echo "  • Requires existing PRD/TechSpec/Tasks"
      echo "  • Goes directly to implementation"
      ;;
    3)
      echo -e "${BOLD}🔁 Ralph Loop Mode${NC}"
      echo "  • Autonomous continuous execution"
      echo "  • Self-correcting with ralph-claude-code"
      echo "  • Runs until completion or manual stop"
      ;;
  esac
  echo ""
}

# Check if files exist for tasks-only mode
validate_tasks_only_mode() {
  local feature_name="$1"
  local feature_path="${DOCS_PATH}/prd-${feature_name}"

  local missing=()

  [[ ! -f "${feature_path}/prd.md" ]] && missing+=("prd.md")
  [[ ! -f "${feature_path}/techspec.md" ]] && missing+=("techspec.md")
  [[ ! -f "${feature_path}/tasks.md" ]] && missing+=("tasks.md")

  if [[ ${#missing[@]} -gt 0 ]]; then
    error "Tasks-only mode requires all files to exist"
    echo ""
    echo "Missing files:"
    for file in "${missing[@]}"; do
      echo "  • ${file}"
    done
    echo ""
    echo "Please use 'Full Workflow' mode (option 1) to generate missing files."
    return 1
  fi

  return 0
}

# Check if ralph-claude-code is available
check_ralph_available() {
  if command -v ralph &> /dev/null; then
    return 0
  fi

  # Check if skill exists
  if [[ -f "${HOME}/.claude/skills/ralph-wiggum/ralph-wiggum.sh" ]]; then
    return 0
  fi

  return 1
}

# Show ralph installation instructions
show_ralph_install_instructions() {
  echo ""
  error "Ralph Loop Mode requires ralph-claude-code"
  echo ""
  echo "Install from: ${BLUE}https://github.com/frankbria/ralph-claude-code${NC}"
  echo ""
  echo "Quick install:"
  echo "  git clone https://github.com/frankbria/ralph-claude-code.git"
  echo "  cd ralph-claude-code"
  echo "  ./install.sh"
  echo ""
}

# Interactive menu selection
select_execution_mode() {
  local feature_name="$1"
  local selected_mode=""

  while true; do
    clear
    banner
    show_main_menu "$feature_name"

    read -p "Select option [0-3]: " selected_mode

    case "$selected_mode" in
      1)
        confirm_mode 1 "$feature_name"
        if ask_yes_no "Proceed with Full Workflow mode?"; then
          export EXECUTION_MODE="full"
          return 0
        fi
        ;;
      2)
        if validate_tasks_only_mode "$feature_name"; then
          confirm_mode 2 "$feature_name"
          if ask_yes_no "Proceed with Tasks Only mode?"; then
            export EXECUTION_MODE="tasks-only"
            return 0
          fi
        fi
        read -p "Press Enter to continue..."
        ;;
      3)
        if check_ralph_available; then
          confirm_mode 3 "$feature_name"
          if ask_yes_no "Proceed with Ralph Loop mode?"; then
            export EXECUTION_MODE="ralph-loop"
            return 0
          fi
        else
          show_ralph_install_instructions
          read -p "Press Enter to continue..."
        fi
        ;;
      0)
        echo ""
        info "Exiting feature-marker"
        exit 0
        ;;
      *)
        error "Invalid option. Please select 0-3."
        sleep 1
        ;;
    esac
  done
}

# Export execution mode status
get_execution_mode() {
  echo "${EXECUTION_MODE:-full}"
}

# Check if mode is tasks-only
is_tasks_only_mode() {
  [[ "${EXECUTION_MODE:-full}" == "tasks-only" ]]
}

# Check if mode is ralph-loop
is_ralph_loop_mode() {
  [[ "${EXECUTION_MODE:-full}" == "ralph-loop" ]]
}

# Check if mode is full workflow
is_full_workflow_mode() {
  [[ "${EXECUTION_MODE:-full}" == "full" ]]
}
