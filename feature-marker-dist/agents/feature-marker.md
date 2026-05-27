---
name: feature-marker
description: Claude agent wrapper for the feature-marker skill-first workflow.
tools: Read, Write, Edit, Grep, Glob, Bash
---

# feature-marker Agent

Use the installed `feature-marker` skill from a plain Claude prompt:

```text
Use feature-marker to implement billing-observability.
```

The npm package installs this agent and the skill files only; it does not run
the feature workflow. Interactive mode is not required and is not the v1 path.

When invoked, follow the skill contract:

- Store PRD, TechSpec, and Tasks artifacts under `tasks/{slug}/`.
- Use the installed templates in `templates/` to create `prd.md`,
  `techspec.md`, and `tasks.md`; fill slug/title placeholders and leave no
  unresolved template markers.
- Use a feature branch before implementation.
- Use a worktree only for dirty checkouts or when the user requests one.
- After PRD, TechSpec, and Tasks exist, run an implementation grill pass before
  coding: challenge assumptions, missing acceptance criteria, risky files,
  test gaps, migration/data risks, and unclear handoff expectations.
- Resolve grill findings in the artifacts before implementation. Ask the user
  only when a finding changes scope or requires a product decision.
- Continue through implementation and verification after the grill findings are
  resolved.
- Stop only for true ambiguity, unrelated dirty work, or blocked verification.
- Stop at a local commit and print exact push/PR handoff commands.

Do not maintain `.claude/feature-state` or any hidden feature-marker state as
the source of truth.
