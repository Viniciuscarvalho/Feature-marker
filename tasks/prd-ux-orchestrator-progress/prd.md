# PRD: Orchestrator Progress & Guidance UX

## Problem

When `feature-marker-orchestrate run --autonomy full_auto` runs a backlog, operators face three distinct pain points:

1. **Silent pipeline**: After `[orchestrate] Autonomy=full_auto — invoking pipeline…` nothing appears on screen for 5–15 minutes. Claude is working (files appear in the worktree) but the terminal looks frozen.

2. **No "what next" instruction**: After a feature completes (e.g. feat-auth), the run ends showing 4 remaining "ready (awaiting-pipeline)" features but prints no command to continue. The operator doesn't know whether to re-run, wait, or do something else. The cycle-gate block is especially opaque — it says "Stopping backlog loop" with no actionable guidance.

3. **Misleading summary stats**: The final `Orchestrator Summary` shows `Avg: 68s/feature` when only 1 feature ran in 344s. `processed` counts all features with state directories, not the ones that actually ran this invocation.

## Goals

1. **Eliminate "looks frozen" during Claude runs.** Operator should see meaningful progress every ≤ 45 seconds without needing to check a separate file.

2. **Print an actionable "what next" block after every feature and at end-of-run.** Operator reads the terminal and knows exactly what command to run, or sees a clear "all done" confirmation.

3. **Fix summary stat accuracy.** `Avg` and `Total` reflect only the features that ran in the current invocation.

4. **Show full backlog status at phase transitions.** When a feature finishes and the next one starts, print a compact table showing all features and their statuses so the operator has a mental model of progress.

## Non-Goals

- A full TUI / ncurses dashboard (too fragile across terminal emulators)
- Streaming Claude's internal token-by-token output (not available without stream-json mode change)
- A web UI or external monitoring service
- Changes to cycle-gate business logic (only messaging is in scope)

## Success Criteria

- After `invoking pipeline…` the operator sees at least one `[progress]` heartbeat within 45s (already implemented — this PRD ensures it's complete and consistent).
- After every `[orchestrate] Done: feat-*` line, a "Next steps" block is printed.
- The block includes the exact command to run next (or "all features complete").
- When cycle-gate blocks, the printed command includes `--skip-cycle-check` with a one-line explanation.
- `Avg` in the final summary equals `Total ÷ (features that ran this invocation)`, not total state-dir count.
- At each feature-start banner, a compact backlog table is shown (id, status, phase, cost).
