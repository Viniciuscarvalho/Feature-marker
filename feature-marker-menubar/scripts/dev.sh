#!/bin/bash
# Run Feature-Marker Menu Bar in development mode

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "Starting Feature-Marker Menu Bar in development mode..."

cd "$PROJECT_DIR"

# Source cargo env if needed
if [ -f "$HOME/.cargo/env" ]; then
    source "$HOME/.cargo/env"
fi

# Install dependencies if needed
if [ ! -d "ui/node_modules" ]; then
    echo "Installing frontend dependencies..."
    cd ui && npm install && cd ..
fi

# Run in dev mode
cargo tauri dev
