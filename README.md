# feature-marker

Native-adapter feature workflow CLI for Claude, Codex, and Gemini.

feature-marker owns the workflow state machine: it creates an isolated git
worktree per feature, stores runtime-neutral checkpoints, generates phase
prompts for the selected runtime, detects the project platform, and finishes
with a clean committed branch plus push/PR handoff commands.

## Install

```bash
npx @viniciuscarvalho/feature-marker install --runtime all
```

Install one runtime adapter:

```bash
feature-marker install --runtime claude
feature-marker install --runtime codex
feature-marker install --runtime gemini
```

## Run

```bash
feature-marker run my-feature --mode full --runtime codex
feature-marker status my-feature
feature-marker resume my-feature
```

Supported v1 modes:

| Mode | Phases |
| --- | --- |
| `full` | Plan, implement, test, branch handoff |
| `tasks-only` | Implement existing artifacts, test, branch handoff |
| `test-only` | Test only |
| `prd-only` | PRD only |

`spec-driven` and `ralph-loop` are not native-adapter v1 modes. They should not
be treated as supported until rebuilt on the shared CLI state machine.

## State Contract

User-facing artifacts stay in:

```text
tasks/{slug}/
  prd.md
  techspec.md
  tasks.md
```

Runtime-neutral state lives in:

```text
.feature-marker/features/{slug}/
  checkpoint.json
  platform-context.json
  logs/
```

Feature work runs in:

```text
.feature-marker/worktrees/{slug}
```

Branches default to:

```text
feature-marker/{slug}
```

## Configuration

`.feature-marker.json` remains optional:

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

## Verification

```bash
npm test
```

The test suite validates mode handling, checkpoint transitions, worktree
creation/resume, dirty-worktree refusal, capability preflight, platform-context
generation, and runtime adapter installation. It uses a mocked adapter path so
tests do not depend on model calls or global authentication.
