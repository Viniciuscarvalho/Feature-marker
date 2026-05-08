#!/usr/bin/env bash
# menu.sh - Interactive menu for feature-marker
set -euo pipefail

# Check if TTY is available for interactive input
check_tty_available() {
  if [[ -t 0 ]] && [[ -t 1 ]]; then
    return 0
  fi
  return 1
}

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
  echo -e "  ${GREEN}3)${NC} ${BOLD}Spec-Driven Mode${NC} - Multi-agent review + worktree isolation"
  echo -e "     ${BLUE}→${NC} Uses spec-workflow for rigorous spec review"
  echo ""
  echo -e "  ${GREEN}4)${NC} ${BOLD}Test Only Mode${NC} - Run tests phase exclusively"
  echo -e "     ${BLUE}→${NC} Uses platform-appropriate test guidance (Swift Testing, Jest, pytest, etc.)"
  echo ""
  echo -e "  ${GREEN}5)${NC} ${BOLD}PRD Only${NC} - Draft PRD and exit"
  echo -e "     ${BLUE}→${NC} Skips TechSpec, Tasks, branch, implementation, PR"
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
      echo -e "${BOLD}🔬 Spec-Driven Mode${NC}"
      echo "  • Multi-agent review of specifications"
      echo "  • Isolated worktree for safe development"
      echo "  • Converts spec to PRD/TechSpec/Tasks format"
      echo "  • Then executes standard FM phases 3-4"
      ;;
    4)
      echo -e "${BOLD}🧪 Test Only Mode${NC}"
      echo "  • Runs only the test phase (Phase 3)"
      echo "  • Uses /swift-testing skill for guided test creation"
      echo "  • Validates existing implementation with tests"
      echo "  • Skips generation, planning, and implementation"
      ;;
    5)
      echo -e "${BOLD}📝 PRD Only Mode${NC}"
      echo "  • Drafts PRD.md via /create-prd"
      echo "  • Exits before TechSpec/Tasks generation"
      echo "  • No branch, no implementation, no PR"
      echo "  • Artifacts are portable — consumable by any LLM"
      ;;
  esac
  echo ""
}

# Check if spec-workflow skills are available
check_spec_workflow_available() {
  local skills_dir="${SKILLS_DIR:-${HOME}/.claude/skills}"

  if [[ -f "${skills_dir}/spec-orchestrator/SKILL.md" ]] && \
     [[ -f "${skills_dir}/spec-executor/SKILL.md" ]]; then
    return 0
  fi

  return 1
}

# Get bundled spec-workflow skills path
get_bundled_spec_workflow_path() {
  local bundled_path=""

  # Priority 1: Installed feature-marker skill location
  if [[ -d "${SKILLS_DIR:-${HOME}/.claude/skills}/feature-marker/resources/spec-workflow/skills" ]]; then
    bundled_path="${SKILLS_DIR:-${HOME}/.claude/skills}/feature-marker/resources/spec-workflow/skills"
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
install_spec_workflow_skills() {
  local target_dir="${SKILLS_DIR:-${HOME}/.claude/skills}"
  local skills=("idea-explorer" "spec-writer" "spec-orchestrator" "spec-executor" "create-worktree" "spec-workflow-init")

  local source_dir
  source_dir="$(get_bundled_spec_workflow_path)"

  if [[ -n "${SPEC_WORKFLOW_SOURCE:-}" ]]; then
    source_dir="${SPEC_WORKFLOW_SOURCE}"
  fi

  if [[ -z "$source_dir" ]] || [[ ! -d "$source_dir" ]]; then
    error "spec-workflow skills not found in bundled resources"
    echo "Expected location: ~/.claude/skills/feature-marker/resources/spec-workflow/skills"
    return 1
  fi

  info "Installing spec-workflow skills from bundled resources..."

  mkdir -p "$target_dir"
  for skill in "${skills[@]}"; do
    if [[ -d "${source_dir}/${skill}" ]] && [[ ! -d "${target_dir}/${skill}" ]]; then
      cp -r "${source_dir}/${skill}" "${target_dir}/"
      success "Installed: ${skill}"
    fi
  done

  return 0
}

# Show spec-workflow installation instructions
show_spec_workflow_install_instructions() {
  echo ""
  error "Spec-Driven Mode requires spec-workflow skills"
  echo ""
  echo "Required skills:"
  echo "  • spec-orchestrator"
  echo "  • spec-executor"
  echo "  • idea-explorer"
  echo "  • spec-writer"
  echo "  • create-worktree"
  echo ""
  echo "Would you like to install them automatically?"
}

# Interactive menu selection
select_execution_mode() {
  local feature_name="$1"
  local selected_mode=""

  # Check if TTY is available
  if ! check_tty_available; then
    # Output marker for agent to detect and use AskUserQuestion
    echo "INTERACTIVE_MODE_REQUESTED"
    echo "FEATURE_NAME=${feature_name}"
    exit 100
  fi

  # Show existing feature state so the user has context before picking a mode.
  if checkpoint_exists "${feature_name}"; then
    show_checkpoint_summary "${feature_name}"
    echo ""
  fi

  while true; do
    clear
    banner
    show_main_menu "$feature_name"

    read -p "Select option [0-5]: " selected_mode

    case "$selected_mode" in
      1)
        confirm_mode 1 "$feature_name"
        if ask_yes_no "Proceed with Full Workflow mode?"; then
          export EXECUTION_MODE="full"
          return 0
        fi
        ;;
      2)
        if validate_mode_requirements "tasks-only"; then
          confirm_mode 2 "$feature_name"
          if ask_yes_no "Proceed with Tasks Only mode?"; then
            export EXECUTION_MODE="tasks-only"
            return 0
          fi
        fi
        read -p "Press Enter to continue..."
        ;;
      3)
        if check_spec_workflow_available; then
          confirm_mode 3 "$feature_name"
          if ask_yes_no "Proceed with Spec-Driven mode?"; then
            export EXECUTION_MODE="spec-driven"
            return 0
          fi
        else
          show_spec_workflow_install_instructions
          if ask_yes_no "Install spec-workflow skills now?"; then
            if install_spec_workflow_skills; then
              success "Spec-workflow skills installed successfully!"
              confirm_mode 3 "$feature_name"
              if ask_yes_no "Proceed with Spec-Driven mode?"; then
                export EXECUTION_MODE="spec-driven"
                return 0
              fi
            else
              error "Failed to install spec-workflow skills."
            fi
          fi
          read -p "Press Enter to continue..."
        fi
        ;;
      4)
        confirm_mode 4 "$feature_name"
        if ask_yes_no "Proceed with Test Only mode?"; then
          export EXECUTION_MODE="test-only"
          return 0
        fi
        ;;
      5)
        confirm_mode 5 "$feature_name"
        if ask_yes_no "Proceed with PRD Only mode?"; then
          export EXECUTION_MODE="prd-only"
          return 0
        fi
        ;;
      0)
        echo ""
        info "Exiting feature-marker"
        exit 0
        ;;
      *)
        error "Invalid option. Please select 0-5."
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

# Check if mode is full workflow
is_full_workflow_mode() {
  [[ "${EXECUTION_MODE:-full}" == "full" ]]
}

# Check if mode is spec-driven
is_spec_driven_mode() {
  [[ "${EXECUTION_MODE:-full}" == "spec-driven" ]]
}

# Check if mode is test-only
is_test_only_mode() {
  [[ "${EXECUTION_MODE:-full}" == "test-only" ]]
}

# Check if mode is prd-only
is_prd_only_mode() {
  [[ "${EXECUTION_MODE:-full}" == "prd-only" ]]
}
