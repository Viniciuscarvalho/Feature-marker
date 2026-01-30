# Feature-Marker v1.4.0

Platform-agnostic workflow automation for feature development with checkpoints and resume capability.

## Overview

Feature-marker automates the complete feature development lifecycle:
1. **Inputs Gate** - Validates/generates PRD, Tech Spec, and Tasks
2. **Analysis & Planning** - Creates implementation plan
3. **Implementation** - Executes tasks with progress tracking
4. **Tests & Validation** - Runs test suites and validates build
5. **Commit & PR** - Commits changes and creates Pull Request

## What's New in v1.4.0

This release focuses on **documentation clarity** to help users understand how feature-marker works:

### 📚 Enhanced Documentation

- **Templates Location Clarified**: Now clearly documented that templates live in `~/.claude/docs/specs/`
  - `prd-template.md`
  - `techspec-template.md`
  - `tasks-template.md`

- **File Generation Flow**: Added visual diagrams showing how the system works:
  ```
  Templates (~/.claude/docs/specs/)
    → Commands (~/.claude/commands/)
    → Generated Files (./tasks/prd-{feature-name}/)
  ```

- **Architecture Overview**: New diagram showing the complete file flow between user's `~/.claude` directory and project directory

- **Template Setup Guide**: Complete guide explaining:
  - Why templates are in `~/.claude/docs/specs/`
  - How commands read and use templates
  - Setup verification steps

- **Error Handling**: Added documentation for missing templates scenario

### 📖 New Files

- **README.md**: Comprehensive project documentation with examples, troubleshooting, and architecture
- **CHANGELOG.md**: Following Keep a Changelog format for version tracking

### 🔧 What Changed

Previously, the documentation mentioned commands but didn't explain where templates should be or how they're used. Now it's crystal clear:

**Before v1.4.0**: "Commands must be in `~/.claude/commands/`" (where are templates? 🤔)

**After v1.4.0**: "Templates in `~/.claude/docs/specs/` → Commands in `~/.claude/commands/` read templates → Generate files in `./tasks/prd-{feature-name}/`" (clear! ✅)

## Installation

```bash
cd feature-marker
./install.sh
```

This will install:
- Skill: `~/.claude/skills/feature-marker.md`
- Agent: `~/.claude/agents/feature-marker.md`

## How It Works

### Architecture Overview

```
User's ~/.claude directory              Project directory
━━━━━━━━━━━━━━━━━━━━━━━━━              ━━━━━━━━━━━━━━━━
~/.claude/
├── commands/                           ./tasks/
│   ├── create-prd.md        ─────┐    └── prd-{feature-name}/
│   ├── generate-spec.md     ────┼┐       ├── prd.md
│   └── generate-tasks.md    ───┼┼┐       ├── techspec.md
│                                │││       └── tasks.md
├── docs/                        │││
│   └── specs/                   │││    .claude/feature-state/
│       ├── prd-template.md   <──┘││    └── {feature-name}/
│       ├── techspec-template.md <─┘│        ├── checkpoint.json
│       └── tasks-template.md    <──┘        ├── analysis.md
│                                            ├── plan.md
├── skills/                                 ├── progress.md
│   └── feature-marker.md                   ├── test-results.md
│                                            └── pr-url.txt
└── agents/
    └── feature-marker.md
```

### File Flow

1. **Templates** → **Commands** → **Generated Files**
   - Templates in `~/.claude/docs/specs/` define document structure
   - Commands in `~/.claude/commands/` read templates and generate files
   - Final files created in project `./tasks/prd-{feature-name}/`

2. **Execution** → **State** → **Resume**
   - Workflow execution tracked in `.claude/feature-state/{feature-name}/`
   - Checkpoint saved after each phase/task
   - Can resume from any interruption point

### Prerequisites

#### Required in `~/.claude/commands/`:
- `create-prd.md` - Creates PRD from requirements discussion
- `generate-spec.md` - Generates technical specification from PRD
- `generate-tasks.md` - Breaks down spec into tasks

#### Required in `~/.claude/docs/specs/`:
- `prd-template.md` - Product Requirements Document template
- `techspec-template.md` - Technical Specification template
- `tasks-template.md` - Tasks breakdown template

**Setup Verification**:
```bash
# Check templates
ls ~/.claude/docs/specs/

# Check commands
ls ~/.claude/commands/

# Check installation
feature-marker --version
```

## Usage

### Basic Usage

```bash
# Via Claude Code skill
/feature-marker prd-user-authentication
```

### Interactive Mode

Choose execution mode via interactive menu:

```bash
/feature-marker --interactive prd-user-authentication
```

**Execution Modes:**
1. **Full Workflow** - Generates missing files and executes all phases
2. **Tasks Only** - Uses existing files, skips generation (all files must exist)
3. **Ralph Loop** - Autonomous execution with self-correction via ralph-wiggum

**Direct Mode Selection** (skip menu):
```bash
/feature-marker --mode full prd-user-authentication
/feature-marker --mode tasks-only prd-user-authentication
/feature-marker --mode ralph-loop prd-user-authentication
```

### Command Options

```bash
feature-marker [OPTIONS] <feature-slug>

Options:
  -i, --interactive      Launch interactive menu
  -m, --mode <mode>      Set execution mode (full|tasks-only|ralph-loop)
  -s, --status           Show workflow status
  -p, --platform         Show detected git platform
  -V, --version          Show version
  -h, --help             Show help
```

## Workflow Details

### Phase 0: Inputs Gate

Validates required files exist. If missing, generates ONLY what's needed:

```
Check prd.md → Missing? → /create-prd → ~/.claude/docs/specs/prd-template.md
Check techspec.md → Missing? → /generate-spec → ~/.claude/docs/specs/techspec-template.md
Check tasks.md → Missing? → /generate-tasks → ~/.claude/docs/specs/tasks-template.md
```

**Smart Detection:**
- ✅ Files exist → Uses them directly, no regeneration
- ⚠️ Files missing → Generates only what's needed
- 🔒 Never overwrites existing content

### Phase 1: Analysis & Planning

- Reads PRD, Tech Spec, and Tasks
- Creates implementation plan
- Identifies critical files and dependencies
- Saves: `analysis.md`, `plan.md`

### Phase 2: Implementation

- Executes tasks from `tasks.md`
- Uses TodoWrite for progress tracking
- Saves: `progress.md`
- **Ralph Loop Mode**: Uses ralph-wiggum for autonomous iteration

### Phase 3: Tests & Validation

Auto-detects test commands based on project type:
- Swift/Xcode: `swift test` or `xcodebuild test`
- Node.js: `npm test` or `yarn test`
- Python: `pytest` or `python -m unittest`
- Rust: `cargo test`
- Go: `go test ./...`

Saves: `test-results.md`

### Phase 4: Commit & PR

- Generates commit message from `progress.md`
- Auto-detects git platform:
  - GitHub → `checking-pr`
  - Azure DevOps → `azure-pr`
  - GitLab/Bitbucket → `checking-pr`
- Creates Pull Request
- Saves: `pr-url.txt`

## Checkpoint & Resume

If interrupted (Ctrl+C, session crash), re-invoke with same feature slug:

```bash
/feature-marker prd-user-authentication
```

The workflow will:
- Detect existing checkpoint
- Show current progress (phase, task index)
- Ask to resume or start fresh

**Checkpoint Location**: `.claude/feature-state/{feature-name}/checkpoint.json`

## Configuration

Override defaults with `.feature-marker.json` in repository root:

```json
{
  "pr_skill": "custom-pr-skill",
  "skip_pr": false,
  "test_command": "npm run test:ci",
  "docs_path": "./tasks",
  "state_path": ".claude/feature-state"
}
```

## Project Structure

```
feature-marker-dist/
├── README.md                    # This file
├── feature-marker/
│   ├── feature-marker.sh        # Entry point script
│   ├── install.sh              # Installation script
│   ├── SKILL.md                # Skill documentation
│   └── lib/
│       ├── config.sh           # Configuration helpers
│       ├── state-manager.sh    # Checkpoint management
│       ├── menu.sh             # Interactive mode menu
│       ├── ui.sh               # UI utilities
│       └── platform-detector.sh # Git platform detection
└── agents/
    └── feature-marker.md       # Agent implementation
```

## Error Handling

| Scenario | Behavior |
|----------|----------|
| Missing templates in ~/.claude/docs/specs/ | Fail with helpful message |
| Missing task files | Generate automatically via commands |
| No git repo | Fail early with helpful message |
| No tests | Skip Phase 3 with warning |
| Test failures | Report issues, allow fix, offer retry |
| Unknown platform | Fallback to `checking-pr` |
| PR skill unavailable | Commit only, log manual instructions |
| Mid-phase interrupt | Auto-save checkpoint |

## Examples

### Example 1: All Files Exist

```bash
> /feature-marker prd-user-authentication

Phase 0: Inputs Gate
✓ prd.md exists
✓ techspec.md exists
✓ tasks.md exists
✅ All files present. Skipping generation.

Phase 1: Analysis & Planning
Reading documents...
Creating implementation plan...
Checkpoint saved.

Phase 2: Implementation
[1/6] Create User entity... ✓
[2/6] Add authentication service... ✓
...
```

### Example 2: Partial Files (Generates Missing)

```bash
> /feature-marker prd-payment-integration

Phase 0: Inputs Gate
✓ prd.md exists
✗ techspec.md missing → Generating via /generate-spec...
✓ tasks.md exists

✅ Generated missing file. All inputs ready.

Phase 1: Analysis & Planning
...
```

### Example 3: Interactive Mode

```bash
> /feature-marker --interactive prd-new-feature

╔════════════════════════════════════════╗
║   Select Execution Mode                ║
╚════════════════════════════════════════╝

  1) Full Workflow      Generate missing files + execute all phases
  2) Tasks Only         Execute existing files only (skip generation)
  3) Ralph Loop         Autonomous execution with ralph-wiggum

Select mode [1-3]: 1

Phase 0: Inputs Gate
✗ prd.md missing → Generating via /create-prd...
✗ techspec.md missing → Generating via /generate-spec...
✗ tasks.md missing → Generating via /generate-tasks...
...
```

## Troubleshooting

### Templates not found

```bash
# Create template directory
mkdir -p ~/.claude/docs/specs

# Add your templates
touch ~/.claude/docs/specs/prd-template.md
touch ~/.claude/docs/specs/techspec-template.md
touch ~/.claude/docs/specs/tasks-template.md
```

### Commands not found

```bash
# Check commands directory
ls ~/.claude/commands/

# Ensure commands exist:
# - create-prd.md
# - generate-spec.md
# - generate-tasks.md
```

### Checkpoint corruption

```bash
# Reset checkpoint
rm -rf .claude/feature-state/{feature-name}

# Restart workflow
/feature-marker prd-{feature-name}
```

## Version History

- **v1.4.0** - Clarified documentation for templates and commands
- **v1.3.0** - Added AskUserQuestion support for interactive mode
- **v1.2.0** - Menu interactive works and path for templates
- **v1.1.0** - Added TTY detection for interactive menu mode
- **v1.0.0** - Initial release

## License

This project is licensed under the terms specified in the LICENSE file.

## Contributing

Contributions are welcome! Please ensure:
1. Documentation is updated
2. Tests pass (if applicable)
3. Commit messages are descriptive

## Support

For issues or questions:
1. Check documentation in `SKILL.md`
2. Review agent implementation in `agents/feature-marker.md`
3. Open an issue in the repository
