#!/usr/bin/env bash
# Compatibility installer for the native-adapter CLI.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
RUNTIME="all"
EXTRA_ARGS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --runtime)
      RUNTIME="$2"
      shift 2
      ;;
    --dry-run)
      EXTRA_ARGS+=("--dry-run")
      shift
      ;;
    --help|-h)
      node "${REPO_ROOT}/bin/cli.js" --help
      echo "Usage: install.sh [--runtime claude|codex|gemini|all] [--dry-run]"
      exit 0
      ;;
    --with-tui|--verbose|-v)
      echo "$1 is no longer used by native-adapter v1; ignoring." >&2
      shift
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

exec node "${REPO_ROOT}/bin/cli.js" install --runtime "$RUNTIME" "${EXTRA_ARGS[@]}"
