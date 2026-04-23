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

## Change 6: Color Module `scripts/lib/ui.sh`

**New file:** `scripts/lib/ui.sh`

TTY-gated ANSI exports. Sourced by `orchestrate.sh`, `orchestrator.sh`, and `display.sh`.

```bash
#!/bin/bash
# lib/ui.sh — ANSI color tokens for orchestrator output
if [[ -t 1 ]] || [[ "${FM_FORCE_COLOR:-}" == "1" ]]; then
  C_RED='\033[0;31m'; C_GREEN='\033[0;32m'; C_YELLOW='\033[0;33m'
  C_BLUE='\033[0;34m'; C_CYAN='\033[0;36m'; C_DIM='\033[2m'
  C_BOLD='\033[1m'; C_NC='\033[0m'
else
  C_RED=''; C_GREEN=''; C_YELLOW=''; C_BLUE=''; C_CYAN=''; C_DIM=''; C_BOLD=''; C_NC=''
fi
export C_RED C_GREEN C_YELLOW C_BLUE C_CYAN C_DIM C_BOLD C_NC
```

Replace inline `log/info/err/banner` in `scripts/orchestrate.sh:53–61` with:

```bash
source "$SCRIPT_DIR/lib/ui.sh"
log()    { echo -e "${C_CYAN}▶${C_NC} [orchestrate] $*"; }
info()   { echo -e "${C_DIM}  [orchestrate] $*${C_NC}"; }
err()    { echo -e "${C_RED}✗${C_NC} [orchestrate] $*" >&2; }
banner() { echo -e "\n${C_BOLD}${C_CYAN}═══════════════════════════════════════════════════${C_NC}"; echo -e "${C_BOLD}  $*${C_NC}"; echo -e "${C_BOLD}${C_CYAN}═══════════════════════════════════════════════════${C_NC}"; }
```

Apply same to `scripts/orchestrator.sh` where it re-defines these helpers.

---

## Change 7: Colored Status Icons in `display.sh`

Update the `icon()` function inside `display_backlog_table` (L64–70 of `display.sh`) to emit ANSI-colored strings. Since the surrounding code is a `node -e` heredoc, inject the ANSI vars as shell variables before the node call:

```bash
display_backlog_table() {
  local active_feat="${1:-}"
  [ ! -d "$STATE_DIR" ] && return
  local c_green="${C_GREEN:-}" c_red="${C_RED:-}" c_yellow="${C_YELLOW:-}" \
        c_cyan="${C_CYAN:-}" c_dim="${C_DIM:-}" c_bold="${C_BOLD:-}" c_nc="${C_NC:-}"
  node -e "
    const g='$c_green', r='$c_red', y='$c_yellow', cy='$c_cyan',
          d='$c_dim',   bo='$c_bold', nc='$c_nc';
    ...
    const icon = f => {
      if (f.id===active||f.status==='in-progress') return cy+'→'+nc;
      if (f.status==='done'||f.status==='pr-created') return g+'✓'+nc;
      if (f.status==='failed') return r+'✗'+nc;
      if (f.status==='paused') return y+'⏸'+nc;
      return d+'·'+nc;
    };
    const hdr = bo+cy+'  BACKLOG  ['+doneN+'/'+features.length+' done]'+nc
              + (totalTok?' — ~'+fmtTok(totalTok)+' tokens':'');
    ...
  "
}
```

Apply same colored-icon pattern to `display_next_steps` (feat_id → done line) and `display_paused_handoff` (⏸ prefix).

---

## Change 8: `display_live_phase()` in `display.sh`

**New function in `display.sh`:**

```bash
# display_live_phase <feat_id> <start_epoch>
# Reads $STATE_DIR/$feat_id/status.json and cost.json.
# Prints a one-line status line suitable for repeated overwrite.
display_live_phase() {
  local feat_id="$1" start_epoch="${2:-0}"
  local status_file="$STATE_DIR/$feat_id/status.json"
  local cost_file="$STATE_DIR/$feat_id/cost.json"

  local phase="?" task_idx="" total_tasks="" tokens="?" elapsed=""

  if [ -f "$status_file" ]; then
    phase=$(node -p "try{const s=JSON.parse(require('fs').readFileSync('$status_file','utf-8')); s.phase||'?'}catch(e){'?'}" 2>/dev/null || echo "?")
    task_idx=$(node -p "try{const s=JSON.parse(require('fs').readFileSync('$status_file','utf-8')); s.task_index||''}catch(e){''}" 2>/dev/null || echo "")
    total_tasks=$(node -p "try{const s=JSON.parse(require('fs').readFileSync('$status_file','utf-8')); s.total_tasks||''}catch(e){''}" 2>/dev/null || echo "")
  fi

  if [ -f "$cost_file" ]; then
    local raw_tok
    raw_tok=$(node -p "try{Math.round(JSON.parse(require('fs').readFileSync('$cost_file','utf-8')).cumulative_tokens/1000)+'k'}catch(e){'?'}" 2>/dev/null || echo "?")
    tokens="~${raw_tok}"
  fi

  if [ "$start_epoch" -gt 0 ] 2>/dev/null; then
    local now; now=$(date +%s)
    local secs=$(( now - start_epoch ))
    elapsed="$(( secs / 60 ))m$(( secs % 60 ))s"
  fi

  local task_seg=""
  [ -n "$task_idx" ] && [ -n "$total_tasks" ] && task_seg=" · task ${task_idx}/${total_tasks}"

  echo -e "  ${C_CYAN:-}→${C_NC:-}  ${feat_id}  •  Phase ${phase}${task_seg}  •  ${tokens} tokens  •  ${elapsed}"
}
```

**Call site in `runner.sh`:** locate the `[progress]` heartbeat emitter (search for `"[progress]"` or `sleep 45` region in the watcher background loop) and replace the plain `info "[progress] …"` line with:

```bash
display_live_phase "$feat_id" "$start_time"
```

Keep the 45s cadence; `display_live_phase` gracefully falls back when files are absent.

---

## Testing

1. Run stub-project with 5 features in full_auto → verify backlog table appears at each feature start (already works)
2. Kill run mid-backlog → re-run → verify "next steps" block shows correct next feature (already works)
3. Force cycle-gate block → verify new messaging with copy-paste command appears (already works)
4. Single-feature run (1 feature done, 0 remaining) → verify "all features complete" block (already works)
5. `Avg` = `Total ÷ ran_count` for any subset of features processed (already works)
6. Run in a TTY → expect colored `▶`, `✓`, `✗`, `⏸`, `→` glyphs; header lines bold/cyan
7. Pipe output (`| cat`) without `FM_FORCE_COLOR` → no escape bytes
8. `FM_FORCE_COLOR=1 … | cat` → colors retained
9. Mid-run heartbeat → `display_live_phase` line shows `Phase N · task k/m · ~Xk tokens · Nm Ns`
