# Implement Phase

Execute the implementation plan produced by the plan phase.

---

## Setup

Read `.claude/feature-state/{slug}/plan.md` and `./tasks/{slug}/tasks.md`.

Check the checkpoint for `current_task_index` — if set, resume from that task index rather than starting from the beginning.

---

## Execution

Use TodoWrite to track progress across all tasks.

For each task in `tasks.md` (and individual `{num}_task.md` files if present):

1. Mark the task as in-progress in TodoWrite
2. Make the required changes using read and edit operations
3. Verify the task's stated success criteria before marking it done
4. Mark the task as complete in TodoWrite
5. Update checkpoint: `current_task_index={n}`, `total_tasks={total}`

Apply `CLAUDE.md` conventions for code style, naming patterns, and architecture decisions throughout.

If a task's success criteria cannot be met (missing dependency, blocker, ambiguous requirement), pause and ask the user before continuing.

---

## Outputs

Save `.claude/feature-state/{slug}/progress.md` with:

- Summary of what was implemented
- Files created or modified
- Any deviations from the plan and why

Update checkpoint: `current_phase=implement`, `phase_status=completed`.
