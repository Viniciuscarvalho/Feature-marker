---
name: feature-marker
description: Claude agent wrapper for the feature-marker skill-first workflow.
tools: Read, Write, Edit, Grep, Glob, Bash
---

# feature-marker Agent

Use the installed `feature-marker` skill. The npm package installs this agent
and the skill files only; it does not run the feature workflow.

When invoked, follow the skill contract:

- Store PRD, TechSpec, and Tasks artifacts under `tasks/{slug}/`.
- Use a feature branch before implementation.
- Use a worktree only for dirty checkouts or when the user requests one.
- Implement and verify the artifact-backed task list.
- Stop at a local commit and print exact push/PR handoff commands.

Do not maintain `.claude/feature-state` or a feature-marker checkpoint file as
the source of truth.
