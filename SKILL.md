---
name: feature-marker
description: >
  Skill-first feature workflow for PRD, TechSpec, Tasks, implementation,
  verification, local commit, and branch handoff across Claude, Codex, and
  Gemini. The npm package installs skill files only; the LLM skill owns the
  workflow.
---

# feature-marker

Use this skill when the user asks to plan, build, test, or hand off a feature
through `PRD -> TechSpec -> Tasks -> branch handoff`.

The workflow is skill-first. Do not use the old CLI workflow commands; those
are not product commands. The npm package is only an installer for this skill.

## Operating Contract

1. Start by reading repo state: current branch, git status, project files, and
   any existing `tasks/{slug}/prd.md`, `tasks/{slug}/techspec.md`, and
   `tasks/{slug}/tasks.md`.
2. Keep artifact state in `tasks/{slug}/`. Generate missing artifacts in order:
   PRD first, then TechSpec, then Tasks. Reuse existing artifacts unless the
   user explicitly asks to revise them.
3. Use branch-first isolation. If the current branch is `main`, `master`,
   `develop`, or `trunk`, create a feature branch named `feature-marker/{slug}`
   unless the user gives another branch name. If the checkout has unrelated
   uncommitted changes, ask whether to create a git worktree or continue on the
   existing branch after the user cleans up.
4. Implement only the tasks in `tasks/{slug}/tasks.md`. Keep changes scoped to
   the feature and preserve unrelated local edits.
5. Run the project-appropriate verification commands. If a command cannot run,
   report the exact blocker and do not claim it passed.
6. Finish with a local commit when the implementation is complete and the user
   has not prohibited commits. Do not push or open a PR automatically.
7. Print exact handoff commands, including:

```bash
git push -u origin <branch>
gh pr create --base <base-branch> --head <branch>
```

## Artifact State

The canonical state lives in:

```text
tasks/{slug}/
  prd.md
  techspec.md
  tasks.md
```

Optional notes such as verification output may also live under `tasks/{slug}/`
when they help future continuation, but do not create checkpoint JSON as the
source of truth.

## Modes by Prompt

There are no CLI modes. Treat these as prompt intents:

- `full`: create or update PRD, TechSpec, and Tasks, then implement, test, and
  hand off the branch.
- `tasks-only`: use existing artifacts and implement the tasks.
- `test-only`: run verification for the existing feature branch and summarize
  results.
- `prd-only`: stop after the PRD artifact.

`spec-driven` and `ralph-loop` are out of scope for this skill-first v1 unless
they are rebuilt as explicit skill instructions.
