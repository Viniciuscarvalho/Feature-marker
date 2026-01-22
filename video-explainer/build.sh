#!/usr/bin/env bash
# build.sh - Helper script to build feature-marker explainer video

set -euo pipefail

echo "🎬 Feature-Marker Video Builder"
echo "================================"
echo ""

# Check if ffmpeg is installed (needed for GIF)
if ! command -v ffmpeg &> /dev/null; then
    echo "⚠️  Warning: ffmpeg not found. GIF generation will be skipped."
    echo "   Install: brew install ffmpeg (macOS) or apt-get install ffmpeg (Linux)"
    echo ""
    FFMPEG_AVAILABLE=false
else
    FFMPEG_AVAILABLE=true
fi

# Check if node_modules exists
if [ ! -d "node_modules" ]; then
    echo "📦 Installing dependencies..."
    npm install
    echo ""
fi

# Create out directory
mkdir -p out

# Build options
echo "Select build option:"
echo "  1) MP4 only (Full HD)"
echo "  2) MP4 + GIF (optimized for README)"
echo "  3) Both + WebM"
echo ""
read -p "Choice [1-3]: " choice

case $choice in
    1)
        echo ""
        echo "📹 Rendering MP4 (Full HD)..."
        npm run build -- FeatureMarkerExplainer --codec h264
        echo "✅ Done! Output: out/FeatureMarkerExplainer.mp4"
        ;;
    2)
        echo ""
        echo "📹 Rendering MP4..."
        npm run build -- FeatureMarkerExplainer --scale 0.5 --codec h264

        if [ "$FFMPEG_AVAILABLE" = true ]; then
            echo ""
            echo "🎨 Converting to GIF..."
            ffmpeg -i out/FeatureMarkerExplainer.mp4 \
                -vf "fps=15,scale=960:-1:flags=lanczos,split[s0][s1];[s0]palettegen[p];[s1][p]paletteuse" \
                -loop 0 out/feature-marker-demo.gif -y
            echo "✅ Done!"
            echo "   MP4: out/FeatureMarkerExplainer.mp4"
            echo "   GIF: out/feature-marker-demo.gif"
        else
            echo "❌ Skipping GIF (ffmpeg not available)"
            echo "✅ MP4 Done: out/FeatureMarkerExplainer.mp4"
        fi
        ;;
    3)
        echo ""
        echo "📹 Rendering MP4 (Full HD)..."
        npm run build -- FeatureMarkerExplainer --codec h264

        echo ""
        echo "📹 Rendering WebM..."
        npm run build -- FeatureMarkerExplainer --codec vp8

        if [ "$FFMPEG_AVAILABLE" = true ]; then
            echo ""
            echo "🎨 Converting to GIF..."
            ffmpeg -i out/FeatureMarkerExplainer.mp4 \
                -vf "fps=15,scale=960:-1:flags=lanczos,split[s0][s1];[s0]palettegen[p];[s1][p]paletteuse" \
                -loop 0 out/feature-marker-demo.gif -y
            echo "✅ All done!"
            echo "   MP4:  out/FeatureMarkerExplainer.mp4"
            echo "   WebM: out/FeatureMarkerExplainer.webm"
            echo "   GIF:  out/feature-marker-demo.gif"
        else
            echo "❌ Skipping GIF (ffmpeg not available)"
            echo "✅ Done!"
            echo "   MP4:  out/FeatureMarkerExplainer.mp4"
            echo "   WebM: out/FeatureMarkerExplainer.webm"
        fi
        ;;
    *)
        echo "Invalid choice"
        exit 1
        ;;
esac

echo ""
echo "🎉 Build complete!"
echo ""
echo "📂 Output directory: ./out/"
echo ""
echo "To preview: npm start"
