<!-- Banner -->
<p align="center">
  <img src="assets/banner.svg" alt="feature-marker — AI-powered feature development skill for Claude Code" width="800">
</p>

<p align="center">
  <strong>AI-powered feature development skill for Claude Code.<br>PRD → Tech Spec → Tasks → Implementation → Tests → PR — automated, with checkpoint/resume and autonomous multi-feature orchestration.</strong>
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
npx skills add Viniciuscarvalho/Feature-marker
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

Each phase writes a checkpoint. Re-run with the same feature name to resume from where you left off.

---

## What It Automates

| Capability                     | Description                                                                             |
| ------------------------------ | --------------------------------------------------------------------------------------- |
| **Artifact Generation**        | Generates PRD, Tech Spec, and Tasks from a one-line description                         |
| **Spec Accuracy Pipeline**     | Context gathering, prompt enrichment, and AC lock checkpoint before coding starts       |
| **Per-Task Validation**        | Lint + related tests after each task; structured auto-fix on failure                    |
| **Checkpoint / Resume**        | Pause at any phase, resume later with the same command                                  |
| **Stack Detection**            | Auto-detects iOS, Node.js, Rust, Python, Go for correct test and lint commands          |
| **Git Platform Detection**     | Auto-detects GitHub, GitLab, Azure DevOps for correct PR creation                       |
| **Multi-Feature Orchestrator** | Reads a backlog, creates isolated worktrees, and processes features autonomously        |
| **Cross-Feature Context**      | Decisions and patterns from previous features inform the next one automatically         |
| **Safety Guardrails**          | Breaking change detection, schema migration review, and configurable file-change limits |
| **Custom Review Personas**     | Domain-specific agents for Firebase, iOS, API Security, Payments, and Migrations        |

---

## Execution Modes

| Mode              | Description                                                |
| ----------------- | ---------------------------------------------------------- |
| **Full Workflow** | Generate all artifacts then run every phase end-to-end     |
| **Tasks Only**    | Skip generation, execute against existing docs             |
| **Ralph Loop**    | Autonomous self-correcting execution                       |
| **Spec-Driven**   | Multi-agent spec review and approval before implementation |
| **Test Only**     | Run the test phase in isolation                            |

Select interactively:

```
/feature-marker --interactive my-feature-name
```

---

## Platform Support

Works with any stack — agnostic by default, platform-aware when detected:

| Platform                | Test Command            | Lint                       |
| ----------------------- | ----------------------- | -------------------------- |
| 🍎 iOS / Swift          | `swift test --parallel` | `swiftlint`                |
| 🟨 Node.js / TypeScript | `jest` / `vitest run`   | `eslint` / `{pm} run lint` |
| 🦀 Rust                 | `cargo test`            | `cargo clippy`             |
| 🐍 Python               | `pytest -v`             | `ruff check .`             |
| 🐹 Go                   | `go test ./...`         | `go vet ./...`             |

iOS projects also get XcodeBuildMCP simulator validation (optional).

---

## Installation

```bash
# Recommended — one command
npx skills add Viniciuscarvalho/Feature-marker
```

Other options:

```bash
# Homebrew (includes orchestrator CLI)
brew tap viniciuscarvalho/tap && brew install feature-marker

# NPX
npx @viniciuscarvalho/feature-marker install

# Manual
git clone https://github.com/Viniciuscarvalho/Feature-marker.git
cd Feature-marker && ./feature-marker-dist/feature-marker/install.sh
```

---

## Usage

**Single feature** — in Claude Code:

```bash
/feature-marker my-feature-name
```

Re-run with the same name to resume from the last checkpoint.

**Multiple features** — from your terminal:

```bash
# Scaffold config in your project
feature-marker-orchestrate init

# Preview the plan
feature-marker-orchestrate --dry-run

# Run the orchestrator
feature-marker-orchestrate
```

Or run directly from the repo:

```bash
./scripts/orchestrate.sh init
./scripts/orchestrate.sh run
```

---

## Orchestrator

The orchestrator reads a backlog, creates isolated worktrees, runs the full pipeline per feature, and propagates context between runs.

```bash
feature-marker-orchestrate init       # scaffold config, .env, features.md
feature-marker-orchestrate            # process the backlog
feature-marker-orchestrate status     # check feature states
feature-marker-orchestrate clean      # reset everything
```

### Backlog Sources

| Adapter           | Source                                     |
| ----------------- | ------------------------------------------ |
| **Markdown**      | Local `features.md` file                   |
| **GitHub Issues** | Open issues filtered by label via `gh` CLI |
| **Linear**        | Team issues via GraphQL API                |

Markdown format:

```markdown
## [FEAT] feat-001: Add Multi-Tenant Auth

- labels: auth, backend
- priority: high

## [BLOCKED] feat-002: Billing Integration

Depends on: feat-001
```

### Autonomy Levels

| Level          | Behavior                                             | Best For                        |
| -------------- | ---------------------------------------------------- | ------------------------------- |
| **supervised** | Pauses after each phase for explicit approval        | New projects, critical features |
| **checkpoint** | Full pipeline, opens PR, human reviews and merges    | Most projects                   |
| **full_auto**  | Full pipeline, opens PR, enables auto-merge after CI | Low-risk batch work             |

Configure via `orchestrator/config.yml`. Inline priority is also supported in feature titles: `[p:high]`.

---

## Custom Personas

Five built-in review personas activate automatically based on feature keywords in Spec-Driven mode:

| Persona                      | Triggers                                | Focus                                           |
| ---------------------------- | --------------------------------------- | ----------------------------------------------- |
| **Firebase Cost Reviewer**   | firestore, query, listener              | Query costs, N+1 reads, unbounded collections   |
| **iOS Performance Reviewer** | swift, swiftui, scroll, animation       | Main thread work, image caching, lazy rendering |
| **API Security Reviewer**    | api, endpoint, auth, token, webhook     | Auth bypass, input validation, rate limiting    |
| **Payment Flow Reviewer**    | stripe, checkout, webhook, subscription | Idempotency, replay attacks, network failures   |
| **Data Migration Reviewer**  | migration, schema, breaking, rename     | Rollback plan, zero-downtime, data integrity    |

Install personas to your project:

```bash
/feature-marker --setup-personas
```

Add your own in `.claude/spec-workflow/personas/my-persona.md` — custom personas always take priority over built-ins with the same name.

---

## Requirements

The following Claude Code commands and templates must be present. Get them from [mindkit](https://github.com/Viniciuscarvalho/mindkit) or create your own.

**Commands** (`~/.claude/commands/`)

- `create-prd.md`
- `generate-spec.md`
- `generate-tasks.md`

**Templates** (`~/.claude/docs/specs/`)

- `prd-template.md`
- `techspec-template.md`
- `tasks-template.md`

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
