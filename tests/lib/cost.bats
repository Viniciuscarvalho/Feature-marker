#!/usr/bin/env bats
# tests/lib/cost.bats — Unit tests for cost_load_config and cost_estimate_phase
#
# cost_record and cost_init are NOT tested — they require node JSON I/O that
# can hang in CI environments.

setup() {
  TEST_TMP="$(mktemp -d)"
  export STATE_DIR="$TEST_TMP/state"
  mkdir -p "$STATE_DIR"

  info() { :; }
  log()  { :; }
  export -f info log

  source /Users/bocato/development/fm-pr-b/scripts/lib/cost.sh
}

teardown() {
  rm -rf "$TEST_TMP"
}

# ── cost_load_config ──────────────────────────────────────────────────────────

@test "cost_load_config uses built-in defaults when no CFG vars set" {
  unset CFG_MODEL_COST_BASELINES_PHASE_1_PLANNING \
        CFG_MODEL_COST_BASELINES_PHASE_2_PER_TASK_SPECIALIST \
        CFG_MODEL_COST_BASELINES_PHASE_2_PER_TASK_GENERIC \
        CFG_MODEL_COST_BASELINES_PHASE_4_COMMIT_PR \
        CFG_MODEL_COST_BASELINES_FIX_ATTEMPT_OVERHEAD
  cost_load_config
  [ "$COST_PHASE_1_PLANNING"    = "25000" ]
  [ "$COST_PHASE_2_SPECIALIST"  = "8000"  ]
  [ "$COST_PHASE_2_GENERIC"     = "12000" ]
  [ "$COST_PHASE_4_COMMIT_PR"   = "5000"  ]
  [ "$COST_FIX_ATTEMPT"         = "3000"  ]
}

@test "cost_load_config picks up CFG overrides" {
  export CFG_MODEL_COST_BASELINES_PHASE_1_PLANNING=99000
  export CFG_MODEL_COST_BASELINES_PHASE_2_PER_TASK_SPECIALIST=1000
  export CFG_MODEL_COST_BASELINES_PHASE_2_PER_TASK_GENERIC=2000
  export CFG_MODEL_COST_BASELINES_PHASE_4_COMMIT_PR=500
  export CFG_MODEL_COST_BASELINES_FIX_ATTEMPT_OVERHEAD=100
  cost_load_config
  [ "$COST_PHASE_1_PLANNING"    = "99000" ]
  [ "$COST_PHASE_2_SPECIALIST"  = "1000"  ]
  [ "$COST_PHASE_2_GENERIC"     = "2000"  ]
  [ "$COST_PHASE_4_COMMIT_PR"   = "500"   ]
  [ "$COST_FIX_ATTEMPT"         = "100"   ]
}

@test "cost_load_config exports variables" {
  cost_load_config
  run bash -c 'source /Users/bocato/development/fm-pr-b/scripts/lib/cost.sh; export -p | grep COST_PHASE_1_PLANNING'
  [ "$status" -eq 0 ]
}

# ── cost_estimate_phase ───────────────────────────────────────────────────────

@test "cost_estimate_phase phase 0 always returns 0" {
  cost_load_config
  run cost_estimate_phase 0
  [ "$status" -eq 0 ]
  [ "$output" = "0" ]
}

@test "cost_estimate_phase phase 1 returns COST_PHASE_1_PLANNING" {
  cost_load_config
  run cost_estimate_phase 1
  [ "$status" -eq 0 ]
  [ "$output" = "$COST_PHASE_1_PLANNING" ]
}

@test "cost_estimate_phase phase 2 generic single task" {
  cost_load_config
  run cost_estimate_phase 2 1 generic
  [ "$status" -eq 0 ]
  [ "$output" = "$COST_PHASE_2_GENERIC" ]
}

@test "cost_estimate_phase phase 2 generic multiple tasks" {
  cost_load_config
  run cost_estimate_phase 2 3 generic
  [ "$status" -eq 0 ]
  expected=$(( 3 * COST_PHASE_2_GENERIC ))
  [ "$output" = "$expected" ]
}

@test "cost_estimate_phase phase 2 specialist single task" {
  cost_load_config
  run cost_estimate_phase 2 1 specialist
  [ "$status" -eq 0 ]
  [ "$output" = "$COST_PHASE_2_SPECIALIST" ]
}

@test "cost_estimate_phase phase 2 specialist multiple tasks" {
  cost_load_config
  run cost_estimate_phase 2 4 specialist
  [ "$status" -eq 0 ]
  expected=$(( 4 * COST_PHASE_2_SPECIALIST ))
  [ "$output" = "$expected" ]
}

@test "cost_estimate_phase phase 2 defaults to generic when agent_type omitted" {
  cost_load_config
  run cost_estimate_phase 2 2
  [ "$status" -eq 0 ]
  expected=$(( 2 * COST_PHASE_2_GENERIC ))
  [ "$output" = "$expected" ]
}

@test "cost_estimate_phase phase 3 zero fix attempts returns 0" {
  cost_load_config
  run cost_estimate_phase 3 0
  [ "$status" -eq 0 ]
  [ "$output" = "0" ]
}

@test "cost_estimate_phase phase 3 with fix attempts" {
  cost_load_config
  run cost_estimate_phase 3 2
  [ "$status" -eq 0 ]
  expected=$(( 2 * COST_FIX_ATTEMPT ))
  [ "$output" = "$expected" ]
}

@test "cost_estimate_phase phase 4 returns COST_PHASE_4_COMMIT_PR" {
  cost_load_config
  run cost_estimate_phase 4
  [ "$status" -eq 0 ]
  [ "$output" = "$COST_PHASE_4_COMMIT_PR" ]
}

@test "cost_estimate_phase unknown phase returns 0" {
  cost_load_config
  run cost_estimate_phase 99
  [ "$status" -eq 0 ]
  [ "$output" = "0" ]
}

@test "cost_estimate_phase phase 2 task_count defaults to 1" {
  cost_load_config
  run cost_estimate_phase 2
  [ "$status" -eq 0 ]
  [ "$output" = "$COST_PHASE_2_GENERIC" ]
}

# cost_record is intentionally NOT tested:
# it calls node JSON I/O which can hang in CI.
