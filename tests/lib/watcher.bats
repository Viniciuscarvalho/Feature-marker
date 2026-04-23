#!/usr/bin/env bats
# tests/lib/watcher.bats — Tests for _watcher_format_tick output formatting.
#
# Tests the formatting helper directly (not the sleep-based watcher subprocess).
# Sources display.sh (which defines _watcher_format_tick) + phases.sh.

REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"

setup() {
  # Stub FM_* vars (no color in test context)
  FM_CYAN='' FM_GREEN='' FM_YELLOW='' FM_RED=''
  FM_DIM='' FM_BOLD='' FM_GRAY='' FM_RESET=''
  FM_COLOR_ENABLED=0
  FM_INTERACTIVE=0
  export FM_CYAN FM_GREEN FM_YELLOW FM_RED FM_DIM FM_BOLD FM_GRAY FM_RESET
  export FM_COLOR_ENABLED FM_INTERACTIVE

  source "$REPO_ROOT/scripts/lib/phases.sh"

  info() { :; }
  log()  { :; }
  export -f info log

  source "$REPO_ROOT/scripts/lib/display.sh"
}

# ── classic style ─────────────────────────────────────────────────

@test "classic style with changed files emits [progress] with filenames" {
  run _watcher_format_tick 60 "prd.md tasks.md " "" 0 "classic"
  [ "$status" -eq 0 ]
  [[ "$output" == *"[progress]"* ]]
  [[ "$output" == *"prd.md"* ]]
  [[ "$output" == *"60s elapsed"* ]]
}

@test "classic style idle emits [progress] no-new-files message" {
  run _watcher_format_tick 90 "" "" 0 "classic"
  [ "$status" -eq 0 ]
  [[ "$output" == *"[progress]"* ]]
  [[ "$output" == *"no new files"* ]]
}

@test "classic style does not emit [fm] key" {
  run _watcher_format_tick 30 "main.ts " "2" 0 "classic"
  [[ "$output" != *"[fm]"* ]]
}

# ── new style, non-interactive (log-safe) ─────────────────────────

@test "new style non-interactive emits [fm] with phase key" {
  run _watcher_format_tick 120 "prd.md " "1" 0 ""
  [ "$status" -eq 0 ]
  [[ "$output" == *"[fm]"* ]]
  [[ "$output" == *"phase=1"* ]]
}

@test "new style non-interactive includes elapsed" {
  run _watcher_format_tick 180 "" "2" 0 ""
  [[ "$output" == *"elapsed=180s"* ]]
}

@test "new style non-interactive with files includes files key" {
  run _watcher_format_tick 45 "auth.ts " "2" 0 ""
  [[ "$output" == *"files=auth.ts"* ]]
}

@test "new style non-interactive idle omits files key" {
  run _watcher_format_tick 45 "" "2" 0 ""
  [[ "$output" != *"files="* ]]
}

@test "new style with unknown phase uses ? as phase" {
  run _watcher_format_tick 30 "" "" 0 ""
  [[ "$output" == *"phase=?"* ]]
}

# ── new style, interactive (TTY) ─────────────────────────────────

@test "interactive style with files emits ▶ glyph" {
  run _watcher_format_tick 60 "prd.md " "1" 1 ""
  [[ "$output" == *"▶"* ]]
}

@test "interactive style includes phase label in header" {
  run _watcher_format_tick 60 "prd.md " "1" 1 ""
  [[ "$output" == *"Plan"* ]]
}

@test "interactive style idle emits · glyph not ▶" {
  run _watcher_format_tick 60 "" "2" 1 ""
  [[ "$output" == *"·"* ]]
  [[ "$output" != *"wrote"* ]]
}

@test "interactive style does not emit [fm] key" {
  run _watcher_format_tick 60 "main.ts " "2" 1 ""
  [[ "$output" != *"[fm]"* ]]
}

# ── phase label integration ───────────────────────────────────────

@test "phase 2 in non-interactive shows phase=2" {
  run _watcher_format_tick 90 "main.ts " "2" 0 ""
  [[ "$output" == *"phase=2"* ]]
}

@test "phase 3 in interactive shows Test in header" {
  run _watcher_format_tick 90 "auth.test.ts " "3" 1 ""
  [[ "$output" == *"Test"* ]]
}

@test "phase 4 in interactive shows Commit in header" {
  run _watcher_format_tick 15 "CHANGELOG.md " "4" 1 ""
  [[ "$output" == *"Commit"* ]]
}

# ── display_phase_start ───────────────────────────────────────────

@test "display_phase_start 1 contains phase number and Plan label" {
  run display_phase_start 1
  [ "$status" -eq 0 ]
  [[ "$output" == *"Phase 1"* ]]
  [[ "$output" == *"Plan"* ]]
}

@test "display_phase_start 3 contains phase number and Test label" {
  run display_phase_start 3
  [[ "$output" == *"Phase 3"* ]]
  [[ "$output" == *"Test"* ]]
}

@test "display_phase_start 4 contains phase number and Commit label" {
  run display_phase_start 4
  [[ "$output" == *"Phase 4"* ]]
  [[ "$output" == *"Commit"* ]]
}

@test "display_phase_start includes ETA when phases.sh provides it" {
  run display_phase_start 2
  # fm_phase_eta 2 returns ~3-12 min
  [[ "$output" == *"min"* ]]
}

# ── display_phase_done ────────────────────────────────────────────

@test "display_phase_done emits checkmark" {
  run display_phase_done 3 42
  [ "$status" -eq 0 ]
  [[ "$output" == *"✓"* ]]
}

@test "display_phase_done includes phase label" {
  run display_phase_done 3 42
  [[ "$output" == *"Test"* ]]
}

@test "display_phase_done includes elapsed seconds" {
  run display_phase_done 3 42
  [[ "$output" == *"42s"* ]]
}

@test "display_phase_done 4 shows Commit" {
  run display_phase_done 4 0
  [[ "$output" == *"Commit"* ]]
}

# ── display_fix_attempt ───────────────────────────────────────────

@test "display_fix_attempt shows attempt and max" {
  run display_fix_attempt 1 5
  [ "$status" -eq 0 ]
  [[ "$output" == *"1/5"* ]]
}

@test "display_fix_attempt 2/5 shows correct numbers" {
  run display_fix_attempt 2 5
  [[ "$output" == *"2/5"* ]]
}

@test "display_fix_attempt shows Fix attempt label" {
  run display_fix_attempt 3 5
  [[ "$output" == *"Fix attempt"* ]]
}
