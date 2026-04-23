#!/usr/bin/env bash
# scripts/guardrails.sh — Per-worktree .claude/settings.json emitter (ADR-011 PR-C)
#
# Usage:
#   bash scripts/guardrails.sh emit <wt_path> [stack]
#
# Writes .claude/settings.json inside <wt_path> with a stack-adaptive
# allow/deny permission set. Under --permission-mode bypassPermissions the
# allow list is advisory; the deny list IS enforced by Claude's pre-tool-use
# hooks regardless of bypass mode.
#
# Stack defaults (override per item in .claude/spec-workflow/PROJECT.md security: block):
#   ios     — swift/xcodebuild/swiftlint
#   nodejs  — npm/pnpm/yarn/bun/jest/tsc/eslint
#   rust    — cargo build/test/clippy
#   python  — pytest/ruff/flake8/python -m build
#   go      — go build/test/vet
#   unknown — read-only + git commands only

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

_emit_settings() {
  local wt_path="$1"
  local stack="${2:-unknown}"
  local out="$wt_path/.claude/settings.json"
  mkdir -p "$wt_path/.claude"

  # Stack-specific allow list
  local allow_bash_cmds=()
  case "$stack" in
    ios)
      allow_bash_cmds=(
        "swift build:*" "swift test:*" "swift package:*"
        "xcodebuild:*"
        "swiftlint:*" "swiftformat:*"
      )
      ;;
    nodejs|node)
      allow_bash_cmds=(
        "npm run:*" "npm test:*" "npm install:*"
        "pnpm run:*" "pnpm test:*" "pnpm install:*"
        "yarn:*" "bun:*"
        "jest:*" "vitest:*" "tsc:*" "eslint:*" "prettier:*"
        "next:*" "vite:*"
      )
      ;;
    rust)
      allow_bash_cmds=(
        "cargo build:*" "cargo test:*" "cargo clippy:*"
        "cargo check:*" "cargo fmt:*" "cargo run:*"
      )
      ;;
    python)
      allow_bash_cmds=(
        "python:*" "python3:*" "pip:*" "pip3:*"
        "pytest:*" "ruff:*" "flake8:*" "mypy:*"
        "poetry run:*" "uv run:*"
      )
      ;;
    go)
      allow_bash_cmds=(
        "go build:*" "go test:*" "go vet:*"
        "go run:*" "go mod:*" "go generate:*"
        "gofmt:*" "golint:*"
      )
      ;;
    *)
      allow_bash_cmds=()
      ;;
  esac

  # Common allow entries for all stacks
  local common_allow=(
    "Bash(git diff:*)"
    "Bash(git status:*)"
    "Bash(git add:*)"
    "Bash(git commit:*)"
    "Bash(git log:*)"
    "Bash(git show:*)"
    "Bash(git branch:*)"
    "Bash(grep:*)"
    "Bash(find:*)"
    "Bash(ls:*)"
    "Bash(cat:*)"
    "Bash(echo:*)"
    "Bash(mkdir:*)"
    "Bash(cp:*)"
    "Bash(mv:*)"
    "Read(**)"
    "Write(tasks/prd-*/**)"
    "Edit(tasks/prd-*/**)"
  )

  # Stack-specific write/edit allowances
  local stack_write=()
  case "$stack" in
    ios)    stack_write=("Write(Sources/**)" "Edit(Sources/**)" "Write(Tests/**)" "Edit(Tests/**)" "Write(*.swift)" "Edit(*.swift)") ;;
    nodejs|node) stack_write=("Write(src/**)" "Edit(src/**)" "Write(tests/**)" "Edit(tests/**)" "Write(**/*.ts)" "Edit(**/*.ts)" "Write(**/*.js)" "Edit(**/*.js)") ;;
    rust)   stack_write=("Write(src/**)" "Edit(src/**)" "Write(tests/**)" "Edit(tests/**)" "Write(**/*.rs)" "Edit(**/*.rs)") ;;
    python) stack_write=("Write(**/*.py)" "Edit(**/*.py)" "Write(tests/**)" "Edit(tests/**)") ;;
    go)     stack_write=("Write(**/*.go)" "Edit(**/*.go)" "Write(tests/**)" "Edit(tests/**)") ;;
  esac

  # Read optional overrides from PROJECT.md security block
  local project_md="$wt_path/.claude/spec-workflow/PROJECT.md"
  local extra_allow=() extra_deny=()
  if [ -f "$project_md" ]; then
    while IFS= read -r line; do
      [[ "$line" =~ ^[[:space:]]*-[[:space:]]\"?(.+)\"?$ ]] && extra_allow+=("${BASH_REMATCH[1]}")
    done < <(python3 -c "
import sys, re
text = open(sys.argv[1]).read()
m = re.search(r'allowed_commands:(.*?)(?:denied_paths:|allowed_network:|sanitize_mode:|$)', text, re.S)
if m:
    for l in m.group(1).splitlines():
        l = l.strip().lstrip('- ').strip('\"').strip()
        if l: print(l)
" "$project_md" 2>/dev/null || true)
  fi

  # Build final JSON
  local bash_allow_json="[]"
  local write_allow_json="[]"
  local deny_json="[]"

  # Build bash allow array — guard empty arrays for set -u compatibility
  local all_allow_entries=()
  if [ ${#allow_bash_cmds[@]} -gt 0 ]; then
    for cmd in "${allow_bash_cmds[@]}"; do
      all_allow_entries+=("\"Bash($cmd)\"")
    done
  fi
  for entry in "${common_allow[@]}"; do
    all_allow_entries+=("\"$entry\"")
  done
  if [ ${#stack_write[@]} -gt 0 ]; then
    for entry in "${stack_write[@]}"; do
      all_allow_entries+=("\"$entry\"")
    done
  fi
  if [ ${#extra_allow[@]} -gt 0 ]; then
    for entry in "${extra_allow[@]}"; do
      all_allow_entries+=("\"Bash($entry:*)\"")
    done
  fi

  # Deny list (always applied regardless of bypassPermissions)
  local deny_entries=(
    "Bash(rm -rf *)"
    "Bash(sudo *)"
    "Bash(curl *)"
    "Bash(wget *)"
    "Bash(nc *)"
    "Bash(ncat *)"
    "Bash(ssh *)"
    "Bash(scp *)"
    "Write(.github/**)"
    "Write(~/.claude/**)"
    "Write(/etc/**)"
    "Write(/tmp/**)"
    "Write(**/*.pem)"
    "Write(**/*.p12)"
    "Write(**/*.pfx)"
    "Write(**/*.key)"
    "Write(Secrets/**)"
    "Write(.env)"
    "Write(.env.*)"
  )

  local allow_str=""
  for entry in "${all_allow_entries[@]}"; do
    [ -n "$allow_str" ] && allow_str="$allow_str,"
    allow_str="$allow_str\n      $entry"
  done

  local deny_str=""
  for entry in "${deny_entries[@]}"; do
    [ -n "$deny_str" ] && deny_str="$deny_str,"
    deny_str="$deny_str\n      \"$entry\""
  done

  printf '{
  "permissions": {
    "allow": [%b
    ],
    "deny": [%b
    ]
  }
}\n' "$allow_str" "$deny_str" > "$out"

  echo "guardrails: wrote $out (stack=$stack)"
}

# ── main ─────────────────────────────────────────────────────────────────────
case "${1:-help}" in
  emit)
    shift
    _emit_settings "$@"
    ;;
  *)
    echo "Usage: guardrails.sh emit <wt_path> [stack]"
    exit 1
    ;;
esac
