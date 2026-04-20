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

Feature-marker has two entry points that share the same pipeline. Run it **inside Claude Code** for a single feature, or use the **terminal orchestrator** to process an entire backlog automatically. [Full walkthrough →](assets/HOW_IT_WORKS.md)

<p align="center">
  <img src="assets/img_two_paths.png" alt="Two paths: in-Claude skill vs terminal orchestrator" width="700">
</p>

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

### Phase reference

| #   | Phase                   | What you provide                                                                       | If something is missing                                                                                                                                          | Autonomy pause point                                                                                  |
| --- | ----------------------- | -------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------- |
| 0   | **Inputs Gate**         | `tasks/prd-{slug}/prd.md`, `techspec.md`, `tasks.md` — or just a one-line description  | Missing artifacts are generated interactively via `/create-prd`, `/generate-spec`, `/generate-tasks`. Plan-mode output from `~/.claude/plans/` is auto-ingested. | `supervised`: pauses for approval of each artifact before continuing                                  |
| 1   | **Analysis & Planning** | Nothing — fully automatic                                                              | `product-manager` skill auto-installed if absent                                                                                                                 | `supervised`: pauses before implementation begins                                                     |
| 2   | **Implementation**      | Nothing normally                                                                       | On breaking changes or when file-change count exceeds `safety.max_file_changes` (default 50), execution pauses even in `full_auto`                               | `supervised`: pauses after every task                                                                 |
| 3   | **Tests & Validation**  | Nothing — platform auto-detected                                                       | Stack detected from project files (`swift test`, `jest`, `cargo test`, `pytest`, `go test`). On test failure you are prompted to retry or continue.              | —                                                                                                     |
| 4   | **Commit & PR**         | Git remote configured; platform CLI authenticated (`gh`, `az`, `glab`) for PR creation | `/commit` command auto-installed; PR opened as draft by default                                                                                                  | `checkpoint`: stops here for human review and merge. `full_auto`: enables auto-merge after CI passes. |

<p align="center">
  <img src="assets/img_pipeline.png" alt="Feature-marker pipeline phases" width="700">
</p>

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

## Two Ways to Run

feature-marker has two distinct entry points with different scopes and behaviors.

### Mode A — In Claude Code (single feature)

Run directly inside a Claude Code session:

```
/feature-marker my-feature-name
```

- Runs one feature at a time in the current session
- Uses whichever model the Claude Code session already has active
- Prompts you interactively for any missing artifacts
- Re-run with the same slug to resume from the last checkpoint (state in `.claude/feature-state/{slug}/checkpoint.json`)

### Mode B — Terminal CLI (one or many features)

Run from your terminal using the `feature-marker-orchestrate` CLI:

```bash
feature-marker-orchestrate init     # scaffold config and backlog file
feature-marker-orchestrate          # process the full backlog
feature-marker-orchestrate --feature feat-001   # run a single feature by ID
```

- Reads features from a backlog (Markdown file, GitHub Issues, Linear, Jira, or Notion)
- Creates an isolated git worktree per feature under `.worktrees/`
- Shells out to `claude --skill feature-marker` per feature — each run is a fresh Claude process
- Model, autonomy level, and safety limits are controlled via `orchestrator/config.yml`

### Comparison

| Dimension      | In-Claude `/feature-marker` | CLI `feature-marker-orchestrate`                |
| -------------- | --------------------------- | ----------------------------------------------- |
| Scope          | One feature per session     | Batch from backlog, or single via `--feature`   |
| Session        | Current Claude Code session | New `claude` process per feature                |
| Model          | Current session model       | Config → `--model` flag → `ANTHROPIC_MODEL` env |
| Working tree   | Current repo                | Isolated git worktree per feature               |
| Autonomy       | You approve inline          | `supervised` / `checkpoint` / `full_auto`       |
| Resume         | Same slug re-run            | `--resume` skips completed features             |
| Backlog source | You type the slug           | Markdown / GitHub / Linear / Jira / Notion      |

---

## Orchestrator

The orchestrator reads a backlog, creates an isolated git worktree per feature, runs the full feature-marker pipeline in each one, and propagates context (decisions, patterns, error history) across runs.

<p align="center">
  <img src="assets/img_orchestrator.png" alt="Orchestrator architecture" width="700">
</p>

### First run walkthrough

```bash
# 1. In your project root, scaffold the config
feature-marker-orchestrate init
```

`init` creates:

| Path                      | Purpose                                                        |
| ------------------------- | -------------------------------------------------------------- |
| `orchestrator/config.yml` | Backlog adapter, autonomy level, model, safety settings        |
| `.env`                    | API keys for Linear / Jira / Notion (gitignored automatically) |
| `features.md`             | Default backlog file when using the Markdown adapter           |
| `.orchestrator/`          | Runtime state directory (gitignored)                           |

```bash
# 2. Edit features.md or point config.yml at your backlog source

# 3. Preview what will run without executing
feature-marker-orchestrate run --dry-run

# 4. Run
feature-marker-orchestrate run
```

<p align="center">
  <img src="assets/orchestrator-terminal-flow.png" alt="Orchestrator terminal execution flow" width="700">
</p>

### CLI reference

| Subcommand      | What it does                                                                    |
| --------------- | ------------------------------------------------------------------------------- |
| `init`          | Scaffold `orchestrator/config.yml`, `.env`, `features.md`, `.gitignore` entries |
| `run` (default) | Execute the orchestration loop against the backlog                              |
| `status`        | Show current state of every feature (pending / running / done / blocked)        |
| `clean`         | Remove all worktrees and reset `.orchestrator/` state                           |

| Flag                   | Values                                                   | Description                                                   |
| ---------------------- | -------------------------------------------------------- | ------------------------------------------------------------- |
| `--autonomy <level>`   | `supervised` \| `checkpoint` \| `full_auto`              | Override autonomy for this run                                |
| `--adapter <type>`     | `markdown` \| `github` \| `linear` \| `jira` \| `notion` | Override backlog source                                       |
| `--model <name>`       | `opus` \| `sonnet` \| `haiku` \| `opusplan`              | Override model for this run                                   |
| `--feature <id>`       | e.g. `feat-001`                                          | Run only one specific feature                                 |
| `--plan` / `--dry-run` | —                                                        | Show the execution plan without running                       |
| `--resume`             | —                                                        | Skip features already marked done, run pending ones           |
| `--config <path>`      | file path                                                | Use a custom config file (default: `orchestrator/config.yml`) |

Examples:

```bash
feature-marker-orchestrate --dry-run
feature-marker-orchestrate --autonomy supervised
feature-marker-orchestrate --feature feat-003
feature-marker-orchestrate --model opus --resume
feature-marker-orchestrate status
feature-marker-orchestrate clean
```

### Backlog sources

Configure the active adapter in `orchestrator/config.yml` under `source.adapter`.

| Adapter           | Source                                     | Auth                                             |
| ----------------- | ------------------------------------------ | ------------------------------------------------ |
| **Markdown**      | Local `features.md`                        | None                                             |
| **GitHub Issues** | Open issues filtered by label via `gh` CLI | `gh auth login`                                  |
| **Linear**        | Team issues via GraphQL API                | `LINEAR_API_KEY` in `.env`                       |
| **Jira**          | Project issues via REST API                | `JIRA_URL`, `JIRA_EMAIL`, `JIRA_TOKEN` in `.env` |
| **Notion**        | Database rows filtered by status           | `NOTION_TOKEN` in `.env`                         |

Markdown format:

```markdown
## [FEAT] feat-001: Add Multi-Tenant Auth

- labels: auth, backend
- priority: high

## [BLOCKED] feat-002: Billing Integration

Depends on: feat-001
```

Inline priority override in any adapter: `[p:high]` in the feature title.

### Autonomy levels

| Level          | Behavior                                      | Phase pause points                                              | Best for                        |
| -------------- | --------------------------------------------- | --------------------------------------------------------------- | ------------------------------- |
| **supervised** | Pauses after each phase for explicit approval | After Phase 0, 1, and every task in Phase 2                     | New projects, critical features |
| **checkpoint** | Full pipeline, opens PR, you review and merge | Phase 4 — PR opened as draft, human merges                      | Most projects                   |
| **full_auto**  | Full pipeline, opens PR, auto-merge after CI  | Only on safety violations (breaking changes, file-change limit) | Low-risk batch work             |

### Safety and state

Safety limits in `orchestrator/config.yml`:

```yaml
safety:
  breaking_change_pause: true # pause on any breaking API/schema change
  schema_migration_review: true # pause when a DB migration is detected
  max_file_changes: 50 # pause if a single task touches more than 50 files
```

These limits apply in all autonomy levels including `full_auto`.

Checkpoint state lives in two places:

- `.orchestrator/state/` — orchestrator-level feature status (pending / running / done)
- `.claude/feature-state/{slug}/checkpoint.json` — per-phase resume data for each feature

Running `feature-marker-orchestrate clean` removes worktrees and resets `.orchestrator/state/` but does not delete `.claude/feature-state/` checkpoints. Re-running the same feature slug after a `clean` will resume from its last checkpoint.

---

## Model Selection

Introduced in v7.4.0. Controls which Claude model the CLI orchestrator uses when it shells out to `claude --skill feature-marker`.

**Accepted values:** `opus`, `sonnet`, `haiku`, `opusplan`, or a full model ID (e.g. `claude-opus-4-7`).

**Default:** `opusplan` — automatically uses Opus for planning phases and Sonnet for execution, giving the best quality/cost balance without any extra config.

**Precedence (highest to lowest):**

1. CLI flag: `--model <name>`
2. Environment variable: `ANTHROPIC_MODEL=<name>`
3. `orchestrator/config.yml` → `model.default`

Examples:

```bash
# One-off override via flag
feature-marker-orchestrate run --model sonnet

# Override via env (useful in CI)
ANTHROPIC_MODEL=opus feature-marker-orchestrate run
```

Config file (per-phase override, uncomment to activate):

```yaml
model:
  default: opusplan # used when per-phase model is not set
  # plan: opus               # PRD, TechSpec, Tasks generation
  # execute: sonnet          # Implementation, testing, review
```

> **Scope:** model selection only applies to the CLI orchestrator. The in-Claude `/feature-marker` skill always uses the model of the current Claude Code session.

---

## Updating feature-marker

### Check your installed version

```bash
# Homebrew
brew list --versions feature-marker

# NPX / npm
npx @viniciuscarvalho/feature-marker --version
```

### Check for a newer version

```bash
# Homebrew — refresh tap index then list outdated
brew update && brew outdated feature-marker

# npm — compare published version against installed
npm view @viniciuscarvalho/feature-marker version
```

You can also watch releases on GitHub: `https://github.com/Viniciuscarvalho/Feature-marker/releases`

### Upgrade

```bash
# Homebrew
brew update && brew upgrade feature-marker

# NPX / npm — re-run the installer to copy updated skill files
npx @viniciuscarvalho/feature-marker install

# Manual / git clone
git -C <repo-path> pull --ff-only
./feature-marker-dist/feature-marker/install.sh
```

### Verify after upgrade

```bash
feature-marker-orchestrate --help | head -5
brew list --versions feature-marker
```

**Notes:**

- The in-Claude skill lives at `~/.claude/skills/feature-marker/`. Homebrew and NPX both update this path automatically. A manual `git pull` does not — you must re-run `install.sh` afterward.
- Orchestrator state under `.orchestrator/` and `.claude/feature-state/` is not touched by upgrades; existing checkpoints continue to work.
- If a release changes the `orchestrator/config.yml` schema, run `feature-marker-orchestrate init` in a scratch directory to see the new defaults, then merge any new keys into your project config manually.

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

### For the in-Claude skill

The following Claude Code commands and templates must be present. Get them from [mindkit](https://github.com/Viniciuscarvalho/mindkit) or create your own.

**Commands** (`~/.claude/commands/`)

- `create-prd.md`
- `generate-spec.md`
- `generate-tasks.md`

**Templates** (`~/.claude/docs/specs/`)

- `prd-template.md`
- `techspec-template.md`
- `tasks-template.md`

### For the CLI orchestrator

- **Claude Code CLI** installed and authenticated — verify with `claude --version`
- **Git** configured with a remote; target branch pushed and accessible
- **Platform CLI authenticated** based on your backlog adapter:
  - GitHub: `gh auth login`
  - Linear: `LINEAR_API_KEY` in `.env`
  - Jira: `JIRA_URL`, `JIRA_EMAIL`, `JIRA_TOKEN` in `.env`
  - Notion: `NOTION_TOKEN` in `.env`
- **PR creation CLI** matching your git platform: `gh` (GitHub), `az` (Azure DevOps), or `glab` (GitLab)

Run `feature-marker-orchestrate init` in your project root to scaffold `orchestrator/config.yml`, `.env`, `features.md`, and the required `.gitignore` entries in one step.

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
