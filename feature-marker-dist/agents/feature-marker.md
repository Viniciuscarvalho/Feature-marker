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

**Checkpoint found** — read `current_phase`, `phase_status`, and `mode`. Show:

> Checkpoint found for `{slug}`: currently at **{current_phase}** ({phase_status}). Resume here? **[yes / start fresh]**

On "start fresh": delete the checkpoint file and proceed as new.

**Mode precedence**: `EXECUTION_MODE` env var (set by `--mode` flag or menu selection) always wins. If `EXECUTION_MODE` is unset, use `checkpoint.mode` as the default. `phase_status=completed` still gates within-mode phases regardless of which source set the mode.

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

On "change path": ask one open question — accept a free-form response. (An opt-in menu is available via `feature-marker.sh --menu <slug>` or `-i`; the agent never invokes it automatically.)

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

**Before entering the loop**, read `~/.claude/skills/feature-marker/lib/modes.json` and find the entry matching `EXECUTION_MODE` (default `"full"`). Derive the run list:

```
run_list = [plan, implement, test, pr]
           starting at entry field
           minus skipped array
```

Example: `prd-only` → `entry="plan"`, `skipped=["implement","test","pr"]` → `run_list=["plan"]`.

This filter happens once, before any phase file is loaded. Never load a phase file for a phase outside `run_list`.

**For each phase in run_list**:

1. Check checkpoint — if status is `completed`, skip it
2. If status is `error`, show the saved `error_state` message. Ask: "Retry this phase or skip it?"
3. Read the phase instructions:
   ```
   ~/.claude/skills/feature-marker/agents/phases/{phase}-agent.md
   ```
4. Follow those instructions for the feature slug `{slug}`
5. On completion, update checkpoint: `current_phase={phase}`, `phase_status=completed`

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
