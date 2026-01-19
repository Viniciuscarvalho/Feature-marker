# Assets

This folder contains images and GIFs for the README.

## Required Assets

Create the following files to complete the README visuals:

### 1. `banner.png` (800x200 recommended)

A header banner for the project. Suggested design:
- Dark gradient background (purple/blue)
- "feature-marker" text with a rocket or automation icon
- Tagline: "Automate your feature development workflow"

**Tools:** Figma, Canva, or any design tool

### 2. `logo.png` (100x100 recommended)

A small logo for the footer. Options:
- Simple rocket icon
- "FM" monogram
- Workflow/automation symbol

### 3. `demo.gif` (700px width recommended)

A GIF showing the skill in action. To record:

```bash
# Option 1: Use asciinema + gif converter
asciinema rec demo.cast
# Then convert to GIF using https://github.com/asciinema/agg

# Option 2: Use a screen recorder
# - macOS: Built-in screen recording (Cmd+Shift+5)
# - Cross-platform: OBS Studio
# Then convert to GIF using:
ffmpeg -i demo.mp4 -vf "fps=10,scale=700:-1:flags=lanczos" -c:v gif demo.gif
```

**What to show in the demo:**
1. Invoking `/feature-marker prd-example`
2. The inputs gate validating files
3. Phase progression (1-4)
4. Final PR creation message

### 4. Optional Screenshots

- `inputs-gate.png` - Showing file validation
- `implementation.png` - Task tracking in progress
- `commit-pr.png` - Platform detection and PR creation

## Quick Placeholder

If you want to test the README without real images, you can use placeholder services:

```markdown
![Banner](https://via.placeholder.com/800x200/6B46C1/FFFFFF?text=feature-marker)
![Logo](https://via.placeholder.com/100x100/6B46C1/FFFFFF?text=FM)
```

## Color Palette Suggestion

| Color | Hex | Usage |
|-------|-----|-------|
| Primary | `#6B46C1` | Purple (Claude/AI theme) |
| Secondary | `#3B82F6` | Blue (actions) |
| Success | `#10B981` | Green (completed) |
| Background | `#1F2937` | Dark gray |
| Text | `#FFFFFF` | White |
