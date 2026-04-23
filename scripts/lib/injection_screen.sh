#!/usr/bin/env bash
# scripts/lib/injection_screen.sh — Local-model injection classifier (ADR-011 PR-F)
#
# Optional second opinion for injection detection, gated by:
#   LOCAL_MODEL_ENABLED=true  AND  SANITIZE_SCREEN_ENABLED=true
#
# When enabled, classifies a feature body using the local model's classify
# function with labels: "safe injection". Returns a numeric score 0-3:
#   0  — classified as safe
#   1  — low confidence injection signal
#   2  — medium confidence injection signal
#   3  — high confidence injection signal
#
# If the local model is unreachable or disabled, returns 0 (safe) so the
# pipeline continues without blocking (fail-open, consistent with ADR-009).
#
# API:
#   source scripts/lib/injection_screen.sh
#   score=$(injection_screen_classify "$body_text")
#   # score 0=safe, 1-3 = escalating injection confidence

set -euo pipefail

# Read env vars at call time (not cached) so tests can override them after sourcing

# Source local_model.sh if not already loaded
_INJECTION_LIB_DIR="${LIB_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
if ! declare -f local_model::classify &>/dev/null 2>&1; then
  if [ -f "$_INJECTION_LIB_DIR/local_model.sh" ]; then
    source "$_INJECTION_LIB_DIR/local_model.sh" 2>/dev/null || true
  fi
fi

# injection_screen_classify <body_text>
# Prints a score 0-3 to stdout.
injection_screen_classify() {
  local body="$1"

  # Disabled — return safe immediately (read env vars dynamically)
  if [ "${LOCAL_MODEL_ENABLED:-false}" != "true" ] || \
     [ "${SANITIZE_SCREEN_ENABLED:-false}" != "true" ]; then
    echo "0"
    return 0
  fi

  # Classify with two labels: "safe" and "injection"
  # Fall back to "safe" if local_model::classify is unavailable or errors
  local label="safe"
  label=$(local_model::classify "$body" "safe injection" 2>/dev/null) || true
  [ -z "$label" ] && label="safe"

  # Map label to score
  case "$label" in
    injection) echo "3" ;;
    unsafe)    echo "2" ;;
    suspect)   echo "1" ;;
    safe|*)    echo "0" ;;
  esac
}

# injection_screen_is_suspicious <body_text>
# Returns 0 (true) if the body scores above threshold, 1 (false) otherwise.
injection_screen_is_suspicious() {
  local body="$1"
  local score
  score=$(injection_screen_classify "$body") || score="0"
  local threshold="${SANITIZE_SCREEN_THRESHOLD:-2}"
  [ "${score:-0}" -ge "$threshold" ]
}
