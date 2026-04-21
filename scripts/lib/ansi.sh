#!/bin/bash
# lib/ansi.sh — ANSI color initialization
#
# Call fm_ansi_init once at startup. Exports FM_* color vars + FM_INTERACTIVE.
# Respects NO_COLOR (https://no-color.org) and FM_FORCE_COLOR override.
# Captures FM_INTERACTIVE before any pipeline redirections change [ -t 1 ].

fm_ansi_init() {
  # Capture tty state immediately — must be called before any pipeline fork
  if [ -t 1 ]; then
    FM_INTERACTIVE=1
  else
    FM_INTERACTIVE=0
  fi

  local use_color=0
  if [ -n "${FM_FORCE_COLOR:-}" ]; then
    use_color=1
  elif [ -z "${NO_COLOR:-}" ] && [ "${FM_INTERACTIVE}" = "1" ]; then
    use_color=1
  fi

  if [ "$use_color" = "1" ]; then
    FM_CYAN='\033[0;36m'
    FM_GREEN='\033[0;32m'
    FM_YELLOW='\033[0;33m'
    FM_RED='\033[0;31m'
    FM_DIM='\033[2m'
    FM_BOLD='\033[1m'
    FM_GRAY='\033[0;90m'
    FM_RESET='\033[0m'
    FM_COLOR_ENABLED=1
  else
    FM_CYAN=''
    FM_GREEN=''
    FM_YELLOW=''
    FM_RED=''
    FM_DIM=''
    FM_BOLD=''
    FM_GRAY=''
    FM_RESET=''
    FM_COLOR_ENABLED=0
  fi

  export FM_CYAN FM_GREEN FM_YELLOW FM_RED FM_DIM FM_BOLD FM_GRAY FM_RESET
  export FM_COLOR_ENABLED FM_INTERACTIVE
}
