<!-- Banner -->
<p align="center">
  <img src="assets/banner.svg" alt="feature-marker — AI-powered feature development skill for Claude Code" width="800">
</p>

<p align="center">
  <strong>AI-powered feature development skill for Claude Code.<br>PRD → Tech Spec → Tasks → Implementation → Tests → PR — automated, with checkpoint/resume across multiple execution modes.</strong>
</p>

<p align="center">
  <a href="https://www.npmjs.com/package/@viniciuscarvalho/feature-marker">
    <img src="https://img.shields.io/npm/v/@viniciuscarvalho/feature-marker.svg" alt="npm version">
  </a>
  <a href="https://github.com/Viniciuscarvalho/Feature-marker/blob/main/LICENSE">
    <img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="License: MIT">
  </a>
  <a href="https://github.com/Viniciuscarvalho/Feature-marker">
    <img src="https://img.shields.io/badge/platform-Claude%20Code-purple.svg" alt="Platform: Claude Code">
  </a>
  <a href="https://github.com/sponsors/Viniciuscarvalho">
    <img src="https://img.shields.io/badge/sponsor-♥-ea4aaa.svg" alt="Sponsor">
  </a>
</p>

<p align="center">
  <code>claude code skill</code> · <code>feature workflow automation</code> · <code>PRD to PR pipeline</code> · <code>checkpoint resume</code> · <code>AI development orchestrator</code> · <code>multi-agent</code>
</p>

---

## Quick Start

```bash
npx @viniciuscarvalho/feature-marker
```

Then in Claude Code:

```
/feature-marker my-feature-name
```

feature-marker generates your PRD, Tech Spec, and task list — then implements, tests, and opens a pull request, pausing at every phase checkpoint so you stay in control.

<p align="center">
  <img src="assets/feature-marker-demo.gif" alt="feature-marker Demo" width="700">
</p>

---

## Why feature-marker

Building a feature end-to-end means context-switching between planning, coding, testing, and PR creation. feature-marker collapses that into a single command — describe the feature once, get a pull request out.

| Metric                         | Without | With feature-marker     |
| ------------------------------ | ------- | ----------------------- |
| Features per session           | 1       | **5+**                  |
| Manual touchpoints per feature | ~10     | **0** (checkpoint mode) |
| Context-aware completion rate  | ~60%    | **85%+**                |
| Cross-feature conflicts        | Unknown | **<10%**                |
| Backlog to PR                  | Manual  | **<10 min per feature** |

---

## How It Works

Invoke the skill once — feature-marker reads your project state and presents a single confirmation prompt, then runs the pipeline. → [Full walkthrough](assets/HOW_IT_WORKS.md)

```
/feature-marker my-feature
        │
        ▼
Phase 0: Inputs Gate     → Validate or generate PRD, Tech Spec, Tasks
Phase 1: Analysis        → Create implementation plan
Phase 2: Implementation  → Execute tasks with per-task lint + test
Phase 3: Tests           → Run platform-appropriate test suite
Phase 4: Commit & PR     → Commit, push, open pull request
```

Each phase writes a checkpoint. Re-run with the same name to resume exactly where you left off.

---

## Key Capabilities

- **Artifact generation** — PRD, Tech Spec, and Tasks from a one-line description
- **Checkpoint / resume** — pause at any phase, pick up later with the same command
- **Per-task validation** — lint + related tests after each task; auto-fix on failure
- **Stack detection** — auto-detects iOS, Node.js, Rust, Python, Go for correct test and lint commands
- **Multiple execution modes** — Full, Tasks-Only, Spec-Driven, Test-Only
- **Safety guardrails** — breaking change detection, schema migration review, configurable file-change limits
- **Custom review personas** — domain-specific agents for Firebase, iOS, API Security, Payments, and Migrations

---

## Installation

```bash
npx @viniciuscarvalho/feature-marker
```

**Update to the latest version:**

```bash
npx @viniciuscarvalho/feature-marker@latest
```

**Manual install:**

```bash
git clone https://github.com/Viniciuscarvalho/Feature-marker.git
cd Feature-marker && ./feature-marker-dist/feature-marker/install.sh
```

---

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/my-change`)
3. Commit your changes using [Conventional Commits](https://www.conventionalcommits.org/)
4. Open a pull request

---

## License

MIT © [Vinicius Carvalho](https://github.com/Viniciuscarvalho)

---

<p align="center">
  <img src="assets/logo.svg" alt="feature-marker logo" width="100">
  <br>
  Built with 🤖 for the AI-assisted development community
</p>
