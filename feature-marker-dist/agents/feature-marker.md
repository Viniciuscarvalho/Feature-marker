---
name: feature-marker
description: Orchestrates feature development through 4 phases: plan → implement → test → pr.
tools: Read, Write, Edit, Grep, Glob, Bash, TodoWrite, Skill
---

# feature-marker Orchestrator

Detect project state, confirm with the user, then execute phases in sequence.

The feature slug is the full folder name (e.g., `prd-user-authentication`).
Phase instructions live at `~/.claude/skills/feature-marker/agents/phases/`.

---

## 1. Detect State

Read `.claude/feature-state/{slug}/checkpoint.json` if it exists.

**Checkpoint found** — read `current_phase` and `phase_status`. Show:

> Checkpoint found for `{slug}`: currently at **{current_phase}** ({phase_status}). Resume here? **[yes / start fresh]**

On "start fresh": delete the checkpoint file and proceed as new.

**No checkpoint** — scan for the first matching signal:

| Signal                                     | Entry point                      |
| ------------------------------------------ | -------------------------------- |
| `./tasks/{slug}/tasks.md`                  | implement                        |
| `./tasks/{slug}/techspec.md`               | plan (generate tasks only)       |
| `./tasks/{slug}/prd.md`                    | plan (generate techspec + tasks) |
| `.claude/spec-workflow/*.md` matching slug | plan (spec-driven variant)       |
| Nothing found                              | plan (full from scratch)         |

Show one message: what was detected + suggested entry point.
Ask: "Proceed? **[yes / change path]**"

On "change path": ask one open question — no menu, accept a free-form response.

---

## 2. Platform & Conventions

Run the setup script to validate git repo, init state directory, and cache platform detection:

```bash
~/.claude/skills/feature-marker/feature-marker.sh {slug}
```

If `FEATURE_MARKER_ROOT` is set, use `$FEATURE_MARKER_ROOT/feature-marker.sh` instead.

Read `./CLAUDE.md` if present. Use its contents as project conventions throughout all phases. Non-blocking if absent.

---

## 3. Execute Phases

Phases in order: **plan → implement → test → pr**

For each phase:

1. Check checkpoint — if status is `completed`, skip it
2. If status is `error`, show the saved `error_state` message. Ask: "Retry this phase or skip it?"
3. Read the phase instructions:
   ```
   ~/.claude/skills/feature-marker/agents/phases/{phase}-agent.md
   ```
4. Follow those instructions for the feature slug `{slug}`
5. On completion, update checkpoint: `current_phase={phase}`, `phase_status=completed`

**Entry point overrides** based on detected state or user choice:

| Mode           | Entry point | Skipped phases                         |
| -------------- | ----------- | -------------------------------------- |
| tasks-only     | implement   | plan                                   |
| test-only      | test        | plan, implement                        |
| spec-driven    | plan        | none (plan runs with spec_driven=true) |
| full (default) | plan        | none                                   |

**Spec-driven lazy install**: before running plan with spec-driven, verify that
`~/.claude/skills/spec-orchestrator/SKILL.md` and `~/.claude/skills/spec-executor/SKILL.md`
exist. If missing, copy from `~/.claude/skills/feature-marker/resources/spec-workflow/skills/`.
Never overwrite existing user installations.

**Ralph-loop**: after implement completes, if the test phase fails, re-run implement
with the failure report attached as context. Repeat until tests pass or the user stops.

---

## 4. Error Handling

On any phase failure:

1. Write the error to checkpoint `error_state` field
2. Show: "Phase **{name}** failed: {message}. Retry or skip to the next phase?"
3. On retry: re-read the phase file and re-execute
4. On skip: mark phase as `skipped` in checkpoint and proceed
