<!-- Banner -->
<p align="center">
  <img src="assets/banner.svg" alt="feature-marker — AI-powered feature development orchestrator for Claude Code" width="800">
</p>

<p align="center">
  <strong>AI-powered feature development orchestrator — PRD → Tech Spec → Tasks → Implementation → Tests → PR — with checkpoint/resume, 5 execution modes, and auto-detection for GitHub/GitLab/Azure DevOps. Claude Code skill.</strong>
</p>

<p align="center">
  <a href="https://www.npmjs.com/package/@viniciuscarvalho/feature-marker">
    <img src="https://img.shields.io/npm/v/@viniciuscarvalho/feature-marker.svg" alt="npm version">
  </a>
  <a href="https://github.com/Viniciuscarvalho/homebrew-tap">
    <img src="https://img.shields.io/badge/homebrew-tap-orange.svg" alt="Homebrew Tap">
  </a>
  <a href="https://github.com/Viniciuscarvalho/Feature-marker/blob/main/LICENSE">
    <img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="License: MIT">
  </a>
  <a href="https://github.com/Viniciuscarvalho/Feature-marker">
    <img src="https://img.shields.io/badge/platform-Claude%20Code-purple.svg" alt="Platform: Claude Code">
  </a>
  <a href="https://github.com/Viniciuscarvalho/Feature-marker">
    <img src="https://img.shields.io/badge/PRs-welcome-brightgreen.svg" alt="PRs Welcome">
  </a>
  <a href="https://github.com/sponsors/Viniciuscarvalho">
    <img src="https://img.shields.io/badge/sponsor-♥-ea4aaa.svg" alt="Sponsor">
  </a>
</p>

<p align="center">
  <code>claude code skill</code> · <code>feature workflow automation</code> · <code>PRD to PR pipeline</code> · <code>checkpoint resume</code> · <code>AI development orchestrator</code>
</p>

---

**feature-marker** is a Claude Code skill that orchestrates the complete feature development lifecycle — from requirements to pull request — with checkpoint/resume, multi-platform support, and 5 execution modes.

<p align="center">
  <img src="assets/feature-marker-demo.gif" alt="feature-marker Demo" width="700">
</p>

---

## Installation

Choose your preferred installation method:

### Skills CLI (Recommended)

The fastest way to install and keep up to date.

```bash
# Install
npx skills add Viniciuscarvalho/Feature-marker

# Update to latest version
npx skills update
```

### NPX

Requires Node.js 18+.

```bash
# Install
npx @viniciuscarvalho/feature-marker install

# Check status
npx @viniciuscarvalho/feature-marker status

# Uninstall
npx @viniciuscarvalho/feature-marker uninstall
```

### Homebrew (macOS/Linux)

For Homebrew users on macOS and Linux.

```bash
# Add tap and install
brew tap viniciuscarvalho/tap
brew install feature-marker

# Complete installation to ~/.claude
feature-marker-install
```

**Uninstall:**

```bash
feature-marker-uninstall
brew uninstall feature-marker
```

### Manual

Clone and run the install script directly.

```bash
git clone https://github.com/Viniciuscarvalho/Feature-marker.git
cd Feature-marker
./feature-marker-dist/feature-marker/install.sh
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

## Platform Support

feature-marker works with any tech stack — agnostic by default, iOS-aware when detected:

- 🍎 **iOS/Swift** — `swift test` + SwiftLint + XcodeBuildMCP simulator validation
- 🟨 **Node.js/TypeScript** — auto-detects npm/yarn/pnpm/bun + Jest/Vitest
- 🦀 **Rust** — `cargo test` + `cargo clippy`
- 🐍 **Python** — `pytest` + ruff/flake8
- 🐹 **Go** — `go test` + `go vet`

iOS/Xcode projects get additional simulator validation via XcodeBuildMCP (optional).

---

## Features

- **Artifact Generation** — Auto-generates PRD, Tech Spec, and Tasks from requirements
- **Spec Accuracy Pipeline** — Context gathering, prompt enrichment, PRD/TechSpec/Tasks validation, AC lock checkpoint
- **4-Phase Workflow** — Analysis → Implementation → Tests → Commit & PR
- **Per-Task Validation** — Lint + related tests after each task; structured failure recovery with auto-fix
- **Checkpoint/Resume** — Pause anytime, resume where you left off
- **Stack Detection** — Auto-detects iOS, Node.js, Rust, Python, Go for correct test/lint commands
- **Git Platform Detection** — Auto-detects GitHub, Azure DevOps, GitLab for PR creation
- **Multiple Modes** — Full workflow, tasks-only, Ralph Loop, Spec-Driven, or Test Only
- **Custom Personas** — Domain-specific review personas with auto-trigger by feature keywords
- **TUI Application** — Rich terminal interface for visual workflow management
- **Menu Bar App** — Native Swift/SwiftUI macOS app (839 KB binary)

---

## Custom Personas

feature-marker ships with 5 built-in review personas for the Spec-Driven mode. Each persona focuses on a specific domain and auto-activates when feature keywords match its triggers.

### Setup

```bash
/feature-marker --setup-personas
```

This installs personas to `.claude/spec-workflow/personas/` for the current project.

### Built-in Personas

| Persona                      | Triggers                                         | Focus                                        |
| ---------------------------- | ------------------------------------------------ | -------------------------------------------- |
| **Firebase Cost Reviewer**   | firestore, collection, query, listener           | Query costs, N+1, unbounded reads            |
| **iOS Performance Reviewer** | swift, ios, swiftui, list, scroll, animation     | Main thread, image caching, lazy rendering   |
| **API Security Reviewer**    | api, route, endpoint, auth, token, webhook       | Auth bypass, input validation, rate limiting |
| **Payment Flow Reviewer**    | stripe, payment, checkout, webhook, subscription | Idempotency, replay, network failure         |
| **Data Migration Reviewer**  | migration, schema, breaking, rename, remove      | Rollback plan, zero-downtime, data integrity |

### Custom Personas

Create `.claude/spec-workflow/personas/my-persona.md`:

```markdown
---
name: My Custom Reviewer
triggers: [keyword1, keyword2, keyword3]
applies_to: [large-feature, api-change]
---

You review specs for [your domain].

### Your perspective

[What you care about and why]

### What you look for

[Specific issues to catch]

### When to pass

"[Your LGTM phrase]"
```

Custom personas always have priority over built-in personas with the same `name`.

---

## Execution Modes

| Mode              | Description                                                     |
| ----------------- | --------------------------------------------------------------- |
| **Full Workflow** | Generate artifacts + run all phases                             |
| **Tasks Only**    | Skip generation, use existing files                             |
| **Ralph Loop**    | Autonomous self-correcting execution                            |
| **Spec-Driven**   | Multi-agent review with worktree isolation                      |
| **Test Only**     | Run tests phase exclusively (Swift Testing, Jest, pytest, etc.) |

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
