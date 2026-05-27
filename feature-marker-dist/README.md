# Feature-Marker Distribution

This distribution contains native adapter assets for Claude, Codex, and Gemini.
The `feature-marker` CLI is the workflow authority.

## Commands

```bash
feature-marker install --runtime claude|codex|gemini|all
feature-marker run <slug> --mode full|tasks-only|test-only|prd-only --runtime claude|codex|gemini
feature-marker status <slug>
feature-marker resume <slug>
feature-marker capabilities
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
