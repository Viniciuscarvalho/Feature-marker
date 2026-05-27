# Feature-Marker Distribution

This distribution contains skill install assets for Claude, Codex, and Gemini.
The package installer copies skill files into each runtime. The workflow itself
runs inside the LLM after the user asks to use `feature-marker`.

## Install

```bash
npx -y @viniciuscarvalho/feature-marker install --runtime claude
npx -y @viniciuscarvalho/feature-marker install --runtime all
npx -y @viniciuscarvalho/feature-marker install --runtime codex
npx -y @viniciuscarvalho/feature-marker install --runtime gemini
```

Preview targets:

```bash
npx -y @viniciuscarvalho/feature-marker install --runtime all --dry-run
```

## Invoke

Use the installed skill from your LLM prompt. Interactive mode is not required
and is not the v1 path.

Claude prompt:

```text
Use feature-marker to implement billing-observability.
```

Codex or Gemini prompt:

```text
Use feature-marker to plan and implement billing-observability.
```

```text
Use feature-marker in tasks-only mode for billing-observability.
```

## Runtime Targets

- Claude: `~/.claude/skills/feature-marker` and `~/.claude/agents/feature-marker.md`
- Codex: `~/.codex/skills/feature-marker`
- Gemini: `~/.gemini/skills/feature-marker`

## State

feature-marker uses artifact state, not a package-owned workflow database:

```text
tasks/{slug}/
  prd.md
  techspec.md
  tasks.md
```

These files are created from installed templates in `templates/`:
`prd-template.md`, `techspec-template.md`, and `tasks-template.md`. The skill
fills `{slug}` and `{feature_title}` before implementation.

The skill works branch-first. It creates or requires a feature branch, uses a
worktree only when the current checkout is dirty or the user asks, runs through
PRD -> TechSpec -> Tasks -> implementation grill -> implementation ->
verification, commits locally, and prints exact push/PR commands. The grill
pass finds gaps before coding and asks the user only when a finding changes
scope or requires a product decision. It stops for true ambiguity, unrelated
dirty work, or blocked verification. It does not push or open PRs automatically.

`spec-driven` and `ralph-loop` are out of scope for this skill-first v1 unless
they are rebuilt as explicit skill instructions.
