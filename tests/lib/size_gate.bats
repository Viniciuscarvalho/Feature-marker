#!/usr/bin/env bats
# tests/lib/size_gate.bats — Unit tests for size_gate functions
#
# NOTE: _count_acceptance_criteria and _count_file_changes use a top-level
# `return` statement inside their node -e scripts, which is a SyntaxError on
# Node >= 22. Those private functions are shimmed via a driver script so the
# shell comparison logic of size_gate_check can be fully exercised.
#
# size_gate_signal's supervised branch is NOT tested in CI — it requires
# interactive /dev/tty input.

setup() {
  TEST_TMP="$(mktemp -d)"
  export STATE_DIR="$TEST_TMP/state"
  mkdir -p "$STATE_DIR"

  info() { echo "$*"; }
  export -f info

  source /Users/bocato/development/fm-pr-b/scripts/lib/size_gate.sh
}

teardown() {
  rm -rf "$TEST_TMP"
}

# ── helper: driver script that shims node-broken counter functions ────────────
_make_check_script() {
  local crit="$1" tasks="$2" files="$3"
  cat > "$TEST_TMP/run_check.sh" << SCRIPT
#!/bin/bash
export STATE_DIR="$STATE_DIR"
info() { echo "\$*"; }
export -f info
source /Users/bocato/development/fm-pr-b/scripts/lib/size_gate.sh
_count_acceptance_criteria() { echo "$crit"; }
_count_tasks()               { echo "$tasks"; }
_count_file_changes()        { echo "$files"; }
size_gate_check "\$1" "\$2"
SCRIPT
  chmod +x "$TEST_TMP/run_check.sh"
}

make_empty_wt() {
  local feat_id="$1"
  local wt="$TEST_TMP/wt-$feat_id"
  local task_dir="$wt/tasks/prd-$feat_id"
  mkdir -p "$task_dir"
  touch "$task_dir/prd.md" "$task_dir/tasks.md" "$task_dir/techspec.md"
  echo "$wt"
}

# ── size_gate_load_config ─────────────────────────────────────────────────────

@test "size_gate_load_config uses built-in defaults when no CFG vars set" {
  unset CFG_SAFETY_FEATURE_SIZE_MAX_ACCEPTANCE_CRITERIA \
        CFG_SAFETY_FEATURE_SIZE_MAX_TASKS \
        CFG_SAFETY_FEATURE_SIZE_MAX_FILE_CHANGES_ESTIMATE
  size_gate_load_config
  [ "$SIZE_MAX_CRITERIA"     = "15" ]
  [ "$SIZE_MAX_TASKS"        = "20" ]
  [ "$SIZE_MAX_FILE_CHANGES" = "80" ]
}

@test "size_gate_load_config picks up CFG overrides" {
  export CFG_SAFETY_FEATURE_SIZE_MAX_ACCEPTANCE_CRITERIA=5
  export CFG_SAFETY_FEATURE_SIZE_MAX_TASKS=10
  export CFG_SAFETY_FEATURE_SIZE_MAX_FILE_CHANGES_ESTIMATE=30
  size_gate_load_config
  [ "$SIZE_MAX_CRITERIA"     = "5"  ]
  [ "$SIZE_MAX_TASKS"        = "10" ]
  [ "$SIZE_MAX_FILE_CHANGES" = "30" ]
}

@test "size_gate_load_config exports variables" {
  size_gate_load_config
  run bash -c 'source /Users/bocato/development/fm-pr-b/scripts/lib/size_gate.sh; export -p | grep SIZE_MAX_CRITERIA'
  [ "$status" -eq 0 ]
}

# ── _count_tasks (no top-level return — works on all Node versions) ───────────

@test "_count_tasks returns 0 for a non-existent file" {
  run _count_tasks "/no/such/file.md"
  [ "$status" -eq 0 ]
  [ "$output" = "0" ]
}

@test "_count_tasks counts checkbox lines" {
  local f="$TEST_TMP/tasks.md"
  printf '%s\n' '- [ ] Task 1' '- [ ] Task 2' '- [x] Task 3' '# heading' > "$f"
  run _count_tasks "$f"
  [ "$status" -eq 0 ]
  [ "$output" = "3" ]
}

@test "_count_tasks falls back to ### headings when no checkboxes" {
  local f="$TEST_TMP/tasks_headings.md"
  printf '%s\n' '### Group A' 'some text' '### Group B' 'more text' > "$f"
  run _count_tasks "$f"
  [ "$status" -eq 0 ]
  [ "$output" = "2" ]
}

@test "_count_tasks returns 0 for empty file" {
  local f="$TEST_TMP/tasks_empty.md"
  touch "$f"
  run _count_tasks "$f"
  [ "$status" -eq 0 ]
  [ "$output" = "0" ]
}

# ── size_gate_check — via driver script (shimmed counters) ────────────────────

@test "size_gate_check returns 0 when all counts are within thresholds" {
  _make_check_script 5 5 5
  local wt; wt=$(make_empty_wt "small")
  run bash "$TEST_TMP/run_check.sh" "small" "$wt"
  [ "$status" -eq 0 ]
}

@test "size_gate_check returns 0 when counts equal thresholds exactly" {
  size_gate_load_config
  _make_check_script "$SIZE_MAX_CRITERIA" "$SIZE_MAX_TASKS" "$SIZE_MAX_FILE_CHANGES"
  local wt; wt=$(make_empty_wt "exact")
  run bash "$TEST_TMP/run_check.sh" "exact" "$wt"
  [ "$status" -eq 0 ]
}

@test "size_gate_check returns 0 when no task files exist" {
  _make_check_script 0 0 0
  run bash "$TEST_TMP/run_check.sh" "nofiles" "$TEST_TMP/wt-nofiles"
  [ "$status" -eq 0 ]
}

@test "size_gate_check returns 1 when acceptance criteria count exceeds max" {
  size_gate_load_config
  _make_check_script $(( SIZE_MAX_CRITERIA + 1 )) 5 5
  local wt; wt=$(make_empty_wt "crit")
  run bash "$TEST_TMP/run_check.sh" "crit" "$wt"
  [ "$status" -eq 1 ]
}

@test "size_gate_check returns 1 when task count exceeds max" {
  size_gate_load_config
  _make_check_script 5 $(( SIZE_MAX_TASKS + 1 )) 5
  local wt; wt=$(make_empty_wt "tasks")
  run bash "$TEST_TMP/run_check.sh" "tasks" "$wt"
  [ "$status" -eq 1 ]
}

@test "size_gate_check returns 1 when file changes count exceeds max" {
  size_gate_load_config
  _make_check_script 5 5 $(( SIZE_MAX_FILE_CHANGES + 1 ))
  local wt; wt=$(make_empty_wt "files")
  run bash "$TEST_TMP/run_check.sh" "files" "$wt"
  [ "$status" -eq 1 ]
}

@test "size_gate_check returns 1 when all three thresholds exceeded" {
  size_gate_load_config
  _make_check_script $(( SIZE_MAX_CRITERIA + 5 )) $(( SIZE_MAX_TASKS + 5 )) $(( SIZE_MAX_FILE_CHANGES + 5 ))
  local wt; wt=$(make_empty_wt "all")
  run bash "$TEST_TMP/run_check.sh" "all" "$wt"
  [ "$status" -eq 1 ]
}

# Direct (non-run) tests for SIZE_EXCEEDED_* variable population
@test "size_gate_check sets SIZE_EXCEEDED_CRITERIA when criteria exceeded" {
  size_gate_load_config
  _count_acceptance_criteria() { echo $(( SIZE_MAX_CRITERIA + 5 )); }
  _count_tasks()               { echo "5"; }
  _count_file_changes()        { echo "5"; }
  size_gate_check "feat-crit-var" "$TEST_TMP" || true
  [[ "$SIZE_EXCEEDED_CRITERIA" == *"acceptance_criteria="* ]]
}

@test "size_gate_check sets SIZE_EXCEEDED_TASKS when tasks exceeded" {
  size_gate_load_config
  _count_acceptance_criteria() { echo "5"; }
  _count_tasks()               { echo $(( SIZE_MAX_TASKS + 5 )); }
  _count_file_changes()        { echo "5"; }
  size_gate_check "feat-tasks-var" "$TEST_TMP" || true
  [[ "$SIZE_EXCEEDED_TASKS" == *"tasks="* ]]
}

@test "size_gate_check sets SIZE_EXCEEDED_FILES when file changes exceeded" {
  size_gate_load_config
  _count_acceptance_criteria() { echo "5"; }
  _count_tasks()               { echo "5"; }
  _count_file_changes()        { echo $(( SIZE_MAX_FILE_CHANGES + 5 )); }
  size_gate_check "feat-files-var" "$TEST_TMP" || true
  [[ "$SIZE_EXCEEDED_FILES" == *"file_changes="* ]]
}

@test "size_gate_check clears exceeded vars when all within threshold" {
  size_gate_load_config
  SIZE_EXCEEDED_CRITERIA="old"
  SIZE_EXCEEDED_TASKS="old"
  SIZE_EXCEEDED_FILES="old"
  _count_acceptance_criteria() { echo "3"; }
  _count_tasks()               { echo "3"; }
  _count_file_changes()        { echo "3"; }
  size_gate_check "feat-clear" "$TEST_TMP"
  [ -z "$SIZE_EXCEEDED_CRITERIA" ]
  [ -z "$SIZE_EXCEEDED_TASKS"    ]
  [ -z "$SIZE_EXCEEDED_FILES"    ]
}

# ── size_gate_signal ──────────────────────────────────────────────────────────

@test "size_gate_signal checkpoint mode returns 1 and writes signal file" {
  size_gate_load_config
  local feat_id="feat-signal-cp"
  mkdir -p "$STATE_DIR/$feat_id"
  run size_gate_signal "$feat_id" "checkpoint" "tasks=25/20"
  [ "$status" -eq 1 ]
  [ -f "$STATE_DIR/$feat_id/size-exceeded.json" ]
}

@test "size_gate_signal full_auto mode returns 1 and writes signal file" {
  size_gate_load_config
  local feat_id="feat-signal-fa"
  mkdir -p "$STATE_DIR/$feat_id"
  run size_gate_signal "$feat_id" "full_auto" "tasks=25/20"
  [ "$status" -eq 1 ]
  [ -f "$STATE_DIR/$feat_id/size-exceeded.json" ]
}

@test "size_gate_signal full_auto signal file contains feature_id" {
  size_gate_load_config
  local feat_id="feat-signal-content"
  mkdir -p "$STATE_DIR/$feat_id"
  size_gate_signal "$feat_id" "full_auto" "tasks=25/20" || true
  local sig_file="$STATE_DIR/$feat_id/size-exceeded.json"
  [ -f "$sig_file" ]
  run node -p "JSON.parse(require('fs').readFileSync('$sig_file','utf-8')).feature_id"
  [ "$output" = "$feat_id" ]
}

@test "size_gate_signal full_auto signal file has action=auto_split_signal" {
  size_gate_load_config
  local feat_id="feat-signal-action"
  mkdir -p "$STATE_DIR/$feat_id"
  size_gate_signal "$feat_id" "full_auto" "tasks=25/20" || true
  local sig_file="$STATE_DIR/$feat_id/size-exceeded.json"
  run node -p "JSON.parse(require('fs').readFileSync('$sig_file','utf-8')).action"
  [ "$output" = "auto_split_signal" ]
}

@test "size_gate_signal unknown autonomy returns 0 and does not write signal file" {
  size_gate_load_config
  local feat_id="feat-signal-unknown"
  mkdir -p "$STATE_DIR/$feat_id"
  run size_gate_signal "$feat_id" "unknown_mode" "tasks=25/20"
  [ "$status" -eq 0 ]
  [ ! -f "$STATE_DIR/$feat_id/size-exceeded.json" ]
}

@test "size_gate_signal creates STATE_DIR subdirectory if missing" {
  size_gate_load_config
  local feat_id="feat-signal-mkdir"
  run size_gate_signal "$feat_id" "full_auto" "tasks=25/20"
  [ "$status" -eq 1 ]
  [ -d "$STATE_DIR/$feat_id" ]
}
