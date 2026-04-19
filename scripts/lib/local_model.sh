#!/bin/bash
# lib/local_model.sh — Local-model provider adapter (ADR-009 PR-E)
#
# Exposes four functions over a thin HTTP adapter:
#   local_model::embed   <text>              → JSON float array (stdout)
#   local_model::classify <text> <labels>    → label string (stdout)
#   local_model::summarize <text>            → summary string (stdout)
#   local_model::generate <prompt>           → generated text (stdout)
#
# Provider selection: local_model.provider in config.yml
#   ollama     — http://localhost:11434  (default)
#   lm-studio  — http://localhost:1234   (OpenAI-compat)
#   llama-cpp  — http://localhost:8080   (OpenAI-compat)
#
# All functions degrade gracefully (return empty / pass-through) when
# local_model.enabled is false or the endpoint is unreachable with fail_open=true.
#
# Health-check result cached to: .orchestrator/state/local_model_health.json

# ── Config defaults (overridden by load_config) ──────────────────────

LOCAL_MODEL_ENABLED="${CFG_LOCAL_MODEL_ENABLED:-false}"
LOCAL_MODEL_PROVIDER="${CFG_LOCAL_MODEL_PROVIDER:-ollama}"
LOCAL_MODEL_ENDPOINT="${CFG_LOCAL_MODEL_ENDPOINT:-http://localhost:11434}"
LOCAL_MODEL_EMBEDDING_MODEL="${CFG_LOCAL_MODEL_EMBEDDING_MODEL:-nomic-embed-text}"
LOCAL_MODEL_CLASSIFIER_MODEL="${CFG_LOCAL_MODEL_CLASSIFIER_MODEL:-llama3.2:3b}"
LOCAL_MODEL_SUMMARIZER_MODEL="${CFG_LOCAL_MODEL_SUMMARIZER_MODEL:-llama3.2:3b}"
LOCAL_MODEL_GENERATOR_MODEL="${CFG_LOCAL_MODEL_GENERATOR_MODEL:-}"
LOCAL_MODEL_TIMEOUT="${CFG_LOCAL_MODEL_TIMEOUT:-10}"
LOCAL_MODEL_FAIL_OPEN="${CFG_LOCAL_MODEL_FAIL_OPEN:-true}"
LOCAL_MODEL_HEALTH_FILE="${STATE_DIR:-/tmp}/local_model_health.json"

# ── _local_model_endpoint_for_provider ───────────────────────────────
# Returns the default base URL for the given provider.

_local_model_default_endpoint() {
  case "$1" in
    ollama)    echo "http://localhost:11434" ;;
    lm-studio) echo "http://localhost:1234" ;;
    llama-cpp) echo "http://localhost:8080" ;;
    *)         echo "http://localhost:11434" ;;
  esac
}

# ── _local_model_health_url ───────────────────────────────────────────

_local_model_health_url() {
  case "${LOCAL_MODEL_PROVIDER}" in
    ollama)    echo "${LOCAL_MODEL_ENDPOINT}/api/tags" ;;
    *)         echo "${LOCAL_MODEL_ENDPOINT}/v1/models" ;;
  esac
}

# ── local_model_health_check ──────────────────────────────────────────
# Usage: local_model_health_check
# Pings the configured endpoint and writes result to local_model_health.json.
# Called once per orchestrator run (result is reused within the run).
# Returns 0 if reachable, 1 if not.

local_model_health_check() {
  [ "${LOCAL_MODEL_ENABLED}" != "true" ] && return 0

  local health_url
  health_url=$(_local_model_health_url)

  local response http_code
  http_code=$(curl -s -o /tmp/lm_health_$$.json -w "%{http_code}" \
    --max-time "${LOCAL_MODEL_TIMEOUT}" "${health_url}" 2>/dev/null || echo "000")

  local reachable=false
  local models="[]"

  if [ "$http_code" = "200" ]; then
    reachable=true
    models=$(cat /tmp/lm_health_$$.json 2>/dev/null || echo "[]")
  fi
  rm -f /tmp/lm_health_$$.json

  mkdir -p "$(dirname "$LOCAL_MODEL_HEALTH_FILE")"
  node -e "
    const fs = require('fs');
    fs.writeFileSync('${LOCAL_MODEL_HEALTH_FILE}', JSON.stringify({
      checked_at: new Date().toISOString(),
      provider: '${LOCAL_MODEL_PROVIDER}',
      endpoint: '${LOCAL_MODEL_ENDPOINT}',
      reachable: ${reachable},
      http_code: '${http_code}'
    }, null, 2));
  " 2>/dev/null || true

  if [ "$reachable" = "true" ]; then
    info "Local model: ${LOCAL_MODEL_PROVIDER} reachable at ${LOCAL_MODEL_ENDPOINT} [DEBUG]"
    return 0
  fi

  if [ "${LOCAL_MODEL_FAIL_OPEN}" = "true" ]; then
    info "Local model: ${LOCAL_MODEL_PROVIDER} unreachable (${LOCAL_MODEL_ENDPOINT}) — degrading to Claude / exact-match"
    return 0
  else
    err "Local model: ${LOCAL_MODEL_PROVIDER} unreachable at ${LOCAL_MODEL_ENDPOINT}"
    err "  Provider: ${LOCAL_MODEL_PROVIDER}"
    err "  Endpoint: ${LOCAL_MODEL_ENDPOINT}"
    err "  Hint: start your local model server and retry, or set fail_open: true in config"
    return 1
  fi
}

# ── _local_model_is_reachable ─────────────────────────────────────────
# Checks cached health-check result. Returns 0 if reachable.

_local_model_is_reachable() {
  [ "${LOCAL_MODEL_ENABLED}" != "true" ] && return 1

  if [ -f "${LOCAL_MODEL_HEALTH_FILE}" ]; then
    local reachable
    reachable=$(node -p "
      try {
        JSON.parse(require('fs').readFileSync('${LOCAL_MODEL_HEALTH_FILE}','utf-8')).reachable;
      } catch(e) { false; }
    " 2>/dev/null || echo "false")
    [ "$reachable" = "true" ] && return 0
  fi
  return 1
}

# ── _local_model_post ─────────────────────────────────────────────────
# Internal: POST JSON body to endpoint, return response body.
# Usage: _local_model_post <url> <json_body>

_local_model_post() {
  local url="$1"
  local body="$2"

  curl -s -X POST "$url" \
    -H "Content-Type: application/json" \
    --max-time "${LOCAL_MODEL_TIMEOUT}" \
    -d "$body" 2>/dev/null || echo ""
}

# ── local_model::embed ────────────────────────────────────────────────
# Usage: local_model::embed <text>
# Returns a JSON float array on stdout, or "" on failure.
# Providers: ollama /api/embeddings, openai-compat /v1/embeddings

local_model::embed() {
  local text="$1"

  _local_model_is_reachable || { echo ""; return 0; }

  local response=""

  case "${LOCAL_MODEL_PROVIDER}" in
    ollama)
      local body
      body=$(node -e "process.stdout.write(JSON.stringify({
        model: '${LOCAL_MODEL_EMBEDDING_MODEL}',
        prompt: $(node -p "JSON.stringify('$text')" 2>/dev/null || echo '""')
      }))" 2>/dev/null)
      response=$(_local_model_post "${LOCAL_MODEL_ENDPOINT}/api/embeddings" "$body")
      # Ollama returns: {"embedding": [...]}
      echo "$response" | node -p "
        try {
          const d = JSON.parse(require('fs').readFileSync('/dev/stdin','utf-8'));
          JSON.stringify(d.embedding || []);
        } catch(e) { '[]'; }
      " 2>/dev/null || echo "[]"
      ;;
    lm-studio|llama-cpp)
      local body
      body=$(node -e "process.stdout.write(JSON.stringify({
        model: '${LOCAL_MODEL_EMBEDDING_MODEL}',
        input: $(node -p "JSON.stringify('$text')" 2>/dev/null || echo '""')
      }))" 2>/dev/null)
      response=$(_local_model_post "${LOCAL_MODEL_ENDPOINT}/v1/embeddings" "$body")
      # OpenAI-compat: {"data": [{"embedding": [...]}]}
      echo "$response" | node -p "
        try {
          const d = JSON.parse(require('fs').readFileSync('/dev/stdin','utf-8'));
          JSON.stringify((d.data && d.data[0] && d.data[0].embedding) || []);
        } catch(e) { '[]'; }
      " 2>/dev/null || echo "[]"
      ;;
    *)
      echo "[]"
      ;;
  esac
}

# ── local_model::classify ─────────────────────────────────────────────
# Usage: local_model::classify <text> <space-separated labels>
# Returns the best matching label, or "unknown" on failure.

local_model::classify() {
  local text="$1"
  local labels="$2"  # e.g. "ui api db infra test unknown"

  _local_model_is_reachable || { echo "unknown"; return 0; }

  local system_prompt="You are a task classifier. Given a task description, output exactly one label from this list: ${labels}. Output only the label, nothing else."
  local user_msg="Task: ${text}"

  local response
  response=$(_local_model_chat_completion \
    "${LOCAL_MODEL_CLASSIFIER_MODEL}" \
    "$system_prompt" \
    "$user_msg")

  local label
  label=$(echo "$response" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')

  # Validate against allowed labels
  local valid=false
  for l in $labels; do
    [ "$label" = "$l" ] && valid=true && break
  done

  [ "$valid" = "true" ] && echo "$label" || echo "unknown"
}

# ── local_model::summarize ────────────────────────────────────────────
# Usage: local_model::summarize <text>
# Returns a JSON object: {"fixes":[{"pattern":"...","fix":"..."}],"confidence":0.82}
# Returns {} on failure.

local_model::summarize() {
  local text="$1"

  _local_model_is_reachable || { echo "{}"; return 0; }

  local system_prompt='You are a code-fix extractor. Given free-form text (PR review comments or CI failure logs), extract actionable fixes. Output ONLY valid JSON in this exact format: {"fixes":[{"pattern":"<error or anti-pattern>","fix":"<corrective action>"}],"confidence":0.85}. If there is nothing actionable, output {"fixes":[],"confidence":0}.'
  local user_msg="$text"

  local response
  response=$(_local_model_chat_completion \
    "${LOCAL_MODEL_SUMMARIZER_MODEL}" \
    "$system_prompt" \
    "$user_msg")

  # Validate JSON
  echo "$response" | node -p "
    try {
      const d = JSON.parse(require('fs').readFileSync('/dev/stdin','utf-8'));
      JSON.stringify(d);
    } catch(e) { '{}'; }
  " 2>/dev/null || echo "{}"
}

# ── local_model::generate ─────────────────────────────────────────────
# Usage: local_model::generate <prompt>
# Returns generated text on stdout, or "" on failure.
# Only active when LOCAL_MODEL_GENERATOR_MODEL is set.

local_model::generate() {
  local prompt="$1"

  [ -z "${LOCAL_MODEL_GENERATOR_MODEL}" ] && { echo ""; return 0; }
  _local_model_is_reachable || { echo ""; return 0; }

  local response
  response=$(_local_model_chat_completion \
    "${LOCAL_MODEL_GENERATOR_MODEL}" \
    "You are an expert software engineer. Implement the requested changes accurately and completely." \
    "$prompt")

  echo "$response"
}

# ── _local_model_chat_completion ──────────────────────────────────────
# Internal: sends a chat completion request to the configured provider.
# Usage: _local_model_chat_completion <model> <system_prompt> <user_msg>
# Returns the assistant message content on stdout.

_local_model_chat_completion() {
  local model="$1"
  local system_prompt="$2"
  local user_msg="$3"

  local body
  body=$(node -e "
    process.stdout.write(JSON.stringify({
      model: $(node -p "JSON.stringify('$model')" 2>/dev/null || echo '\"\"'),
      messages: [
        { role: 'system', content: $(node -p "JSON.stringify('$system_prompt')" 2>/dev/null || echo '\"\"') },
        { role: 'user',   content: $(node -p "JSON.stringify('$user_msg')" 2>/dev/null || echo '\"\"') }
      ],
      stream: false,
      temperature: 0.1
    }));
  " 2>/dev/null)

  local url
  case "${LOCAL_MODEL_PROVIDER}" in
    ollama)    url="${LOCAL_MODEL_ENDPOINT}/api/chat" ;;
    *)         url="${LOCAL_MODEL_ENDPOINT}/v1/chat/completions" ;;
  esac

  local response
  response=$(_local_model_post "$url" "$body")

  # Extract assistant content
  echo "$response" | node -p "
    try {
      const d = JSON.parse(require('fs').readFileSync('/dev/stdin','utf-8'));
      // Ollama: d.message.content  |  OpenAI-compat: d.choices[0].message.content
      (d.message && d.message.content) ||
      (d.choices && d.choices[0] && d.choices[0].message && d.choices[0].message.content) ||
      '';
    } catch(e) { ''; }
  " 2>/dev/null || echo ""
}
