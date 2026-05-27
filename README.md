# feature-marker - Native feature workflows for Claude, Codex, and Gemini.

![feature-marker Banner](assets/banner.svg)

[![npm package](https://img.shields.io/npm/v/@viniciuscarvalho/feature-marker?logo=npm&logoColor=white&style=flat-square)](https://www.npmjs.com/package/@viniciuscarvalho/feature-marker)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue?style=flat-square)](LICENSE)
[![node >=18](https://img.shields.io/badge/node-%3E%3D18.0.0-2ea44f?logo=node.js&logoColor=white&style=flat-square)](https://nodejs.org/)
[![Claude Code](https://img.shields.io/badge/runtime-Claude_Code-6f42c1?style=flat-square)](https://www.anthropic.com/claude-code)
[![Codex](https://img.shields.io/badge/runtime-Codex-111111?style=flat-square)](https://openai.com/codex/)
[![Gemini](https://img.shields.io/badge/runtime-Gemini-4285f4?style=flat-square)](https://gemini.google.com/)

feature-marker turns one feature slug into a repeatable workflow: plan,
implement, test, and finish on a clean branch. The CLI owns the state machine,
while Claude, Codex, and Gemini act as runtime adapters for phase execution.

## What you get

- Native adapters for Claude Code, Codex, and Gemini.
- One CLI-owned workflow contract across all runtimes.
- Isolated git worktree per feature under `.feature-marker/worktrees/{slug}`.
- Runtime-neutral checkpoints, prompts, logs, and platform context under `.feature-marker/features/{slug}`.
- User-facing PRD, TechSpec, and Tasks artifacts under `tasks/{slug}/`.
- Branch-only delivery with a local commit and exact push/PR handoff commands.
- Deterministic tests that validate mode handling, checkpoint resume, worktree safety, platform detection, and adapter installation.

## Use in any project

You do not need a global install. Run feature-marker through `npx` from any git
repo:

```bash
npx -y @viniciuscarvalho/feature-marker install --runtime all
npx -y @viniciuscarvalho/feature-marker run my-feature --mode full --runtime codex
npx -y @viniciuscarvalho/feature-marker status my-feature
```

Install only one runtime adapter when you do not need all three:

```bash
npx -y @viniciuscarvalho/feature-marker install --runtime claude
npx -y @viniciuscarvalho/feature-marker install --runtime codex
npx -y @viniciuscarvalho/feature-marker install --runtime gemini
```

Prefer the short `feature-marker` command only if you install the package
globally:

```bash
npm install -g @viniciuscarvalho/feature-marker
feature-marker run my-feature --mode full --runtime codex
```

Check the runtime capability contract with either form:

```bash
npx -y @viniciuscarvalho/feature-marker capabilities
```

## Quick start

Run a complete workflow with Codex:

```bash
npx -y @viniciuscarvalho/feature-marker run native-adapters --mode full --runtime codex
```

Resume a feature from its checkpoint:

```bash
npx -y @viniciuscarvalho/feature-marker resume native-adapters
```

Inspect status as text or JSON:

```bash
npx -y @viniciuscarvalho/feature-marker status native-adapters
npx -y @viniciuscarvalho/feature-marker status native-adapters --json
```

Run from inside an LLM prompt:

```text
Use feature-marker to implement this feature:
npx -y @viniciuscarvalho/feature-marker run billing-observability --runtime codex --mode full
```

```text
Use feature-marker to resume the workflow:
npx -y @viniciuscarvalho/feature-marker resume billing-observability
```

## Command reference

| Command | Key flags | What it does |
| --- | --- | --- |
| `install` | `--runtime claude\|codex\|gemini\|all` | Installs native adapter assets for the selected runtime. |
| `run <slug>` | `--mode`, `--runtime`, `--dry-run` | Creates or resumes an isolated feature workflow. |
| `resume <slug>` | `--dry-run` | Continues from `.feature-marker/features/{slug}/checkpoint.json`. |
| `status <slug>` | `--json` | Prints checkpoint status, branch, worktree, mode, and runtime. |
| `capabilities` | none | Prints the runtime and mode capability manifest as JSON. |
| `--help` | none | Prints CLI usage. |
| `--version` | none | Prints the installed feature-marker version. |

All commands in the table work with either `feature-marker ...` after a global
install or `npx -y @viniciuscarvalho/feature-marker ...` without one.

## Modes

| Mode | Phases | Use when |
| --- | --- | --- |
| `full` | plan, implement, test, branch | Starting from a feature idea or missing artifacts. |
| `tasks-only` | implement, test, branch | `tasks/{slug}/prd.md`, `techspec.md`, and `tasks.md` already exist. |
| `test-only` | test | You only need verification in the isolated worktree. |
| `prd-only` | plan | You want a PRD draft and no implementation. |

`spec-driven` and `ralph-loop` are not native-adapter v1 modes. Do not rely on
them until they are rebuilt on the CLI state machine.

## State and artifacts

```text
tasks/{slug}/
  prd.md
  techspec.md
  tasks.md

.feature-marker/features/{slug}/
  checkpoint.json
  platform-context.json
  logs/

.feature-marker/worktrees/{slug}
```

Branches default to:

```text
feature-marker/{slug}
```

The branch phase commits local feature changes and prints handoff commands. It
does not push or open remote PRs automatically.

## Configuration

Create `.feature-marker.json` in your project root when defaults are not enough:

```json
{
  "base_branch": "origin/main",
  "worktrees_path": ".feature-marker/worktrees",
  "branch_prefix": "feature-marker",
  "default_runtime": "codex",
  "mode_defaults": {},
  "capabilities": {},
  "docs_path": "./tasks",
  "state_path": ".feature-marker/features"
}
```

## Runtime adapters

- Claude adapter assets install under `~/.claude/skills/feature-marker` and `~/.claude/agents/feature-marker.md`.
- Codex adapter assets install under `~/.codex/skills/feature-marker`.
- Gemini adapter assets install under `~/.gemini/skills/feature-marker`.
- All adapters delegate workflow authority to the CLI. They should not edit checkpoint files directly.

## Verification

Run the deterministic suite:

```bash
npm test
```

Package smoke:

```bash
npm pack --dry-run --json
```

Adapter matrix smoke without model calls:

```bash
FEATURE_MARKER_ADAPTER_MOCK=1 npx -y @viniciuscarvalho/feature-marker run demo --mode full --runtime codex
```

See [feature-marker-dist/HEALTH.md](feature-marker-dist/HEALTH.md) for the
latest recorded verification matrix.

## Learn more

- Distribution notes: [feature-marker-dist/README.md](feature-marker-dist/README.md)
- Health report: [feature-marker-dist/HEALTH.md](feature-marker-dist/HEALTH.md)
- Capability manifest: [feature-marker-dist/capabilities.json](feature-marker-dist/capabilities.json)
- Config schema: [schemas/config.schema.json](schemas/config.schema.json)
- Checkpoint schema: [schemas/checkpoint.schema.json](schemas/checkpoint.schema.json)

## Development basics

Requirements:

- Node.js 18+
- Git
- Optional runtime CLIs for non-mocked execution: `claude`, `codex`, `gemini`

Common checks:

```bash
npm test
node bin/cli.js --help
node bin/cli.js capabilities
```

## License

MIT
