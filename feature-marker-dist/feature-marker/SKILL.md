---
name: feature-marker
description: Platform-agnostic workflow automation with checkpoints (PRD/TechSpec/Tasks generation + implementation + tests + commit/PR).
tools: Read, Write, Edit, Grep, Glob, Bash, TodoWrite, Skill
---

# feature-marker

Automates feature development with a 4-phase workflow:

1. **Inputs Gate** - Validates `prd.md`, `techspec.md`, `tasks.md` exist; generates them via `~/.claude/commands/` if missing.
2. **Analysis & Planning** - Reads docs, creates implementation plan.
3. **Implementation** - Executes tasks with progress tracking.
4. **Tests & Validation** - Runs test suites, validates build.
5. **Commit & PR** - Commits changes and creates PR (auto-detects git platform).

## Usage

```
/feature-marker <feature-slug>
```

**Example**:
```
/feature-marker prd-user-authentication
```

### Interactive Mode

```
/feature-marker --interactive <feature-slug>
```

Opens a menu to select execution mode:
- **Full Workflow** - Default, generates missing files and executes all phases
- **Tasks Only** - Uses existing files, skips generation phase
- **Ralph Loop** - Autonomous continuous execution with ralph-wiggum

Works both in terminal (TTY menu) and Claude CLI (AskUserQuestion prompt).

**Direct mode selection** (skip menu):
```
/feature-marker --mode full <feature-slug>
/feature-marker --mode tasks-only <feature-slug>
/feature-marker --mode ralph-loop <feature-slug>
```

## Prerequisites

### Commands

The following commands must be available in `~/.claude/commands/`:

- `create-prd.md` - Creates a new PRD from requirements discussion
- `generate-spec.md` - Generates technical specification from PRD
- `generate-tasks.md` - Breaks down feature spec into implementable tasks

### Templates

The commands above read templates from `~/.claude/docs/specs/` to generate structured documents.

Required templates:
- `~/.claude/docs/specs/prd-template.md` - Product Requirements Document template
- `~/.claude/docs/specs/techspec-template.md` - Technical Specification template
- `~/.claude/docs/specs/tasks-template.md` - Tasks breakdown template

**Template Format**: Templates should be markdown files with placeholders and structure that commands will use to generate feature-specific documents.

**Setup**: Ensure these templates exist before running feature-marker:
```bash
ls ~/.claude/docs/specs/
# Should show: prd-template.md, techspec-template.md, tasks-template.md
```

**Note**: If templates are missing, commands in `~/.claude/commands/` will fail to generate files.

### Project Structure

**Feature Documents** (generated in project):
```
./tasks/
└── prd-{feature-name}/
    ├── prd.md            ← Generated from ~/.claude/docs/specs/prd-template.md
    ├── techspec.md       ← Generated from ~/.claude/docs/specs/techspec-template.md
    ├── tasks.md          ← Generated from ~/.claude/docs/specs/tasks-template.md
    └── {num}_task.md     ← Individual task files (optional)
```

**State Directory** (checkpoint & progress):
```
.claude/feature-state/{feature-name}/
├── checkpoint.json
├── analysis.md
├── plan.md
├── progress.md
├── test-results.md
└── pr-url.txt
```

**User Configuration** (required setup):
```
~/.claude/
├── commands/           ← Commands that generate files
│   ├── create-prd.md
│   ├── generate-spec.md
│   └── generate-tasks.md
└── docs/
    └── specs/          ← Templates used by commands
        ├── prd-template.md
        ├── techspec-template.md
        └── tasks-template.md
```

## Behavior

When invoked, the skill:

1. **Validates inputs** - Checks if `./tasks/prd-{feature-slug}/` contains required files
   - If all files exist → Skips to step 3
   - If any file is missing → Proceeds to step 2
2. **Generates ONLY missing files** - Existing files are never overwritten:
   - Missing PRD → `/create-prd`
   - Missing Tech Spec → `/generate-spec {feature-slug}`
   - Missing Tasks → `/generate-tasks {feature-slug}`
3. **Executes 4-phase workflow** via the `feature-marker` agent
4. **Persists state** - Saves checkpoints after each phase/task for resume capability

**Important**: The workflow is smart about file detection:
- ✅ Files exist → Uses them directly, no regeneration
- ⚠️ Files missing → Generates only what's needed
- 🔒 Never overwrites existing content

## Template Setup Guide

### Template Directory Structure

Commands in `~/.claude/commands/` read templates from a centralized location:

```
~/.claude/docs/specs/
├── prd-template.md          # Product Requirements Document template
├── techspec-template.md     # Technical Specification template
└── tasks-template.md        # Task breakdown template
```

### Why Templates in ~/.claude/docs/specs?

- **Centralized**: All projects share the same templates
- **User-controlled**: Users can customize their own templates
- **Portable**: Commands reference templates via standard path
- **Separation**: Templates are not in project repositories

### Template Content

Each template should be a markdown file with:
- Clear section structure
- Placeholder text or variables
- Examples and formatting guidelines

Commands read these templates and populate them with feature-specific content.

### Setup Verification

To verify your setup is complete:

```bash
# Check templates exist
ls -l ~/.claude/docs/specs/

# Check commands exist
ls -l ~/.claude/commands/

# Test feature-marker
/feature-marker --interactive prd-test-feature
```

If templates are missing, create them in `~/.claude/docs/specs/` before running feature-marker.

## Checkpoint & Resume

If interrupted (Ctrl+C, session crash, etc.), re-invoke with the same feature slug to resume:

```
/feature-marker prd-user-authentication
```

The skill will:
- Detect existing checkpoint
- Show current progress (phase, task index)
- Ask if you want to resume or start fresh

## Platform Detection

In Phase 4, the skill auto-detects your git platform and selects the appropriate PR skill:

| Platform | Detection | PR Skill |
|----------|-----------|----------|
| GitHub | `github.com` in remote URL | `checking-pr` |
| Azure DevOps | `dev.azure.com` in remote URL | `azure-pr` |
| GitLab | `gitlab.com` in remote URL | `checking-pr` |
| Bitbucket | `bitbucket.org` in remote URL | `checking-pr` |
| Other | (fallback) | `checking-pr` |

## Configuration

Override default behavior with `.feature-marker.json` in your repository root:

```json
{
  "pr_skill": "custom-pr-skill",
  "skip_pr": false,
  "test_command": "npm run test:ci",
  "docs_path": "./tasks",
  "state_path": ".claude/feature-state"
}
```

## Error Handling

| Scenario | Behavior |
|----------|----------|
| Missing files | Auto-generate via commands |
| No git repo | Fail early with helpful message |
| No tests | Skip Phase 3 with warning |
| Test failures | Report issues, allow fix, offer retry |
| Unknown platform | Fallback to `checking-pr` |
| PR skill unavailable | Commit only, log manual instructions |

## Example Sessions

### Example 1: All Files Exist (No Generation Needed)
```
> /feature-marker prd-user-authentication

Checking for existing checkpoint...
No checkpoint found. Starting new workflow.

Phase 0: Inputs Gate
✓ prd.md exists
✓ techspec.md exists
✓ tasks.md exists
✅ All files present. Skipping generation.

Phase 1: Analysis & Planning
Reading existing documents...
Creating implementation plan...
Checkpoint saved.

Phase 2: Implementation
[1/6] Create User entity... ✓
[2/6] Add authentication service... ✓
...
```

### Example 2: Partial Files (Generates Only Missing)
```
> /feature-marker prd-payment-integration

Checking for existing checkpoint...
No checkpoint found. Starting new workflow.

Phase 0: Inputs Gate
✓ prd.md exists
✗ techspec.md missing → Generating via /generate-spec...
✓ tasks.md exists

✅ Generated missing file. All inputs ready.

Phase 1: Analysis & Planning
Reading documents...
Creating implementation plan...
Checkpoint saved.
...
```

### Example 3: Complete Workflow
```
> /feature-marker prd-new-feature

Phase 0: Inputs Gate
✗ prd.md missing → Generating via /create-prd...
✗ techspec.md missing → Generating via /generate-spec...
✗ tasks.md missing → Generating via /generate-tasks...

Phase 1: Analysis & Planning
...

Phase 2: Implementation
[1/6] Create User entity... ✓
[2/6] Add authentication service... ✓
[3/6] Implement login endpoint... ✓
[4/6] Add JWT token handling... ✓
[5/6] Create logout endpoint... ✓
[6/6] Add session management... ✓
Checkpoint saved.

Phase 3: Tests & Validation
Running: swift test
All tests passed.
Checkpoint saved.

Phase 4: Commit & PR
Detected platform: GitHub
Creating PR via /checking-pr...

✓ Feature complete!
PR URL: https://github.com/user/repo/pull/42
```
