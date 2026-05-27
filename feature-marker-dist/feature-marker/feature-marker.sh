#!/usr/bin/env bash
# Compatibility wrapper. The Node CLI owns native-adapter workflows.
set -euo pipefail

MODE="full"
RUNTIME="claude"
STATUS=false
FEATURE_NAME=""
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

run_feature_marker() {
  if [[ -f "${REPO_ROOT}/bin/cli.js" ]]; then
    node "${REPO_ROOT}/bin/cli.js" "$@"
  else
    feature-marker "$@"
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --help|-h)
      run_feature_marker --help
      exit 0
      ;;
    --version|-V)
      run_feature_marker --version
      exit 0
      ;;
    --status|-s)
      STATUS=true
      shift
      ;;
    --mode|-m)
      MODE="$2"
      shift 2
      ;;
    --runtime)
      RUNTIME="$2"
      shift 2
      ;;
    --menu|-i)
      echo "Interactive menu is not part of native-adapter v1. Use --mode explicitly." >&2
      exit 1
      ;;
    -*)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
    *)
      FEATURE_NAME="$1"
      shift
      ;;
  esac
done

if [[ -z "$FEATURE_NAME" ]]; then
  echo "Feature name required" >&2
  exit 1
fi

if [[ "$STATUS" == "true" ]]; then
  run_feature_marker status "$FEATURE_NAME"
  exit $?
fi

run_feature_marker run "$FEATURE_NAME" --mode "$MODE" --runtime "$RUNTIME"
