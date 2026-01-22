# Feature-Marker Explainer Video

Professional explainer video created with Remotion for the feature-marker CLI tool.

## 📺 Video Specifications

- **Duration**: 40 seconds (1200 frames at 30fps) - 1.5x faster for engaging viewing
- **Resolution**: 1920x1080 (Full HD)
- **Format**: MP4 and optimized GIF
- **GIF Optimization**: 720px width, 15fps, 128-color palette with Bayer dithering

## 🎬 Scenes

### Scene 1: Intro (0-6.6s)
- Feature-marker logo with gradient animation
- Main tagline and subtitle
- Smooth fade-in and spring animations

### Scene 2: Basic Command (6.6-13.3s)
- Terminal mockup with typing effect
- Command demonstration
- 4-phase workflow diagram

### Scene 3: Interactive Panel (13.3-26.6s)
- Interactive menu showcase
- 3 execution modes explained
- Sequential highlighting and descriptions

### Scene 4: Workflow Execution (26.6-33.3s)
- Progress indicators for each phase
- Animated progress bars
- Completion checkmarks

### Scene 5: Outro (33.3-40s)
- GitHub repository URL
- Call-to-action with pulse effect
- Installation command

## 🚀 Getting Started

### Install Dependencies

```bash
npm install
# or
bun install
# or
pnpm install
# or
yarn install
```

### Preview Video

```bash
npm start
# or
bun start
```

This opens the Remotion Studio at `http://localhost:3000`

### Render Video (MP4)

```bash
npm run build -- FeatureMarkerExplainer --codec h264
# or with bun
bun run build FeatureMarkerExplainer --codec h264
```

Output: `out/FeatureMarkerExplainer.mp4`

### Render GIF (optimized for web)

```bash
# First, render at smaller resolution for GIF
npm run build -- FeatureMarkerExplainer --scale 0.5 --codec h264

# Then convert to optimized GIF using ffmpeg
ffmpeg -i out/FeatureMarkerExplainer.mp4 \
  -vf "fps=15,scale=720:-1:flags=lanczos,split[s0][s1];[s0]palettegen=max_colors=128[p];[s1][p]paletteuse=dither=bayer:bayer_scale=5" \
  -loop 0 out/feature-marker-demo.gif
```

### Render Multiple Formats

```bash
# HD MP4
npm run build -- FeatureMarkerExplainer --codec h264

# Optimized for web (lower quality, smaller size)
npm run build -- FeatureMarkerExplainer --codec h264 --crf 28

# WebM
npm run build -- FeatureMarkerExplainer --codec vp8
```

## 🎨 Customization

### Colors

The video uses the feature-marker brand colors:
- **Purple**: `#9333ea` (primary)
- **Blue**: `#3b82f6` (accent)
- **Dark**: `#0a0a0a` (background)
- **Terminal**: `#1e1e1e` (surface)

### Timing

All timings are defined in frames (30fps):
- Intro: frames 0-200 (6.6s)
- Basic Command: frames 200-400 (6.6s)
- Interactive Panel: frames 400-800 (13.3s)
- Workflow: frames 800-1000 (6.6s)
- Outro: frames 1000-1200 (6.6s)
- **Total**: 1200 frames (40 seconds at 30fps)

To adjust, edit the `<Sequence>` components in `src/compositions/MainVideo.tsx`

### Fonts

The video uses:
- **Monospace** for code/terminal (system default)
- **Sans-serif** for UI text (system default)

To add custom fonts, see: [Remotion Fonts Guide](https://www.remotion.dev/docs/fonts)

## 📦 Output Files

After rendering, you'll find files in the `out/` directory:

- `FeatureMarkerExplainer.mp4` - Full quality video
- `feature-marker-demo.gif` - Optimized GIF for README

## 🔧 Troubleshooting

### Video won't render
Ensure you have Node.js 18+ and all dependencies installed:
```bash
npm install
```

### GIF is too large
Reduce the scale factor in the ffmpeg command:
```bash
# Even smaller GIF (lower quality but < 1MB)
ffmpeg -i out/FeatureMarkerExplainer.mp4 \
  -vf "fps=10,scale=640:-1:flags=lanczos,split[s0][s1];[s0]palettegen=max_colors=64[p];[s1][p]paletteuse=dither=bayer:bayer_scale=3" \
  -loop 0 out/feature-marker-demo-tiny.gif
```

### Preview is slow
Reduce the resolution in Remotion Studio settings or use Chrome/Edge (faster than Firefox for Remotion)

## 📚 Learn More

- [Remotion Documentation](https://www.remotion.dev/)
- [Remotion API Reference](https://www.remotion.dev/docs/api)
- [Animation Examples](https://www.remotion.dev/docs/animating-properties)

## 📄 License

Same as feature-marker: MIT
