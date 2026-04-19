#!/bin/bash
# lib/size_gate.sh — Feature-sizing gate (ADR-008 PR-D)
#
# Reads metrics from PRD/techspec/tasks files in the worktree and compares
# them against configured thresholds. In supervised mode the user is prompted;
# in checkpoint/full_auto mode a split-signal file is written.
#
# Exported variables (populated by size_gate_load_config):
#   SIZE_MAX_CRITERIA    — max acceptance criteria lines in prd.md
#   SIZE_MAX_TASKS       — max task lines in tasks.md
#   SIZE_MAX_FILE_CHANGES — max file paths in techspec.md "Files to Modify"

# ── Load thresholds from CFG_* (set by config.sh / parse-config.js) ──

size_gate_load_config() {
  SIZE_MAX_CRITERIA="${CFG_SAFETY_FEATURE_SIZE_MAX_ACCEPTANCE_CRITERIA:-15}"
  SIZE_MAX_TASKS="${CFG_SAFETY_FEATURE_SIZE_MAX_TASKS:-20}"
  SIZE_MAX_FILE_CHANGES="${CFG_SAFETY_FEATURE_SIZE_MAX_FILE_CHANGES_ESTIMATE:-80}"

  export SIZE_MAX_CRITERIA SIZE_MAX_TASKS SIZE_MAX_FILE_CHANGES
}

# Ensure thresholds are available when the module is sourced
size_gate_load_config

# ── _count_acceptance_criteria ───────────────────────────────────────
# Counts bullet/numbered lines in the acceptance section of prd.md.

_count_acceptance_criteria() {
  local prd_file="$1"
  [ ! -f "$prd_file" ] && echo "0" && return

  node -e "
    const fs = require('fs');
    const text = fs.readFileSync('$prd_file', 'utf-8');
    // Find acceptance criteria section (case-insensitive heading)
    const match = text.match(/##[^\\n]*acceptance[^\\n]*/i);
    if (!match) {
      // Fall back: count all bullet/numbered lines
      const lines = text.split('\\n').filter(l => /^-\\s/.test(l) || /^\\d+\\.\\s/.test(l));
      console.log(lines.length);
      return;
    }
    const start = text.indexOf(match[0]) + match[0].length;
    // Section ends at next ## heading or EOF
    const rest = text.slice(start);
    const nextSection = rest.search(/\\n##\\s/);
    const section = nextSection >= 0 ? rest.slice(0, nextSection) : rest;
    const lines = section.split('\\n').filter(l => /^-\\s/.test(l) || /^\\d+\\.\\s/.test(l));
    console.log(lines.length);
  " 2>/dev/null || echo "0"
}

# ── _count_tasks ──────────────────────────────────────────────────────
# Counts task lines (checkboxes or headings) in tasks.md.

_count_tasks() {
  local tasks_file="$1"
  [ ! -f "$tasks_file" ] && echo "0" && return

  node -e "
    const fs = require('fs');
    const lines = fs.readFileSync('$tasks_file', 'utf-8').split('\\n');
    // Count checkbox lines: - [ ] or - [x]
    const checkboxes = lines.filter(l => /^-\\s+\\[/.test(l)).length;
    // Count ### headings as task groups if no checkboxes found
    const headings = lines.filter(l => /^###\\s/.test(l)).length;
    console.log(checkboxes > 0 ? checkboxes : headings);
  " 2>/dev/null || echo "0"
}

# ── _count_file_changes ───────────────────────────────────────────────
# Counts file paths listed under a "Files to Modify" section in techspec.md.

_count_file_changes() {
  local techspec_file="$1"
  [ ! -f "$techspec_file" ] && echo "0" && return

  node -e "
    const fs = require('fs');
    const text = fs.readFileSync('$techspec_file', 'utf-8');
    const match = text.match(/##[^\\n]*(files to modify|files changed|modified files)[^\\n]*/i);
    if (!match) { console.log(0); return; }
    const start = text.indexOf(match[0]) + match[0].length;
    const rest = text.slice(start);
    const nextSection = rest.search(/\\n##\\s/);
    const section = nextSection >= 0 ? rest.slice(0, nextSection) : rest;
    // Count bullet lines containing a path-like string (contains / or .)
    const lines = section.split('\\n').filter(l => /^-\\s/.test(l) && /[\\/.]/.test(l));
    console.log(lines.length);
  " 2>/dev/null || echo "0"
}

# ── size_gate_check ───────────────────────────────────────────────────
# Usage: size_gate_check <feat_id> <wt_path>
# Reads metrics and compares to thresholds.
# Returns 0 if within bounds; 1 if any threshold is exceeded.
# Populates SIZE_EXCEEDED_CRITERIA, SIZE_EXCEEDED_TASKS, SIZE_EXCEEDED_FILES
# shell variables with actual vs max strings for diagnostics.

size_gate_check() {
  local feat_id="$1"
  local wt_path="$2"

  local task_dir="$wt_path/tasks/prd-$feat_id"
  local prd_file="$task_dir/prd.md"
  local techspec_file="$task_dir/techspec.md"
  local tasks_file="$task_dir/tasks.md"

  local criteria_count
  local task_count
  local file_count

  criteria_count=$(_count_acceptance_criteria "$prd_file")
  task_count=$(_count_tasks "$tasks_file")
  file_count=$(_count_file_changes "$techspec_file")

  SIZE_EXCEEDED_CRITERIA=""
  SIZE_EXCEEDED_TASKS=""
  SIZE_EXCEEDED_FILES=""

  local exceeded=0

  if [ "$criteria_count" -gt "$SIZE_MAX_CRITERIA" ]; then
    SIZE_EXCEEDED_CRITERIA="acceptance_criteria=${criteria_count}/${SIZE_MAX_CRITERIA}"
    exceeded=1
  fi

  if [ "$task_count" -gt "$SIZE_MAX_TASKS" ]; then
    SIZE_EXCEEDED_TASKS="tasks=${task_count}/${SIZE_MAX_TASKS}"
    exceeded=1
  fi

  if [ "$file_count" -gt "$SIZE_MAX_FILE_CHANGES" ]; then
    SIZE_EXCEEDED_FILES="file_changes=${file_count}/${SIZE_MAX_FILE_CHANGES}"
    exceeded=1
  fi

  export SIZE_EXCEEDED_CRITERIA SIZE_EXCEEDED_TASKS SIZE_EXCEEDED_FILES

  return $exceeded
}

# ── size_gate_signal ──────────────────────────────────────────────────
# Usage: size_gate_signal <feat_id> <autonomy> <exceeded_metrics>
# Handles the policy response to an oversized feature.
#   supervised    : warns and prompts the user interactively
#   checkpoint    : logs split signal to state/{feat_id}/size-exceeded.json
#   full_auto     : logs split signal (same as checkpoint)

size_gate_signal() {
  local feat_id="$1"
  local autonomy="$2"
  local exceeded_metrics="$3"

  local signal_file="$STATE_DIR/$feat_id/size-exceeded.json"
  mkdir -p "$STATE_DIR/$feat_id"

  case "$autonomy" in
    supervised)
      echo ""
      info "! Feature $feat_id exceeds size thresholds: $exceeded_metrics"
      info "  Consider splitting into smaller features before proceeding."
      echo ""
      # Read from /dev/tty to avoid consuming stdin from the calling pipeline.
      # 120-second timeout (ADR-010): unattended runs auto-decline rather than hang.
      local answer="n"
      if [ -t 0 ]; then
        read -t 120 -r -p "  Proceed anyway? [y/N] " answer </dev/tty || answer="n"
      else
        info "  (non-interactive mode — defaulting to skip)"
      fi
      case "$answer" in
        y|Y|yes|YES)
          info "Proceeding despite size warning for $feat_id"
          return 0
          ;;
        *)
          local action="user_skipped"
          [ -z "${answer:-}" ] && action="timeout_skipped"
          [ "$action" = "timeout_skipped" ] && info "Size-gate prompt timed out (120s) — skipping $feat_id"
          info "Skipping $feat_id due to size gate. Split the feature and re-run."
          node -e "
            require('fs').writeFileSync('$signal_file', JSON.stringify({
              feature_id: '$feat_id',
              recorded_at: new Date().toISOString(),
              exceeded: '$exceeded_metrics',
              action: '$action'
            }, null, 2));
          " 2>/dev/null || true
          return 1
          ;;
      esac
      ;;

    checkpoint|full_auto)
      info "! Feature $feat_id exceeds size thresholds: $exceeded_metrics"
      info "  Writing split signal to: $signal_file"
      node -e "
        require('fs').writeFileSync('$signal_file', JSON.stringify({
          feature_id: '$feat_id',
          recorded_at: new Date().toISOString(),
          exceeded: '$exceeded_metrics',
          action: 'auto_split_signal',
          note: 'Feature should be split before next run'
        }, null, 2));
      " 2>/dev/null || true
      return 1
      ;;

    *)
      info "! Size gate exceeded for $feat_id ($exceeded_metrics) — no action for autonomy=$autonomy"
      return 0
      ;;
  esac
}
