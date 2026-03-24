#!/usr/bin/env bash
# ui.sh - User interface helpers for feature-marker
set -euo pipefail

# Colors (if terminal supports them)
if [[ -t 1 ]]; then
  RED='\033[0;31m'
  GREEN='\033[0;32m'
  YELLOW='\033[0;33m'
  BLUE='\033[0;34m'
  BOLD='\033[1m'
  NC='\033[0m' # No Color
else
  RED=''
  GREEN=''
  YELLOW=''
  BLUE=''
  BOLD=''
  NC=''
fi

# Print success message
success() {
  echo -e "${GREEN}✓${NC} $1"
}

# Print error message
error() {
  echo -e "${RED}✗${NC} $1" >&2
}

# Print warning message
warning() {
  echo -e "${YELLOW}⚠${NC} $1"
}

# Print info message
info() {
  echo -e "${BLUE}ℹ${NC} $1"
}

# Print bold header
header() {
  echo -e "\n${BOLD}$1${NC}"
}

# Print phase indicator
phase_indicator() {
  local phase_num="$1"
  local phase_name="$2"
  local status="$3"

  case "$status" in
    completed)
      echo -e "${GREEN}[Phase $phase_num]${NC} $phase_name - ${GREEN}Completed${NC}"
      ;;
    in_progress)
      echo -e "${BLUE}[Phase $phase_num]${NC} $phase_name - ${BLUE}In Progress${NC}"
      ;;
    pending)
      echo -e "[Phase $phase_num] $phase_name - Pending"
      ;;
    error)
      echo -e "${RED}[Phase $phase_num]${NC} $phase_name - ${RED}Error${NC}"
      ;;
  esac
}

# Print progress bar
progress_bar() {
  local current="$1"
  local total="$2"
  local width=30
  local percent=$((current * 100 / total))
  local filled=$((current * width / total))
  local empty=$((width - filled))

  printf "\r["
  printf "%${filled}s" | tr ' ' '='
  printf "%${empty}s" | tr ' ' ' '
  printf "] %d/%d (%d%%)" "$current" "$total" "$percent"
}

# Print task progress
task_progress() {
  local task_num="$1"
  local total_tasks="$2"
  local task_name="$3"
  local status="$4"

  case "$status" in
    completed)
      echo -e "  ${GREEN}[$task_num/$total_tasks]${NC} $task_name ${GREEN}✓${NC}"
      ;;
    in_progress)
      echo -e "  ${BLUE}[$task_num/$total_tasks]${NC} $task_name ${BLUE}...${NC}"
      ;;
    pending)
      echo -e "  [$task_num/$total_tasks] $task_name"
      ;;
    failed)
      echo -e "  ${RED}[$task_num/$total_tasks]${NC} $task_name ${RED}✗${NC}"
      ;;
  esac
}

# Ask yes/no question
ask_yes_no() {
  local question="$1"
  local default="${2:-y}"

  if [[ "$default" == "y" ]]; then
    prompt="[Y/n]"
  else
    prompt="[y/N]"
  fi

  read -p "$question $prompt " answer
  answer="${answer:-$default}"

  [[ "${answer,,}" == "y" || "${answer,,}" == "yes" ]]
}

# Print workflow summary
workflow_summary() {
  local feature_name="$1"
  local current_phase="$2"
  local phase_status="$3"

  header "Workflow Summary: $feature_name"
  echo "  Current Phase: $current_phase"
  echo "  Status: $phase_status"
  echo ""
}

# Print separator line
separator() {
  echo "────────────────────────────────────────"
}

# Print feature-marker banner
banner() {
  echo ""
  echo -e "${BOLD}╔═══════════════════════════════════════╗${NC}"
  echo -e "${BOLD}║        feature-marker v1.2.0          ║${NC}"
  echo -e "${BOLD}╚═══════════════════════════════════════╝${NC}"
  echo ""
}
