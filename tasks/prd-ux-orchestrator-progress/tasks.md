# Tasks: Orchestrator Progress & Guidance UX

## Task List

- [ ] 1. Add `display_backlog_table()` to `display.sh`
- [ ] 2. Call `display_backlog_table()` at each feature-start banner in `runner.sh`
- [ ] 3. Add `display_next_steps()` to `display.sh`
- [ ] 4. Thread `next_feat_id` from `run_backlog()` into `run_feature()` and call `display_next_steps()`
- [ ] 5. Improve cycle-gate block messaging in `runner.sh`
- [ ] 6. Fix `processed` count (introduce `ran_count`) in `run_backlog()`
- [ ] 7. Add "Ran this session" row to `display_summary()` in `display.sh`
- [ ] 8. Manual smoke test against stub-project

## Task Details

### Task 1 — `display_backlog_table()` in display.sh

**File:** `scripts/lib/display.sh`

Add after `display_backlog()`. Reads all `$STATE_DIR/*/status.json` and `$STATE_DIR/*/cost.json`. Prints the bordered table with columns: Feature (16), Status (12), Phase (14), Tokens (10). Status icons: `✓` done/pr-created, `→` in-progress, `✗` failed, `⏸` paused, `·` ready/pending/created. Tokens from `cost.json .cumulative_tokens`; show `—` if absent.

Accept one optional argument: the currently-active feat_id, so it can mark that row `→ active` regardless of status.json (which may lag).

### Task 2 — Call site in `runner.sh`

**File:** `scripts/lib/runner.sh`, inside `run_feature()`, after the existing `banner "[$index/$total]..."` line (~line 232 post-watcher changes).

```bash
display_backlog_table "$feat_id"
```

### Task 3 — `display_next_steps()` in display.sh

**File:** `scripts/lib/display.sh`

Arguments: `current_feat_id`, `exit_code`, `next_feat_id` (empty = last), `autonomy`, `model` (optional, empty ok), `adapter` (optional, empty ok).

- If `next_feat_id` is non-empty: print "Next feature" box with copy-paste re-run command
- If `next_feat_id` is empty: print "All features complete" box
- If `exit_code` != 0: prefix the box with a warning line about the failure

### Task 4 — Thread next_feat_id and call display_next_steps

**File:** `scripts/lib/runner.sh`

In `run_backlog()`, after collecting the list of ready items, determine the next item for each index and pass it into `process_item()` / `run_feature()`. Add a 9th parameter `next_feat_id` to `run_feature()`.

At the end of `run_feature()`, after `info "Feature time: ${duration}s"`:

```bash
display_next_steps "$feat_id" "$exit_code" "${next_feat_id:-}" "$AUTONOMY" "${MODEL_DEFAULT:-}" "$ADAPTER"
```

### Task 5 — Cycle-gate block messaging

**File:** `scripts/lib/runner.sh`, the `cycle_gate_check` block (~line 155 pre-changes, will shift).

Replace the two bare `info` lines with the expanded block from the techspec: warning box + copy-paste command including `--skip-cycle-check`.

### Task 6 — Fix `ran_count` in `run_backlog()`

**File:** `scripts/lib/runner.sh`, `run_backlog()`.

Add `local ran_count=0`. Increment after each `process_item()` call where the item was not skipped (status not already done/pr-created). Pass as `processed` to `display_summary()`.

### Task 7 — "Ran this session" row in `display_summary()`

**File:** `scripts/lib/display.sh`, `display_summary()`.

Add a 7th parameter `ran_n`. Insert row `│  Ran this session: %-26s │` between the Failed row and the separator. Callers: update the single call site in `run_backlog()`.

### Task 8 — Smoke test

Run `feature-marker-orchestrate run --autonomy full_auto` against `/Users/viniciuscarvalho/fm-validation/stub-project/`. Verify:

- Backlog table appears at each feature-start banner
- `[progress]` heartbeats fire every ~45s during Claude run
- "Next steps" box with correct command appears after feat-auth
- Final summary shows `Ran this session: 1` and `Avg: 344s/feature` (not 68s)
