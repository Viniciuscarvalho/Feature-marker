#!/usr/bin/env bash
# scripts/audit_commands.sh — Post-run command audit log verifier (ADR-011 PR-C)
#
# Parses Claude's tool-use log (run-*.log) for the feature worktree and checks
# for deny-list pattern matches. Fails PR creation if any prohibited commands
# were executed during the autonomous run.
#
# Usage:
#   bash scripts/audit_commands.sh verify-clean <wt_path>
#   bash scripts/audit_commands.sh report <wt_path>
#
# Exit codes:
#   0 — clean, no deny-list hits
#   1 — one or more deny-list patterns found; operator must review audit.log

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Patterns that should NEVER appear in a legitimate autonomous run log.
# These match tool-use lines in Claude's --print output format.
_AUDIT_DENY_PATTERNS=(
  'rm -rf'
  'sudo '
  'curl '
  'wget '
  ' nc '
  'ncat '
  'ssh '
  'scp '
  '/etc/passwd'
  '/etc/shadow'
  '~/\.ssh'
  '~/\.claude'
  '~\/\.gnupg'
  '\.pem'
  '\.p12\b'
  '\.pfx\b'
  '\.key\b'
  'IGNORE_PREVIOUS'
  'ignore.*previous.*instructions'
  '\[SYSTEM\]'
  '\[ADMIN\]'
)

_scan_log() {
  local log_file="$1"
  local hits=0
  local hit_lines=()

  for pat in "${_AUDIT_DENY_PATTERNS[@]}"; do
    local matched
    matched=$(grep -niE "$pat" "$log_file" 2>/dev/null || true)
    if [ -n "$matched" ]; then
      hits=$((hits + 1))
      hit_lines+=("  DENY-HIT [$pat]: $(echo "$matched" | head -2)")
    fi
  done

  echo "$hits"
  for line in "${hit_lines[@]}"; do
    echo "$line"
  done
}

_find_latest_log() {
  local wt_path="$1"
  # Look in state dir for the most recent run log for this worktree
  local feat_id
  feat_id=$(basename "$wt_path" | sed 's/^feat-//')
  local log_dir="${STATE_DIR:-$wt_path/../.orchestrator/state}/$feat_id/logs"

  if [ -d "$log_dir" ]; then
    ls -t "$log_dir"/run-*.log 2>/dev/null | head -1
  else
    # Fallback: look for any log adjacent to the worktree
    local state_root
    state_root="$(dirname "$wt_path")/../.orchestrator/state"
    if [ -d "$state_root" ]; then
      find "$state_root" -name "run-*.log" \
        -newer "$wt_path" 2>/dev/null | sort | tail -1
    fi
  fi
}

_verify_clean() {
  local wt_path="$1"
  local audit_log="${2:-$wt_path/.orchestrator-audit.log}"

  local log_file=""
  log_file=$(_find_latest_log "$wt_path") || true

  if [ -z "$log_file" ] || [ ! -f "$log_file" ]; then
    echo "audit_commands: no run log found for $wt_path — skipping audit" >&2
    return 0
  fi

  local result
  result=$(_scan_log "$log_file")
  local hits
  hits=$(echo "$result" | head -1)
  local details
  details=$(echo "$result" | tail -n +2)

  # Write audit log
  {
    echo "# Command Audit — $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    echo "# Log: $log_file"
    echo "# Hits: $hits"
    echo "$details"
  } > "$audit_log"

  if [ "${hits:-0}" -gt 0 ]; then
    echo "audit_commands: FAIL — $hits deny-list hit(s) in run log" >&2
    echo "$details" >&2
    echo "audit_commands: review $audit_log" >&2
    return 1
  fi

  echo "audit_commands: clean — no deny-list hits in $log_file"
  return 0
}

_report() {
  local wt_path="$1"
  local log_file
  log_file=$(_find_latest_log "$wt_path")
  if [ -z "$log_file" ] || [ ! -f "$log_file" ]; then
    echo "audit_commands: no run log found"
    return 0
  fi
  echo "# Audit report for: $wt_path"
  echo "# Source log: $log_file"
  _scan_log "$log_file"
}

# ── main ─────────────────────────────────────────────────────────────────────
case "${1:-help}" in
  verify-clean)
    shift
    _verify_clean "$@"
    ;;
  report)
    shift
    _report "$@"
    ;;
  *)
    echo "Usage: audit_commands.sh verify-clean <wt_path>"
    echo "       audit_commands.sh report <wt_path>"
    exit 1
    ;;
esac
