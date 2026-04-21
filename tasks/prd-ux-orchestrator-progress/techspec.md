# TechSpec: Orchestrator Progress & Guidance UX

## Architecture Overview

All changes are confined to:

- `scripts/lib/runner.sh` — run_backlog(), run_feature(), display_summary()
- `scripts/lib/display.sh` — new display_backlog_table(), enhanced display_summary()
- `scripts/orchestrate.sh` — cycle-gate messaging block

No new files, no external dependencies, no changes to state file formats.

---

## Change 1: Backlog Status Table at Feature Start

**Location:** `scripts/lib/display.sh` + called from `run_feature()` in `runner.sh`

### New function: `display_backlog_table()`

Reads all `$STATE_DIR/*/status.json` and `$STATE_DIR/*/cost.json` files and prints a compact table.

```
  ┌────────────────────────────────────────────────────────────────┐
  │  BACKLOG  [2/5 done]  total ~134,000 tokens                   │
  ├──────────────────┬──────────────┬──────────────┬──────────────┤
  │  Feature         │  Status      │  Phase       │  Tokens      │
  ├──────────────────┼──────────────┼──────────────┼──────────────┤
  │  feat-auth       │  ✓ done      │  complete    │   67,000     │
  │  feat-export     │  → active    │  impl.       │   25,000     │
  │  feat-profile    │  · ready     │  pending     │       —      │
  │  feat-search     │  · ready     │  pending     │       —      │
  │  feat-settings   │  · ready     │  pending     │       —      │
  └──────────────────┴──────────────┴──────────────┴──────────────┘
```

**Implementation:**

- Pure bash + `node -p` (already used throughout the codebase) to read JSON
- Column widths fixed (no dynamic sizing needed)
- Status icons: `✓` done/pr-created, `→` in-progress, `✗` failed, `·` ready/pending, `⏸` paused
- Tokens column: reads `cost.json` cumulative field; shows `—` if file absent
- Called at the top of `run_feature()` after the `banner "[$index/$total]..."` line

### Call site in `run_feature()` (`runner.sh` ~line 232):

```bash
banner "[$index/$total] $feat_id: $title [$priority]"
display_backlog_table   # NEW — shows full backlog state before starting this feature
```

`display_backlog_table` needs `$STATE_DIR` — already exported globally.

---

## Change 2: "Next Steps" Block After Each Feature

**Location:** end of `run_feature()` in `runner.sh`, after the `info "Feature time: ${duration}s"` line.

### New function: `display_next_steps()` in `display.sh`

Arguments: `feat_id` `exit_code` `next_feat_id` (empty string if last feature)

```
  ┌──────────────────────────────────────────────────────────────┐
  │  feat-auth: DONE  (340s · 67,000 tokens)                     │
  ├──────────────────────────────────────────────────────────────┤
  │  Next feature: feat-export                                   │
  │                                                              │
  │  Re-run the same command to continue:                        │
  │                                                              │
  │    feature-marker-orchestrate run --autonomy full_auto       │
  └──────────────────────────────────────────────────────────────┘
```

When no next feature (all done):

```
  ┌──────────────────────────────────────────────────────────────┐
  │  All features complete.                                      │
  │  Run `feature-marker-orchestrate status` to review results.  │
  └──────────────────────────────────────────────────────────────┘
```

**Implementation:**

- Reads `$STATE_DIR/*/status.json` to find the next non-done feature
- Reconstructs the exact CLI invocation by reading `$AUTONOMY`, `$MODEL_DEFAULT`, `$ADAPTER`
- Prints the command verbatim so operator can copy-paste

### Call site in `run_feature()`:

```bash
info "Feature time: ${duration}s"
display_next_steps "$feat_id" "$exit_code" "$next_feat_id"   # NEW
```

`next_feat_id` is the next item from the backlog loop — passed into `run_feature()` as a new optional 9th argument. If absent (last feature), `display_next_steps` prints the "all done" variant.

---

## Change 3: Cycle-Gate Block Messaging

**Location:** `runner.sh` ~line 155, inside the cycle-gate check block.

### Current code:

```bash
info "Cycle gate: $feat_id_check did not complete full cycle"
cycle_gate_report "$feat_id_check"
info "Use --skip-cycle-check to bypass. Stopping backlog loop."
break
```

### New code:

```bash
info "Cycle gate: $feat_id_check did not complete full cycle"
cycle_gate_report "$feat_id_check"
echo ""
echo "  ⚠  Cycle gate blocked advancement to the next feature."
echo "     This happens when the previous feature has no merged PR or incomplete phases."
echo ""
echo "     To continue anyway:"
echo "       feature-marker-orchestrate run --autonomy $AUTONOMY --skip-cycle-check"
echo ""
break
```

The existing `--skip-cycle-check` flag is already implemented — this just makes it discoverable.

---

## Change 4: Fix Summary `processed` Count

**Location:** `runner.sh`, the code block that calls `display_summary()`.

### Root cause:

`processed` is calculated as `done_n + pr_n + ready_n + failed_n` — counting ALL features with state dirs. Should count only features that were in the backlog this invocation.

### Fix:

Track a `ran_count` counter inside `run_backlog()` that increments only when `process_item()` actually calls `run_feature()` (i.e., the feature was not skipped as already-done). Pass `ran_count` to `display_summary()` as the `processed` argument instead of the current aggregate.

**In `run_backlog()`:**

```bash
local ran_count=0

# Inside the loop, after process_item():
ran_count=$((ran_count + 1))

# At summary:
display_summary "$done_n" "$pr_n" "$ready_n" "$failed_n" "$total_time" "$ran_count"
```

Skipped features (already done/pr-created) do NOT increment `ran_count`.

---

## Change 5: Enhanced `display_summary()` Column

**Location:** `display.sh`, `display_summary()`.

Add a "Ran this session" row between the counts and the timing:

```
  │  Ran this session: 1                     │
```

This makes it unambiguous that `Avg` refers only to features processed in this run.

---

## Data Dependencies

| What                      | Source                                          | Already exists?  |
| ------------------------- | ----------------------------------------------- | ---------------- |
| Feature status            | `$STATE_DIR/$id/status.json`                    | Yes              |
| Cumulative tokens         | `$STATE_DIR/$id/cost.json` `.cumulative_tokens` | Yes              |
| Next feature ID           | Backlog JSON, passed from `run_backlog()`       | Needs threading  |
| Run invocation flags      | `$AUTONOMY`, `$MODEL_DEFAULT`, `$ADAPTER`       | Exported globals |
| Features ran this session | New `ran_count` local in `run_backlog()`        | New              |

---

## Testing

1. Run stub-project with 5 features in full_auto → verify backlog table appears at each feature start
2. Kill run mid-backlog → re-run → verify "next steps" block shows correct next feature
3. Force cycle-gate block → verify new messaging with copy-paste command appears
4. Single-feature run (1 feature done, 0 remaining) → verify "all features complete" block
5. `Avg` = `Total ÷ ran_count` for any subset of features processed
