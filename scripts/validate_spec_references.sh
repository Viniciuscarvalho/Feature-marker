#!/usr/bin/env bash
# scripts/validate_spec_references.sh — Spec reference validator (ADR-011 PR-E)
#
# Parses generated PRD/techspec/tasks.md files and cross-checks file path
# references against the worktree inventory (inventory.json).
# "Declared-new" artifacts listed in tasks.md as to-be-created are allowed.
#
# Usage:
#   bash scripts/validate_spec_references.sh <wt_path> <task_dir>
#
# Exit codes:
#   0 — all file-path references are either existing or declared-new
#   1 — unresolved file paths that don't exist and aren't declared in tasks

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

_validate_references() {
  local wt_path="$1"
  local task_dir="$2"

  local inv="$wt_path/.orchestrator/inventory.json"
  if [ ! -f "$inv" ]; then
    echo "validate_spec_references: no inventory.json — skipping" >&2
    return 0
  fi

  local prd="$task_dir/prd.md"
  local techspec="$task_dir/techspec.md"
  local tasks="$task_dir/tasks.md"

  # At minimum prd.md must exist for there to be anything to validate
  if [ ! -f "$prd" ] && [ ! -f "$techspec" ] && [ ! -f "$tasks" ]; then
    echo "validate_spec_references: no spec docs found — skipping"
    return 0
  fi

  # Write doc list to a temp file so Python gets stable argv
  local tmpfile
  tmpfile=$(mktemp)
  for doc in "$prd" "$techspec" "$tasks"; do
    [ -f "$doc" ] && echo "$doc" >> "$tmpfile" || true
  done

  local result
  result=$(python3 - "$inv" "$tasks" "$tmpfile" <<'PYEOF'
import sys, json, os, re

inv_path = sys.argv[1]
tasks_path = sys.argv[2]
doc_list_file = sys.argv[3]

inv = json.load(open(inv_path))
existing_files = set(inv.get('files', []))
existing_basenames = {os.path.basename(f) for f in existing_files}

# Collect declared-new: backtick tokens in task checklist lines
declared_new = set()
if os.path.isfile(tasks_path):
    for line in open(tasks_path):
        if re.match(r'\s*-\s*\[[ x]\]', line, re.I):
            for m in re.finditer(r'`([^`\n]+)`', line):
                declared_new.add(m.group(1).strip())
            # bare filenames after create/add/write/implement
            for m in re.finditer(
                r'\b(?:create|add|write|implement|define)\s+([A-Za-z0-9_./]+\.[A-Za-z]+)',
                line, re.I
            ):
                declared_new.add(m.group(1))

# Collect file-path-like references from all spec docs
FILE_EXTS = ('.swift', '.ts', '.tsx', '.js', '.jsx', '.py', '.go', '.rs',
             '.md', '.json', '.yaml', '.yml', '.sh', '.kt', '.java', '.rb')

refs = set()
for doc_path in open(doc_list_file).read().splitlines():
    if not os.path.isfile(doc_path):
        continue
    text = open(doc_path).read()
    for m in re.finditer(r'`([^`\n]+)`', text):
        tok = m.group(1).strip()
        if ('/' in tok or tok.endswith(FILE_EXTS)) and len(tok) > 3:
            refs.add(tok)

warnings = []
for ref in sorted(refs):
    if ref in declared_new:
        continue
    basename = os.path.basename(ref)
    if ref in existing_files or basename in existing_basenames:
        continue
    # New files (not yet created) that appear in specs but not in inventory
    # are only warned if they have a directory path — bare filenames are likely new
    if '/' in ref:
        warnings.append(f"UNRESOLVED-FILE: {ref}")

for w in warnings[:10]:
    print(w)
if warnings:
    sys.exit(1)
PYEOF
)
  local py_exit=$?
  rm -f "$tmpfile"

  if [ "$py_exit" -ne 0 ] && [ -n "$result" ]; then
    echo "validate_spec_references: unresolved file references in spec for $(basename "$task_dir"):" >&2
    echo "$result" >&2
    return 1
  fi

  echo "validate_spec_references: spec references OK for $(basename "$task_dir")"
  return 0
}

# ── main ─────────────────────────────────────────────────────────────────────
case "${1:-help}" in
  verify)
    shift
    _validate_references "$@"
    ;;
  *)
    if [ $# -ge 2 ] && [ "$1" != "help" ]; then
      _validate_references "$@"
    else
      echo "Usage: validate_spec_references.sh <wt_path> <task_dir>"
      exit 1
    fi
    ;;
esac
