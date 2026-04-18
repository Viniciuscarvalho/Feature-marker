<!-- Banner -->
<p align="center">
  <img src="assets/banner.svg" alt="feature-marker — AI-powered feature development orchestrator for Claude Code" width="800">
</p>

<p align="center">
  <strong>AI-powered feature development orchestrator — PRD → Tech Spec → Tasks → Implementation → Tests → PR — with checkpoint/resume, 5 execution modes, autonomous multi-feature orchestration, and auto-detection for GitHub/GitLab/Azure DevOps. Claude Code skill.</strong>
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

**feature-marker** is a Claude Code skill that orchestrates the complete feature development lifecycle — from requirements to pull request — with checkpoint/resume, multi-platform support, 5 execution modes, and an **autonomous multi-feature orchestrator** that reads a backlog, creates isolated worktrees per feature, and drains the backlog with configurable autonomy levels.

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

## Orchestrator

The orchestrator evolves feature-marker from a single-feature skill into an autonomous system that drains an entire backlog — creating isolated worktrees, running the full pipeline per feature, and propagating context across features.

### Quick Start

```bash
# 1. Define your backlog
cat features.md

# 2. Configure (optional — sensible defaults)
cat orchestrator/config.yml

# 3. Run
./scripts/orchestrator.sh
```

### Backlog Adapters

Features can come from any source. Each adapter normalizes items into a canonical JSON schema:

| Adapter | Source | Command |
| ------- | ------ | ------- |
| **Markdown** | Local `features.md` file | `node scripts/adapters/markdown.js features.md` |
| **GitHub** | Issues by label via `gh` CLI | `node scripts/adapters/github.js feature-marker` |
| **Linear** | Issues by team via GraphQL | `LINEAR_API_KEY=... node scripts/adapters/linear.js ENG` |

Markdown format:

```markdown
## [FEAT] feat-001: Add Multi-Tenant Auth
Description here
- labels: auth, multi-tenant
- priority: high

## [BLOCKED] feat-002: Billing Integration
Depends on: feat-001
- labels: billing
- priority: medium
```

Supported statuses: `FEAT` (backlog), `WIP` (in-progress), `DONE`, `BLOCKED`.

### Autonomy Levels

| Level | Behavior | Best for |
| ----- | -------- | -------- |
| **supervised** | Pauses after each pipeline phase for explicit approval | New projects, critical features |
| **checkpoint** (default) | Runs full pipeline, creates PR, human reviews and merges | Established projects, medium-risk |
| **full_auto** | Runs pipeline, creates PR, enables auto-merge after CI | Low-risk features, batch operations |

### Configuration

All orchestrator behavior is controlled via `orchestrator/config.yml`:

```yaml
source:
  adapter: markdown          # markdown | github | linear
  file: features.md          # for markdown adapter

autonomy: checkpoint         # supervised | checkpoint | full_auto

execution:
  base_branch: main
  skip_done: true
  skip_blocked: true

worktrees:
  base_path: .worktrees      # where worktrees are created
  branch_prefix: feat        # branches named feat/<id>
  auto_cleanup: true         # remove worktrees after done/pr-created

memory:
  carry_forward_from: global-context.md  # cross-feature context file
  error_pattern_window: 5                # keep last N error patterns
  env_refresh: true                      # re-run env discovery between features

safety:
  breaking_change_pause: true    # pause on breaking changes
  schema_migration_review: true  # pause on schema changes
  max_file_changes: 50           # pause if feature touches >50 files

pr_creation:
  strategy: draft            # draft | ready | none
  auto_assign: true

monitoring:
  enabled: true              # poll checkpoint.json for phase transitions
  poll_interval_seconds: 1

posthoc:
  qa_review: conditional     # always | conditional | never
  qa_trigger: test_failure   # test_failure | breaking_change
  review_trigger: full_auto  # full_auto | always | never
  max_posthoc_per_feature: 2

review:
  enabled: true              # code review before PR creation
  max_cycles: 2              # review-fix iterations
  checklist_source: knowledge-base
```

Inline priority is also supported in feature titles: `## [FEAT] feat-001: My Feature [p:high]`

### How It Works

```
features.md → adapter → backlog.json → orchestrator loop:
  ┌──────────────────────────────────────────────────────┐
  │  for each feature (sorted by priority):              │
  │    1. Create isolated git worktree                   │
  │    2. Build context (cross-feature + behavioral      │
  │       rules from knowledge base + routing hints)     │
  │    3. Seed PRD from backlog description               │
  │    4. Start checkpoint monitor (background)          │
  │    5. Invoke feature-marker pipeline (monolithic)    │
  │    6. Stop monitor, sync phase state                 │
  │    7. Post-hoc QA (conditional, ~2,500 tokens)       │
  │    8. Safety check (breaking changes, schema, files) │
  │    9. Collect results from git state                 │
  │   10. Post-hoc review (full_auto only)               │
  │   11. Intelligent retry (QA analyzes before retry)   │
  │   12. Update knowledge base (patterns → rules)       │
  │   13. Create PR (if autonomy allows)                 │
  │   14. Cleanup worktree                               │
  └──────────────────────────────────────────────────────┘
  → status.json (Kanban) + terminal progress + benchmark
```

### Orchestrator Skills

The orchestrator's responsibilities are exposed as Claude Code skills for interactive
use within a Claude session. These skills read the same `.orchestrator/` state files
that the shell scripts use.

| Skill | Purpose | Example |
| ----- | ------- | ------- |
| `/kb-query` | Search learned error patterns and behavioral rules | `/kb-query "Cannot find module"` |
| `/kb-learn` | Teach new patterns from QA reports or manual input | `/kb-learn --from-qa feat-001` |
| `/kb-rules` | List, toggle, edit, prune behavioral rules | `/kb-rules list` |
| `/orch-status` | Dashboard: per-feature progress, metrics, history | `/orch-status --feature feat-005` |
| `/safety-check` | Analyze results.json for breaking changes, security issues | `/safety-check feat-001` |
| `/context-builder` | Build feature context with rules and routing hints | `/context-builder feat-001` |
| `/collect-results` | Collect pipeline results from git state and logs | `/collect-results feat-001` |

**How invocation works**: Skills are Claude Code SKILL.md files invoked within a Claude
session via slash commands (`/kb-query "module"`). When the orchestrator runs as a shell
script (`./scripts/orchestrator.sh`), it uses shell fallback functions that produce
identical results at zero token cost. Set `ORCHESTRATOR_USE_SKILLS=true` to delegate to
skills via `claude -p` (spawns a Claude session per call, ~7,500 tokens overhead each).

The main pipeline invocation (`/feature-marker prd-<id>`) always uses `claude -p` — that's
the core work. Post-hoc agents (`qa-reviewer`, `review-agent`) also use `claude -p` but are
lightweight (~2,500 tokens each) and conditional.

### Token Cost Model

The orchestrator uses a **monolithic invocation** — one `claude -p` session per feature
runs the entire PRD → TechSpec → Tasks → Implementation → Tests pipeline. This avoids
the 5-11x cost multiplier of per-phase splitting.

| Scenario (5 features) | Invocations | Token Overhead | vs Baseline |
| ---------------------- | ----------- | -------------- | ----------- |
| All succeed, no QA | 5 | ~37,500 | **1.0x** |
| + conditional QA | 5 + 5 lightweight | ~50,000 | **1.3x** |
| + QA + review (full_auto) | 5 + 10 lightweight | ~62,500 | **1.7x** |
| 2 failures + smart retry | 7 + 2 QA | ~57,500 | **1.5x** |
| Worst case (all fail) | 10 + 10 lightweight | ~100,000 | **2.7x** |
| Per-phase split (NOT used) | 25+ | ~187,500 | **5.0x** |

Token counts are context overhead (system prompt + agent definition + feature context
loading). Actual generation tokens depend on feature complexity.

**Cost controls in `config.yml`:**
- `posthoc.qa_review: never` — disables QA agent entirely
- `posthoc.review_trigger: never` — disables review agent
- `posthoc.max_posthoc_per_feature: 1` — caps lightweight invocations
- `ORCHESTRATOR_USE_SKILLS=false` (default) — skill operations run as shell, zero extra tokens

### Benchmark

| Metric | Baseline | With Orchestrator |
| ------ | -------- | ----------------- |
| Features per session | 1 | **5+** |
| Manual intervention per feature | ~10 touchpoints | **0** (checkpoint mode) |
| Context-aware task completion | ~60% | **85%+** |
| Cross-feature conflicts | Unknown | **<10%** |
| Time from backlog to PR | Manual | **<10min per feature** |

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
- **Multi-Feature Orchestrator** — Reads a backlog (Markdown, GitHub Issues, or Linear), creates isolated worktrees, and processes features autonomously with priority sorting and dependency resolution
- **Cross-Feature Context** — Each feature benefits from decisions made in previous features via automatic context propagation
- **Autonomy Levels** — Supervised (pause per phase), Checkpoint (human reviews PR), or Full Auto (end-to-end)
- **Safety Guardrails** — Breaking change detection pauses execution; schema change warnings; configurable retry limits; security anti-pattern scanning
- **Knowledge Base** — Structured error pattern learning with auto-derived behavioral rules; patterns that recur become rules injected into future features
- **Post-hoc QA & Review** — Lightweight agents verify implementation quality and analyze failures before retry; independent of the implementing agent
- **Intelligent Retry** — QA agent classifies root cause before retry; low-confidence failures escalate to human instead of blind retry
- **Orchestrator Skills** — Interactive Claude Code skills (`/kb-query`, `/kb-learn`, `/kb-rules`, `/orch-status`, `/safety-check`, `/context-builder`, `/collect-results`) for inspecting and managing orchestrator state within a Claude session
- **Status & Observability** — Real-time `status.json` for Kanban integration, terminal progress display, per-feature timing
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

**Feature documents** (per feature):

```
./tasks/prd-{feature-name}/
├── prd.md
├── techspec.md
└── tasks.md
```

**Feature-marker state** (checkpoint & progress):

```
.claude/feature-state/{feature-name}/
├── checkpoint.json
├── analysis.md
├── plan.md
├── progress.md
└── test-results.md
```

**Orchestrator** (multi-feature pipeline):

```
orchestrator/
└── config.yml                    # Declarative configuration

scripts/
├── orchestrator.sh               # Main loop controller (delegates to skills or fallbacks)
├── worktree-manager.sh           # Worktree lifecycle (create/remove/cleanup)
├── parse-config.js               # YAML config → shell vars
├── feedback-collector.sh         # Cross-feature context + error patterns
├── environment-discovery.sh      # Runtime environment manifest
├── status-writer.js              # status.json + terminal progress
├── route-tasks.sh                # Task routing to agents by capability
├── agent-discovery.sh            # Agent manifest discovery
├── lib/
│   ├── checkpoint-monitor.sh     # Background phase transition polling
│   ├── knowledge.sh              # Structured knowledge base (patterns + rules)
│   ├── qa.sh                     # Post-hoc QA agent invocation
│   ├── review.sh                 # Post-hoc code review agent
│   └── orchestrator-fallbacks.sh # Shell fallbacks for skill-delegated operations
└── adapters/
    ├── markdown.js               # Markdown backlog parser
    ├── github.js                 # GitHub Issues adapter (via gh CLI)
    └── linear.js                 # Linear adapter (via GraphQL)

schemas/
├── backlog-item-schema.json      # Canonical backlog item schema
└── results-schema.json           # Pipeline results schema (v2)

.orchestrator/                    # Generated at runtime
├── status.json                   # Real-time Kanban data
├── global-context.md             # Cross-feature context accumulator
├── knowledge-base.json           # Structured error patterns + learned rules
├── behavioral-rules.json         # Auto-derived rules from recurring patterns
├── error-patterns.json           # Legacy error tracking (migrated to knowledge base)
├── environment.manifest.json     # Runtime environment snapshot
├── state/{feature-id}/           # Per-feature state
│   ├── status.json
│   ├── context.md
│   ├── results.json
│   ├── qa-report.json            # QA analysis (if triggered)
│   ├── review-report.json        # Code review (if triggered)
│   └── logs/
│       ├── run-*.log
│       └── phases.log            # Phase transition log
└── results/                      # Collected run logs
```

**Agents** (lightweight post-hoc verification):

```
feature-marker-dist/agents/
├── feature-marker.md             # Main pipeline agent
├── qa-reviewer.md                # Post-hoc QA verification (~2,500 tokens)
└── review-agent.md               # Post-hoc code review (~2,500 tokens)
```

**Orchestrator Skills** (interactive Claude Code skills):

```
feature-marker-dist/.../skills/
├── kb-query/SKILL.md             # Search knowledge base
├── kb-learn/SKILL.md             # Teach new patterns
├── kb-rules/SKILL.md             # Manage behavioral rules
├── context-builder/SKILL.md      # Build feature context
├── safety-check/SKILL.md         # Analyze safety concerns
├── collect-results/SKILL.md      # Collect pipeline results
└── orch-status/SKILL.md          # Orchestration status dashboard
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
