# Spec Workflow Abstraction Plan

## Design Philosophy

**Core Tension**: Framework structure vs. user philosophy

These skills encode a particular way of working (spec-driven, iterative, review-heavy). We want to:
1. Preserve this as sensible defaults that work immediately
2. Let users override details (paths, commands) without friction
3. Let users inject their own philosophy (review criteria, personas, process)
4. Avoid forcing our opinions where they don't add value

**Guiding Principle**: *Opinionated defaults, open philosophy*

The framework provides structure (what phases exist, what artifacts are produced). Users provide philosophy (what makes a good spec, who reviews, when something is "done").

---

## Progressive Disclosure Model

Users should be able to engage at the level that matches their needs:

```
Level 0: Zero Config
├── Works out of the box
├── Auto-detects project structure
├── Uses built-in defaults
└── Good for: trying it out, simple projects

Level 1: Path & Command Config
├── Customize paths, build commands, services
├── Single config file
└── Good for: adapting to existing project structure

Level 2: Philosophy Customization
├── Custom personas, review criteria, templates
├── Markdown files injected into prompts
└── Good for: teams with specific processes

Level 3: Workflow Extension
├── Skip/add phases, custom hooks
├── Compose skills differently
└── Good for: fundamentally different workflows
```

---

## Configuration Architecture

### Where Config Lives

**Important**: Configuration lives in the **user's project**, not in the plugin. This follows the same pattern as ESLint, Prettier, TypeScript, etc. - the tool knows where to look, but config is owned by the project.

```
user-project/                        # User's actual codebase
├── .claude/
│   └── spec-workflow/               # Plugin looks here for config
│       ├── config.yaml              # Level 1: Paths, commands, services
│       ├── philosophy/              # Level 2: Injected into prompts
│       │   ├── exploration.md       # What makes exploration complete?
│       │   ├── spec-standards.md    # What makes a good spec?
│       │   └── review-criteria.md   # What should reviewers focus on?
│       ├── personas/                # Level 2: Custom reviewer perspectives
│       │   └── *.md                 # Each file is a reviewer persona
│       └── templates/               # Level 2: Custom templates
│           └── spec.md              # Spec document template
├── src/
├── package.json
└── ...
```

**Why this approach:**
- Config is version-controlled with the project
- Teammates share the same workflow configuration
- Different projects can have different configs
- Not tied to plugin installation or Claude Code settings

### Init Command

The plugin provides a `/spec-workflow-init` skill to scaffold config:

```
/spec-workflow-init
  --minimal          # Just config.yaml with comments
  --full             # All files with example content
  --philosophy-only  # Just philosophy/ and personas/
```

This creates the `.claude/spec-workflow/` structure with documented examples so users don't start from scratch.

### File Structure

### config.yaml Schema

```yaml
# .claude/spec-workflow/config.yaml

# ─────────────────────────────────────────────────────────────
# PATHS - Where things live
# ─────────────────────────────────────────────────────────────
paths:
  specs: "./specs"                    # Default: ./specs
  worktrees: "./worktrees"            # Default: ./worktrees
  # Philosophy/persona/template dirs default to .claude/spec-workflow/*

# ─────────────────────────────────────────────────────────────
# SERVICES - Your technology stack
# ─────────────────────────────────────────────────────────────
# If omitted, auto-detected from project structure
services:
  backend:
    path: "./backend"
    build: "npm run build"
    test: "npm test"
    lint: "npm run lint"
    patterns: "./backend/AGENTS.md"   # Optional: architecture docs

  frontend:
    path: "./frontend"
    build: "npm run build"
    test: "npm test"
    lint: "npm run lint"

  # Special key: use '_default' for monorepo root or single-service projects
  _default:
    build: "make build"
    test: "make test"

# ─────────────────────────────────────────────────────────────
# SPEC FORMAT - How specs are named and structured
# ─────────────────────────────────────────────────────────────
spec:
  # Naming pattern. Available tokens: {date}, {topic}, {id}
  naming: "{date}-{topic}-spec.md"    # Default: YYYY-MM-DD-{topic}-spec.md

  # Required frontmatter fields (validated before execution)
  requiredFields:
    - status
    - services

  # Optional frontmatter fields (documented but not required)
  optionalFields:
    - worktree
    - branch
    - reviewers
    - risk

# ─────────────────────────────────────────────────────────────
# REVIEW PROCESS - How specs get reviewed
# ─────────────────────────────────────────────────────────────
review:
  # Maximum revision cycles before escalating to user
  maxIterations: 3                    # Default: 3

  # Minimum reviewer consensus for auto-approval (0.0-1.0)
  # Set to 1.0 to always require user approval
  autoApproveThreshold: 0.8           # Default: 0.8

  # Reviewer selection strategy
  selection:
    # "auto" = select based on spec classification
    # "all" = always use all personas
    # "explicit" = only use personas listed in spec frontmatter
    strategy: "auto"                  # Default: auto

    # Minimum reviewers per spec
    minimum: 2                        # Default: 2

    # Maximum reviewers per spec (prevents over-review)
    maximum: 4                        # Default: 4

# ─────────────────────────────────────────────────────────────
# EXECUTION - How specs get implemented
# ─────────────────────────────────────────────────────────────
execution:
  # Steps per batch before checkpoint
  batchSize: 5                        # Default: 5

  # Checkpoint behavior
  checkpoint:
    # "pause" = always pause for user review
    # "continue" = auto-continue if no issues
    # "smart" = pause on warnings/errors, continue otherwise
    behavior: "smart"                 # Default: smart

  # Parallelization
  parallel:
    # Enable spawning sub-agents for parallel work
    enabled: true                     # Default: true
    # Max concurrent sub-agents
    maxAgents: 3                      # Default: 3

# ─────────────────────────────────────────────────────────────
# WORKTREE - Git worktree configuration
# ─────────────────────────────────────────────────────────────
worktree:
  # Branch naming pattern. Tokens: {name}, {date}, {spec}
  branchNaming: "{name}"              # Default: {name}

  # Base branch for new worktrees (null = current branch)
  defaultBase: null                   # Default: null (current branch)

  # Bootstrap hook - runs after worktree creation
  # Receives environment variables:
  #   WORKTREE_PATH - absolute path to the new worktree
  #   WORKTREE_NAME - name of the worktree
  #   SPEC_FILE     - path to spec file (if --spec was provided)
  #   BASE_BRANCH   - the branch this worktree was created from
  #
  # User's script handles all service-specific setup
  onBootstrap: null                   # Default: null (no hook)
  # Example: onBootstrap: "./scripts/bootstrap-worktree.sh"

# ─────────────────────────────────────────────────────────────
# WORKFLOW CUSTOMIZATION (Level 3)
# ─────────────────────────────────────────────────────────────
workflow:
  # Skip phases entirely
  skip:
    - exploration    # Skip idea-explorer, start with spec-writer
    - review         # Skip spec-orchestrator review cycle

  # Require explicit user approval at these points
  requireApproval:
    - beforeExecution
    - afterReview
```

---

## Philosophy Injection System

### How It Works

Philosophy files are **markdown documents** that get injected into skill prompts at runtime. They let users express *how* they want work done without modifying skill code.

The skill sees: `[default instructions] + [user philosophy if present]`

### Philosophy Files

#### `philosophy/exploration.md`
*Injected into idea-explorer*

```markdown
# Exploration Philosophy

## When is exploration complete?

An idea is ready for spec writing when:
- [ ] The problem is clearly articulated
- [ ] We've identified who benefits and how
- [ ] Technical approach is outlined (not detailed)
- [ ] Major unknowns are called out
- [ ] Scope is bounded

## Questions we always ask

1. What's the simplest version that delivers value?
2. What existing patterns can we reuse?
3. What are we explicitly NOT doing?

## Red flags to surface

- Scope creep ("while we're at it...")
- Premature optimization
- Solutions looking for problems
```

#### `philosophy/spec-standards.md`
*Injected into spec-writer*

```markdown
# Spec Standards

## What makes a good spec?

A spec is ready for review when:
- Someone unfamiliar with the context can implement it
- Edge cases are explicitly handled or explicitly deferred
- Testing strategy is clear
- Rollback plan exists for risky changes

## Our conventions

- Implementation steps should be atomic (one concern each)
- Prefer explicit over clever
- Include "Why" not just "What"
```

#### `philosophy/review-criteria.md`
*Injected into spec-orchestrator and all reviewers*

```markdown
# Review Criteria

## What reviewers should evaluate

1. **Completeness**: Can this be implemented without guesswork?
2. **Correctness**: Does this solve the actual problem?
3. **Consistency**: Does this fit our existing patterns?
4. **Risk**: Are failure modes addressed?

## Review tone

- Assume good intent
- Ask questions rather than demand changes
- "Consider..." rather than "You must..."
- Distinguish blocking issues from suggestions
```

### Persona Files

Each file in `personas/` defines a reviewer perspective.

#### `personas/security.md`

```markdown
---
name: Security Reviewer
triggers:
  - auth
  - api
  - user-data
  - tokens
  - permissions
---

# Security Reviewer Persona

You are reviewing this spec from a security perspective.

## Your focus areas

- Authentication and authorization
- Data exposure and leakage
- Input validation
- Injection vulnerabilities
- Secure defaults

## Questions to ask

- What happens if this is called by an unauthorized user?
- What data could leak if this fails?
- Are we validating all external inputs?

## What you DON'T review

- Code style, naming conventions
- Performance (unless security-relevant)
- Feature completeness
```

#### `personas/pragmatist.md`

```markdown
---
name: Pragmatist
triggers:
  - always  # This reviewer is always included
---

# Pragmatist Persona

You are the voice of "let's ship it."

## Your focus

- Is this the simplest solution?
- Are we over-engineering?
- Can we defer complexity?
- What's the minimum viable version?

## Your questions

- Do we need this for v1?
- What can we hardcode now and make configurable later?
- Is there a library that does this?
```

---

## Argument System

Skills accept arguments for one-off overrides that don't warrant config changes.

### Syntax

```
/skill-name [positional-args] [--flags] [--key=value]
```

### Per-Skill Arguments

#### idea-explorer

```
/idea-explorer [topic]
  --depth=<quick|normal|thorough>   # How deep to explore (default: normal)
  --skip-yagni                      # Skip YAGNI checkpoint
  --output=<path>                   # Write refined idea to file
```

#### spec-writer

```
/spec-writer [topic-or-idea-file]
  --mode=<interactive|autonomous>   # default: interactive
  --services=<svc1,svc2>           # Limit to specific services
  --template=<path>                # Use custom template
  --output=<path>                  # Override output location
```

#### spec-orchestrator

```
/spec-orchestrator [spec-file]
  --skip-review                    # Write spec without review cycle
  --reviewers=<p1,p2>             # Use specific personas only
  --max-iterations=<n>            # Override max revision cycles
  --require-approval              # Always require user approval
```

#### spec-executor

```
/spec-executor <spec-file>
  --batch-size=<n>                # Steps per checkpoint
  --no-checkpoint                 # Run without pausing
  --dry-run                       # Show what would be done
  --resume                        # Resume from last checkpoint
  --parallel=<true|false>         # Enable/disable parallelization
```

#### create-worktree

```
/create-worktree <name>
  --spec=<path>                   # Spec file to copy into worktree
  --base=<branch>                 # Base branch (default: current)
  --no-bootstrap                  # Skip onBootstrap hook
```

---

## Default Behaviors (Zero-Config)

When no configuration exists, skills should still work:

### Auto-Detection

```
Project Structure Detection:
├── package.json found?
│   ├── Has "workspaces"? → Multi-service, detect each
│   └── No workspaces? → Single service at root
├── Cargo.toml found? → Rust project
├── go.mod found? → Go project
├── pyproject.toml found? → Python project
└── Multiple of above? → Multi-service, one per tech

Build Command Detection (per service):
├── package.json with scripts.build? → npm run build
├── Makefile with build target? → make build
├── Cargo.toml? → cargo build
└── Fallback → skip build verification
```

### Built-in Personas

When no custom personas exist, use these defaults:

1. **Completeness Reviewer** - Can this be implemented without guesswork?
2. **Pragmatist** - Is this the simplest solution?
3. **Risk Assessor** - What could go wrong?

### Built-in Spec Template

A generic template that works for any project:

```markdown
---
status: draft
services: []
created: {date}
---

# {title}

## Problem Statement
What problem are we solving? Why now?

## Proposed Solution
High-level approach.

## Design Details
Technical details, broken into sections as needed.

## Implementation Steps
| # | Service | Description | Dependencies |
|---|---------|-------------|--------------|

## Testing Strategy
How will we verify this works?

## Rollback Plan
What if this goes wrong?

## Open Questions
What's still unclear?
```

---

## Skill Refactoring Requirements

### idea-explorer

**Remove:**
- Hardcoded `specs/*` path

**Add:**
- Read config for `paths.specs`
- Accept `--output` argument
- Inject `philosophy/exploration.md` if present
- Default behavior unchanged when no config

### spec-orchestrator

**Remove:**
- Hardcoded persona definitions
- Hardcoded model references ("Sonnet", "Haiku")

**Add:**
- Load personas from `personas/*.md` (fallback to built-in)
- Read `review.*` config for iteration limits, thresholds
- Inject `philosophy/review-criteria.md` if present
- Accept `--reviewers`, `--max-iterations` arguments

### spec-writer

**Remove:**
- "Cut-Specific Considerations" section entirely
- Hardcoded service paths (`/backend/`, `/ios/`, `/web/`)
- Hardcoded template reference

**Add:**
- Read `services` from config (fallback to auto-detect)
- Read `spec.*` config for naming, required fields
- Load template from `templates/spec.md` (fallback to built-in)
- Inject `philosophy/spec-standards.md` if present
- Accept `--mode`, `--services`, `--template` arguments
- Reference service `patterns` paths from config when available

### spec-executor

**Remove:**
- Hardcoded build commands (`bun run build`, `pnpm build`)
- Hardcoded worktree path assumption

**Add:**
- Read `services.*.build/test/lint` from config
- Read `execution.*` config for batch size, checkpoint behavior
- Read `paths.worktrees` from config
- Accept `--batch-size`, `--no-checkpoint`, `--dry-run` arguments
- Auto-detect build commands when not configured

### create-worktree

**Remove:**
- Hardcoded `./worktrees/` path
- Hardcoded `./scripts/setup-worktree.sh` reference
- Hardcoded service list and service-specific flags

**Add:**
- Read `paths.worktrees` from config
- Read `worktree.*` config for branch naming, onBootstrap hook
- Run `onBootstrap` hook with environment variables (WORKTREE_PATH, WORKTREE_NAME, SPEC_FILE, BASE_BRANCH)
- Accept `--spec`, `--base`, `--no-bootstrap` arguments

---

## Implementation Phases

### Phase 1: Core Abstraction
1. Create config loading utility (with defaults)
2. Refactor path references in all skills
3. Add argument parsing to all skills
4. Test with zero-config (must still work)

### Phase 2: Service Abstraction
1. Implement service auto-detection
2. Refactor build/test/lint command references
3. Add service config to all skills
4. Test with various project structures

### Phase 3: Philosophy Injection
1. Implement philosophy file loading
2. Implement persona file loading
3. Refactor spec-orchestrator to use loaded personas
4. Create built-in defaults for all philosophy/personas

### Phase 4: Template System
1. Implement template loading
2. Create built-in spec template
3. Refactor spec-writer to use templates
4. Document template customization

### Phase 5: Workflow Customization
1. Implement phase skipping
2. Implement approval gates
3. Document advanced customization
4. Create example configurations

---

## User Experience Examples

### Example 1: Zero Config (Just Works)

```bash
# User installs plugin and immediately uses it
$ /idea-explorer "add user notifications"
# → Uses auto-detected project structure
# → Uses built-in exploration philosophy
# → Outputs to ./specs/ (default)
```

### Example 2: Simple Path Override

```yaml
# .claude/spec-workflow/config.yaml
paths:
  specs: "./docs/specs"
  worktrees: "./.worktrees"
```

```bash
$ /spec-writer "notifications"
# → Outputs to ./docs/specs/2024-01-15-notifications-spec.md
```

### Example 3: Custom Tech Stack

```yaml
# .claude/spec-workflow/config.yaml
services:
  api:
    path: "./services/api"
    build: "cargo build"
    test: "cargo test"
  web:
    path: "./apps/web"
    build: "pnpm build"
    test: "pnpm test"
```

```bash
$ /spec-executor ./specs/my-spec.md
# → Uses correct build commands for each service
```

### Example 4: Custom Review Process

```yaml
# .claude/spec-workflow/config.yaml
review:
  maxIterations: 5
  autoApproveThreshold: 1.0  # Always require human approval
```

```markdown
<!-- .claude/spec-workflow/personas/compliance.md -->
---
name: Compliance Reviewer
triggers: [data, pii, gdpr, user]
---

You review specs for regulatory compliance...
```

```bash
$ /spec-orchestrator ./specs/user-data-spec.md
# → Includes compliance reviewer
# → Never auto-approves
```

### Example 5: Different Workflow Entirely

```yaml
# .claude/spec-workflow/config.yaml
workflow:
  skip:
    - review  # We do reviews in PRs, not specs
  requireApproval:
    - beforeExecution  # But always check before implementing
```

---

## Open Questions

1. **Config file format**: YAML is human-friendly but adds a dependency. JSON is universal but less readable. Support both?

2. **Philosophy file format**: Pure markdown, or markdown with frontmatter for metadata?

3. **Inheritance**: Should services inherit from a `_default` service config, or require full specification?

4. **Validation**: How strict should config validation be? Warn on unknown keys, or error?

5. **Migration path**: How do existing Cut-specific skills transition? Provide a migration guide?

6. **Skill composition**: Should orchestrator *invoke* writer, or should they be independent with a contract?
