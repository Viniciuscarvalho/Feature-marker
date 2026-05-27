# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [7.8.1] - 2026-05-27

### Changed

- Restored the distribution to a skill-first contract for Claude, Codex, and
  Gemini.
- Kept npm/npx as an installer for skill files only.
- Documented branch-first handoff with local commits and no automatic push or
  PR creation.

### Removed

- Removed current support for package-owned workflow commands such as `run`,
  `resume`, `status`, and `capabilities`.

## [7.0.0] - 2026-04-13

### Added

- **Orchestrator feature isolated from skill** — orchestrator functionality decoupled from the core skill for independent operation and cleaner separation of concerns

## [6.2.0] - 2026-03-24

### Added

- **Skills CLI installation** — `npx skills add Viniciuscarvalho/Feature-marker` as recommended install method
- **Sponsor badge** — GitHub Sponsors link in README header
- **SEO keyword tags** — visible keyword line in README

### Changed

- **SKILL.md description overhaul** — comprehensive description with all 5 execution modes, checkpoint/resume, platform auto-detection, and trigger phrases
- **PRD template** — expanded with richer structure and guidance
- **Tech Spec template** — expanded with richer structure and guidance

## [6.1.0] - 2026-03-20

### Added

- **Skill discovery optimization** — package.json, skill.json, comprehensive SKILL.md with SEO keywords

### Changed

- **Build artifacts cleanup** — removed from tracking, updated .gitignore

## [6.0.0] - 2026-03-02

### Added

- Enrichment prompt, spec accuracy pipeline and tests for ios validated

## [5.2.1] - 2026-02-24

### Added

- **Plan Mode Integration** - Agent automatically detects and uses Claude plan mode output to enrich PRD generation
  - Auto-detects most recent plan file from `~/.claude/plans/` (sorted by modification time)
  - Reads project conventions from `./CLAUDE.md` at project root (if present)
  - Uses plan content as pre-answered context for `/create-prd`, reducing redundant clarification questions
  - Plan context also supplements Phase 1 (Analysis & Planning) with pre-explored codebase understanding
  - Fully backward-compatible: no plan = unchanged behavior

### Changed

- Added "Pre-Phase: Context Loading" section to agent definition
- Enhanced Phase 0 "Missing PRD" logic with conditional plan context injection
- Enhanced Phase 1 to leverage plan context and CLAUDE.md conventions
- Updated SKILL.md with Plan Mode Integration documentation

## [4.0.0] - 2026-02-09

### Added

- **Feature-Marker Menu Bar** - Native macOS menu bar application built with Tauri v2
  - System tray icon with quick access menu
  - Real-time process output streaming (no external Terminal needed)
  - Dashboard for viewing and managing feature workflows
  - Support for all workflow modes (Full, Tasks Only, Ralph Loop, Spec Driven)
  - Checkpoint monitoring with file watching
  - Native notifications on phase completion
  - Keyboard shortcuts (Cmd+N, Cmd+R, Cmd+D, Cmd+,, Cmd+Q, ESC)
  - Native file picker for project directory selection
  - Catppuccin Mocha dark theme

## [3.0.0] - 2026-02-08

### Added

- **Feature-Marker TUI** - Terminal User Interface application built with Ratatui
  - Full-screen terminal interface with real-time output
  - Feature list panel with status indicators
  - Interactive mode selection (Full, Tasks Only, Ralph Loop, Spec Driven)
  - Project directory configuration
  - Vim-style navigation (j/k, Tab, Enter)
  - Cross-platform support (macOS, Linux, Windows)

## [2.0.0] - 2026-02-05

### Added

- **Spec-Driven Mode (Spec Kit Pattern)** - New execution mode (option 4) with multi-agent review and isolated worktrees
  - Multi-agent spec review with 6 built-in personas (Pragmatic Architect, Paranoid Engineer, Operator, Simplifier, User Advocate, Product Strategist)
  - Isolated worktree creation for safe development in separate git branches
  - Automatic spec-to-Feature-Marker conversion (generates prd.md, techspec.md, tasks.md)
  - Iterative feedback → revision cycle with configurable consensus threshold (default 80%)
- **Bundled spec-workflow skills** - All skills included, no external installation needed:
  - `/idea-explorer` - Collaborative idea refinement with YAGNI
  - `/spec-writer` - Transform ideas into detailed specs
  - `/spec-orchestrator` - Write specs with multi-agent review
  - `/spec-executor` - Implement specs with checkpoints
  - `/create-worktree` - Setup isolated git worktree
  - `/spec-workflow-init` - Scaffold configuration structure
- **Spec-to-FM bridge script** (`lib/spec-workflow-bridge.sh`) - Converts spec-workflow specs to Feature-Marker format
- **References and documentation** - Bundled `ABSTRACTION_PLAN.md`, spec templates, personas documentation
- **Configuration support** - Optional `.claude/spec-workflow/config.yaml` for customizing review and execution behavior

### Changed

- Updated interactive menu to include option 4 (Spec-Driven Mode)
- Updated `dependency-installer.sh` to use bundled spec-workflow skills path
- Updated `menu.sh` with spec-workflow availability check and auto-installation
- Enhanced agent documentation with full Spec-Driven Mode workflow
- Updated CLI to support `--mode spec-driven` flag

### Technical Details

- Skills bundled in `resources/spec-workflow/skills/`
- References bundled in `resources/spec-workflow/references/`
- Priority path resolution: installed skill → FEATURE_MARKER_ROOT → script directory
- Backward compatible: all existing modes (full, tasks-only, ralph-loop) continue to work

## [1.6.0] - 2026-02-01

### Added

- **Smart Dependency Management** - Automatic detection and installation of dependencies
- **Bundled commit command** - Enhanced commit workflow included as bundled resource

### Changed

- Improved error handling for missing dependencies
- Better feedback during dependency installation

## [1.5.0] - 2026-01-30

### Added

- **XcodeBuildMCP Integration** - iOS simulator validation in Phase 3
- Automatic detection of XcodeBuildMCP skill
- Auto-configuration via `discover_projs` and `session_set_defaults`
- `build_run_sim` for building and running iOS apps on simulator

### Changed

- test-results.md now includes simulator build/run section for iOS projects
- Non-blocking build failures (logs warnings but workflow continues)

## [1.4.0] - 2026-01-30

### Added

- **Documentation improvements** - Templates location clarified
- File generation flow diagrams
- Architecture overview showing complete file flow
- Template setup guide

### Changed

- README.md comprehensively updated with examples and troubleshooting
- Error handling documentation for missing templates

## [1.3.0] - 2026-01-28

### Added

- **AskUserQuestion support in Claude CLI** - Interactive mode now works inside Claude CLI using AskUserQuestion tool when TTY is not available
  - Script outputs `INTERACTIVE_MODE_REQUESTED` marker when no TTY detected
  - Agent detects marker and presents options via Claude's native AskUserQuestion
  - Seamless UX both in terminal (TTY menu) and Claude CLI (AskUserQuestion prompt)
- **Direct mode selection flag** - New `--mode` flag allows skipping interactive menu:
  - `--mode full` - Full Workflow mode
  - `--mode tasks-only` - Tasks Only mode
  - `--mode ralph-loop` - Ralph Loop mode

### Changed

- Updated `lib/menu.sh` to output marker instead of error when no TTY
- Updated `feature-marker.sh` to capture exit code 100 and propagate marker
- Enhanced agent documentation with AskUserQuestion handling instructions
- Updated SKILL.md with interactive mode and direct mode documentation

## [1.2.0] - 2026-01-26

### Fixed

- **Interactive menu TTY detection** - Menu now properly detects when running without a terminal and provides clear guidance instead of hanging
- **Template paths corrected** - Commands now use global templates from `~/.claude/docs/` instead of project-relative paths:
  - PRD template: `~/.claude/docs/specs/prd-template.md`
  - TechSpec template: `~/.claude/docs/specs/techspec-template.md`
  - Task template: `~/.claude/docs/tasks/task-template.md`

## [1.1.0] - 2026-01-19

### Added

- **Interactive CLI Panel** - New `--interactive` flag launches a beautiful menu to select execution mode
  - Full Workflow Mode: Generate + Execute all phases (default behavior)
  - Tasks Only Mode: Skip file generation, execute existing tasks directly
  - Ralph Loop Mode: Autonomous execution with self-correction via ralph-wiggum
- **Multiple Execution Modes** - Flexibility to choose workflow based on current project state
- **Ralph Loop Integration** - Support for autonomous, self-correcting execution using ralph-wiggum skill
- New `lib/menu.sh` library for interactive menu functionality
- Execution mode detection in agent and scripts
- Comprehensive documentation for all three execution modes

### Changed

- Updated `feature-marker.sh` to support `--interactive` flag
- Enhanced agent behavior to respect execution modes
- Updated help text to include interactive mode option
- Improved README with detailed usage instructions for each mode
- Version bumped from 1.0 to 1.1.0

### Fixed

- Menu validation ensures Tasks Only mode has all required files
- Clear error messages when ralph-wiggum is not installed but Loop mode is selected

## [1.0.0] - 2026-01-18

### Added

- Initial release of feature-marker skill + agent
- 4-phase workflow automation (Inputs Gate → Analysis → Implementation → Tests → Commit & PR)
- Smart file detection that never overwrites existing files
- Checkpoint/resume capability for interrupted workflows
- Platform-agnostic PR creation with auto-detection (GitHub, Azure DevOps, GitLab, Bitbucket)
- Simplified project structure using `./tasks/` instead of `./docs/tasks/`
- Removed template file requirements (all generated via commands)
- Integration with mindkit commands for PRD/TechSpec/Tasks generation
- Comprehensive documentation and examples
- State management and progress tracking
- TodoWrite integration for task management

### Changed

- Migrated from template-based to command-based file generation
- Simplified directory structure (./tasks instead of ./docs/tasks)

[5.2.1]: https://github.com/Viniciuscarvalho/Feature-marker/compare/v5.2.0...v5.2.1
[4.0.0]: https://github.com/Viniciuscarvalho/Feature-marker/compare/v3.0.0...v4.0.0
[3.0.0]: https://github.com/Viniciuscarvalho/Feature-marker/compare/v2.0.0...v3.0.0
[2.0.0]: https://github.com/Viniciuscarvalho/Feature-marker/compare/v1.6.0...v2.0.0
[1.6.0]: https://github.com/Viniciuscarvalho/Feature-marker/compare/v1.5.0...v1.6.0
[1.5.0]: https://github.com/Viniciuscarvalho/Feature-marker/compare/v1.4.0...v1.5.0
[1.4.0]: https://github.com/Viniciuscarvalho/Feature-marker/compare/v1.3.0...v1.4.0
[1.3.0]: https://github.com/Viniciuscarvalho/Feature-marker/compare/v1.2.0...v1.3.0
[1.2.0]: https://github.com/Viniciuscarvalho/Feature-marker/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/Viniciuscarvalho/Feature-marker/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/Viniciuscarvalho/Feature-marker/releases/tag/v1.0.0
