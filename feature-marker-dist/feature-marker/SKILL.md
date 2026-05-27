---
name: feature-marker
description: >
  Native Claude adapter for the feature-marker CLI state machine. Use for
  feature workflows that need PRD, TechSpec, Tasks, isolated git worktrees,
  checkpoint/resume, tests, and clean branch-only delivery.
tools: Read, Write, Edit, Grep, Glob, Bash
---

# feature-marker

The `feature-marker` CLI is the workflow authority. It owns runtime-neutral
state in `.feature-marker/features/{slug}`, creates an isolated worktree for
each feature, invokes runtime phase prompts, and ends with a clean committed
branch plus push/PR handoff commands.

## Usage

```bash
feature-marker run <feature-slug> --runtime claude --mode full
feature-marker resume <feature-slug>
feature-marker status <feature-slug>
```

Supported modes:

- `full` - plan, implement, test, branch handoff
- `tasks-only` - implement existing PRD/TechSpec/Tasks, test, branch handoff
- `test-only` - run verification only
- `prd-only` - draft PRD only

`spec-driven` and `ralph-loop` are not v1 native-adapter modes. Do not claim
they are supported unless rebuilt on the CLI state machine.

## State Contract

- Artifacts: `tasks/{slug}/prd.md`, `techspec.md`, `tasks.md`
- Checkpoints: `.feature-marker/features/{slug}/checkpoint.json`
- Logs/prompts: `.feature-marker/features/{slug}/logs/`
- Worktrees: `.feature-marker/worktrees/{slug}`
- Branches: `feature-marker/{slug}` by default

Do not write checkpoint state directly. If a phase prompt asks Claude to work,
keep changes inside the feature worktree and let the CLI update the checkpoint.
