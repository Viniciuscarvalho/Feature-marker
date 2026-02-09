
<!-- Banner -->
<p align="center">
  <img src="assets/banner.svg" alt="feature-marker Banner" width="800">
</p>

<p align="center">
  <strong>Automate your feature development workflow with AI-powered checkpoints</strong>
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
</p>

---

**feature-marker** is a Claude Code skill that guides you through the complete feature development lifecycle: PRD → Tech Spec → Tasks → Implementation → Tests → PR.

<p align="center">
  <img src="assets/feature-marker-demo.gif" alt="feature-marker Demo" width="700">
</p>

---

## Installation

```bash
# Clone and install
git clone https://github.com/Viniciuscarvalho/Feature-marker.git
cd Feature-marker
./feature-marker-dist/feature-marker/install.sh

# With TUI (requires Rust)
./feature-marker-dist/feature-marker/install.sh --with-tui
```

---

## Usage

```bash
# In Claude Code
/feature-marker prd-user-authentication

# Interactive mode
/feature-marker --interactive prd-user-authentication

# Launch TUI
feature-marker-tui
```

---

## Features

- **Artifact Generation** — Auto-generates PRD, Tech Spec, and Tasks from requirements
- **4-Phase Workflow** — Analysis → Implementation → Tests → Commit & PR
- **Checkpoint/Resume** — Pause anytime, resume where you left off
- **Platform Detection** — Auto-detects GitHub, Azure DevOps, GitLab for PR creation
- **Multiple Modes** — Full workflow, tasks-only, Ralph Loop, or Spec-Driven
- **TUI Application** — Rich terminal interface for visual workflow management
- **Menu Bar App** — Native macOS app with global shortcut (⌘⇧F)

---

## Execution Modes

| Mode | Description |
|------|-------------|
| **Full Workflow** | Generate artifacts + run all phases |
| **Tasks Only** | Skip generation, use existing files |
| **Ralph Loop** | Autonomous self-correcting execution |
| **Spec-Driven** | Multi-agent review with worktree isolation |

---

## Requirements

Commands in `~/.claude/commands/`:
- `create-prd.md`
- `generate-spec.md`
- `generate-tasks.md`

Templates in `~/.claude/docs/specs/`:
- `prd-template.md`
- `techspec-template.md`
- `tasks-template.md`

> Get these from [mindkit](https://github.com/Viniciuscarvalho/mindkit) or create your own.

---

## Project Structure

```
./tasks/prd-{feature-name}/
├── prd.md
├── techspec.md
└── tasks.md

.claude/feature-state/{feature-name}/
├── checkpoint.json
├── analysis.md
├── plan.md
├── progress.md
└── test-results.md
```

---

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

---

## License

MIT © [Vinicius Carvalho](https://github.com/Viniciuscarvalho)

---

<p align="center">
  <img src="assets/logo.svg" alt="feature-marker logo" width="100">
  <br>
  Built with 🤖 for the AI-assisted development community
</p>
