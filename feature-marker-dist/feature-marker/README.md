# feature-marker

Skill + agent to automate feature development workflows with **checkpoints**, **pause/resume**, artifact generation (PRD/Tech Spec/Tasks), and a final step that creates a commit + PR (with platform detection).

This project is designed to be **platform-agnostic** and to compose with existing skills (e.g. `checking-pr`, `azure-pr`).

## Quick start

```bash
# Install
./feature-marker/install.sh

# Then in Claude Code:
/feature-marker prd-user-authentication
```

## What it does

| Feature | Description |
|---------|-------------|
| **Validates inputs** | Checks if `prd.md`, `techspec.md`, `tasks.md` exist |
| **Auto-generates** | Creates missing artifacts via `~/.claude/commands/` |
| **Phased workflow** | Analysis → Implementation → Tests → Commit & PR |
| **Checkpoint/resume** | Persists state for uninterrupted work |
| **Platform detection** | Selects right PR skill (GitHub, Azure DevOps, etc.) |

## Installation

### Via install script (recommended)

```bash
# Clone the repository
git clone https://github.com/your-username/feature-marker.git
cd feature-marker

# Run install script
./feature-marker/install.sh

# Verify
ls ~/.claude/skills/feature-marker/
ls ~/.claude/agents/feature-marker.md
```

### Manual installation

1. Copy the skill folder:
   ```bash
   cp -R feature-marker/ ~/.claude/skills/feature-marker/
   ```

2. Copy the agent:
   ```bash
   cp agents/feature-marker.md ~/.claude/agents/feature-marker.md
   ```

3. Set permissions:
   ```bash
   chmod +x ~/.claude/skills/feature-marker/*.sh
   chmod +x ~/.claude/skills/feature-marker/lib/*.sh
   ```

## Usage

In Claude Code:

```
/feature-marker <feature-slug>
```

**Example:**
```
/feature-marker prd-user-authentication
```

## Prerequisites

### Required commands

The following commands must exist in `~/.claude/commands/`:

- `create-prd.md` - Creates PRD from requirements discussion
- `generate-spec.md` - Generates tech spec from PRD
- `generate-tasks.md` - Breaks down feature into tasks

### Project structure (docs-based)

```
your-project/
├── docs/
│   ├── specs/
│   │   ├── prd-template.md
│   │   └── techspec-template.md
│   ├── tasks-template.md
│   ├── task-template.md
│   └── tasks/
│       └── prd-{feature-name}/
│           ├── prd.md
│           ├── techspec.md
│           └── tasks.md
└── .claude/
    └── feature-state/
        └── {feature-name}/
            └── checkpoint.json
```

## Workflow phases

```
┌─────────────────────────────────────────────────────────────────┐
│                    /feature-marker prd-xyz                       │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  Phase 0: Inputs Gate                                           │
│  ├── Validate prd.md, techspec.md, tasks.md                     │
│  └── Generate missing files via ~/.claude/commands/             │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  Phase 1: Analysis & Planning                                   │
│  ├── Read PRD, Tech Spec, Tasks                                 │
│  ├── Create implementation plan                                 │
│  └── Save analysis.md, plan.md                                  │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  Phase 2: Implementation                                        │
│  ├── Execute tasks with TodoWrite tracking                      │
│  ├── Make file changes                                          │
│  └── Save progress.md                                           │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  Phase 3: Tests & Validation                                    │
│  ├── Run test suites (swift test, npm test, etc.)               │
│  ├── Validate build                                             │
│  └── Save test-results.md                                       │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  Phase 4: Commit & PR                                           │
│  ├── Create commit with meaningful message                      │
│  ├── Detect git platform (GitHub, Azure DevOps, GitLab)         │
│  ├── Select appropriate PR skill                                │
│  └── Create Pull Request                                        │
└─────────────────────────────────────────────────────────────────┘
```

## Platform detection

The skill auto-detects your git platform and selects the appropriate PR skill:

| Platform | Detection Pattern | PR Skill |
|----------|------------------|----------|
| GitHub | `github.com` | `checking-pr` |
| Azure DevOps | `dev.azure.com` | `azure-pr` |
| GitLab | `gitlab.com` | `checking-pr` |
| Bitbucket | `bitbucket.org` | `checking-pr` |
| Other | (any) | `checking-pr` |

## Checkpoint & resume

State is persisted in `.claude/feature-state/{feature-name}/checkpoint.json`.

If interrupted, simply re-invoke with the same feature slug:

```
/feature-marker prd-user-authentication
```

The skill will:
- Detect existing checkpoint
- Show current progress
- Ask if you want to resume or start fresh

## Configuration

Override defaults with `.feature-marker.json` in your project root:

```json
{
  "pr_skill": "custom-pr-skill",
  "skip_pr": false,
  "test_command": "npm run test:ci",
  "docs_path": "./docs/tasks",
  "state_path": ".claude/feature-state"
}
```

## CLI usage

The `feature-marker.sh` script can also be used directly:

```bash
# Show help
./feature-marker/feature-marker.sh --help

# Show status of a feature
./feature-marker/feature-marker.sh --status prd-user-authentication

# Show detected git platform
./feature-marker/feature-marker.sh --platform
```

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Missing templates | Ensure templates exist at `./docs/specs/` |
| PRD created in wrong location | `create-prd.md` writes to `./tasks/`; workflow copies to `./docs/tasks/` |
| Task generation needs approval | `generate-tasks.md` requires preview approval |
| No PR skill for platform | Falls back to `checking-pr`; if unavailable, commits only |
| Checkpoint corrupted | Delete `.claude/feature-state/{feature}/checkpoint.json` |

## Update / Uninstall

**Update:**
```bash
./feature-marker/install.sh
```

**Uninstall:**
```bash
rm -rf ~/.claude/skills/feature-marker/
rm ~/.claude/agents/feature-marker.md
```

## License

MIT
