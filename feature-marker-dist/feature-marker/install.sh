#!/usr/bin/env bash
# install.sh - Install feature-marker skill and agent
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Source directories (in the repository)
SKILL_SRC="${REPO_ROOT}/feature-marker"
AGENT_SRC="${REPO_ROOT}/agents/feature-marker.md"

# Destination directories (in user's ~/.claude)
SKILL_DST="${HOME}/.claude/skills/feature-marker"
AGENT_DST="${HOME}/.claude/agents/feature-marker.md"

# Parse arguments
DRY_RUN=false
VERBOSE=false

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
    --help|-h)
      echo "Usage: install.sh [OPTIONS]"
      echo ""
      echo "Options:"
      echo "  --dry-run    Show what would be installed without making changes"
      echo "  --verbose    Show detailed output"
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
echo "║   Installing feature-marker v1.2.0   ║"
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

echo ""
echo "╔═══════════════════════════════════════╗"
echo "║       Installation Complete!          ║"
echo "╚═══════════════════════════════════════╝"
echo ""
echo "Installed:"
echo "  ✓ Skill: ${SKILL_DST}"
echo "  ✓ Agent: ${AGENT_DST}"
echo ""
echo "Usage:"
echo "  In Claude Code, use: /feature-marker <feature-slug>"
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
