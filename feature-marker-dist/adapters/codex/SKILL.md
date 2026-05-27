---
name: feature-marker
description: >
  Codex-ready install target for the feature-marker skill-first workflow.
  Use from a Codex prompt; the npm package is only the installer.
tools: Read, Write, Edit, Grep, Glob, Bash
---

# feature-marker for Codex

Use this skill from inside Codex prompts, for example:

```text
Use feature-marker to plan and implement billing-observability.
```

Follow the portable feature-marker contract:

- Keep workflow artifacts in `tasks/{slug}/prd.md`,
  `tasks/{slug}/techspec.md`, and `tasks/{slug}/tasks.md`.
- Work branch-first. Create or require a feature branch before implementation.
- Use a git worktree only when the current checkout is dirty or the user asks.
- Implement, verify, and finish with a local commit plus exact push/PR commands.
- Do not push, open a PR, or create checkpoint JSON automatically.

`spec-driven` and `ralph-loop` are out of scope for this skill-first v1 unless
they are rebuilt as explicit skill instructions.
