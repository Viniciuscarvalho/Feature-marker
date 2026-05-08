#!/usr/bin/env bash
# Usage: lint-artifacts.sh <dir>
# Exit 0 = clean (no Claude-isms), Exit 1 = leaks found
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: lint-artifacts.sh <artifacts-dir>" >&2
  exit 1
fi

dir="$1"

if [[ ! -d "$dir" ]]; then
  echo "ERROR: directory not found: $dir" >&2
  exit 1
fi

# Patterns that should never appear in portable artifacts
patterns='/spec-orchestrator|/spec-executor|/idea-explorer|/spec-writer|/swift-testing|/create-prd|/generate-spec|/generate-tasks|/commit|/feature-marker|<command-name>|Use the [A-Z][a-zA-Z-]* (agent|skill)'

hits=$(grep -REn "$patterns" "$dir" 2>/dev/null || true)

if [[ -n "$hits" ]]; then
  echo "LEAKS FOUND in $dir:"
  echo "$hits"
  exit 1
fi

echo "clean: $dir"
exit 0
