#!/bin/bash
# lib/config.sh — Config loading, .env sourcing, validation
#
# Sources .env for secrets, parses config.yml via parse-config.js,
# applies CLI overrides, and validates adapter-specific requirements.
# Does not export API keys to subprocesses unnecessarily.

load_config() {
  local config_path="${1:-orchestrator/config.yml}"

  if [ ! -f "$config_path" ]; then
    err "Config not found: $config_path"
    info "Run: ./scripts/orchestrate.sh init"
    exit 1
  fi

  # Source .env (secrets — never in config.yml)
  if [ -f ".env" ]; then
    local line
    while IFS= read -r line || [ -n "$line" ]; do
      line=$(echo "$line" | sed 's/#.*//' | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
      [ -z "$line" ] && continue
      export "$line" 2>/dev/null || true
    done < ".env"
  fi

  # Parse config.yml → CFG_* variables
  eval "$(node "$LIB_DIR/../parse-config.js" "$config_path" 2>/dev/null || echo '')"

  # Map config to runtime variables
  ADAPTER="${CFG_SOURCE_ADAPTER:-markdown}"
  BACKLOG_OUTPUT="${CFG_SOURCE_OUTPUT:-orchestration-backlog.json}"
  AUTONOMY="${CFG_AUTONOMY:-checkpoint}"
  BASE_BRANCH="${CFG_EXECUTION_BASE_BRANCH:-main}"
  SKIP_DONE="${CFG_EXECUTION_SKIP_DONE:-true}"
  SKIP_BLOCKED="${CFG_EXECUTION_SKIP_BLOCKED:-true}"
  MAX_RETRIES="${CFG_FEATURES_MAX_RETRIES:-2}"
  PR_STRATEGY="${CFG_PR_CREATION_STRATEGY:-draft}"

  # Adapter-specific config
  SOURCE_FILE="${CFG_SOURCE_MARKDOWN_FILE:-features.md}"
  SOURCE_LABEL="${CFG_SOURCE_GITHUB_LABEL:-feature-marker}"
  SOURCE_TEAM="${CFG_SOURCE_LINEAR_TEAM:-ENG}"

  # Worktree config
  WORKTREE_BASE="${CFG_WORKTREES_BASE_PATH:-.worktrees}"
  BRANCH_PREFIX="${CFG_WORKTREES_BRANCH_PREFIX:-feat}"
  AUTO_CLEANUP="${CFG_WORKTREES_AUTO_CLEANUP:-true}"

  # Memory (ADR-002)
  CARRY_FORWARD="${CFG_MEMORY_CARRY_FORWARD_FROM:-global-context.md}"
  ERROR_WINDOW="${CFG_MEMORY_ERROR_PATTERN_WINDOW:-5}"
  ENV_REFRESH="${CFG_MEMORY_ENV_REFRESH:-true}"

  # Safety
  BREAKING_PAUSE="${CFG_SAFETY_BREAKING_CHANGE_PAUSE:-true}"
  SCHEMA_REVIEW="${CFG_SAFETY_SCHEMA_MIGRATION_REVIEW:-true}"
  MAX_FILE_CHANGES="${CFG_SAFETY_MAX_FILE_CHANGES:-50}"

  # Discovery (ADR-006)
  AGENT_DISCOVERY="${CFG_DISCOVERY_ENABLED:-true}"
  ROUTING_PREFER="${CFG_ROUTING_PREFER_AGENTS:-true}"
  ROUTING_FALLBACK="${CFG_ROUTING_FALLBACK:-feature-marker}"

  # Model selection
  MODEL_DEFAULT="${CFG_MODEL_DEFAULT:-opusplan}"
  MODEL_PLAN="${CFG_MODEL_PLAN:-}"
  MODEL_EXECUTE="${CFG_MODEL_EXECUTE:-}"

  # Apply CLI overrides
  [ -n "${OPT_AUTONOMY:-}" ] && AUTONOMY="$OPT_AUTONOMY"
  [ -n "${OPT_ADAPTER:-}" ] && ADAPTER="$OPT_ADAPTER"
  [ -n "${OPT_MODEL:-}" ] && MODEL_DEFAULT="$OPT_MODEL"

  # ANTHROPIC_MODEL env var takes highest precedence
  if [ -n "${ANTHROPIC_MODEL:-}" ]; then
    MODEL_DEFAULT="$ANTHROPIC_MODEL"
    MODEL_PLAN=""
    MODEL_EXECUTE=""
  fi

  # ADR-009 — local model config
  LOCAL_MODEL_ENABLED="${CFG_LOCAL_MODEL_ENABLED:-false}"
  LOCAL_MODEL_PROVIDER="${CFG_LOCAL_MODEL_PROVIDER:-ollama}"
  LOCAL_MODEL_ENDPOINT="${CFG_LOCAL_MODEL_ENDPOINT:-http://localhost:11434}"
  LOCAL_MODEL_EMBEDDING_MODEL="${CFG_LOCAL_MODEL_EMBEDDING_MODEL:-nomic-embed-text}"
  LOCAL_MODEL_CLASSIFIER_MODEL="${CFG_LOCAL_MODEL_CLASSIFIER_MODEL:-llama3.2:3b}"
  LOCAL_MODEL_SUMMARIZER_MODEL="${CFG_LOCAL_MODEL_SUMMARIZER_MODEL:-llama3.2:3b}"
  LOCAL_MODEL_GENERATOR_MODEL="${CFG_LOCAL_MODEL_GENERATOR_MODEL:-}"
  LOCAL_MODEL_TIMEOUT="${CFG_LOCAL_MODEL_TIMEOUT_SECONDS:-10}"
  LOCAL_MODEL_FAIL_OPEN="${CFG_LOCAL_MODEL_FAIL_OPEN:-true}"

  # Export so local_model.sh and ingest.sh can read them in subshells
  export LOCAL_MODEL_ENABLED LOCAL_MODEL_PROVIDER LOCAL_MODEL_ENDPOINT
  export LOCAL_MODEL_EMBEDDING_MODEL LOCAL_MODEL_CLASSIFIER_MODEL
  export LOCAL_MODEL_SUMMARIZER_MODEL LOCAL_MODEL_GENERATOR_MODEL
  export LOCAL_MODEL_TIMEOUT LOCAL_MODEL_FAIL_OPEN

  # ADR-009 — per-phase engine overrides (read by runner.sh)
  CFG_LOCAL_MODEL_ENGINE_PHASE2="${CFG_LOCAL_MODEL_ENGINE_PER_PHASE_PHASE_2:-claude}"
  export CFG_LOCAL_MODEL_ENGINE_PHASE2

  # Validate
  validate_config
}

validate_config() {
  local errors=0

  # Validate autonomy
  case "$AUTONOMY" in
    supervised|checkpoint|full_auto) ;;
    *) err "Invalid autonomy: $AUTONOMY (expected: supervised, checkpoint, full_auto)"; errors=$((errors+1)) ;;
  esac

  # Validate adapter exists
  local adapter_script="$LIB_DIR/../adapters/${ADAPTER}.js"
  if [ ! -f "$adapter_script" ]; then
    err "No adapter for source.adapter: $ADAPTER"
    err "Available: $(ls "$LIB_DIR/../adapters/"*.js 2>/dev/null | xargs -I{} basename {} .js | tr '\n' ', ')"
    errors=$((errors+1))
  fi

  # Adapter-specific validation (only check active adapter)
  case "$ADAPTER" in
    github)
      if ! command -v gh &>/dev/null; then
        err "gh CLI not found. Install: https://cli.github.com"
        errors=$((errors+1))
      elif ! gh auth status >/dev/null 2>&1; then
        err "gh not authenticated. Run: gh auth login"
        errors=$((errors+1))
      fi
      ;;
    linear)
      if [ -z "${LINEAR_API_KEY:-}" ]; then
        err "LINEAR_API_KEY not set. Add it to .env (see .env.example)"
        errors=$((errors+1))
      fi
      ;;
  esac

  # gh CLI is needed for execution but not for dry-run
  if [ "$PR_STRATEGY" != "none" ] && [ "$AUTONOMY" = "full_auto" ]; then
    if ! command -v gh &>/dev/null; then
      info "gh CLI not found. Install it. PR creation will be skipped."
    fi
  fi

  # Validate adapter-specific requirements
  if [ "$ADAPTER" = "markdown" ] && [ ! -f "$SOURCE_FILE" ]; then
    err "Backlog file not found: $SOURCE_FILE"
    errors=$((errors+1))
  fi

  [ $errors -gt 0 ] && exit 1
  return 0
}

run_adapter() {
  local adapter_script="$LIB_DIR/../adapters/${ADAPTER}.js"

  case "$ADAPTER" in
    markdown)
      node "$adapter_script" "$ROOT_DIR/$SOURCE_FILE"
      ;;
    github)
      node "$adapter_script" "$SOURCE_LABEL"
      ;;
    linear)
      node "$adapter_script" "$SOURCE_TEAM"
      ;;
    *)
      node "$adapter_script" 2>&1 || { err "Adapter $ADAPTER failed"; exit 1; }
      ;;
  esac

  local output="$ROOT_DIR/$BACKLOG_OUTPUT"
  if [ ! -f "$output" ]; then
    err "Adapter produced no output: $output"
    exit 1
  fi

  local count
  count=$(node -p "JSON.parse(require('fs').readFileSync('$output','utf-8')).length" 2>/dev/null || echo "0")
  echo "$count"
}
