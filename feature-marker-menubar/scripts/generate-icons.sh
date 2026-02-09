#!/bin/bash
# Generate icons for Feature-Marker Menu Bar app
# This script requires either ImageMagick (convert) or librsvg (rsvg-convert)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
ICONS_DIR="$PROJECT_DIR/src-tauri/icons"
SVG_FILE="$ICONS_DIR/icon.svg"

cd "$ICONS_DIR"

echo "Generating icons from SVG..."

# Function to convert SVG to PNG
convert_svg() {
    local size=$1
    local output=$2

    if command -v rsvg-convert &> /dev/null; then
        rsvg-convert -w "$size" -h "$size" "$SVG_FILE" -o "$output"
    elif command -v convert &> /dev/null; then
        convert -background none -resize "${size}x${size}" "$SVG_FILE" "$output"
    elif command -v sips &> /dev/null && command -v qlmanage &> /dev/null; then
        # macOS fallback using Quick Look and sips
        qlmanage -t -s "$size" -o . "$SVG_FILE" 2>/dev/null || true
        if [ -f "icon.svg.png" ]; then
            mv "icon.svg.png" "$output"
        fi
    else
        echo "Error: No image converter found. Install ImageMagick or librsvg."
        echo "  brew install imagemagick"
        echo "  or"
        echo "  brew install librsvg"
        exit 1
    fi
}

# Generate PNG icons
echo "  32x32.png"
convert_svg 32 "32x32.png"

echo "  128x128.png"
convert_svg 128 "128x128.png"

echo "  128x128@2x.png"
convert_svg 256 "128x128@2x.png"

echo "  icon.png (512x512)"
convert_svg 512 "icon.png"

# Generate macOS .icns
if command -v iconutil &> /dev/null; then
    echo "  icon.icns (macOS)"
    mkdir -p icon.iconset
    convert_svg 16 "icon.iconset/icon_16x16.png"
    convert_svg 32 "icon.iconset/icon_16x16@2x.png"
    convert_svg 32 "icon.iconset/icon_32x32.png"
    convert_svg 64 "icon.iconset/icon_32x32@2x.png"
    convert_svg 128 "icon.iconset/icon_128x128.png"
    convert_svg 256 "icon.iconset/icon_128x128@2x.png"
    convert_svg 256 "icon.iconset/icon_256x256.png"
    convert_svg 512 "icon.iconset/icon_256x256@2x.png"
    convert_svg 512 "icon.iconset/icon_512x512.png"
    convert_svg 1024 "icon.iconset/icon_512x512@2x.png"
    iconutil -c icns icon.iconset
    rm -rf icon.iconset
fi

# Generate Windows .ico (requires ImageMagick)
if command -v convert &> /dev/null; then
    echo "  icon.ico (Windows)"
    convert_svg 256 "icon-256.png"
    convert "icon-256.png" -define icon:auto-resize=256,128,64,48,32,16 "icon.ico"
    rm -f "icon-256.png"
fi

echo "Icons generated successfully!"
ls -la "$ICONS_DIR"
