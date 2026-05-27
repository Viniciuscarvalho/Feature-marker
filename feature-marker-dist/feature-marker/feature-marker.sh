#!/usr/bin/env bash
# Compatibility wrapper for older local installs.
set -euo pipefail

cat <<'MSG'
feature-marker is skill-first.

Use the CLI only to install skill files:
  npx -y @viniciuscarvalho/feature-marker install --runtime all

Then invoke the workflow inside your LLM:
  Use feature-marker to plan and implement <feature-slug>.
MSG
