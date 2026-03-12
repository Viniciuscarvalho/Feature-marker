# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [6.1.0] - 2026-03-12

### Added

- **MCP Awareness & Skill Dispatcher** - Automatic detection and integration of MCP servers in the development environment
  - `mcp-detector.sh` script for discovering active MCP servers and their capabilities
  - `discover-env.sh` script for comprehensive environment discovery
  - Stack-specific reference patterns for React, Python, and Swift projects
  - MCP adapter references for Docker, Playwright, and XcodeBuild
  - PRD and TechSpec templates for standardized document generation
  - Enhanced context-gatherer and prompt-enricher skills with MCP awareness
  - iOS-specific workflow skill for Apple platform development
  - Spec-executor enhanced with MCP tool integration during implementation

## [6.0.0] - 2026-03-02

### Added

- Enrichment prompt, spec accuracy pipeline and tests for ios validated

## [5.3.0] - 2026-02-27

### Added

- **Native Swift/SwiftUI Menu Bar App** - Complete rewrite of the menu bar application from Rust/Tauri to native Swift/SwiftUI
  - Pure Swift 6 with zero external dependencies (Foundation, AppKit, SwiftUI, UserNotifications only)
  - `@Observable` + `@MainActor` for efficient state management with property-level tracking
  - Actor-based `ProcessManager` and `FileWatcher` for safe structured concurrency
  - NSStatusItem + NSPopover for native macOS menu bar experience with vibrancy material
  - Full feature parity: tray icon, popover dashboard (4 views), process spawning, output streaming, file watching, notifications
  - SF Symbols for template icon (adapts to light/dark mode automatically)
  - Native macOS controls and system colors throughout

### Removed

- **Rust/Tauri menu bar app** - Removed all Rust, TypeScript, Vite, and Tauri dependencies
  - Removed `src-tauri/` directory (Rust backend: tokio, serde, notify, chrono, tauri plugins)
  - Removed `ui/` directory (TypeScript/Vite frontend with node_modules)
  - Removed `scripts/` directory (Tauri build scripts)

### Changed

- **93.5% binary size reduction** - From 13 MB (Rust/Tauri) to 839 KB (Swift)
- **App bundle size**: 844 KB total (vs estimated 15-20 MB for Tauri .app bundle)
- **Source code**: 19 Swift files, 1652 lines (unified from 5 Rust + 2 TS/CSS files)
- macOS 15+ (Sequoia) minimum target for latest SwiftUI APIs
- Swift Package Manager project structure (no Xcode project needed)
- Build via `./build.sh` creates optimized .app bundle with `-Osize` flag

## [5.2.1] - 2026-02-24

### Added

- **Plan Mode Integration** - Agent automatically detects and uses Claude plan mode output to enrich PRD generation
  - Auto-detects most recent plan file from `~/.claude/plans/` (sorted by modification time)
  - Reads project conventions from `./CLAUDE.md` at project root (if present)
  - Uses plan content as pre-answered context for `/create-prd`, reducing redundant clarification questions
  - Plan context also supplements Phase 1 (Analysis & Planning) with pre-explored codebase understanding
  - Fully backward-compatible: no plan = unchanged behavior
  - No new execution modes, flags, or shell script changes required

### Changed

- Added "Pre-Phase: Context Loading" section to agent definition (runs before Phase 0)
- Enhanced Phase 0 "Missing PRD" logic with conditional plan context injection
- Enhanced Phase 1 to leverage plan context and CLAUDE.md conventions
- Updated SKILL.md with Plan Mode Integration documentation and recommended flow

## [5.2.0] - 2026-02-20

### Added

- **Prompt Area on TUI** - New prompt input area in TUI mode for interactive command input
- **Kanban Visualization** - Visual Kanban board for tracking task execution and status changes

## [5.1.0] - 2026-02-17

### Added

- **Test Only Mode** - New execution mode (option 5) for running tests phase exclusively
  - Skips Phases 0-2 (inputs gate, planning, implementation)
  - Runs only Phase 3 (Tests & Validation)
  - Uses `/swift-testing` skill for guided test creation and best practices
  - Supports Swift Testing framework patterns: `@Test`, `@Suite`, `#expect`, `#require`
  - Applies F.I.R.S.T. principles and Arrange-Act-Assert patterns
  - Adapts testing methodology to non-Swift projects using native test frameworks
  - Ideal for adding tests to already-implemented features
- **Direct mode selection**: `--mode test-only` flag for CLI usage
- **Interactive menu**: Option 5 in interactive mode panel

### Changed

- Updated interactive menu to include option 5 (Test Only Mode)
- Updated `menu.sh` with `is_test_only_mode()` helper function
- Updated `feature-marker.sh` with test-only mode display and inputs gate handling
- Enhanced agent documentation with full Test Only Mode workflow and examples
- Updated SKILL.md with test-only mode in usage and direct mode selection docs
- Updated CLI help text to list all 5 execution modes

### Technical Details

- Environment variable: `EXECUTION_MODE=test-only`
- Integrates with `/swift-testing` skill for Swift project test guidance
- Non-Swift projects adapt the testing methodology to their native frameworks
- Checkpoint support: saves test results to `.claude/feature-state/{feature-name}/test-results.md`
- Backward compatible: all existing modes continue to work unchanged

## [5.0.0] - 2026-02-12

### Added

- **NPX Distribution** - Install feature-marker via npm/npx for easier cross-platform installation
  - `npx feature-marker install` - One-command installation
  - `npx feature-marker uninstall` - Clean removal
  - `npx feature-marker status` - Check installation status
  - Auto-install on package installation (postinstall hook)
  - ES modules with Node.js 18+ support
- **Homebrew Distribution** - Install feature-marker via Homebrew for macOS/Linux users
  - `brew tap viniciuscarvalho/tap && brew install feature-marker`
  - `feature-marker-install` - Install skill to ~/.claude
  - `feature-marker-uninstall` - Remove skill from ~/.claude
  - Optional `--with-tui` flag to build TUI from source
  - Standard Homebrew formula with test and caveats

### Changed

- Updated README with new installation methods (NPX, Homebrew, Manual)
- Version bumped to 5.0.0

### Technical Details

- NPX package uses ES modules (type: module)
- Bundle script copies dist files during npm prepare
- Homebrew formula includes wrapper scripts for installation management
- Both distribution methods install to standard ~/.claude paths

## [4.0.0] - 2026-02-10

### Added

- **Feature-Marker Menu Bar** - Native macOS menu bar application
  - Global keyboard shortcut (Cmd+Shift+F)
  - Quick access to feature workflows
  - System tray integration

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

[6.0.0]: https://github.com/Viniciuscarvalho/Feature-marker/compare/v5.3.0...v6.0.0
[5.3.0]: https://github.com/Viniciuscarvalho/Feature-marker/compare/v5.2.1...v5.3.0
[5.2.1]: https://github.com/Viniciuscarvalho/Feature-marker/compare/v5.2.0...v5.2.1
[5.2.0]: https://github.com/Viniciuscarvalho/Feature-marker/compare/v5.1.0...v5.2.0
[5.1.0]: https://github.com/Viniciuscarvalho/Feature-marker/compare/v5.0.0...v5.1.0
[5.0.0]: https://github.com/Viniciuscarvalho/Feature-marker/compare/v4.0.0...v5.0.0
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
