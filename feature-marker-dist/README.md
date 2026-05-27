# Feature-Marker Distribution

This distribution contains native adapter assets for Claude, Codex, and Gemini.
The `feature-marker` CLI is the workflow authority.

## Use with npx

```bash
npx -y @viniciuscarvalho/feature-marker install --runtime claude|codex|gemini|all
npx -y @viniciuscarvalho/feature-marker run <slug> --mode full|tasks-only|test-only|prd-only --runtime claude|codex|gemini
npx -y @viniciuscarvalho/feature-marker status <slug>
npx -y @viniciuscarvalho/feature-marker resume <slug>
npx -y @viniciuscarvalho/feature-marker capabilities
```

Global install is optional:

```bash
npm install -g @viniciuscarvalho/feature-marker
feature-marker run <slug> --mode full --runtime codex
```

## Runtime State

- Artifacts: `tasks/{slug}/prd.md`, `techspec.md`, `tasks.md`
- Checkpoints/logs: `.feature-marker/features/{slug}/`
- Worktrees: `.feature-marker/worktrees/{slug}`
- Branches: `feature-marker/{slug}` by default

The branch phase commits local feature changes and prints handoff commands. It
does not push or open remote PRs automatically.

## v1 Modes

| Mode | Description |
| --- | --- |
| `full` | Plan, implement, test, branch handoff |
| `tasks-only` | Implement existing artifacts, test, branch handoff |
| `test-only` | Run verification only |
| `prd-only` | Draft PRD only |

`spec-driven` and `ralph-loop` are intentionally excluded from v1 parity until
they are rebuilt on the neutral state machine.
