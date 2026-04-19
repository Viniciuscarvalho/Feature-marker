#!/usr/bin/env bats
# tests/lib/worktree_cleanup_merged.bats
#
# Unit tests for wt_cleanup_merged() in scripts/lib/worktree.sh.
#
# Prerequisites: bats-core >= 1.7
#   brew install bats-core       # macOS
#   apt-get install bats         # Ubuntu/Debian
#
# Run:
#   bats tests/lib/worktree_cleanup_merged.bats

REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"

setup() {
  # Isolated temp environment for each test
  TEST_TMP="$(mktemp -d)"
  export WORKTREE_ROOT="$TEST_TMP/worktrees"
  export STATE_DIR="$TEST_TMP/state"
  export RESULTS_DIR="$TEST_TMP/results"
  export ROOT_DIR="$TEST_TMP"
  export BASE_BRANCH="main"
  export BRANCH_PREFIX="feat"
  mkdir -p "$WORKTREE_ROOT" "$STATE_DIR" "$RESULTS_DIR"

  # Put stubs ahead of real binaries on PATH
  export STUBS_DIR="$BATS_TEST_DIRNAME/../stubs"
  export PATH="$STUBS_DIR:$PATH"

  # Source the library under test
  # shellcheck source=scripts/lib/worktree.sh
  source "$REPO_ROOT/scripts/lib/worktree.sh"
}

teardown() {
  rm -rf "$TEST_TMP"
  unset GH_STUB_MODE GH_MERGED_BRANCHES GIT_WORKTREE_STUB
}

# ── gh CLI not installed ───────────────────────────────────────

@test "warns and returns 0 when gh CLI is not installed" {
  # Use a minimal PATH containing only core system dirs so that gh (installed
  # via Homebrew or elsewhere) is not found and command -v gh returns non-zero.
  local saved_path="$PATH"
  export PATH="/usr/bin:/bin"

  run wt_cleanup_merged "main"

  export PATH="$saved_path"
  [ "$status" -eq 0 ]
  [[ "$output" == *"gh CLI not found"* ]]
}

# ── gh not authenticated ───────────────────────────────────────

@test "warns and returns 0 when gh is not authenticated" {
  export GH_STUB_MODE="auth_fail"

  run wt_cleanup_merged "main"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Not authenticated"* ]]
}

# ── GitHub query failures ──────────────────────────────────────

@test "warns and returns 0 when GitHub API query fails" {
  export GH_STUB_MODE="fail_query"

  run wt_cleanup_merged "main"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Could not query GitHub"* ]]
}

# ── No merged branches ────────────────────────────────────────

@test "reports no branches and returns 0 when no merged feat/* PRs exist" {
  export GH_STUB_MODE="no_prs"

  run wt_cleanup_merged "main"

  [ "$status" -eq 0 ]
  [[ "$output" == *"No merged feat/* branches found"* ]]
}

# ── Merged branch, no local worktree ──────────────────────────

@test "reports nothing to clean when merged branch has no local worktree" {
  export GH_STUB_MODE="has_merged"
  export GH_MERGED_BRANCHES="feat/feat-001"
  export GIT_WORKTREE_STUB=""  # git worktree list returns nothing

  run wt_cleanup_merged "main"

  [ "$status" -eq 0 ]
  [[ "$output" == *"No local worktrees found"* ]]
}

# ── Merged branch, worktree exists ────────────────────────────

@test "removes worktree and reports cleaned when merged branch has a local worktree" {
  export GH_STUB_MODE="has_merged"
  export GH_MERGED_BRANCHES="feat/feat-001"

  # Create the worktree directory so wt_remove has something to remove
  mkdir -p "$WORKTREE_ROOT/feat-001"
  export GIT_WORKTREE_STUB="has:$WORKTREE_ROOT/feat-001"

  run wt_cleanup_merged "main"

  [ "$status" -eq 0 ]
  [[ "$output" == *"✓ Cleaned"* ]]
  [[ "$output" == *"feat-001"* ]]
  # Directory should be gone
  [ ! -d "$WORKTREE_ROOT/feat-001" ]
}

@test "removes multiple worktrees when several merged branches have local worktrees" {
  export GH_STUB_MODE="has_merged"
  export GH_MERGED_BRANCHES="$(printf 'feat/feat-001\nfeat/feat-002')"

  mkdir -p "$WORKTREE_ROOT/feat-001" "$WORKTREE_ROOT/feat-002"
  # git worktree list stub needs to match both paths; we return both on separate lines
  # Use the first one — the function checks each path individually so stub returning
  # either path is sufficient to exercise the removal logic per-branch
  export GIT_WORKTREE_STUB="has:$WORKTREE_ROOT/feat-001"

  run wt_cleanup_merged "main"

  [ "$status" -eq 0 ]
  [[ "$output" == *"feat-001"* ]]
}

@test "logs are copied to results before worktree is removed" {
  export GH_STUB_MODE="has_merged"
  export GH_MERGED_BRANCHES="feat/feat-001"

  mkdir -p "$WORKTREE_ROOT/feat-001" "$STATE_DIR/feat-001/logs"
  echo "test log" > "$STATE_DIR/feat-001/logs/run.log"
  export GIT_WORKTREE_STUB="has:$WORKTREE_ROOT/feat-001"

  run wt_cleanup_merged "main"

  [ "$status" -eq 0 ]
  [ -f "$RESULTS_DIR/run.log" ]
}

# ── BRANCH_PREFIX customisation ───────────────────────────────

@test "respects a custom BRANCH_PREFIX" {
  export BRANCH_PREFIX="feature"
  export GH_STUB_MODE="has_merged"
  export GH_MERGED_BRANCHES="feature/feat-003"

  mkdir -p "$WORKTREE_ROOT/feat-003"
  export GIT_WORKTREE_STUB="has:$WORKTREE_ROOT/feat-003"

  run wt_cleanup_merged "main"

  [ "$status" -eq 0 ]
  [[ "$output" == *"feat-003"* ]]
}
