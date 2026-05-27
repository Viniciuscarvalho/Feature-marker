---
name: feature-marker
description: >
  Gemini-ready install target for the feature-marker run-through skill workflow.
  Use from a Gemini prompt; the npm package is only the installer.
---

# feature-marker for Gemini

Use this skill from inside Gemini prompts:

```text
Use feature-marker to implement billing-observability.
```

Run the complete flow by default:

- Create or reuse `tasks/{slug}/prd.md`, `tasks/{slug}/techspec.md`, and
  `tasks/{slug}/tasks.md`.
- Create or require a feature branch before implementation.
- Use a git worktree only when the checkout is dirty or the user asks.
- Continue from artifacts to implementation without stopping for approval.
- Stop only for true ambiguity, unrelated dirty work, or blocked verification.
- Run verification, commit locally, and print exact push/PR handoff commands.
- Do not push, open a PR, create checkpoint JSON, or use an interactive menu.

`spec-driven` and `ralph-loop` are out of scope for this skill-first v1 unless
they are rebuilt as explicit skill instructions.
