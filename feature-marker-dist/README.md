# Feature-Marker

Workflow automation for feature development with checkpoints and resume capability.

## Versions

| Version | Type | Description |
|---------|------|-------------|
| **CLI** | `feature-marker-dist/` | Command-line skill for Claude Code |
| **TUI** | `feature-marker-tui/` | Terminal UI application |
| **Menu Bar** | `feature-marker-menubar/` | Native macOS menu bar app |

## Installation

### CLI (Skill)

```bash
cd feature-marker-dist
./install.sh
```

Installs to `~/.claude/skills/feature-marker/`

### TUI (Terminal UI)

```bash
cd feature-marker-tui
./install.sh
```

Run with: `feature-marker`

### Menu Bar (macOS)

```bash
cd feature-marker-menubar
./scripts/install.sh
```

Installs to `/Applications/Feature-Marker.app`

## Usage

### CLI

```bash
# Start workflow
/feature-marker my-feature-name

# Interactive mode selection
/feature-marker --interactive my-feature-name

# Direct mode
/feature-marker --mode full my-feature-name
```

### TUI / Menu Bar

1. Set project directory
2. Enter feature name
3. Select mode
4. Monitor progress in real-time

## Workflow Modes

| Mode | Description |
|------|-------------|
| **Full** | Generate missing docs (PRD, TechSpec, Tasks) + execute all phases |
| **Tasks Only** | Use existing docs, skip generation |
| **Ralph Loop** | Autonomous execution with self-correction |
| **Spec Driven** | Generate from requirements with multi-agent review |

## Platform Support

Works with any tech stack — agnostic by default:

| Platform | Test | Lint |
|----------|------|------|
| 🍎 iOS/Swift | `swift test --parallel` | `swiftlint` |
| 🟨 Node.js/TS | `jest` / `vitest run` | `{pm} run lint` |
| 🦀 Rust | `cargo test` | `cargo clippy` |
| 🐍 Python | `pytest -v` | `ruff check .` |
| 🐹 Go | `go test ./...` | `go vet ./...` |

iOS projects also get XcodeBuildMCP simulator validation (optional).

## Workflow Phases

```
Phase 0: Inputs Gate     → Validate/generate PRD, TechSpec, Tasks
Phase 1: Analysis        → Create implementation plan
Phase 2: Implementation  → Execute tasks with progress tracking
Phase 3: Tests           → Run platform-appropriate tests + lint
Phase 4: Commit & PR     → Create commit and pull request
```

## Requirements

### CLI
- Claude Code with skills support
- Commands in `~/.claude/commands/`: `create-prd.md`, `generate-spec.md`, `generate-tasks.md`
- Templates in `~/.claude/docs/specs/`: `prd-template.md`, `techspec-template.md`, `tasks-template.md`

### TUI
- Rust 1.70+ (for building)
- Claude Code CLI installed

### Menu Bar
- macOS 11+ (Big Sur)
- Rust 1.70+ and Node.js 18+ (for building)
- Claude Code CLI installed

## Resume

If interrupted, re-run with same feature name to resume from checkpoint.

## Configuration

Optional `.feature-marker.json` in project root:

```json
{
  "test_command": "npm run test:ci",
  "docs_path": "./tasks",
  "skip_pr": false
}
```

## Project Structure

```
Feature-marker/
├── feature-marker-dist/     # CLI skill
├── feature-marker-tui/      # Terminal UI
└── feature-marker-menubar/  # macOS menu bar app
```

## License

MIT
