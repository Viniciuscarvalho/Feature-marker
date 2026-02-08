# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [3.0.0] - 2026-02-08

### Added
- **Feature-Marker TUI** - New Terminal User Interface application built with Rust + Ratatui
  - Rich visual interface with multi-pane layout (sidebar + main content)
  - Real-time progress visualization for phases and tasks
  - Live output streaming with auto-scroll and manual scrolling
  - Keyboard-driven navigation (j/k, Enter, Esc, Tab)
  - Four screens: Welcome, Feature Selection, Mode Selection, Execution Dashboard
  - Async shell integration with Tokio runtime
  - File watcher for external checkpoint changes (via notify crate)
  - Full compatibility with existing checkpoint.json format
  - Pause/resume execution support
  - Color themes matching Feature-Marker branding
- **TUI Installation** - New `--with-tui` flag in install.sh to build and install the TUI
- **Standalone TUI installer** - `feature-marker-tui/install.sh` for independent TUI installation
- **Integration tests** - 20 automated tests covering checkpoint, model, and config modules

### Technical Details
- TUI built with Rust 2021 edition
- Dependencies: ratatui 0.29, crossterm 0.28, tokio 1.x, serde, notify 7, chrono
- Release binary optimized with LTO and strip (~1.8 MB)
- MVU (Model-View-Update) architecture pattern
- Async event loop with multi-channel message passing

### Changed
- Updated install.sh version banner to v3.0.0
- Install script now supports `--with-tui` option for optional TUI installation

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

[3.0.0]: https://github.com/Viniciuscarvalho/Feature-marker/compare/v2.0.0...v3.0.0
[2.0.0]: https://github.com/Viniciuscarvalho/Feature-marker/compare/v1.6.0...v2.0.0
[1.6.0]: https://github.com/Viniciuscarvalho/Feature-marker/compare/v1.5.0...v1.6.0
[1.5.0]: https://github.com/Viniciuscarvalho/Feature-marker/compare/v1.4.0...v1.5.0
[1.4.0]: https://github.com/Viniciuscarvalho/Feature-marker/compare/v1.3.0...v1.4.0
[1.3.0]: https://github.com/Viniciuscarvalho/Feature-marker/compare/v1.2.0...v1.3.0
[1.2.0]: https://github.com/Viniciuscarvalho/Feature-marker/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/Viniciuscarvalho/Feature-marker/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/Viniciuscarvalho/Feature-marker/releases/tag/v1.0.0
