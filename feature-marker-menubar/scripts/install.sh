#!/bin/bash
# Install Feature-Marker Menu Bar app

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "========================================"
echo "  Feature-Marker Menu Bar Installer"
echo "  v0.1.0"
echo "========================================"
echo

# Check for required tools
check_requirements() {
    echo "Checking requirements..."

    if ! command -v cargo &> /dev/null; then
        echo "Error: Rust/Cargo not found"
        echo "Install from: https://rustup.rs"
        exit 1
    fi

    if ! command -v npm &> /dev/null; then
        echo "Error: Node.js/npm not found"
        echo "Install from: https://nodejs.org"
        exit 1
    fi

    if ! command -v cargo-tauri &> /dev/null; then
        echo "Installing Tauri CLI..."
        cargo install tauri-cli
    fi

    echo "All requirements met."
}

# Build the app
build_app() {
    echo
    echo "Building Feature-Marker Menu Bar app..."

    cd "$PROJECT_DIR"

    # Install frontend dependencies
    echo "Installing frontend dependencies..."
    cd ui && npm install && cd ..

    # Build the Tauri app
    echo "Building Tauri app..."
    cargo tauri build
}

# Install the app
install_app() {
    echo
    echo "Installing app..."

    APP_SOURCE="$PROJECT_DIR/src-tauri/target/release/bundle/macos/Feature-Marker.app"
    APP_DEST="/Applications/Feature-Marker.app"

    if [ -d "$APP_DEST" ]; then
        echo "Removing existing installation..."
        rm -rf "$APP_DEST"
    fi

    echo "Copying to /Applications..."
    cp -R "$APP_SOURCE" "$APP_DEST"

    echo
    echo "========================================"
    echo "  Installation Complete!"
    echo "========================================"
    echo
    echo "Feature-Marker.app has been installed to /Applications"
    echo
    echo "To launch, run:"
    echo "  open /Applications/Feature-Marker.app"
    echo
}

# Main
check_requirements
build_app
install_app
