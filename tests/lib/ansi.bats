#!/usr/bin/env bats
# tests/lib/ansi.bats — Tests for scripts/lib/ansi.sh ANSI color initialization.

REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"

setup() {
  source "$REPO_ROOT/scripts/lib/ansi.sh"
  # Reset vars between tests
  unset FM_CYAN FM_GREEN FM_YELLOW FM_RED FM_DIM FM_BOLD FM_GRAY FM_RESET
  unset FM_COLOR_ENABLED FM_INTERACTIVE
  unset NO_COLOR FM_FORCE_COLOR
}

# ── NO_COLOR ──────────────────────────────────────────────────────

@test "NO_COLOR=1 produces empty color vars" {
  NO_COLOR=1 fm_ansi_init
  [ "$FM_CYAN"  = "" ]
  [ "$FM_RED"   = "" ]
  [ "$FM_RESET" = "" ]
  [ "$FM_COLOR_ENABLED" = "0" ]
}

@test "NO_COLOR=anything disables color" {
  NO_COLOR=true fm_ansi_init
  [ "$FM_COLOR_ENABLED" = "0" ]
}

# ── FM_FORCE_COLOR ────────────────────────────────────────────────

@test "FM_FORCE_COLOR=1 enables color even with NO_COLOR unset and no tty" {
  FM_FORCE_COLOR=1 fm_ansi_init
  [ "$FM_COLOR_ENABLED" = "1" ]
  [ -n "$FM_CYAN" ]
  [ -n "$FM_RESET" ]
}

@test "FM_FORCE_COLOR=1 wins over NO_COLOR" {
  NO_COLOR=1 FM_FORCE_COLOR=1 fm_ansi_init
  [ "$FM_COLOR_ENABLED" = "1" ]
}

# ── Non-tty default (bats runs in a pipe — no tty) ────────────────

@test "without FM_FORCE_COLOR and no tty, colors are empty" {
  # bats stdout is not a tty, and NO_COLOR is unset — so use_color=0
  unset NO_COLOR; unset FM_FORCE_COLOR
  fm_ansi_init
  # In non-tty bats context, FM_INTERACTIVE=0 → no color
  [ "$FM_COLOR_ENABLED" = "0" ]
}

# ── FM_INTERACTIVE ────────────────────────────────────────────────

@test "FM_INTERACTIVE is exported as 0 in non-tty context" {
  fm_ansi_init
  [ "$FM_INTERACTIVE" = "0" ]
}

@test "FM_FORCE_COLOR sets FM_COLOR_ENABLED but FM_INTERACTIVE reflects actual tty" {
  FM_FORCE_COLOR=1 fm_ansi_init
  # tty detection is independent of color forcing
  [ "$FM_COLOR_ENABLED" = "1" ]
  # FM_INTERACTIVE will be 0 in bats (no tty)
  [ "$FM_INTERACTIVE" = "0" ]
}

# ── Exports ───────────────────────────────────────────────────────

@test "all FM_* vars are exported after fm_ansi_init" {
  FM_FORCE_COLOR=1 fm_ansi_init
  # Verify they're in the environment (subshell can see them)
  local result
  result=$(bash -c 'echo "${FM_COLOR_ENABLED:-MISSING}"')
  [ "$result" = "1" ]
}

@test "FM_RESET is exported and subshell sees it" {
  FM_FORCE_COLOR=1 fm_ansi_init
  local result
  result=$(bash -c 'printf "%s" "${FM_RESET:+set}"')
  [ "$result" = "set" ]
}
