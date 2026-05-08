#!/usr/bin/env bash
# Usage: scrape-tokens.sh <session-id> [project-abs-path]
# Prints: <input_tokens>\t<output_tokens>\t<total>
# Requires: jq
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: scrape-tokens.sh <session-id> [project-abs-path]" >&2
  exit 1
fi

sid="$1"
proj="${2:-$(pwd)}"
encoded="${proj//\//-}"
jsonl="${HOME}/.claude/projects/${encoded}/${sid}.jsonl"

if [[ ! -f "$jsonl" ]]; then
  echo "ERROR: session file not found: $jsonl" >&2
  exit 1
fi

jq -rs '
  map(select(.type == "assistant" and .message.usage != null))
  | if length == 0 then error("no assistant turns with usage found")
    else
      { input:  (map(.message.usage.input_tokens  // 0) | add),
        output: (map(.message.usage.output_tokens // 0) | add) }
      | if (.input + .output) == 0 then error("total tokens is 0 — check session ID")
        else "\(.input)\t\(.output)\t\(.input + .output)"
        end
    end
' "$jsonl"
