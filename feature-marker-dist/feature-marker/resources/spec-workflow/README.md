# Spec Workflow Plugin

A spec-driven development workflow for Claude Code. Helps you explore ideas, write detailed specifications, review them with AI personas, and execute implementations systematically.

## Skills Included

| Skill | Description |
|-------|-------------|
| `/idea-explorer` | Collaborative exploration to refine ideas into clear requirements |
| `/spec-writer` | Transform ideas into detailed implementation specifications |
| `/spec-orchestrator` | Multi-agent review cycle with AI personas |
| `/spec-executor` | Execute specs with batched checkpoints |
| `/create-worktree` | Create isolated git worktrees for spec work |
| `/spec-workflow-init` | Scaffold configuration in your project |

## Quick Start

```bash
# Install the plugin
/plugin install spec-workflow@ky1ejs-plugins

# Initialize config in your project (optional)
/spec-workflow-init

# Start exploring an idea
/idea-explorer "add user notifications"

# Or jump straight to writing a spec
/spec-writer "notification system"
```

## Workflow

```
/idea-explorer          # Refine the idea
       ↓
/spec-orchestrator      # Write spec + AI review cycle
       ↓
/create-worktree        # Isolated environment
       ↓
/spec-executor          # Implement the spec
```

## Configuration

Configuration is optional. The plugin works out of the box with sensible defaults.

To customize, create `.claude/spec-workflow/` in your project:

```
your-project/
├── .claude/
│   └── spec-workflow/
│       ├── config.yaml         # Paths, services, thresholds
│       ├── philosophy/         # Custom guidance (injected into prompts)
│       │   ├── exploration.md  # How to explore ideas
│       │   ├── spec-standards.md
│       │   └── review-criteria.md
│       ├── personas/           # Custom reviewer personas
│       │   └── *.md
│       └── templates/
│           └── spec.md         # Custom spec template
```

Run `/spec-workflow-init` to scaffold this structure with examples.

### config.yaml

```yaml
# Paths
paths:
  specs: "./specs"              # Where specs are saved
  worktrees: "./worktrees"      # Where worktrees are created

# Your technology stack (optional - auto-detected if omitted)
services:
  backend:
    path: "./backend"
    build: "npm run build"
    test: "npm test"
    lint: "npm run lint"

# Review process
review:
  maxIterations: 3              # Cycles before escalating to human
  autoApproveThreshold: 0.8     # Consensus level for auto-approval

# Worktree setup
worktree:
  branchNaming: "{name}"        # Branch naming pattern
  onBootstrap: "./scripts/bootstrap.sh"  # Hook after worktree creation
```

### Philosophy Files

Inject your team's philosophy into the workflow. These markdown files are included in skill prompts when present.

**`philosophy/exploration.md`** - What makes an idea ready for spec writing?

**`philosophy/spec-standards.md`** - What makes a good spec?

**`philosophy/review-criteria.md`** - What should reviewers focus on?

### Custom Personas

Add reviewer perspectives specific to your domain. Each `.md` file in `personas/` becomes a reviewer.

```markdown
---
name: Security Reviewer
triggers: [auth, api, user-data]
---

You review specs from a security perspective...
```

## Skill Arguments

Each skill accepts arguments for one-off overrides:

```bash
/idea-explorer "topic" --depth=thorough
/spec-writer "topic" --mode=autonomous --services=backend
/spec-orchestrator spec.md --reviewers=security,simplifier
/spec-executor spec.md --batch-size=10 --dry-run
/create-worktree myfeature --spec=specs/feature.md --base=develop
```

See individual skill documentation for full argument lists.
