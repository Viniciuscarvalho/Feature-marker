#!/usr/bin/env bash
# lib/stack_profile.sh — Stack profile: exports PROJECT_* env vars from detector output.
#
# Wraps stack-detector.sh (copied from the dist bundle into scripts/lib) and provides
# a stable, cached API that the rest of the orchestrator uses for build/test/lint commands.
# Resolves the schism between the rich ios-aware stack-detector.sh (formerly dist-only)
# and the extension-counting router.sh, making stack_profile the single source of truth.
#
# Public API:
#   stack_profile_init <wt_path>   — detect + export PROJECT_* vars; cache in wt_path/.orchestrator/
#   stack_profile_primary          — print $PROJECT_STACK (or "unknown" if not yet initialised)
#   stack_profile_cache_path <wt>  — print path to platform-context.json for the given worktree
#
# Exported vars (all available after stack_profile_init):
#   PROJECT_STACK          — primary stack: ios | nodejs | rust | python | go | unknown
#   PROJECT_STACK_SUBTYPE  — e.g. swift-package | xcodeproj | nextjs | cargo | ...
#   PROJECT_BUILD_CMD      — e.g. "xcodebuild build"
#   PROJECT_TEST_CMD       — e.g. "swift test --parallel"
#   PROJECT_LINT_CMD       — e.g. "swiftlint"
#   PROJECT_MANIFEST       — e.g. "Package.swift"
#   PROJECT_SOURCE_DIRS    — colon-separated source directories (best-effort)
#   PROJECT_PACKAGE_MANAGER — npm | pnpm | yarn | bun | spm | pip | poetry | cargo | go | unknown

# Source the detector (same directory as this file)
_SP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./stack-detector.sh
source "${_SP_DIR}/stack-detector.sh"

# ── stack_profile_cache_path ─────────────────────────────────────────────────

stack_profile_cache_path() {
  local wt_path="${1:-.}"
  echo "${wt_path}/.orchestrator/platform-context.json"
}

# ── _sp_field ────────────────────────────────────────────────────────────────
# Read a field from the primary platform object in platform-context.json.
# context_file and field are passed as argv to python3, never interpolated.

_sp_field() {
  local context_file="$1" field="$2"
  python3 -c "
import json, sys
ctx = json.load(open(sys.argv[1]))
primary = ctx.get('primary_platform', 'unknown')
for p in ctx.get('platforms', []):
    if p.get('type') == primary:
        print(p.get(sys.argv[2], ''))
        sys.exit(0)
print('')
" "$context_file" "$field" 2>/dev/null || echo ""
}

# ── stack_profile_init ───────────────────────────────────────────────────────

stack_profile_init() {
  local wt_path="${1:-.}"
  local cache_file
  cache_file=$(stack_profile_cache_path "$wt_path")
  local state_dir
  state_dir="$(dirname "$cache_file")"

  if [ ! -f "$cache_file" ]; then
    detect_stack "$wt_path" "$state_dir" > /dev/null 2>&1 || true
  fi

  if [ ! -f "$cache_file" ]; then
    export PROJECT_STACK="unknown" PROJECT_STACK_SUBTYPE="unknown"
    export PROJECT_BUILD_CMD="" PROJECT_TEST_CMD="" PROJECT_LINT_CMD=""
    export PROJECT_MANIFEST="" PROJECT_SOURCE_DIRS="" PROJECT_PACKAGE_MANAGER="unknown"
    return 0
  fi

  local primary
  primary=$(python3 -c "import json,sys; ctx=json.load(open(sys.argv[1])); print(ctx.get('primary_platform','unknown'))" \
    "$cache_file" 2>/dev/null || echo "unknown")

  export PROJECT_STACK="$primary"
  export PROJECT_STACK_SUBTYPE
  PROJECT_STACK_SUBTYPE=$(_sp_field "$cache_file" "subtype")
  export PROJECT_BUILD_CMD
  PROJECT_BUILD_CMD=$(_sp_field "$cache_file" "build_command")
  export PROJECT_TEST_CMD
  PROJECT_TEST_CMD=$(_sp_field "$cache_file" "test_command")
  export PROJECT_LINT_CMD
  PROJECT_LINT_CMD=$(_sp_field "$cache_file" "lint_command")
  export PROJECT_PACKAGE_MANAGER
  PROJECT_PACKAGE_MANAGER=$(_sp_field "$cache_file" "package_manager")

  export PROJECT_MANIFEST=""
  case "$primary" in
    ios)    if [ -f "$wt_path/Package.swift" ]; then PROJECT_MANIFEST="Package.swift"; fi ;;
    nodejs) if [ -f "$wt_path/package.json" ]; then PROJECT_MANIFEST="package.json"; fi ;;
    rust)   if [ -f "$wt_path/Cargo.toml" ];   then PROJECT_MANIFEST="Cargo.toml"; fi ;;
    python) for m in pyproject.toml setup.py requirements.txt; do
              if [ -f "$wt_path/$m" ]; then PROJECT_MANIFEST="$m"; break; fi
            done ;;
    go)     if [ -f "$wt_path/go.mod" ]; then PROJECT_MANIFEST="go.mod"; fi ;;
  esac

  export PROJECT_SOURCE_DIRS=""
  case "$primary" in
    ios)    if [ -d "$wt_path/Sources" ]; then PROJECT_SOURCE_DIRS="Sources"; fi ;;
    nodejs) if [ -d "$wt_path/src" ];     then PROJECT_SOURCE_DIRS="src"; fi ;;
    rust)   if [ -d "$wt_path/src" ];     then PROJECT_SOURCE_DIRS="src"; fi ;;
    python) PROJECT_SOURCE_DIRS="." ;;
    go)     PROJECT_SOURCE_DIRS="." ;;
  esac
}

# ── stack_profile_primary ────────────────────────────────────────────────────

stack_profile_primary() {
  echo "${PROJECT_STACK:-unknown}"
}

# ── CLI usage ────────────────────────────────────────────────────────────────
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  wt="${1:-.}"
  stack_profile_init "$wt"
  echo "Stack:   $PROJECT_STACK ($PROJECT_STACK_SUBTYPE)"
  echo "Build:   ${PROJECT_BUILD_CMD:-n/a}"
  echo "Test:    ${PROJECT_TEST_CMD:-n/a}"
  echo "Lint:    ${PROJECT_LINT_CMD:-n/a}"
  echo "Manifest:${PROJECT_MANIFEST:-n/a}"
  echo "PM:      ${PROJECT_PACKAGE_MANAGER:-n/a}"
fi
