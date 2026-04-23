# Plan Phase

Validate and generate feature input files, then create the implementation plan.

---

## Inputs Gate

Check each file in `./tasks/{slug}/`. Generate only what is missing — never overwrite existing files.

| File          | If missing                                                                         |
| ------------- | ---------------------------------------------------------------------------------- |
| `prd.md`      | Invoke `/create-prd` (reads `~/.claude/docs/specs/prd-template.md`)                |
| `techspec.md` | Invoke `/generate-spec {slug}` (reads `~/.claude/docs/specs/techspec-template.md`) |
| `tasks.md`    | Invoke `/generate-tasks {slug}` (reads `~/.claude/docs/specs/tasks-template.md`)   |

If a template is missing, stop and show the expected path. Do not proceed without all three files present.

**Plan context** — check `~/.claude/plans/` for the most recently modified `.md` file. If found, present its contents when invoking `/create-prd` with this framing: "The following plan covers problem definition, constraints, and scope. Use it as pre-answered context and reduce clarifying questions to only items not covered." This is non-blocking if absent.

---

## Spec-Driven Variant

When the orchestrator passes `spec_driven=true`:

1. No `prd.md` exists → invoke `/idea-explorer` for collaborative idea refinement
2. Invoke `/spec-orchestrator` — runs multi-agent review until 80% consensus threshold
3. Invoke `/create-worktree` — creates an isolated git branch for development
4. Convert the approved spec to `prd.md`, `techspec.md`, `tasks.md` using the spec-workflow bridge

After conversion, continue with the analysis step below.

---

## Product-Manager Skill

Check if `~/.claude/skills/product-manager/SKILL.md` exists.

If missing and `npx` is available:

```bash
npx skills add https://github.com/aj-geddes/claude-code-bmad-skills --skill product-manager
```

Non-blocking — continue without it if `npx` is unavailable or installation fails.

---

## Analysis

Read `prd.md`, `techspec.md`, and `tasks.md` from `./tasks/{slug}/`.

If `CLAUDE.md` conventions were loaded by the orchestrator, validate implementation decisions against them. Ask clarifying questions if the requirements are ambiguous — pause and wait for the user's response before continuing.

Save:

- `.claude/feature-state/{slug}/analysis.md` — requirements summary, key decisions, dependencies
- `.claude/feature-state/{slug}/plan.md` — file-by-file implementation plan with task mapping

Update checkpoint: `current_phase=plan`, `phase_status=completed`.
