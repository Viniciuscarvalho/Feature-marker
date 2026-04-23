#!/bin/bash
# lib/router.sh — Block-based stack routing with specialist fallback (ADR-008 PR-B, ADR-009 PR-G)
#
# Detects the tech stack from file paths associated with a task, maps that stack
# to the most appropriate specialist agent, checks if the agent is installed, and
# falls back to the generic feature-marker if not.
#
# ADR-009 PR-G: when local_model.enabled=true, local_model::classify refines
# routing beyond file-path heuristics. The classification_label is stored in
# stack-map.json alongside the resolved_agent.
#
# Stack-map cache: .orchestrator/stack-map.json
# Agent install check: .claude/agents/<name>.md (or .yaml)

STACK_MAP_FILE="${STACK_MAP_FILE:-$CONFIG_DIR/stack-map.json}"
AGENTS_DIR="${AGENTS_DIR:-$ROOT_DIR/.claude/agents}"

# ── router_init ──────────────────────────────────────────────────────
# Usage: router_init <feat_id>
# Initialises stack-map.json if it does not already exist.

router_init() {
  local feat_id="$1"
  mkdir -p "$CONFIG_DIR"

  if [ ! -f "$STACK_MAP_FILE" ]; then
    json_init_file "$STACK_MAP_FILE" 2>/dev/null \
      || echo '{"created_at":"","entries":{}}' > "$STACK_MAP_FILE"
  fi
}

# ── router_detect_stack_from_paths ───────────────────────────────────
# Usage: router_detect_stack_from_paths <colon:separated:file:paths>
# Inspects file extensions and returns the detected stack name.
# Returns: ios | node | python | rust | go | unknown

router_detect_stack_from_paths() {
  local paths_str="$1"

  # Prefer stack_profile_primary when stack_profile_init has already run for this worktree.
  # Fall back to extension counting so direct callers (e.g. tests) still work without a worktree.
  if [ -n "${PROJECT_STACK:-}" ] && [ "${PROJECT_STACK}" != "unknown" ]; then
    # Normalise: stack-detector.sh uses "nodejs" but the router historically used "node"
    case "$PROJECT_STACK" in
      nodejs) echo "node" ;;
      *)      echo "$PROJECT_STACK" ;;
    esac
    return 0
  fi

  # Extension-counting fallback (preserved for backward compatibility)
  local stack="unknown"
  local swift_count=0 node_count=0 python_count=0 rust_count=0 go_count=0

  local IFS_ORIG="$IFS"
  IFS=":"
  for p in $paths_str; do
    IFS="$IFS_ORIG"
    case "$p" in
      *.swift)           swift_count=$((swift_count + 1)) ;;
      *.ts|*.tsx|*.js)   node_count=$((node_count + 1)) ;;
      *.py)              python_count=$((python_count + 1)) ;;
      *.rs)              rust_count=$((rust_count + 1)) ;;
      *.go)              go_count=$((go_count + 1)) ;;
    esac
    IFS=":"
  done
  IFS="$IFS_ORIG"

  local max=0
  [ "$swift_count"  -gt "$max" ] && max="$swift_count"  && stack="ios"
  [ "$node_count"   -gt "$max" ] && max="$node_count"   && stack="node"
  [ "$python_count" -gt "$max" ] && max="$python_count" && stack="python"
  [ "$rust_count"   -gt "$max" ] && max="$rust_count"   && stack="rust"
  [ "$go_count"     -gt "$max" ] && max="$go_count"     && stack="go"

  echo "$stack"
}

# ── router_stack_to_agent ────────────────────────────────────────────
# Usage: router_stack_to_agent <stack>
# Maps a stack name to the preferred specialist agent name.

router_stack_to_agent() {
  local stack="$1"

  case "$stack" in
    ios)    echo "swift-expert" ;;
    node)   echo "typescript-pro" ;;
    python) echo "python-pro" ;;
    rust)   echo "rust-expert" ;;
    go)     echo "go-expert" ;;
    *)      echo "feature-marker" ;;
  esac
}

# ── router_agent_installed ───────────────────────────────────────────
# Usage: router_agent_installed <agent_name>
# Returns 0 if an agent definition exists under .claude/agents/; 1 otherwise.
# Checks for both .md and .yaml/.yml extensions.

router_agent_installed() {
  local agent_name="$1"

  [ -f "$AGENTS_DIR/${agent_name}.md"   ] && return 0
  [ -f "$AGENTS_DIR/${agent_name}.yaml" ] && return 0
  [ -f "$AGENTS_DIR/${agent_name}.yml"  ] && return 0
  return 1
}

# ── router_route_task ────────────────────────────────────────────────
# Usage: router_route_task <feat_id> <task_id> <colon:separated:file:paths>
# Full routing pipeline:
#   1. Detect stack from file paths
#   2. Map stack to preferred agent
#   3. Check if agent is installed; fall back to feature-marker if not
#   4. Cache result in stack-map.json
# Prints the resolved agent name to stdout.

router_route_task() {
  local feat_id="$1"
  local task_id="$2"
  local file_paths="$3"

  router_init "$feat_id"

  # Check cache first
  local cached
  cached=$(router_get_cached "$feat_id" "$task_id")
  if [ -n "$cached" ] && [ "$cached" != "null" ]; then
    echo "$cached"
    return 0
  fi

  # Detect stack
  local stack
  stack=$(router_detect_stack_from_paths "$file_paths")

  # Map to agent
  local preferred_agent
  preferred_agent=$(router_stack_to_agent "$stack")

  # Fallback if agent not installed
  local resolved_agent="$preferred_agent"
  if [ "$preferred_agent" != "feature-marker" ]; then
    if ! router_agent_installed "$preferred_agent"; then
      info "Router: $preferred_agent not installed — falling back to feature-marker (task: $task_id)"
      resolved_agent="feature-marker"
    fi
  fi

  # ADR-009 PR-G: optional classifier refinement via local model
  local classification_label="unknown"
  if [ "${LOCAL_MODEL_ENABLED:-false}" = "true" ]; then
    local classify_input
    classify_input="Stack: $stack. Files: $(echo "$file_paths" | tr ':' ' ')"
    local classified
    classified=$(local_model::classify "$classify_input" "ui api db infra test unknown" 2>/dev/null || echo "unknown")
    if [ "$classified" != "unknown" ]; then
      classification_label="$classified"
      info "Router: classifier label=$classification_label (task: $task_id)"
    fi
  fi

  # Cache the result — values passed as argv, not interpolated into JS source
  json_set_entry "$STACK_MAP_FILE" "${feat_id}::${task_id}" \
    feat_id              "$feat_id" \
    task_id              "$task_id" \
    stack                "$stack" \
    classification_label "$classification_label" \
    preferred_agent      "$preferred_agent" \
    resolved_agent       "$resolved_agent" \
    file_paths           "$file_paths" \
    2>/dev/null || true

  echo "$resolved_agent"
}

# ── router_get_cached ────────────────────────────────────────────────
# Usage: router_get_cached <feat_id> <task_id>
# Reads the resolved agent from stack-map.json cache.
# Prints the agent name, or empty string if not cached.

router_get_cached() {
  local feat_id="$1"
  local task_id="$2"

  [ ! -f "$STACK_MAP_FILE" ] && echo "" && return

  json_get_entry "$STACK_MAP_FILE" "${feat_id}::${task_id}" resolved_agent 2>/dev/null || echo ""
}
