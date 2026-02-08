#!/usr/bin/env bash
# install.sh - Install feature-marker skill, agent, and optional TUI
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Source directories (in the repository)
SKILL_SRC="${REPO_ROOT}/feature-marker"
AGENT_SRC="${REPO_ROOT}/agents/feature-marker.md"
TUI_SRC="${REPO_ROOT}/../feature-marker-tui"

# Destination directories (in user's ~/.claude)
SKILL_DST="${HOME}/.claude/skills/feature-marker"
AGENT_DST="${HOME}/.claude/agents/feature-marker.md"
TUI_INSTALL_DIR="${HOME}/.local/bin"

# Parse arguments
DRY_RUN=false
VERBOSE=false
INSTALL_TUI=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --verbose|-v)
      VERBOSE=true
      shift
      ;;
    --with-tui)
      INSTALL_TUI=true
      shift
      ;;
    --help|-h)
      echo "Usage: install.sh [OPTIONS]"
      echo ""
      echo "Options:"
      echo "  --dry-run    Show what would be installed without making changes"
      echo "  --verbose    Show detailed output"
      echo "  --with-tui   Also install the TUI application (requires Rust)"
      echo "  --help       Show this help message"
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

echo "╔═══════════════════════════════════════╗"
echo "║   Installing feature-marker v3.0.0   ║"
echo "╚═══════════════════════════════════════╝"
echo ""

echo "Source:"
echo "  Skill: ${SKILL_SRC}"
echo "  Agent: ${AGENT_SRC}"
echo ""
echo "Destination:"
echo "  Skill: ${SKILL_DST}"
echo "  Agent: ${AGENT_DST}"
echo ""

# Validate source files exist
if [[ ! -d "${SKILL_SRC}" ]]; then
  echo "ERROR: Skill source folder not found: ${SKILL_SRC}" >&2
  exit 1
fi

if [[ ! -f "${AGENT_SRC}" ]]; then
  echo "ERROR: Agent source file not found: ${AGENT_SRC}" >&2
  exit 1
fi

if [[ ! -f "${SKILL_SRC}/SKILL.md" ]]; then
  echo "ERROR: SKILL.md not found in: ${SKILL_SRC}" >&2
  exit 1
fi

echo "✓ Source files validated"

# Dry run mode
if [[ "${DRY_RUN}" == "true" ]]; then
  echo ""
  echo "Dry-run mode: No files were copied."
  echo ""
  echo "Would copy:"
  echo "  ${SKILL_SRC}/ -> ${SKILL_DST}/"
  echo "  ${AGENT_SRC} -> ${AGENT_DST}"
  exit 0
fi

# Create destination directories
echo ""
echo "Creating directories..."
mkdir -p "${SKILL_DST}"
mkdir -p "$(dirname "${AGENT_DST}")"

# Copy skill files
echo "Copying skill files..."
if command -v rsync &> /dev/null; then
  rsync -a --delete "${SKILL_SRC}/" "${SKILL_DST}/"
else
  rm -rf "${SKILL_DST}"
  cp -R "${SKILL_SRC}" "${SKILL_DST}"
fi

# Copy agent file
echo "Copying agent file..."
cp -f "${AGENT_SRC}" "${AGENT_DST}"

# Set permissions
echo "Setting permissions..."
chmod +x "${SKILL_DST}/feature-marker.sh" 2>/dev/null || true
chmod +x "${SKILL_DST}/install.sh" 2>/dev/null || true
chmod +x "${SKILL_DST}/lib/"*.sh 2>/dev/null || true

# Verify resources were copied
if [[ -f "${SKILL_DST}/resources/commit.md" ]]; then
  echo "  ✓ Commit command bundled in resources"
fi

echo ""
echo "╔═══════════════════════════════════════╗"
echo "║       Installation Complete!          ║"
echo "╚═══════════════════════════════════════╝"
echo ""
echo "Installed:"
echo "  ✓ Skill: ${SKILL_DST}"
echo "  ✓ Agent: ${AGENT_DST}"

# Install TUI if requested
if [[ "${INSTALL_TUI}" == "true" ]]; then
  echo ""
  echo "Installing TUI application..."

  if [[ ! -d "${TUI_SRC}" ]]; then
    echo "WARNING: TUI source not found at ${TUI_SRC}"
    echo "Skipping TUI installation."
  elif ! command -v cargo &> /dev/null; then
    echo "WARNING: Rust/Cargo not found. TUI requires Rust to build."
    echo "Install Rust: curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh"
    echo "Skipping TUI installation."
  else
    (
      cd "${TUI_SRC}"
      cargo build --release --quiet
      mkdir -p "${TUI_INSTALL_DIR}"
      cp target/release/feature-marker-tui "${TUI_INSTALL_DIR}/"
      chmod +x "${TUI_INSTALL_DIR}/feature-marker-tui"
    )
    echo "  ✓ TUI: ${TUI_INSTALL_DIR}/feature-marker-tui"
  fi
fi

echo ""
echo "Usage:"
echo "  In Claude Code, use: /feature-marker <feature-slug>"
if [[ "${INSTALL_TUI}" == "true" ]] && command -v cargo &> /dev/null; then
  echo "  Or launch TUI: feature-marker-tui"
fi
echo ""
echo "Example:"
echo "  /feature-marker prd-user-authentication"
echo ""
echo "Prerequisites:"
echo "  Make sure you have these commands in ~/.claude/commands/:"
echo "  - create-prd.md"
echo "  - generate-spec.md"
echo "  - generate-tasks.md"
echo ""
