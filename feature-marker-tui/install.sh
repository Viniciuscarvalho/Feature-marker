#!/usr/bin/env bash
# install.sh - Install feature-marker-tui binary
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Destination for binary
INSTALL_DIR="${HOME}/.local/bin"
BINARY_NAME="feature-marker-tui"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Parse arguments
BUILD_RELEASE=true
INSTALL_ONLY=false
VERBOSE=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --debug)
      BUILD_RELEASE=false
      shift
      ;;
    --install-only)
      INSTALL_ONLY=true
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
      echo "  --debug        Build in debug mode (faster compile, larger binary)"
      echo "  --install-only Skip build, install existing binary"
      echo "  --verbose      Show detailed output"
      echo "  --help         Show this help message"
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

echo -e "${BLUE}╔═══════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   Installing feature-marker-tui v3.0.0    ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════╝${NC}"
echo ""

# Check for Rust
check_rust() {
  # Try to source cargo env if not in PATH
  if ! command -v cargo &> /dev/null; then
    if [[ -f "${HOME}/.cargo/env" ]]; then
      source "${HOME}/.cargo/env"
    fi
  fi

  if ! command -v cargo &> /dev/null; then
    echo -e "${RED}ERROR: Rust/Cargo not found.${NC}"
    echo ""
    echo "Please install Rust first:"
    echo "  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh"
    echo "  source ~/.cargo/env"
    echo ""
    exit 1
  fi
  echo -e "${GREEN}✓${NC} Rust/Cargo found: $(cargo --version)"
}

# Build the binary
build_binary() {
  echo ""
  echo -e "${YELLOW}Building feature-marker-tui...${NC}"

  cd "${SCRIPT_DIR}"

  if [[ "${BUILD_RELEASE}" == "true" ]]; then
    if [[ "${VERBOSE}" == "true" ]]; then
      cargo build --release
    else
      cargo build --release --quiet
    fi
    BINARY_PATH="${SCRIPT_DIR}/target/release/${BINARY_NAME}"
  else
    if [[ "${VERBOSE}" == "true" ]]; then
      cargo build
    else
      cargo build --quiet
    fi
    BINARY_PATH="${SCRIPT_DIR}/target/debug/${BINARY_NAME}"
  fi

  if [[ ! -f "${BINARY_PATH}" ]]; then
    echo -e "${RED}ERROR: Build failed. Binary not found at ${BINARY_PATH}${NC}"
    exit 1
  fi

  BINARY_SIZE=$(du -h "${BINARY_PATH}" | cut -f1)
  echo -e "${GREEN}✓${NC} Build complete (${BINARY_SIZE})"
}

# Install the binary
install_binary() {
  echo ""
  echo -e "${YELLOW}Installing to ${INSTALL_DIR}...${NC}"

  # Create install directory if needed
  mkdir -p "${INSTALL_DIR}"

  # Determine binary path
  if [[ "${INSTALL_ONLY}" == "true" ]]; then
    if [[ -f "${SCRIPT_DIR}/target/release/${BINARY_NAME}" ]]; then
      BINARY_PATH="${SCRIPT_DIR}/target/release/${BINARY_NAME}"
    elif [[ -f "${SCRIPT_DIR}/target/debug/${BINARY_NAME}" ]]; then
      BINARY_PATH="${SCRIPT_DIR}/target/debug/${BINARY_NAME}"
    else
      echo -e "${RED}ERROR: No binary found. Run without --install-only first.${NC}"
      exit 1
    fi
  fi

  # Copy binary
  cp "${BINARY_PATH}" "${INSTALL_DIR}/${BINARY_NAME}"
  chmod +x "${INSTALL_DIR}/${BINARY_NAME}"

  echo -e "${GREEN}✓${NC} Installed to ${INSTALL_DIR}/${BINARY_NAME}"
}

# Check PATH
check_path() {
  if [[ ":$PATH:" != *":${INSTALL_DIR}:"* ]]; then
    echo ""
    echo -e "${YELLOW}Note:${NC} ${INSTALL_DIR} is not in your PATH."
    echo ""
    echo "Add this to your shell profile (~/.zshrc or ~/.bashrc):"
    echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
    echo ""
  fi
}

# Run installation
if [[ "${INSTALL_ONLY}" == "false" ]]; then
  check_rust
  build_binary
fi
install_binary
check_path

echo ""
echo -e "${GREEN}╔═══════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║        Installation Complete!             ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════╝${NC}"
echo ""
echo "Usage:"
echo "  ${BINARY_NAME}"
echo ""
echo "Or run directly from source:"
echo "  cd ${SCRIPT_DIR} && cargo run --release"
echo ""
