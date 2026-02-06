# Configuration Reference

This document defines how spec-workflow skills load and use configuration.

## Configuration Location

Configuration lives in the **user's project** at `.claude/spec-workflow/`:

```
project-root/
├── .claude/
│   └── spec-workflow/
│       ├── config.yaml              # Main configuration
│       ├── philosophy/              # Philosophy files (injected into prompts)
│       │   ├── exploration.md
│       │   ├── spec-standards.md
│       │   └── review-criteria.md
│       ├── personas/                # Custom reviewer personas
│       │   └── *.md
│       └── templates/
│           └── spec.md              # Custom spec template
```

## Loading Configuration

### Step 1: Check for config file

Look for `.claude/spec-workflow/config.yaml` in the working directory.

If it exists, parse it. If not, use defaults.

### Step 2: Apply defaults

For any missing values, use these defaults:

```yaml
paths:
  specs: "./specs"
  worktrees: "./worktrees"

services: null  # Auto-detect if null

spec:
  naming: "{date}-{topic}-spec.md"
  requiredFields: [status]
  optionalFields: [worktree, branch, services]

review:
  maxIterations: 3
  autoApproveThreshold: 0.8
  selection:
    strategy: "auto"
    minimum: 2
    maximum: 4

execution:
  batchSize: 5
  checkpoint:
    behavior: "smart"
  parallel:
    enabled: true
    maxAgents: 3

worktree:
  branchNaming: "{name}"
  defaultBase: null
  onBootstrap: null
```

### Step 3: Load philosophy files

If `.claude/spec-workflow/philosophy/` exists, check for relevant files:

| Skill | Philosophy file |
|-------|-----------------|
| idea-explorer | `exploration.md` |
| spec-writer | `spec-standards.md` |
| spec-orchestrator | `review-criteria.md` |
| All reviewers | `review-criteria.md` |

If the file exists, inject its contents into the skill's context.

### Step 4: Load personas (spec-orchestrator only)

If `.claude/spec-workflow/personas/` exists and contains `.md` files:
- Load each file as a reviewer persona
- Parse frontmatter for `name` and `triggers`
- Use these instead of built-in personas

If the directory doesn't exist or is empty, use built-in personas.

### Step 5: Load template (spec-writer only)

If `.claude/spec-workflow/templates/spec.md` exists:
- Use it as the spec template

Otherwise, use the built-in template.

## Service Auto-Detection

When `services` is null in config, auto-detect based on project structure:

1. Look for `package.json` at root → Node.js project
   - Check for `workspaces` → Multi-service
   - Check `scripts` for `build`, `test`, `lint` commands
2. Look for `Cargo.toml` → Rust project
3. Look for `go.mod` → Go project
4. Look for `pyproject.toml` → Python project
5. Look for subdirectories with their own package managers

Build detected services object:

```yaml
services:
  root:  # or service name
    path: "."
    build: "npm run build"  # from package.json scripts
    test: "npm test"
    lint: "npm run lint"
```

## Config Schema

```yaml
# ─────────────────────────────────────────────────────────────
# PATHS
# ─────────────────────────────────────────────────────────────
paths:
  specs: string           # Default: "./specs"
  worktrees: string       # Default: "./worktrees"

# ─────────────────────────────────────────────────────────────
# SERVICES
# ─────────────────────────────────────────────────────────────
services:
  <service-name>:
    path: string          # Relative path to service
    build: string         # Build command (optional)
    test: string          # Test command (optional)
    lint: string          # Lint command (optional)
    patterns: string      # Path to patterns/architecture doc (optional)

# ─────────────────────────────────────────────────────────────
# SPEC FORMAT
# ─────────────────────────────────────────────────────────────
spec:
  naming: string          # Default: "{date}-{topic}-spec.md"
  requiredFields: array   # Default: [status]
  optionalFields: array   # Default: [worktree, branch, services]

# ─────────────────────────────────────────────────────────────
# REVIEW PROCESS
# ─────────────────────────────────────────────────────────────
review:
  maxIterations: number   # Default: 3
  autoApproveThreshold: number  # Default: 0.8 (0.0-1.0)
  selection:
    strategy: string      # "auto" | "all" | "explicit"
    minimum: number       # Default: 2
    maximum: number       # Default: 4

# ─────────────────────────────────────────────────────────────
# EXECUTION
# ─────────────────────────────────────────────────────────────
execution:
  batchSize: number       # Default: 5
  checkpoint:
    behavior: string      # "pause" | "continue" | "smart"
  parallel:
    enabled: boolean      # Default: true
    maxAgents: number     # Default: 3

# ─────────────────────────────────────────────────────────────
# WORKTREE
# ─────────────────────────────────────────────────────────────
worktree:
  branchNaming: string    # Default: "{name}"
  defaultBase: string     # Default: null (current branch)
  onBootstrap: string     # Default: null (no hook)
```

## Argument Override

Skill arguments override config values for that invocation:

```
/spec-executor spec.md --batch-size=10
```

This uses `batchSize: 10` instead of config value, but only for this invocation.

## Environment Variables for Hooks

When `onBootstrap` is called, these environment variables are set:

| Variable | Description |
|----------|-------------|
| `WORKTREE_PATH` | Absolute path to the new worktree |
| `WORKTREE_NAME` | Name of the worktree |
| `SPEC_FILE` | Path to spec file (if --spec was provided) |
| `BASE_BRANCH` | Branch the worktree was created from |
