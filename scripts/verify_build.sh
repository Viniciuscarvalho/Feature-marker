#!/usr/bin/env bash
# scripts/verify_build.sh — Build verification gate (ADR-011 PR-E)
#
# Runs the project build command (from stack_profile / platform-context.json)
# inside the feature worktree. Non-zero exit pauses the feature run with
# reason "build-broken" so a human can review before PR creation.
#
# Usage:
#   bash scripts/verify_build.sh <wt_path>
#
# Exit codes:
#   0 — build succeeded
#   1 — build failed (or no build command configured)
#   2 — build command not configured / unknown stack (soft skip)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

_read_build_cmd() {
  local wt_path="$1"
  local ctx="$wt_path/.orchestrator/platform-context.json"
  [ -f "$ctx" ] || return 0

  python3 - "$ctx" <<'PYEOF'
import sys, json

ctx = json.load(open(sys.argv[1]))

# platform-context.json may use different key names depending on who wrote it
cmd = (ctx.get('build_command') or
       ctx.get('PROJECT_BUILD_CMD') or
       ctx.get('buildCommand') or
       '')
print(cmd)
PYEOF
}

_verify_build() {
  local wt_path="$1"

  # Resolve absolute wt_path
  if ! wt_abs=$(cd "$wt_path" 2>/dev/null && pwd); then
    echo "verify_build: worktree $wt_path not found — skipping" >&2
    return 2
  fi

  local build_cmd
  build_cmd=$(_read_build_cmd "$wt_abs") || build_cmd=""

  if [ -z "$build_cmd" ]; then
    echo "verify_build: no build command configured — skipping build check" >&2
    return 2
  fi

  echo "verify_build: running '$build_cmd' in $wt_abs..."
  local log_dir="$wt_abs/.orchestrator"
  mkdir -p "$log_dir"
  local log_file="$log_dir/verify-build.log"

  local build_exit=0
  (
    cd "$wt_abs"
    eval "$build_cmd"
  ) > "$log_file" 2>&1 || build_exit=$?

  if [ "$build_exit" -ne 0 ]; then
    echo "verify_build: FAIL — build exited $build_exit" >&2
    echo "verify_build: last 20 lines of build log:" >&2
    tail -20 "$log_file" >&2
    return 1
  fi

  echo "verify_build: build succeeded"
  return 0
}

# ── main ─────────────────────────────────────────────────────────────────────
case "${1:-help}" in
  check)
    shift
    _verify_build "$@"
    ;;
  *)
    if [ $# -ge 1 ] && [ "$1" != "help" ]; then
      _verify_build "$@"
    else
      echo "Usage: verify_build.sh <wt_path>"
      exit 1
    fi
    ;;
esac
