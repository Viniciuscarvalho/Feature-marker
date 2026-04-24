# How Feature-marker Works

Feature-marker is a Claude Code skill that automates the full feature development lifecycle inside a single Claude session. Invoke it once — it reads your project state and runs the pipeline.

---

## The Skill (inside Claude Code)

```bash
/feature-marker prd-user-authentication
```

feature-marker reads your project state on every invocation and presents a single confirmation:

- Checkpoint found → offers to resume from saved phase
- Tasks exist → suggests implement → test → pr
- PRD/TechSpec exist → suggests generating missing files first
- Nothing found → starts from PRD generation

### The pipeline

Every feature goes through 4 phases. Each phase produces artifacts that feed the next.

### Phase 1 — Analysis

Feature-marker reads your prompt, scans your codebase, and generates three documents:

1. **PRD** — What to build and why. Extracted from your prompt, CLAUDE.md constraints, and codebase context.
2. **TechSpec** — How to build it. Aligned to your existing architecture, naming conventions, and patterns.
3. **Tasks** — What to do, step by step. Each task has acceptance criteria and file references.

Output location:

```
tasks/{feature-name}/
├── prd.md
├── techspec.md
└── tasks.md
```

### Phase 2 — Implementation

Feature-marker executes each task from `tasks.md`. It writes code following your project's patterns — the same naming conventions, file structure, error handling, and config management it detected in Phase 1.

### Phase 3 — Testing

Tests are written using your project's test framework (detected automatically — Swift Testing, XCTest, Jest, pytest, etc.). Feature-marker runs the tests, and if any fail, it attempts to fix and re-run.

### Phase 4 — Delivery

Feature-marker commits the changes, pushes the branch, and creates a Pull Request. It auto-detects your platform (GitHub, GitLab, Azure DevOps) and uses the appropriate CLI.

### Execution modes

| Mode        | Command                                       | Description                                |
| ----------- | --------------------------------------------- | ------------------------------------------ |
| Full        | `/feature-marker prd-auth`                    | All 4 phases, start to finish              |
| Tasks only  | `/feature-marker --mode tasks-only prd-auth`  | Skip PRD/TechSpec, use existing spec files |
| Spec-driven | `/feature-marker --mode spec-driven prd-auth` | Multi-agent review with worktree isolation |
| Test only   | `/feature-marker --mode test-only prd-auth`   | Run just the testing phase                 |

### Checkpoint and resume

You can pause at any time. Feature-marker saves its state to `checkpoint.json`. When you resume, it picks up exactly where it left off — no rework.

```
.claude/feature-state/{feature-name}/
├── checkpoint.json       # Current phase + task progress
├── platform-context.json # Detected stack and tooling
├── analysis.md           # Phase 1 output summary
├── plan.md               # Execution plan
├── progress.md           # Task completion tracking
└── test-results.md       # Phase 3 results
```

---

## Quick start

```bash
# 1. Install
npx skills add Viniciuscarvalho/Feature-marker

# 2. Open Claude Code in your project

# 3. Invoke
/feature-marker prd-user-authentication
```
