# How Feature-marker Works

Feature-marker is a skill-first workflow for Claude, Codex, and Gemini. The npm
package only installs skill files. The workflow itself runs from a normal LLM
prompt inside the user's git project.

## Current README Visuals

- `banner.svg`: project banner.
- `skill-first-flow.svg`: current usage diagram for the README.

## Quick Start

```bash
npx -y @viniciuscarvalho/feature-marker install --runtime all
```

Then open a git project in Claude, Codex, or Gemini and prompt:

```text
Use feature-marker to implement billing-observability.
```

## Skill-First Flow

1. The skill reads repository context and existing instructions.
2. It creates or reuses `tasks/{slug}/prd.md`, `techspec.md`, and `tasks.md`
   from bundled templates.
3. It creates or requires a feature branch.
4. It runs an implementation grill before coding to find gaps in acceptance
   criteria, task order, risks, tests, and handoff.
5. It implements, verifies, commits locally, and prints exact push/PR commands.

Feature-marker does not require an interactive menu, does not use
checkpoint JSON as canonical state, does not push automatically, and does not
open a PR automatically.
