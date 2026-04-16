#!/bin/bash
# homebrew/update-tap.sh
# Updates the viniciuscarvalho/homebrew-tap formula with the latest version.
#
# Usage: ./homebrew/update-tap.sh
#
# Prerequisites:
#   - The homebrew-tap repo must be cloned alongside this repo
#   - Or set TAP_DIR to point to your homebrew-tap clone

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Where is the homebrew-tap repo?
TAP_DIR="${TAP_DIR:-$REPO_DIR/../homebrew-tap}"

if [ ! -d "$TAP_DIR" ]; then
  echo "Homebrew tap not found at: $TAP_DIR"
  echo ""
  echo "Option 1: Clone it first:"
  echo "  git clone https://github.com/Viniciuscarvalho/homebrew-tap.git $TAP_DIR"
  echo ""
  echo "Option 2: Set TAP_DIR:"
  echo "  TAP_DIR=/path/to/homebrew-tap ./homebrew/update-tap.sh"
  echo ""
  echo "Option 3: Copy the formula manually:"
  echo "  cp homebrew/feature-marker.rb /path/to/homebrew-tap/Formula/"
  exit 1
fi

FORMULA_SRC="$REPO_DIR/homebrew/feature-marker.rb"
FORMULA_DST="$TAP_DIR/Formula/feature-marker.rb"

echo "Updating homebrew-tap formula..."
echo "  Source: $FORMULA_SRC"
echo "  Dest:   $FORMULA_DST"

mkdir -p "$(dirname "$FORMULA_DST")"
cp "$FORMULA_SRC" "$FORMULA_DST"

echo ""
echo "Formula copied. Now push to the tap:"
echo "  cd $TAP_DIR"
echo "  git add Formula/feature-marker.rb"
echo "  git commit -m 'Update feature-marker to v7.3.0 — orchestrator CLI'"
echo "  git push origin main"
echo ""
echo "Then users can:"
echo "  brew update && brew upgrade feature-marker"
