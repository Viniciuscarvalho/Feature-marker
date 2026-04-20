#!/bin/bash
# orchestrate.sh — Shell Script Orchestrator CLI
#
# Single entry point with 4 subcommands and 6 flags.
# Reads config, loads secrets, adapts backlog, discovers agents,
# routes tasks, manages worktrees, runs the loop, and reports status.
#
# Usage:
#   ./scripts/orchestrate.sh init                      # Scaffold project
#   ./scripts/orchestrate.sh run                       # Execute orchestration
#   ./scripts/orchestrate.sh run --autonomy full_auto  # Override autonomy
#   ./scripts/orchestrate.sh run --dry-run             # Show plan, don't execute
#   ./scripts/orchestrate.sh status                    # Show current state
#   ./scripts/orchestrate.sh clean                     # Remove all worktrees
#
# Flags:
#   --autonomy <level>   Override: supervised | checkpoint | full_auto
#   --adapter <type>     Override: markdown | github | linear
#   --config <path>      Config file (default: orchestrator/config.yml)
#   --plan               Show the plan, don't execute
#   --dry-run             Alias for --plan
#   --help               Show this help

set -euo pipefail

# ── Path resolution — works from Homebrew, local, or NPX ────────

if [ -n "${ORCHESTRATOR_HOME:-}" ]; then
  # Set by wrapper (Homebrew or NPX)
  SCRIPT_DIR="$ORCHESTRATOR_HOME"
else
  # Running directly from repo
  SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0" 2>/dev/null || echo "$0")")" && pwd)"
fi

# Project root is always the current working directory
PROJECT_ROOT="$(pwd)"

# Source modules from SCRIPT_DIR (Homebrew or local)
LIB_DIR="$SCRIPT_DIR/lib"
TEMPLATES_DIR="$SCRIPT_DIR/templates"

# Everything else operates on PROJECT_ROOT
ROOT_DIR="$PROJECT_ROOT"
CONFIG_DIR="$ROOT_DIR/.orchestrator"
STATE_DIR="$CONFIG_DIR/state"
RESULTS_DIR="$CONFIG_DIR/results"

cd "$ROOT_DIR"

# ── Helpers (available before modules load) ──────────────────────

log()    { echo "▶ [orchestrate] $*"; }
info()   { echo "  [orchestrate] $*"; }
err()    { echo "✗ [orchestrate] $*" >&2; }
banner() {
  echo ""
  echo "═══════════════════════════════════════════════════"
  echo "  $*"
  echo "═══════════════════════════════════════════════════"
}

# ── CLI Parsing ──────────────────────────────────────────────────

SUBCOMMAND=""
OPT_AUTONOMY=""
OPT_ADAPTER=""
OPT_MODEL=""
OPT_CONFIG="orchestrator/config.yml"
OPT_DRY_RUN=false
OPT_FEATURE=""
OPT_RESUME_FEAT=""
OPT_RESUME_ACK=false
OPT_SKIP_CYCLE_CHECK=false
OPT_SAMPLE=10
OPT_LEARNING_ACTION=""
OPT_LEARNING_ID=""
OPT_LEARNING_CANDIDATES=false
OPT_INGEST_FEAT=""

while [ $# -gt 0 ]; do
  case "$1" in
    init|run|status|clean|calibrate|learning|promote-learning|ingest-status)
      SUBCOMMAND="$1"
      ;;
    --resume-paused)
      shift; OPT_RESUME_FEAT="$1"; SUBCOMMAND="resume-paused"
      ;;
    --ack)
      OPT_RESUME_ACK=true
      ;;
    --autonomy)
      shift; OPT_AUTONOMY="$1"
      ;;
    --adapter)
      shift; OPT_ADAPTER="$1"
      ;;
    --model)
      shift; OPT_MODEL="$1"
      ;;
    --config)
      shift; OPT_CONFIG="$1"
      ;;
    --feature)
      shift; OPT_FEATURE="$1"
      ;;
    --plan|--dry-run)
      OPT_DRY_RUN=true
      ;;
    --skip-cycle-check)
      OPT_SKIP_CYCLE_CHECK=true
      ;;
    --sample)
      shift; OPT_SAMPLE="$1"
      ;;
    --candidates)
      OPT_LEARNING_CANDIDATES=true
      ;;
    list|archive|promote)
      [ "$SUBCOMMAND" = "learning" ] && OPT_LEARNING_ACTION="$1"
      ;;
    --help|-h)
      echo "Usage: orchestrate.sh <command> [flags]"
      echo ""
      echo "Commands:"
      echo "  init                         Scaffold config, .env, features.md, .gitignore"
      echo "  run                          Execute the orchestration loop"
      echo "  status                       Show current orchestrator state"
      echo "  clean                        Remove all worktrees and reset state"
      echo "  calibrate                    Show token-cost calibration guidance"
      echo "  learning list                List all learning entries"
      echo "  learning list --candidates   List only promotion candidates"
      echo "  learning archive <id>        Archive a learning entry by ID"
      echo "  learning promote <id>        Promote a project entry to global tier"
      echo "  promote-learning <id>        Alias for: learning promote <id>"
      echo "  ingest-status                Show active background ingest jobs (ADR-009)"
      echo ""
      echo "Flags:"
      echo "  --autonomy <level>           supervised | checkpoint | full_auto"
      echo "  --adapter <type>             markdown | github | linear"
      echo "  --model <name>              opus | sonnet | haiku | opusplan"
      echo "  --config <path>              Config file (default: orchestrator/config.yml)"
      echo "  --feature <id>              Run only the specified feature"
      echo "  --plan, --dry-run            Show plan without executing"
      echo "  --resume-paused <feat-id>    Resume a paused feature from its checkpoint"
      echo "  --ack                        Acknowledge human-class pauses for --resume-paused"
      echo "  --skip-cycle-check           Skip the cycle-completion gate"
      echo "  --sample <n>                 Sample size for calibrate (default: 10)"
      echo "  --help                       Show this help"
      exit 0
      ;;
    *)
      if [ "$SUBCOMMAND" = "learning" ] && [ -z "$OPT_LEARNING_ACTION" ]; then
        OPT_LEARNING_ACTION="$1"
      elif [ "$SUBCOMMAND" = "learning" ] && [ -z "$OPT_LEARNING_ID" ]; then
        OPT_LEARNING_ID="$1"
      elif [ "$SUBCOMMAND" = "promote-learning" ] && [ -z "$OPT_LEARNING_ID" ]; then
        OPT_LEARNING_ID="$1"
      elif [ "$SUBCOMMAND" = "ingest-reviews" ] && [ -z "$OPT_INGEST_FEAT" ]; then
        OPT_INGEST_FEAT="$1"
      else
        err "Unknown argument: $1"
        err "Run: ./scripts/orchestrate.sh --help"
        exit 1
      fi
      ;;
  esac
  shift
done

export OPT_SKIP_CYCLE_CHECK

[ -z "$SUBCOMMAND" ] && { err "No command given. Run: ./scripts/orchestrate.sh --help"; exit 1; }

# Verify we're in a git repo (--help exits inside arg parsing before reaching here)
if ! git rev-parse --is-inside-work-tree &>/dev/null; then
  echo "✗ Not inside a git repository." >&2
  echo "  Run this from the root of your project." >&2
  exit 1
fi

# ══════════════════════════════════════════════════════════════════
# Subcommand: init
# ══════════════════════════════════════════════════════════════════

sub_init() {
  banner "Initializing orchestrator in $(basename "$PROJECT_ROOT")"

  mkdir -p .orchestrator/{results,context,logs}

  # Copy templates from wherever the orchestrator is installed
  if [ ! -f .orchestrator/config.yaml ]; then
    if [ -f "$TEMPLATES_DIR/config.yaml" ]; then
      cp "$TEMPLATES_DIR/config.yaml" .orchestrator/config.yaml
    else
      cat > .orchestrator/config.yaml <<'EOCFG'
source:
  adapter: markdown
  output: orchestration-backlog.json
  markdown:
    file: features.md

autonomy: checkpoint

execution:
  base_branch: main
  skip_done: true
  skip_blocked: true

worktrees:
  base_path: .worktrees
  branch_prefix: feat
  auto_cleanup: true

memory:
  carry_forward_from: global-context.md
  error_pattern_window: 5
  env_refresh: true

safety:
  breaking_change_pause: true
  schema_migration_review: true
  max_file_changes: 50

pr_creation:
  strategy: draft
  auto_assign: true

discovery:
  enabled: true

routing:
  prefer_agents: true
  fallback: feature-marker
EOCFG
    fi
    info "Created .orchestrator/config.yaml"
  else
    echo "  .orchestrator/config.yaml already exists"
  fi

  # .env.example
  if [ ! -f ".env.example" ]; then
    if [ -f "$TEMPLATES_DIR/env.example" ]; then
      cp "$TEMPLATES_DIR/env.example" .env.example
    else
      cat > .env.example <<'EOENV'
LINEAR_API_KEY=
JIRA_URL=
JIRA_EMAIL=
JIRA_TOKEN=
NOTION_TOKEN=
EOENV
    fi
    info "Created .env.example"
  fi

  # .env from template
  if [ ! -f ".env" ]; then
    cp .env.example .env 2>/dev/null || true
    info "Created .env from template"
  fi

  # Gitignore entries
  touch .gitignore
  if [ -f "$TEMPLATES_DIR/gitignore-entries.txt" ]; then
    while IFS= read -r entry; do
      [ -z "$entry" ] && continue
      [[ "$entry" == \#* ]] && continue
      grep -qxF "$entry" .gitignore || echo "$entry" >> .gitignore
    done < "$TEMPLATES_DIR/gitignore-entries.txt"
  else
    for entry in ".env" "orchestration-backlog.json" ".orchestrator/" ".worktrees/"; do
      grep -qxF "$entry" .gitignore || echo "$entry" >> .gitignore
    done
  fi
  info "Updated .gitignore"

  # Starter features.md
  if [ ! -f features.md ]; then
    cat > features.md <<'STARTER'
# Feature Backlog

## [FEAT] feat-001: Example feature
Describe what this feature should do.
- labels: example
- priority: high
STARTER
    info "Created features.md (starter)"
  fi

  echo ""
  echo "Next steps:"
  echo "  1. cp .env.example .env && vim .env"
  echo "  2. vim .orchestrator/config.yaml"
  echo "  3. vim features.md"
  echo "  4. feature-marker-orchestrate --dry-run"
  echo "  5. feature-marker-orchestrate"
}

# ══════════════════════════════════════════════════════════════════
# Subcommand: run
# ══════════════════════════════════════════════════════════════════

sub_run() {
  # Load modules
  source "$LIB_DIR/util.sh"
  source "$LIB_DIR/config.sh"
  source "$LIB_DIR/worktree.sh"
  source "$LIB_DIR/memory.sh"
  source "$LIB_DIR/display.sh"
  # ADR-008 modules
  source "$LIB_DIR/cost.sh"
  source "$LIB_DIR/router.sh"
  source "$LIB_DIR/learning.sh"
  source "$LIB_DIR/size_gate.sh"
  source "$LIB_DIR/cycle_gate.sh"
  # ADR-009 modules (optional — loaded if present)
  [ -f "$LIB_DIR/local_model.sh" ] && source "$LIB_DIR/local_model.sh"
  [ -f "$LIB_DIR/ingest.sh"      ] && source "$LIB_DIR/ingest.sh"
  source "$LIB_DIR/runner.sh"

  # Resolve config file — check multiple locations
  local config_file="$OPT_CONFIG"
  if [ ! -f "$config_file" ]; then
    if [ -f ".orchestrator/config.yaml" ]; then
      config_file=".orchestrator/config.yaml"
    elif [ -f ".orchestrator/config.yml" ]; then
      config_file=".orchestrator/config.yml"
    elif [ -f "orchestrator/config.yml" ]; then
      config_file="orchestrator/config.yml"
    fi
  fi

  # Load config + secrets + validate
  load_config "$config_file"

  WORKTREE_ROOT="$ROOT_DIR/$WORKTREE_BASE"
  export ROOT_DIR CONFIG_DIR STATE_DIR RESULTS_DIR WORKTREE_ROOT
  export WORKTREE_BASE BRANCH_PREFIX BASE_BRANCH ADAPTER AUTONOMY MODEL_DEFAULT MODEL_PLAN MODEL_EXECUTE

  mkdir -p "$STATE_DIR" "$RESULTS_DIR"

  banner "Orchestrate — $ADAPTER / $AUTONOMY / $BASE_BRANCH / model:$MODEL_DEFAULT"

  # ADR-010: reap any finished background ingest jobs from prior sessions
  if declare -f ingest_reap_stale &>/dev/null; then
    ingest_reap_stale || true
  fi

  # ADR-009 PR-E: startup health check (when local_model.sh is present)
  if declare -f local_model_health_check &>/dev/null; then
    local_model_health_check || true
  fi

  # Agent discovery (ADR-006)
  local manifest_file="$CONFIG_DIR/agents-manifest.json"
  if [ "$AGENT_DISCOVERY" = "true" ] && [ -f "$SCRIPT_DIR/agent-discovery.sh" ]; then
    bash "$SCRIPT_DIR/agent-discovery.sh" "$ROOT_DIR" "$manifest_file" 2>&1
  fi

  # Environment discovery
  mem_refresh_env

  # Run adapter
  info "Loading backlog via $ADAPTER adapter..."
  local count
  count=$(run_adapter)
  info "Loaded $count features"

  local backlog_file="$ROOT_DIR/$BACKLOG_OUTPUT"

  # Dry-run: show plan and exit
  if [ "$OPT_DRY_RUN" = true ]; then
    banner "Dry Run — Plan"
    display_backlog "$backlog_file"
    echo ""
    info "Autonomy: $AUTONOMY"
    info "Worktrees: $WORKTREE_ROOT"
    info "Model: $MODEL_DEFAULT (plan: ${MODEL_PLAN:-inherit}, execute: ${MODEL_EXECUTE:-inherit})"
    info "PR strategy: $PR_STRATEGY"
    rm -f "$backlog_file"
    exit 0
  fi

  # Execute
  run_backlog "$backlog_file"

  # Cleanup backlog file
  rm -f "$backlog_file"
}

# ══════════════════════════════════════════════════════════════════
# Subcommand: status
# ══════════════════════════════════════════════════════════════════

sub_status() {
  source "$LIB_DIR/worktree.sh"
  source "$LIB_DIR/display.sh"

  banner "Orchestrator Status"

  if [ ! -d "$STATE_DIR" ] || [ -z "$(ls -A "$STATE_DIR" 2>/dev/null)" ]; then
    info "No features tracked yet. Run: ./scripts/orchestrate.sh run"
    exit 0
  fi

  local done_n=0 pr_n=0 ready_n=0 failed_n=0 total=0

  for dir in "$STATE_DIR"/*/; do
    [ -d "$dir" ] || continue
    local fid
    fid=$(basename "$dir")
    [ -f "$dir/status.json" ] || continue
    total=$((total + 1))
    display_feature_result "$fid"
    local st
    st=$(wt_get_status "$fid")
    case "$st" in
      done) done_n=$((done_n+1)) ;;
      pr-created) pr_n=$((pr_n+1)) ;;
      ready) ready_n=$((ready_n+1)) ;;
      failed) failed_n=$((failed_n+1)) ;;
    esac
  done

  echo ""
  info "Total: $total | Done: $done_n | PR: $pr_n | Ready: $ready_n | Failed: $failed_n"

  # Worktrees
  echo ""
  log "Worktrees:"
  wt_list

  # Agent manifest
  if [ -f "$CONFIG_DIR/agents-manifest.json" ]; then
    local agent_count
    agent_count=$(node -p "JSON.parse(require('fs').readFileSync('$CONFIG_DIR/agents-manifest.json','utf-8')).agents.length" 2>/dev/null || echo "0")
    echo ""
    info "Discovered agents: $agent_count"
  fi
}

# ══════════════════════════════════════════════════════════════════
# Subcommand: clean
# ══════════════════════════════════════════════════════════════════

sub_clean() {
  source "$LIB_DIR/worktree.sh"
  source "$LIB_DIR/memory.sh"

  banner "Cleaning orchestrator state"

  wt_cleanup_all
  mem_reset
  rm -rf "$STATE_DIR" "$RESULTS_DIR"
  mkdir -p "$STATE_DIR" "$RESULTS_DIR"

  info "All state cleared. Ready for a fresh run."
}

# ══════════════════════════════════════════════════════════════════
# Subcommand: calibrate (ADR-008 PR-A)
# ══════════════════════════════════════════════════════════════════

sub_calibrate() {
  source "$LIB_DIR/config.sh"
  source "$LIB_DIR/cost.sh"

  local config_file="$OPT_CONFIG"
  if [ ! -f "$config_file" ]; then
    [ -f ".orchestrator/config.yaml" ] && config_file=".orchestrator/config.yaml"
    [ -f ".orchestrator/config.yml"  ] && config_file=".orchestrator/config.yml"
    [ -f "orchestrator/config.yml"   ] && config_file="orchestrator/config.yml"
  fi

  load_config "$config_file" 2>/dev/null || true
  cost_load_config

  banner "Token Cost Calibration"
  cost_calibrate "$OPT_SAMPLE"
}

# ══════════════════════════════════════════════════════════════════
# Subcommand: learning (ADR-008 PR-C)
# ══════════════════════════════════════════════════════════════════

sub_learning() {
  source "$LIB_DIR/config.sh"
  source "$LIB_DIR/learning.sh"

  local config_file="$OPT_CONFIG"
  if [ ! -f "$config_file" ]; then
    [ -f ".orchestrator/config.yaml" ] && config_file=".orchestrator/config.yaml"
    [ -f ".orchestrator/config.yml"  ] && config_file=".orchestrator/config.yml"
    [ -f "orchestrator/config.yml"   ] && config_file="orchestrator/config.yml"
  fi
  load_config "$config_file" 2>/dev/null || true

  local project_path="$ROOT_DIR/.claude/feature-state/learned.json"
  local global_path="$HOME/.claude/feature-marker/learned/learned.json"

  case "${OPT_LEARNING_ACTION:-list}" in
    list)
      banner "Learning Entries (project tier)"
      learning_list "$project_path" "$OPT_LEARNING_CANDIDATES"
      ;;
    archive)
      if [ -z "$OPT_LEARNING_ID" ]; then
        err "Usage: learning archive <id>"
        exit 1
      fi
      banner "Archive Learning Entry"
      learning_archive "$OPT_LEARNING_ID" "$project_path"
      ;;
    promote)
      if [ -z "$OPT_LEARNING_ID" ]; then
        err "Usage: learning promote <id>"
        exit 1
      fi
      banner "Promote Learning Entry to Global"
      learning_promote "$OPT_LEARNING_ID" "$project_path" "$global_path"
      ;;
    *)
      err "Unknown learning action: $OPT_LEARNING_ACTION"
      err "Available: list, archive <id>, promote <id>"
      exit 1
      ;;
  esac
}

# ══════════════════════════════════════════════════════════════════
# Subcommand: promote-learning (alias for learning promote)
# ══════════════════════════════════════════════════════════════════

sub_promote_learning() {
  if [ -z "$OPT_LEARNING_ID" ]; then
    err "Usage: promote-learning <id>"
    exit 1
  fi
  OPT_LEARNING_ACTION="promote"
  sub_learning
}

# ══════════════════════════════════════════════════════════════════
# Subcommand: resume-paused (ADR-010)
# ══════════════════════════════════════════════════════════════════

sub_resume_paused() {
  if [ -z "$OPT_RESUME_FEAT" ]; then
    err "Usage: ./scripts/orchestrate.sh --resume-paused <feat-id> [--ack]"
    exit 1
  fi

  source "$LIB_DIR/util.sh"
  source "$LIB_DIR/config.sh"
  source "$LIB_DIR/worktree.sh"
  source "$LIB_DIR/memory.sh"
  source "$LIB_DIR/display.sh"
  source "$LIB_DIR/cost.sh"
  source "$LIB_DIR/router.sh"
  source "$LIB_DIR/learning.sh"
  source "$LIB_DIR/size_gate.sh"
  source "$LIB_DIR/cycle_gate.sh"
  [ -f "$LIB_DIR/local_model.sh" ] && source "$LIB_DIR/local_model.sh"
  [ -f "$LIB_DIR/ingest.sh"      ] && source "$LIB_DIR/ingest.sh"
  source "$LIB_DIR/runner.sh"

  local config_file="$OPT_CONFIG"
  if [ ! -f "$config_file" ]; then
    [ -f ".orchestrator/config.yaml" ] && config_file=".orchestrator/config.yaml"
    [ -f ".orchestrator/config.yml"  ] && config_file=".orchestrator/config.yml"
    [ -f "orchestrator/config.yml"   ] && config_file="orchestrator/config.yml"
  fi
  load_config "$config_file" 2>/dev/null || true

  WORKTREE_ROOT="$ROOT_DIR/$WORKTREE_BASE"
  export ROOT_DIR CONFIG_DIR STATE_DIR RESULTS_DIR WORKTREE_ROOT
  export WORKTREE_BASE BRANCH_PREFIX BASE_BRANCH ADAPTER AUTONOMY MODEL_DEFAULT MODEL_PLAN MODEL_EXECUTE
  mkdir -p "$STATE_DIR" "$RESULTS_DIR"

  banner "Resume Paused — $OPT_RESUME_FEAT"

  local ack_flag=""
  [ "$OPT_RESUME_ACK" = "true" ] && ack_flag="--ack"

  run_feature_resume "$OPT_RESUME_FEAT" $ack_flag
}

# ══════════════════════════════════════════════════════════════════
# Subcommand: ingest-status (ADR-009)
# ══════════════════════════════════════════════════════════════════

sub_ingest_status() {
  [ -f "$LIB_DIR/ingest.sh" ] && source "$LIB_DIR/ingest.sh" || true

  banner "Background Ingest Status"
  if declare -f ingest_status &>/dev/null; then
    ingest_status
  else
    info "ingest.sh not loaded — no background ingest infrastructure present."
  fi
}

# ══════════════════════════════════════════════════════════════════
# Dispatch
# ══════════════════════════════════════════════════════════════════

case "$SUBCOMMAND" in
  init)            sub_init ;;
  run)             sub_run ;;
  status)          sub_status ;;
  clean)           sub_clean ;;
  calibrate)       sub_calibrate ;;
  learning)        sub_learning ;;
  promote-learning) sub_promote_learning ;;
  resume-paused)   sub_resume_paused ;;
  ingest-status)   sub_ingest_status ;;
esac
