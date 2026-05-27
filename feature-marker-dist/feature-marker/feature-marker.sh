#!/usr/bin/env bash
# Compatibility wrapper for older local installs.
set -euo pipefail

cat <<'MSG'
feature-marker is skill-first.

Use the CLI only to install skill files:
  npx -y @viniciuscarvalho/feature-marker install --runtime all

Interactive mode is not required and is not the v1 path.

Then invoke the run-through workflow inside your LLM:
  Use feature-marker to implement <feature-slug>.
MSG
