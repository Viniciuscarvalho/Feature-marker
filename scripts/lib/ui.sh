#!/bin/bash
# lib/ui.sh — ANSI color tokens for orchestrator terminal output
# TTY-gated: colors emit only when stdout is a terminal.
# Override: FM_FORCE_COLOR=1 forces colors even in pipes.

if [[ -t 1 ]] || [[ "${FM_FORCE_COLOR:-}" == "1" ]]; then
  C_RED=$'\033[0;31m'
  C_GREEN=$'\033[0;32m'
  C_YELLOW=$'\033[0;33m'
  C_BLUE=$'\033[0;34m'
  C_CYAN=$'\033[0;36m'
  C_DIM=$'\033[2m'
  C_BOLD=$'\033[1m'
  C_NC=$'\033[0m'
else
  C_RED=''; C_GREEN=''; C_YELLOW=''; C_BLUE=''; C_CYAN=''; C_DIM=''; C_BOLD=''; C_NC=''
fi
export C_RED C_GREEN C_YELLOW C_BLUE C_CYAN C_DIM C_BOLD C_NC
