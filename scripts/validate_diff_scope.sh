#!/usr/bin/env bash
# scripts/validate_diff_scope.sh — Post-run diff scope verifier (ADR-011 PR-D)
#
# Validates that all files touched by Claude during an autonomous run remain
# inside the feature worktree. Fails if any changed path escapes to:
#   - Outside the worktree root
#   - ~/.claude/** (user config)
#   - /etc/** or /tmp/** (system paths)
#   - Any path matching the PROJECT.md denied_paths list
#
# Usage:
#   bash scripts/validate_diff_scope.sh <wt_path> <feat_id>
#
# Exit codes:
#   0 — all changed files are inside the worktree
#   1 — one or more paths violate scope; details on stderr

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Absolute deny patterns for worktree-level location checks.
# Applied to the worktree path itself (not individual files) since git diff
# always returns relative paths — files are always "inside" wt_abs by construction.
# The primary scope enforcement is the PROJECT.md denied_paths and the scope-escape check.
_SENSITIVE_WT_LOCATIONS=(
  "${HOME}/.claude"
  "/etc"
  "/System"
  "/Library"
)

_load_project_denied_paths() {
  local wt_path="$1"
  local project_md="$wt_path/.claude/spec-workflow/PROJECT.md"
  [ -f "$project_md" ] || return 0

  python3 - "$project_md" <<'PYEOF'
import sys, re

text = open(sys.argv[1]).read()
m = re.search(r'denied_paths:(.*?)(?:allowed_commands:|allowed_network:|sanitize_mode:|allowed_write_paths:|$)', text, re.S)
if m:
    for line in m.group(1).splitlines():
        line = line.strip().lstrip('- ').strip('"').strip()
        if line:
            print(line)
PYEOF
}

_matches_glob() {
  # Test whether $1 (relative path) matches $2 (glob pattern like **/*.pem)
  local rel_path="$1" pat="$2"
  python3 - "$rel_path" "$pat" <<'PYEOF'
import sys, fnmatch, os

path = sys.argv[1]
pat  = sys.argv[2]

# fnmatch handles * but not **.  Implement ** manually:
# **/<something> should match at any depth
if pat.startswith('**/'):
    tail = pat[3:]
    # Match against basename or any suffix of the path
    basename = os.path.basename(path)
    matched = (fnmatch.fnmatch(basename, tail) or
               fnmatch.fnmatch(path, tail) or
               any(fnmatch.fnmatch(path[i:], tail)
                   for i in range(len(path)) if path[i-1:i] == '/'))
elif pat.endswith('/**'):
    # Prefix/**: match anything under prefix/
    prefix = pat[:-3]
    matched = path.startswith(prefix + '/') or path == prefix
else:
    matched = fnmatch.fnmatch(path, pat)

sys.exit(0 if matched else 1)
PYEOF
}

_validate_scope() {
  local wt_path="$1"
  local feat_id="${2:-unknown}"

  # Resolve absolute wt_path
  if ! wt_abs=$(cd "$wt_path" 2>/dev/null && pwd); then
    echo "validate_diff_scope: worktree $wt_path not found — skipping" >&2
    return 0
  fi

  # Reject worktrees located in sensitive system directories
  for sensitive in "${_SENSITIVE_WT_LOCATIONS[@]}"; do
    case "$wt_abs" in
      "$sensitive"|"$sensitive/"*)
        echo "validate_diff_scope: FAIL — worktree is inside sensitive path: $wt_abs" >&2
        return 1
        ;;
    esac
  done

  local report_dir="$wt_abs/.orchestrator"
  mkdir -p "$report_dir"

  # Get changed files from git
  local changed_files=""
  changed_files=$(
    git -C "$wt_abs" diff --name-only HEAD 2>/dev/null || true
    git -C "$wt_abs" diff --name-only --cached 2>/dev/null || true
    git -C "$wt_abs" ls-files --others --exclude-standard 2>/dev/null || true
  ) || true

  if [ -z "$changed_files" ]; then
    {
      echo "# Diff Scope Report — $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
      echo "# Feature: $feat_id"
      echo "# Files checked: 0"
      echo "# Violations: 0"
    } > "$report_dir/diff-scope.log"
    echo "validate_diff_scope: no changed files detected in $feat_id — scope clean"
    return 0
  fi

  # Load project-specific denied paths
  local project_denied_patterns=()
  while IFS= read -r pat; do
    [ -n "$pat" ] && project_denied_patterns+=("$pat")
  done < <(_load_project_denied_paths "$wt_abs" 2>/dev/null || true)

  local violations=()
  local total=0
  while IFS= read -r rel_path; do
    [ -z "$rel_path" ] && continue
    total=$((total + 1))

    # Resolve to absolute path (git always gives relative paths, so this is always inside wt_abs)
    local abs_path="$wt_abs/$rel_path"

    # Check project-specific denied_paths globs
    local denied=0
    if [ ${#project_denied_patterns[@]} -gt 0 ]; then
      for glob_pat in "${project_denied_patterns[@]}"; do
        if _matches_glob "$rel_path" "$glob_pat" 2>/dev/null; then
          violations+=("PROJECT-DENY: $rel_path (matches $glob_pat)")
          denied=1
          break
        fi
      done
    fi
  done <<< "$changed_files"

  # Write scope report alongside inventory
  {
    echo "# Diff Scope Report — $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    echo "# Feature: $feat_id"
    echo "# Files checked: $total"
    echo "# Violations: ${#violations[@]}"
    if [ ${#violations[@]} -gt 0 ]; then
      for v in "${violations[@]}"; do
        echo "  $v"
      done
    fi
  } > "$report_dir/diff-scope.log"

  if [ ${#violations[@]} -gt 0 ]; then
    echo "validate_diff_scope: FAIL — ${#violations[@]} scope violation(s) for $feat_id" >&2
    for v in "${violations[@]}"; do
      echo "  $v" >&2
    done
    echo "validate_diff_scope: review $report_dir/diff-scope.log" >&2
    return 1
  fi

  echo "validate_diff_scope: clean — $total file(s) all within worktree for $feat_id"
  return 0
}

# ── main ─────────────────────────────────────────────────────────────────────
case "${1:-help}" in
  verify)
    shift
    _validate_scope "$@"
    ;;
  *)
    # Default: treat args as <wt_path> <feat_id> for direct invocation from runner.sh
    if [ $# -ge 1 ] && [ "$1" != "help" ]; then
      _validate_scope "$@"
    else
      echo "Usage: validate_diff_scope.sh <wt_path> <feat_id>"
      exit 1
    fi
    ;;
esac
