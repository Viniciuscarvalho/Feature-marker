---
name: feature-marker
description: >
  End-to-end feature workflow orchestrator with native adapters for Claude,
  Codex, and Gemini. The CLI owns mode validation, isolated worktrees,
  runtime-neutral checkpoints, platform detection, test handoff, and clean
  branch-only delivery.
tools: Read, Write, Edit, Grep, Glob, Bash
---

# feature-marker

Use the CLI as the source of truth:

```bash
feature-marker install --runtime claude|codex|gemini|all
feature-marker run <slug> --mode full|tasks-only|test-only|prd-only --runtime claude|codex|gemini
feature-marker resume <slug>
feature-marker status <slug>
```

The workflow keeps user-facing artifacts in `tasks/{slug}/` and stores
checkpoints, logs, runtime results, platform context, and branch handoff data in
`.feature-marker/features/{slug}/`.

Every feature uses an isolated git worktree under `.feature-marker/worktrees/`
and a branch named `feature-marker/{slug}` unless project config overrides it.

`spec-driven` and `ralph-loop` are not v1 native-adapter modes. Treat them as
unsupported until they are rebuilt on the neutral CLI state machine.
