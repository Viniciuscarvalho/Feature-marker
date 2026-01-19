
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

<p align="center">
  <img src="assets/demo.gif" alt="feature-marker Demo" width="700">
</p>

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

In Claude Code, simply invoke:

```
/feature-marker <feature-slug>
```

### Examples

```bash
# Start a new feature
/feature-marker prd-user-authentication

# Resume an interrupted workflow
/feature-marker prd-user-authentication  # Will detect checkpoint and offer resume

# Work on multiple features
/feature-marker prd-payment-integration
/feature-marker prd-notification-system
```

---

## 🔧 Prerequisites

### Required Commands

The following commands must exist in `~/.claude/commands/`:

| Command | Description |
|---------|-------------|
| `create-prd.md` | Creates PRD from requirements discussion |
| `generate-spec.md` | Generates tech spec from PRD |
| `generate-tasks.md` | Breaks down feature into implementable tasks |

> 💡 **Tip:** You can get these commands from [mindkit](https://github.com/Viniciuscarvalho/mindkit) or create your own.

### Project Structure

Your project should follow this structure:

```
your-project/
├── tasks/
│   └── prd-{feature-name}/
│       ├── prd.md            # Generated PRD
│       ├── techspec.md       # Generated tech spec
│       └── tasks.md          # Generated task list
└── .claude/
    └── feature-state/
        └── {feature-name}/
            └── checkpoint.json   # Workflow state
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
│  ├── ✓ Validate prd.md, techspec.md, tasks.md                   │
│  └── 🔧 Generate missing files via ~/.claude/commands/          │
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

## 🔧 Troubleshooting

| Issue | Solution |
|-------|----------|
| Task generation needs approval | `generate-tasks.md` requires preview approval before writing |
| No PR skill for platform | Falls back to `creating-pr`; if unavailable, commits only |
| Checkpoint corrupted | Delete `.claude/feature-state/{feature}/checkpoint.json` |
| Commands not found | Ensure commands exist in `~/.claude/commands/` |

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
