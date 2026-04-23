#!/usr/bin/env bash
# lib/sanitize.sh — Input sanitisation for autonomous orchestration (ADR-011 PR-B)
#
# Exposes three functions:
#   sanitize_feature_body <text>    — sanitise a raw backlog body; returns cleaned text on stdout
#   sanitize_context_chunk <text>   — sanitise a memory chunk before prompt injection
#   detect_injection_markers <text> — exits 1 if markers found; prints matching patterns to stderr
#
# Detection corpus covers:
#   - Delimiter/role-hijack phrases ("ignore previous instructions", "you are now", etc.)
#   - Secret-exfiltration requests (cat ~/.ssh, ~/.claude, /etc/passwd)
#   - Unicode direction-overrides (U+202E, U+200B, U+FEFF)
#   - Known jailbreak prefixes (DAN, STAN, "pretend you are", etc.)
#   - Suspicious shell metacharacter patterns in prose
#
# Sanitised output wraps the (cleaned) user content in an explicit USER_FEATURE fence so
# the Claude system prompt can instruct Claude to treat that section as untrusted user input.
#
# SANITIZE_MODE env var: strict (default) | relaxed | off
#   strict  — strip all markers, emit WARNING on stderr, quarantine if score >= threshold
#   relaxed — strip obvious markers only, no quarantine
#   off     — pass through unchanged (for debugging only)

SANITIZE_MODE="${SANITIZE_MODE:-strict}"
_SANITIZE_SCORE_THRESHOLD=2

# ── detect_injection_markers ─────────────────────────────────────────────────

detect_injection_markers() {
  local text="$1"
  local found=0

  # Role-hijack and delimiter-breakout patterns (case-insensitive)
  local patterns=(
    "ignore (all )?(previous|prior|above) instructions?"
    "you are now"
    "disregard (your|all) (previous|prior|above)"
    "forget (everything|all) (you|above)"
    "act as (if you are|a|an)"
    "pretend (you are|to be)"
    "your (new|real|true) (role|persona|instructions?) (is|are)"
    "from now on[,.]? (you|always|never|do)"
    "(DAN|STAN|AIM|JAILBREAK)[: ]"
    "override (safety|security|ethical) (guidelines|rules|constraints)"
    "===RULES===" "===SYSTEM===" "===OVERRIDE==="
    "\[SYSTEM\]" "\[ADMIN\]" "\[ASSISTANT\]"
    "IGNORE_PREVIOUS" "NEW_INSTRUCTIONS"
  )

  # Secret-exfiltration patterns
  local exfil_patterns=(
    "cat ~/\.(ssh|claude|gnupg|aws|config)"
    "~\/\.ssh\/" "\/etc\/passwd" "\/etc\/shadow"
    "id_rsa" "\.pem" "\.p12" "\.pfx" "\.key"
    "\$HOME\/\." "\/root\/\."
  )

  # Unicode direction-override and zero-width characters
  local unicode_patterns=(
    $'\xe2\x80\xae'  # U+202E RIGHT-TO-LEFT OVERRIDE
    $'\xef\xbb\xbf'  # U+FEFF BOM
    $'\xe2\x80\x8b'  # U+200B ZERO WIDTH SPACE
  )

  local score=0

  for pat in "${patterns[@]}"; do
    if echo "$text" | grep -qiE "$pat" 2>/dev/null; then
      echo "INJECTION_MARKER: role-hijack pattern matched: $pat" >&2
      score=$((score + 1))
      found=1
    fi
  done

  for pat in "${exfil_patterns[@]}"; do
    if echo "$text" | grep -qE "$pat" 2>/dev/null; then
      echo "INJECTION_MARKER: exfil pattern matched: $pat" >&2
      score=$((score + 2))
      found=1
    fi
  done

  for uc in "${unicode_patterns[@]}"; do
    if echo "$text" | grep -qF "$uc" 2>/dev/null; then
      echo "INJECTION_MARKER: unicode direction-override detected" >&2
      score=$((score + 1))
      found=1
    fi
  done

  if [ "$found" -eq 1 ]; then
    echo "$score"
    return 1
  fi
  echo "0"
  return 0
}

# ── _sanitize_strip ───────────────────────────────────────────────────────────
# Strip known injection patterns from text; return cleaned text on stdout.

_sanitize_strip() {
  local text="$1"

  # Remove lines containing role-hijack phrases
  local cleaned
  cleaned=$(echo "$text" | grep -viE \
    "(ignore (all )?(previous|prior|above) instructions?|you are now|disregard (your|all)|forget (everything|all) (you|above)|act as (if you are|a|an)|pretend (you are|to be)|your (new|real|true) (role|persona)|from now on[,.] ?(you|always|never|do)|DAN[: ]|STAN[: ]|AIM[: ]|JAILBREAK[: ]|override (safety|security|ethical)|===RULES===|===SYSTEM===|===OVERRIDE===|\[SYSTEM\]|\[ADMIN\]|\[ASSISTANT\]|IGNORE_PREVIOUS|NEW_INSTRUCTIONS)" \
    2>/dev/null || echo "$text")

  # Remove secret-exfil patterns
  cleaned=$(echo "$cleaned" | grep -viE \
    "(cat ~/\.(ssh|claude|gnupg|aws|config)|\/etc\/passwd|\/etc\/shadow|id_rsa|\.pem\b|\.p12\b|\.pfx\b|\.key\b|\$HOME\/\.)" \
    2>/dev/null || echo "$cleaned")

  # Remove unicode direction-overrides (replace with empty)
  cleaned=$(printf '%s' "$cleaned" | tr -d $'\xe2\x80\xae\xef\xbb\xbf\xe2\x80\x8b' 2>/dev/null || echo "$cleaned")

  echo "$cleaned"
}

# ── sanitize_feature_body ─────────────────────────────────────────────────────

sanitize_feature_body() {
  local body="$1"

  if [ "$SANITIZE_MODE" = "off" ]; then
    echo "$body"
    return 0
  fi

  local score
  score=$(detect_injection_markers "$body" 2>/dev/null) || true

  if [ "$SANITIZE_MODE" = "strict" ] && [ "${score:-0}" -ge "$_SANITIZE_SCORE_THRESHOLD" ]; then
    echo "SANITIZE WARNING: injection score $score >= threshold $_SANITIZE_SCORE_THRESHOLD — quarantining body" >&2
    echo "[SANITIZED: body QUARANTINED due to injection markers — score $score]"
    return 0
  fi

  local cleaned
  cleaned=$(_sanitize_strip "$body")

  # Wrap in USER_FEATURE fence so Claude can treat it as untrusted user input
  printf '===USER_FEATURE===\n%s\n===END_USER_FEATURE===\n' "$cleaned"
}

# ── sanitize_context_chunk ────────────────────────────────────────────────────

sanitize_context_chunk() {
  local chunk="$1"
  local max_lines="${2:-50}"

  if [ "$SANITIZE_MODE" = "off" ]; then
    echo "$chunk"
    return 0
  fi

  local score
  score=$(detect_injection_markers "$chunk" 2>/dev/null) || true

  if [ "$SANITIZE_MODE" = "strict" ] && [ "${score:-0}" -ge "$_SANITIZE_SCORE_THRESHOLD" ]; then
    echo "SANITIZE WARNING: context chunk injection score $score — stripping chunk" >&2
    echo "[CONTEXT CHUNK QUARANTINED: score $score]"
    return 0
  fi

  # Strip markers and cap at max_lines
  _sanitize_strip "$chunk" | head -n "$max_lines"
}
