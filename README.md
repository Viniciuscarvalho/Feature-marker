
<!-- Banner -->
<p align="center">
  <img src="assets/banner.svg" alt="feature-marker Banner" width="800">
</p>

<p align="center">
  <strong>Automate your feature development workflow with AI-powered checkpoints</strong>
</p>

<p align="center">
  <a href="#-quick-start">Quick Start</a> •
  <a href="#-features">Features</a> •
  <a href="#-installation">Installation</a> •
  <a href="#-usage">Usage</a> •
  <a href="#-demo">Demo</a>
</p>

<p align="center">
  <a href="https://github.com/Viniciuscarvalho/Feature-marker/blob/main/LICENSE">
    <img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="License: MIT">
  </a>
  <a href="https://github.com/Viniciuscarvalho/Feature-marker">
    <img src="https://img.shields.io/badge/platform-Claude%20Code-purple.svg" alt="Platform: Claude Code">
  </a>
  <a href="https://github.com/Viniciuscarvalho/Feature-marker">
    <img src="https://img.shields.io/badge/PRs-welcome-brightgreen.svg" alt="PRs Welcome">
  </a>
  <a href="https://github.com/Viniciuscarvalho/Feature-marker/stargazers">
    <img src="https://img.shields.io/github/stars/Viniciuscarvalho/Feature-marker?style=social" alt="GitHub Stars">
  </a>
</p>

---

**feature-marker** is a Claude Code skill + agent that automates feature development workflows with checkpoints, pause/resume capabilities, artifact generation (PRD/Tech Spec/Tasks), and a final step that creates a commit + PR with automatic platform detection.

Designed to be **platform-agnostic** and compose with existing skills like `creating-pr` and `azure-pr`.

---

## 🎬 Demo

### 📹 Video Explainer (40s)

<p align="center">
  <img src="assets/feature-marker-demo.gif" alt="feature-marker Demo" width="700">
</p>

> **Note**: Full HD video available in `video-explainer/` directory. See [Video Generation Guide](#-video-generation) to create custom explainer videos.

<details>
<summary>📸 <strong>See more screenshots</strong></summary>

### Inputs Gate - Validating & Generating Artifacts
<img src="assets/inputs-gate.png" alt="Inputs Gate" width="600">

### Implementation Phase - Task Tracking
<img src="assets/implementation.png" alt="Implementation" width="600">

### Commit & PR - Platform Detection
<img src="assets/commit-pr.png" alt="Commit & PR" width="600">

</details>

---

## 🆕 What's New

| Version | Date | Highlights |
|---------|------|------------|
| **v2.0.0** | 2026-02-05 | 🔬 **Spec-Driven Mode** - Multi-agent review + worktree isolation (Spec Kit Pattern) |
| **v1.6.0** | 2026-02-01 | 📦 Smart Dependency Management |
| **v1.5.0** | 2026-01-30 | 🎯 XcodeBuildMCP integration - iOS simulator validation in Phase 3 |
| **v1.4.0** | 2026-01-30 | 📚 Documentation improvements - Templates location clarified |
| **v1.3.0** | 2026-01-28 | 🤖 AskUserQuestion support in Claude CLI for interactive mode |
| **v1.2.0** | 2026-01-26 | 🔧 Interactive menu TTY fix, template paths corrected |
| **v1.1.0** | 2026-01-19 | 🎯 Interactive execution panel, Ralph Loop mode |
| **v1.0.0** | 2026-01-18 | 🚀 Initial release with 4-phase workflow |

<details>
<summary>📋 <strong>Version Details</strong></summary>

### v2.0.0 - Spec-Driven Mode 🔬

Major release introducing the **Spec Kit Pattern** - a rigorous approach to feature development with multi-agent review.

**New Features:**
- **Spec-Driven Mode (Option 4)**: New execution mode with multi-agent spec review
- **Bundled spec-workflow skills**: All skills included - no external installation needed
- **Multi-agent review**: 6 built-in reviewer personas (Pragmatic Architect, Paranoid Engineer, Operator, Simplifier, User Advocate, Product Strategist)
- **Isolated worktree**: Safe development in separate git branches
- **Automatic conversion**: Spec artifacts converted to Feature-Marker format (prd.md, techspec.md, tasks.md)
- **Spec-to-FM bridge**: New bridge script for artifact conversion

**Bundled Skills:**
| Skill | Purpose |
|-------|---------|
| `/idea-explorer` | Collaborative idea refinement with YAGNI |
| `/spec-writer` | Transform ideas into detailed specs |
| `/spec-orchestrator` | Write specs with multi-agent review |
| `/spec-executor` | Implement specs with checkpoints |
| `/create-worktree` | Setup isolated git worktree |
| `/spec-workflow-init` | Scaffold configuration structure |

**Breaking Changes:** None - all existing modes continue to work.

### v1.6.0 - Smart Dependency Management 📦
- Automatic dependency detection and installation
- Bundled commit command for enhanced commit workflow
- Improved error handling for missing dependencies

### v1.5.0 - iOS Simulator Integration 🎯
- **XcodeBuildMCP Integration**: Phase 3 now validates iOS apps on simulator after tests pass
- **Automatic Detection**: Checks for `~/.claude/skills/xcodebuildmcp/SKILL.md`
- **Auto-Configuration**: Automatically runs `discover_projs` and `session_set_defaults`
- **build_run_sim**: Builds and runs iOS app on simulator for real validation
- **Non-Blocking**: Build failures log warnings but workflow continues
- **Enhanced Reports**: test-results.md includes simulator build/run section
- **iOS Only**: Integration only activates for Swift/Xcode projects

### v1.4.0 - Documentation Improvements 📚
- **Templates Location Clarified**: Now clearly documented that templates live in `~/.claude/docs/specs/`
- **File Generation Flow**: Added visual diagrams showing Templates → Commands → Generated Files flow
- **Architecture Overview**: New diagram showing complete file flow between `~/.claude` and project directories
- **Template Setup Guide**: Complete guide explaining why templates are in `~/.claude/docs/specs/` and how to verify setup
- **README.md**: Comprehensive project documentation with examples, troubleshooting, and architecture
- **CHANGELOG.md**: Following Keep a Changelog format for version tracking
- **Error Handling**: Added documentation for missing templates scenario

### v1.3.0 - Claude CLI Integration 🤖
- **AskUserQuestion support**: Interactive mode now works seamlessly inside Claude CLI
- **Direct mode selection**: New `--mode` flag to skip menu (`--mode full|tasks-only|ralph-loop`)
- **Cross-environment UX**: Works both in terminal (TTY menu) and Claude CLI (AskUserQuestion)

### v1.2.0 - Bug Fixes
- **Interactive menu TTY detection**: Menu now detects non-terminal environments and provides guidance
- **Template paths corrected**: Commands now use global templates from `~/.claude/docs/`

### v1.1.0 - Interactive Execution Panel 🎯
- **Interactive CLI Panel**: Choose execution mode via beautiful interactive menu
- **Multiple Execution Modes**: Full Workflow, Tasks Only, Ralph Loop
- **Ralph Loop Integration**: Autonomous self-correcting execution

### v1.0.0 - Initial Release
- **No templates required**: All files generated automatically via commands
- **Streamlined paths**: Tasks in `./tasks/` instead of `./docs/tasks/`
- **Smart detection**: Auto-detects existing files, never overwrites

</details>

### How It Works
When you run `/feature-marker prd-{feature-name}`, the workflow:

1. **Checks for existing files** in `./tasks/prd-{feature-name}/`
   - ✅ If `prd.md`, `techspec.md`, and `tasks.md` exist → Proceeds directly to implementation
   - ⚠️ If any file is missing → Generates only the missing files via commands

2. **No duplicates**: Existing files are never overwritten or duplicated
3. **Resume friendly**: You can stop and resume at any time with checkpoint support

---

## ✨ Features

| Feature | Description |
|---------|-------------|
| 🔍 **Validates inputs** | Checks if `prd.md`, `techspec.md`, `tasks.md` exist |
| 🛠️ **Auto-generates** | Creates missing artifacts via `~/.claude/commands/` |
| 📋 **Phased workflow** | Analysis → Implementation → Tests → Commit & PR |
| 💾 **Checkpoint/resume** | Persists state for uninterrupted work |
| 🔀 **Platform detection** | Selects right PR skill (GitHub, Azure DevOps, etc.) |
| ⏸️ **Pause/Resume** | Continue where you left off after interruptions |
| 📊 **Progress tracking** | TodoWrite integration for task management |

---

## 🚀 Quick Start

```bash
# Install
./feature-marker/install.sh

# Then in Claude Code:
/feature-marker prd-user-authentication

# Or use interactive mode (v1.1.0+):
/feature-marker --interactive prd-user-authentication
```

That's it! The skill will guide you through the entire feature development process.

---

## 📦 Installation

### Via install script (recommended)

```bash
# Clone the repository
git clone https://github.com/Viniciuscarvalho/Feature-marker.git
cd Feature-marker

# Run install script
./feature-marker/install.sh

# Verify installation
ls ~/.claude/skills/feature-marker/
ls ~/.claude/agents/feature-marker.md
```

### Manual installation

```bash
# 1. Copy the skill folder
cp -R feature-marker/ ~/.claude/skills/feature-marker/

# 2. Copy the agent
cp agents/feature-marker.md ~/.claude/agents/feature-marker.md

# 3. Set permissions
chmod +x ~/.claude/skills/feature-marker/*.sh
chmod +x ~/.claude/skills/feature-marker/lib/*.sh
```

---

## 📖 Usage

### Basic Usage

In Claude Code, simply invoke:

```
/feature-marker <feature-slug>
```

**Examples:**
```bash
# Start a new feature
/feature-marker prd-user-authentication

# Resume an interrupted workflow
/feature-marker prd-user-authentication  # Will detect checkpoint and offer resume

# Work on multiple features
/feature-marker prd-payment-integration
/feature-marker prd-notification-system
```

### 🎯 Interactive Mode (v1.1.0+)

Launch the interactive panel to choose your execution mode:

```bash
/feature-marker --interactive prd-user-authentication
```

The panel offers **four execution modes**:

#### 1️⃣  Full Workflow Mode (default)
- **Best for**: New features or features with missing files
- **What it does**:
  - Validates existing files
  - Generates missing PRD/TechSpec/Tasks
  - Executes all 4 phases

#### 2️⃣  Tasks Only Mode
- **Best for**: When you already have PRD/TechSpec/Tasks ready
- **What it does**:
  - Skips file generation entirely
  - Goes directly to implementation
  - Requires all files to exist

#### 3️⃣  Ralph Loop Mode
- **Best for**: Autonomous execution with self-correction
- **What it does**:
  - Uses [ralph-wiggum](https://github.com/frankbria/ralph-claude-code) for continuous iteration
  - Self-corrects errors automatically
  - Runs until completion or manual stop
- **Requires**: ralph-wiggum skill installed

#### 4️⃣  Spec-Driven Mode (v2.0.0+) 🔬
- **Best for**: Rigorous feature development with multi-agent review
- **What it does**:
  - Multi-agent spec review (6 reviewer personas)
  - Creates isolated worktree for safe development
  - Converts spec to PRD/TechSpec/Tasks format
  - Executes implementation with checkpoints
- **Skills bundled**: All spec-workflow skills included

**Interactive Panel Preview:**
```
┌──────────────────────────────────────────────────────┐
│         🚀 Feature Marker - Execution Mode           │
└──────────────────────────────────────────────────────┘

  Feature: prd-user-authentication

  Select execution mode:

  1) Full Workflow - Generate PRD/TechSpec/Tasks + Implementation
     → Creates missing files and executes all phases

  2) Execute Tasks Only - Skip generation, run implementation
     → Use existing PRD/TechSpec/Tasks (must exist)

  3) Ralph Loop Mode - Autonomous loop execution
     → Uses ralph-wiggum for continuous iteration

  4) Spec-Driven Mode - Multi-agent review + worktree isolation
     → Uses spec-workflow for rigorous spec review

  0) Exit

Select option [0-4]:
```

---

## 🔬 Spec-Driven Mode (v2.0.0+)

The **Spec-Driven Mode** introduces a rigorous approach to feature development using the **Spec Kit Pattern**.

### What is Spec-Driven Mode?

This mode combines **multi-agent review** with **isolated worktrees** for safer, more rigorous feature development:

```
┌─────────────────────────────────────────────────────────┐
│ Phase 0: Spec Generation with Multi-Agent Review        │
│                                                         │
│ 1. Idea exploration (if no PRD exists)                  │
│    └─ /idea-explorer for collaborative refinement       │
│                                                         │
│ 2. Spec generation with review cycle                    │
│    └─ /spec-orchestrator invokes 2-6 reviewer personas  │
│    └─ Iterative feedback → revision cycle               │
│    └─ Auto-approval at 80% consensus                    │
│                                                         │
│ 3. Worktree creation                                    │
│    └─ /create-worktree for isolated development         │
│                                                         │
│ 4. Spec conversion to Feature-Marker format             │
│    └─ Generates prd.md, techspec.md, tasks.md           │
└─────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────┐
│ Phase 1-2: Implementation via /spec-executor            │
│ Phase 3-4: Standard FM Tests & Commit/PR                │
└─────────────────────────────────────────────────────────┘
```

### Built-in Reviewer Personas

The spec-orchestrator uses 6 built-in personas to review your specifications:

| Persona | Focus |
|---------|-------|
| **Pragmatic Architect** | Overall design and maintainability |
| **Paranoid Engineer** | Edge cases and failure modes |
| **Operator** | Operational concerns and monitoring |
| **Simplifier** | Challenges unnecessary complexity |
| **User Advocate** | User experience considerations |
| **Product Strategist** | Alignment with product goals |

### Usage

```bash
# Via interactive menu
/feature-marker --interactive my-feature
# Select option 4) Spec-Driven Mode

# Via direct mode flag
/feature-marker --mode spec-driven my-feature
```

### Configuration (Optional)

Create `.claude/spec-workflow/config.yaml` in your project:

```yaml
paths:
  specs: "./specs"
  worktrees: "./worktrees"

review:
  maxIterations: 3
  autoApproveThreshold: 0.8

execution:
  batchSize: 5
  checkpoint:
    behavior: "smart"  # pause, continue, or smart
```

See `~/.claude/skills/feature-marker/resources/spec-workflow/ABSTRACTION_PLAN.md` for full configuration options.

---

## 🔧 Prerequisites

### Required Commands (for Full Workflow mode)

The following commands must exist in `~/.claude/commands/`:

| Command | Description |
|---------|-------------|
| `create-prd.md` | Creates PRD from requirements discussion |
| `generate-spec.md` | Generates tech spec from PRD |
| `generate-tasks.md` | Breaks down feature into implementable tasks |

> 💡 **Tip:** You can get these commands from [mindkit](https://github.com/Viniciuscarvalho/mindkit) or create your own.

### Required Templates (v1.4.0+)

The following templates must exist in `~/.claude/docs/specs/`:

| Template | Description |
|----------|-------------|
| `prd-template.md` | Product Requirements Document template |
| `techspec-template.md` | Technical Specification template |
| `tasks-template.md` | Tasks breakdown template |

**Template Format**: Templates should be markdown files with placeholders and structure that commands will use to generate feature-specific documents.

**Setup verification:**
```bash
# Check templates exist
ls ~/.claude/docs/specs/

# Check commands exist
ls ~/.claude/commands/

# Test feature-marker
/feature-marker --version
```

### Optional: Ralph Loop Mode

To use **Ralph Loop Mode** (option 3 in interactive panel):

```bash
# Install ralph-wiggum skill
git clone https://github.com/frankbria/ralph-claude-code.git
cd ralph-claude-code
./install.sh
```

**What is Ralph Loop Mode?**
Based on [Ralph Wiggum pattern](https://ghuntley.com/ralph/), this mode enables autonomous, self-correcting execution where the agent continuously iterates until the feature is complete or an error requires human intervention.

### Project Structure

Your setup should follow this structure:

```
User's ~/.claude directory              Project directory
━━━━━━━━━━━━━━━━━━━━━━━━━              ━━━━━━━━━━━━━━━━
~/.claude/
├── commands/                           ./tasks/
│   ├── create-prd.md        ─────┐    └── prd-{feature-name}/
│   ├── generate-spec.md     ────┼┐       ├── prd.md
│   └── generate-tasks.md    ───┼┼┐       ├── techspec.md
│                                │││       └── tasks.md
├── docs/                        │││
│   └── specs/                   │││    .claude/feature-state/
│       ├── prd-template.md   <──┘││    └── {feature-name}/
│       ├── techspec-template.md <─┘│        ├── checkpoint.json
│       └── tasks-template.md    <──┘        ├── analysis.md
│                                            ├── plan.md
├── skills/                                 ├── progress.md
│   └── feature-marker/                     ├── test-results.md
│                                            └── pr-url.txt
└── agents/
    └── feature-marker.md
```

**File Generation Flow:**
```
Missing prd.md
  ↓
Invoke ~/.claude/commands/create-prd.md
  ↓
Command reads ~/.claude/docs/specs/prd-template.md
  ↓
Generates ./tasks/prd-{feature-name}/prd.md
```

---

## 🔄 Workflow Phases

```
┌─────────────────────────────────────────────────────────────────┐
│                    /feature-marker prd-xyz                      │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  🚦 Phase 0: Inputs Gate                                        │
│  ├── 📂 Check ./tasks/prd-{feature-name}/ for existing files    │
│  ├── ✅ All files exist? → Skip to Phase 1                      │
│  ├── ⚠️  Files missing? → Generate ONLY missing files           │
│  │   • prd.md → ~/.claude/commands/create-prd.md               │
│  │   • techspec.md → ~/.claude/commands/generate-spec.md       │
│  │   • tasks.md → ~/.claude/commands/generate-tasks.md         │
│  └── 🔒 Never overwrites existing files                         │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  📋 Phase 1: Analysis & Planning                                │
│  ├── 📖 Read PRD, Tech Spec, Tasks                              │
│  ├── 🗺️ Create implementation plan                              │
│  └── 💾 Save analysis.md, plan.md                               │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  ⚡ Phase 2: Implementation                                      │
│  ├── ✅ Execute tasks with TodoWrite tracking                   │
│  ├── 📝 Make file changes                                       │
│  └── 💾 Save progress.md                                        │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  🧪 Phase 3: Tests & Validation                                 │
│  ├── 🏃 Run test suites (swift test, npm test, etc.)            │
│  ├── 🔨 Validate build                                          │
│  └── 💾 Save test-results.md                                    │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  🚀 Phase 4: Commit & PR                                        │
│  ├── 📝 Create commit with meaningful message                   │
│  ├── 🔍 Detect git platform (GitHub, Azure DevOps, GitLab)      │
│  ├── 🎯 Select appropriate PR skill                             │
│  └── 🔗 Create Pull Request                                     │
└─────────────────────────────────────────────────────────────────┘
```

---

## 🔀 Platform Detection

The skill auto-detects your git platform and selects the appropriate PR skill:

| Platform | Detection Pattern | PR Skill | Status |
|----------|------------------|----------|--------|
| GitHub | `github.com` | `creating-pr` | ✅ Supported |
| Azure DevOps | `dev.azure.com` | `azure-pr` | ✅ Supported |
| GitLab | `gitlab.com` | `creating-pr` | ✅ Supported |
| Bitbucket | `bitbucket.org` | `creating-pr` | ✅ Supported |
| Other | (any) | `creating-pr` | 🔄 Fallback |

> 💡 **Pro tip:** For best results, install the [`creating-pr`](https://www.skillsdirectory.com/skills/udecode-creating-pr) skill.

---

## 💾 Checkpoint & Resume

State is persisted in `.claude/feature-state/{feature-name}/checkpoint.json`.

### How it works

```
You: /feature-marker prd-user-authentication

feature-marker: Checkpoint found!
                Phase 2 in progress (Task 3/6)
                Last updated: 2026-01-19T10:30:00Z
                
                Resume from checkpoint? [Y/n]

You: Y

feature-marker: Resuming from Task 3/6...
```

### Checkpoint data includes

- Current phase and status
- Completed tasks
- Generated artifacts
- Error state (if any)
- Timestamps

---

## ⚙️ Configuration

Override defaults with `.feature-marker.json` in your project root:

```json
{
  "pr_skill": "custom-pr-skill",
  "skip_pr": false,
  "test_command": "npm run test:ci",
  "docs_path": "./tasks",
  "state_path": ".claude/feature-state"
}
```

### Configuration Options

| Option | Default | Description |
|--------|---------|-------------|
| `pr_skill` | Auto-detected | Override PR skill selection |
| `skip_pr` | `false` | Skip PR creation, commit only |
| `test_command` | Auto-detected | Custom test command |
| `docs_path` | `./tasks` | Path to task documents |
| `state_path` | `.claude/feature-state` | Path for checkpoint storage |

---

## 🖥️ CLI Usage

The `feature-marker.sh` script can also be used directly:

```bash
# Show help
./feature-marker/feature-marker.sh --help

# Show status of a feature
./feature-marker/feature-marker.sh --status prd-user-authentication

# Show detected git platform
./feature-marker/feature-marker.sh --platform

# Show version
./feature-marker/feature-marker.sh --version

# Direct mode selection (v1.3.0+) - skip interactive menu
./feature-marker/feature-marker.sh --mode full prd-user-authentication
./feature-marker/feature-marker.sh --mode tasks-only prd-user-authentication
./feature-marker/feature-marker.sh --mode ralph-loop prd-user-authentication
./feature-marker/feature-marker.sh --mode spec-driven prd-user-authentication  # v2.0.0+
```

### CLI Output Example

```
╔═══════════════════════════════════════╗
║         feature-marker v1.0           ║
╚═══════════════════════════════════════╝

Feature: prd-user-authentication

Checking feature files in ./tasks/prd-user-authentication/...
  ✓ prd.md exists
  ✓ techspec.md exists
  ✓ tasks.md exists

Git Platform Detection:
  Platform: github
  PR Skill: creating-pr
  Skill Status: Available

────────────────────────────────────────

ℹ To start/continue this workflow, use Claude Code:
  /feature-marker prd-user-authentication
```

---

## ❓ Frequently Asked Questions

### Q: What if my files already exist in `./tasks/prd-{feature-name}/`?
**A:** The workflow automatically detects existing files and **never** overwrites them. It will:
- ✅ Read existing `prd.md`, `techspec.md`, and `tasks.md`
- ✅ Proceed directly to Phase 1 (Analysis & Planning)
- ✅ Skip file generation entirely

### Q: Can I have partial files (e.g., only PRD exists)?
**A:** Yes! The workflow generates **only the missing files**. For example:
- If you have `prd.md` but not `techspec.md` → Generates only `techspec.md`
- If you have all three → Skips generation and proceeds to implementation

### Q: Where should my task files be located?
**A:** All task files should be in:
```
./tasks/prd-{feature-name}/
├── prd.md
├── techspec.md
└── tasks.md
```
Note: The path is `./tasks/` in the project root, **not** `./docs/tasks/`

### Q: Do I need template files?
**A:** Yes! As of v1.4.0, templates are required in `~/.claude/docs/specs/`:
- `prd-template.md` - Product Requirements Document template
- `techspec-template.md` - Technical Specification template
- `tasks-template.md` - Tasks breakdown template

Commands in `~/.claude/commands/` read these templates to generate feature-specific files.

**Setup verification:**
```bash
ls ~/.claude/docs/specs/
# Should show: prd-template.md, techspec-template.md, tasks-template.md
```

### Q: How does the file generation flow work?
**A:** The flow is:
```
Templates (~/.claude/docs/specs/)
  → Commands (~/.claude/commands/) read templates
  → Generated Files (./tasks/prd-{feature-name}/)
```

For example:
1. Missing `prd.md` detected
2. Command `~/.claude/commands/create-prd.md` invoked
3. Command reads `~/.claude/docs/specs/prd-template.md`
4. Generates `./tasks/prd-{feature-name}/prd.md` in your project

### Q: How do I migrate from the old `docs/tasks/` structure?
**A:** Simply move your files:
```bash
mv docs/tasks/* tasks/
rm -rf docs/tasks/ docs/specs/
```

---

## 🔧 Troubleshooting

| Issue | Solution |
|-------|----------|
| Templates not found | Create template directory: `mkdir -p ~/.claude/docs/specs` and add template files |
| Commands not found | Ensure commands exist in `~/.claude/commands/` |
| Task generation needs approval | `generate-tasks.md` requires preview approval before writing |
| No PR skill for platform | Falls back to `creating-pr`; if unavailable, commits only |
| Checkpoint corrupted | Delete `.claude/feature-state/{feature}/checkpoint.json` |

### Templates Not Found

If you see "Template not found" errors:

```bash
# 1. Create template directory
mkdir -p ~/.claude/docs/specs

# 2. Add your templates
touch ~/.claude/docs/specs/prd-template.md
touch ~/.claude/docs/specs/techspec-template.md
touch ~/.claude/docs/specs/tasks-template.md

# 3. Verify setup
ls ~/.claude/docs/specs/
```

---

## 🔄 Update / Uninstall

### Update

```bash
cd Feature-marker
git pull
./feature-marker/install.sh
```

### Uninstall

```bash
rm -rf ~/.claude/skills/feature-marker/
rm ~/.claude/agents/feature-marker.md
```

---

## 🎥 Video Generation

Want to create your own explainer video or customize the existing one?

### Prerequisites

```bash
# Install Node.js 18+ and npm/bun/pnpm
# Then navigate to video project
cd video-explainer
npm install  # or bun install / pnpm install
```

### Preview Video

```bash
npm start
```

Opens Remotion Studio at `http://localhost:3000` where you can:
- Preview all scenes in real-time
- Adjust timings and animations
- Test different configurations

### Render Video (MP4)

```bash
# Full HD quality
npm run build -- FeatureMarkerExplainer --codec h264

# Output: out/FeatureMarkerExplainer.mp4
```

### Create Optimized GIF for README

```bash
# 1. Render at smaller resolution (40 seconds, 1.5x faster)
npm run build -- FeatureMarkerExplainer --scale 0.5 --codec h264

# 2. Convert to optimized GIF (requires ffmpeg)
# 720px width, 128 colors, Bayer dithering for smaller file size
ffmpeg -i out/FeatureMarkerExplainer.mp4 \
  -vf "fps=15,scale=720:-1:flags=lanczos,split[s0][s1];[s0]palettegen=max_colors=128[p];[s1][p]paletteuse=dither=bayer:bayer_scale=5" \
  -loop 0 out/feature-marker-demo.gif

# 3. Copy to assets folder
cp out/feature-marker-demo.gif ../assets/feature-marker-demo.gif
```

**Optimizations applied:**
- **Faster playback**: 40s video (was 60s) for more engaging viewing
- **Smaller file**: 720px width with 128-color palette (reduced from 960px/256 colors)
- **Better compression**: Bayer dithering reduces banding artifacts
- **Infinite loop**: Automatically replays in README

### Customize Video

All scenes are in `video-explainer/src/compositions/`:
- `IntroScene.tsx` - Logo and tagline
- `BasicCommandScene.tsx` - Command demonstration
- `InteractivePanelScene.tsx` - Menu showcase
- `WorkflowScene.tsx` - Progress indicators
- `OutroScene.tsx` - CTA and GitHub link

Edit these files to:
- Change colors and branding
- Adjust animation timing
- Update text content
- Add new scenes

See full documentation: [`video-explainer/README.md`](video-explainer/README.md)

---

## 🤝 Contributing

Contributions are welcome! Feel free to:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

---

## 📄 License

MIT © [Vinicius Carvalho](https://github.com/Viniciuscarvalho)

---

<p align="center">
  <img src="assets/logo.svg" alt="feature-marker logo" width="100">
  <br>
  Built with 🤖 for the AI-assisted development community
</p>
