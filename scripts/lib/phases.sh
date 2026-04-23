#!/bin/bash
# lib/phases.sh — Orchestrator phase detection from filenames
#
# Maps filenames / paths written by Claude to pipeline phase numbers:
#   1 = Plan    (prd.md, tasks.md, techspec.md)
#   2 = Execute (source code files)
#   3 = Test    (test files, *.bats, *.spec.*, *.test.*)
#   4 = Commit  (CHANGELOG.md)
#
# Functions are exported so the watcher subshell inherits them.

# fm_phase_for_file <filepath>
# Returns "1"|"2"|"3"|"4" or "" when phase is unknown.
# Accepts full paths or basenames — checks both path patterns and extension.
fm_phase_for_file() {
  local filepath="$1"
  local base
  base=$(basename "$filepath")

  # Phase 4: commit artifacts (check first — CHANGELOG is a special code file)
  case "$base" in
    CHANGELOG.md|CHANGELOG.*) echo "4"; return ;;
  esac

  # Phase 1: planning artifacts
  case "$base" in
    prd.md|tasks.md|techspec.md) echo "1"; return ;;
  esac

  # Phase 3: test files — basename patterns
  case "$base" in
    *.bats) echo "3"; return ;;
    *.test.*|*.spec.*) echo "3"; return ;;
  esac
  # Phase 3: test files — directory path patterns (leading segment or nested)
  case "$filepath" in
    */tests/*|tests/*|*/test/*|test/*|*/__tests__/*|__tests__/*|*/spec/*|spec/*) echo "3"; return ;;
  esac

  # Phase 2: source code extensions
  case "$base" in
    *.ts|*.tsx|*.js|*.jsx|*.mjs|*.cjs) echo "2"; return ;;
    *.py|*.rb|*.go|*.rs|*.swift|*.kt|*.java) echo "2"; return ;;
    *.c|*.cpp|*.h|*.hpp|*.sh|*.bash) echo "2"; return ;;
  esac

  echo ""
}

# fm_phase_label <phase_num>
# Returns human-readable label for a phase number.
fm_phase_label() {
  case "$1" in
    1) echo "Plan" ;;
    2) echo "Execute" ;;
    3) echo "Test" ;;
    4) echo "Commit" ;;
    *) echo "?" ;;
  esac
}

# fm_phase_eta <phase_num>
# Returns a static ETA estimate string (stub — real data in future follow-up).
fm_phase_eta() {
  case "$1" in
    1) echo "~1-3 min" ;;
    2) echo "~3-12 min" ;;
    3) echo "~1-5 min" ;;
    4) echo "~1 min" ;;
    *) echo "" ;;
  esac
}

export -f fm_phase_for_file fm_phase_label fm_phase_eta
