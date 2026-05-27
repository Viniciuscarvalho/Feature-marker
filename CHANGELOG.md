# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [7.8.1] - 2026-05-27

### Changed

- Restored Feature Marker as a skill-first workflow. The npm package now acts
  as an installer for Claude, Codex, and Gemini skill files instead of running
  feature workflows from JavaScript.
- Replaced workflow CLI documentation with npx install instructions and LLM
  invocation examples.
- Clarified Claude usage as a prompt-invoked run-through flow with an
  implementation grill pass before coding.

### Removed

- Removed workflow command support for `run`, `resume`, `status`, and
  `capabilities`; users now invoke the installed skill inside their LLM.

## [7.7.0] - 2026-04-21

### Added

- **Live backlog table in orchestrator progress view** (PR #46) — The UX orchestrator now renders a live-updating table of the feature backlog during a run, giving operators real-time visibility into which tasks are queued, in-progress, and done
- **Next-steps guidance after a run** (PR #46) — After each orchestrator cycle completes, the UX layer surfaces a curated next-steps panel so operators know exactly what action to take (e.g. review PR, approve checkpoint, retry failed task) without scanning raw logs
- **Summary accuracy improvements** (PR #46) — Orchestrator run summaries now reflect the actual terminal state of each task rather than the last known state, eliminating stale "in-progress" entries in post-run reports

### Fixed

- **Git push and `gh pr create` errors surfaced on PR creation failure** (PR #46) — When the orchestrator's automated PR creation step fails (network error, branch protection, quota limit, etc.) the underlying `git push` or `gh pr create` stderr is now captured and shown to the operator instead of a generic "PR creation failed" message

## [7.6.0] - 2026-04-21

### Added

- **Ollama & semantic embedding retrieval** (PR #39) — Learning module now integrates with Ollama for local semantic embeddings; retrieved context is ranked by cosine similarity and injected into the orchestrator prompt at the start of each feature run
- **`full_auto` mode with extended Ralph Loop** (PR #43) — Full-autonomy run path uses `--permission-mode bypassPermissions` so the inner agent never stalls on a permission prompt (replaces `--dangerously-skip-permissions`, which triggered an interactive "Verify the reason" confirmation in `-p` mode); the outer retry loop (Ralph Loop) keeps cycling until the feature reaches DONE or the retry budget is exhausted

### Fixed

- **`--help` outside a git repo** (PR #36) — CLI argument parsing now runs before the git-repo guard; `feature-marker-orchestrate --help` works in any directory, not just inside a git repo
- **Context-gatherer Phase 0.1 failures** (PR #37) — Resolved a cluster of failures: missing tool declarations in the gatherer prompt, slug generation edge cases, `mkdir -p` race condition on worktree init, and incorrect resume-state detection after a partial run
- **`full_auto` hang and invalid model flag** (PR #43) — Replaced `--dangerously-skip-permissions` (which blocks `-p` mode with an interactive confirmation) with `--permission-mode bypassPermissions`; also translates the internal `opusplan` alias to `opus` before passing `--model` to the Claude CLI. Both changes applied to Phase 2 invocation and Phase 3 Ralph Loop fix attempts

### Documentation

- **`HOW_IT_WORKS.md`** (PR #38) — New top-level reference document covering the end-to-end orchestrator flow; also patches the gap between checkpoint and supervised modes in `orchestrate.sh`
- **`depends-on` syntax and checkpoint halt behavior** (PR #40) — Corrected YAML syntax examples and documented how a failed checkpoint halts all downstream dependent features
- **Per-run log path and `--verbose` capture** (PR #41) — Documented where each run's log lands and that `--verbose` routes full Claude output to the run log file
- **Phase-2 cost estimate variance** (PR #42) — Clarified that Phase-2 token estimates vary with routing decisions; added a note in cost docs so operators know to treat the figure as a lower bound

## [7.5.0] - 2026-04-19

### Added

- **ADR-008 Token-Economy & Block-Based Architecture** — Cost-aware orchestrator loop with block-gated execution (`scripts/lib/cost.sh`, `router.sh`, `learning.sh`, `size_gate.sh`, `cycle_gate.sh`); features are only promoted through pipeline stages when token budget and cycle/size gates allow
- **ADR-009 Local-Model Integration** — Offline embedding, classification, summarization, and generation via pluggable local models (`scripts/lib/local_model.sh`, `scripts/lib/ingest.sh`); ingest pipeline falls back gracefully when no local model is configured
- **ADR-010 Stuck-State Elimination** — Drops the bash skill registry in favour of Claude's native agent-discovery flow; orchestrator can no longer stall waiting for a skill that isn't registered
- **`wt_cleanup_merged` in `scripts/lib/worktree.sh`** — Scans worktrees whose PRs have been merged and removes them; underlying function for the intended `clean-merged` subcommand
- **`VERBOSE` guard in `scripts/lib/local_model.sh`** — Detailed local-model log lines are gated behind `VERBOSE=true`; intended to be exposed as a `--verbose` / `-v` flag (CLI wiring pending — see regression note below)
- **Auto-update `global-context.md`** — Orchestrator appends a feature-completion summary to `global-context.md` after every successful feature run, keeping cross-feature memory current
- **Bats unit-test coverage** — New test suites in `tests/lib/` for: ingest pid-file reads and JS-interpolation hardening, cost gate, router, size gate, cycle gate, verbose-flag output gating, worktree cleanup on merge, and `gc_append_feature_summary`

### Changed

- **Homebrew formula** — Now pins to a tag-based GitHub archive URL (`archive/refs/tags/v7.5.0.tar.gz`) instead of a branch tarball; SHA is deterministic and stable across re-downloads

### Fixed

- **`ingest.sh`** — Collapsed redundant pid-file reads to a single atomic check; removed JS-interpolation vectors from local-model CLI invocation to close a command-injection surface

### Known regression

- **`clean-merged` subcommand and `--verbose` flag not wired in `orchestrate.sh`** — PRs #30 and #31 (from `bocato/feat/worktree-cleanup-on-merge` and `bocato/feat/verbose-flag`) added the underlying library code, but the `orchestrate.sh` dispatcher entries were dropped when PR #29 (ADR-010) merged afterward. The lib functions (`wt_cleanup_merged`, `VERBOSE` guard) exist; the CLI entry points need to be re-added in a follow-up.

## [7.4.0] - 2026-04-17

### Changed

- **Model selection** — Plan phase now runs on Opus (deeper reasoning for task decomposition); execute phase runs on Sonnet (faster, cost-efficient for code generation). Configured in `orchestrate.sh` runner and documented in ADR-008

## [7.3.0] - 2026-04-16

### Added

- **Shell Script Orchestration CLI** — New single entry point `orchestrate.sh` with 4 subcommands (`init`, `run`, `status`, `clean`) and 6 flags (`--autonomy`, `--adapter`, `--config`, `--feature`, `--dry-run`, `--resume`)
  - Modular architecture: 5 library modules in `scripts/lib/` (config, worktree, memory, display, runner) — each independently testable
  - Full dependency tracking with blocked feature display
  - Resume support: re-run skips completed features, runs pending
  - Single-feature mode via `--feature <id>`
  - Dry-run mode shows backlog plan without executing
- **Homebrew + NPX distribution** — `feature-marker-orchestrate` command available globally
  - `brew install feature-marker` now includes the orchestrator alongside the existing skill
  - `feature-marker-orchestrate init` scaffolds config in any project directory
  - `feature-marker-orchestrate run` executes the loop from anywhere
  - NPX wrapper: `npx @viniciuscarvalho/feature-marker orchestrate`
  - Dual-mode path resolution via `ORCHESTRATOR_HOME` env var — Homebrew, NPX, and local `./scripts/` all work with zero code duplication
- **Templates** — `config.yaml`, `env.example`, `gitignore-entries.txt` shipped with install, copied into projects by `init`
- **Wrapper script** — `bin/feature-marker-orchestrate` resolves symlinks to libexec or falls back to local scripts/

### Changed

- **Homebrew formula** — Updated to v7.3.0 with libexec orchestrator installation, wrapper binary, jq + node dependencies, and test block
- **npm package.json** — Added `feature-marker-orchestrate` bin entry
- **orchestrate.sh** — Dual-mode path resolution (ORCHESTRATOR_HOME or relative to $0), PROJECT_ROOT is always cwd

## [7.1.0] - 2026-04-14

### Added

- **Agent Discovery and Task Routing (ADR-006)** — The orchestrator now scans `.claude/agents/` for specialized agents, builds a capability manifest, and routes individual tasks to the best-matching agent instead of running everything through feature-marker's generic pipeline
  - `scripts/agent-discovery.sh` — Scans `.claude/agents/*.md` recursively, parses YAML frontmatter (`name`, `description`, `capabilities`, `phase`), outputs `agents-manifest.json`
  - `scripts/route-tasks.sh` — Reads task tags from `tasks.md`, matches against agent capabilities using priority scoring (phase match > capability overlap > fallback), outputs routing JSON
  - `schemas/agents-manifest-schema.json` — JSON Schema for the agent manifest format
  - Routing rules: phase exact match (100 pts), capability overlap (10 pts each), phase=any bonus (5 pts), fallback to feature-marker
  - Tag inference from task content when no explicit tags: detects language (Swift, React, Python, Rust, Go) and phase (testing, review, implementation)
- **Provider-Agnostic Config & Secrets Management (ADR-005)** — The orchestrator never accesses external services directly; adapters handle all provider communication
  - Per-adapter config blocks in `orchestrator/config.yml` (`source.markdown`, `source.github`, `source.linear`, `source.jira`, `source.notion`)
  - `.env` for runtime secrets (never committed), `.env.example` as committed template
  - Dynamic adapter resolution with per-provider auth validation (`gh auth status`, `LINEAR_API_KEY` check)
  - 3-level YAML config parser for nested adapter sections
- **Enhanced Safety Guardrails** — `max_file_changes` limit pauses execution when a feature touches too many files; `schema_migration_review` pauses on schema changes
- **Error Pattern Windowing (ADR-002)** — Keeps only the last N error patterns (configurable via `memory.error_pattern_window`) to prevent unbounded growth
- **Worktree Manager v2** — `rebase_pending()` rebases in-progress worktrees against base branch; `clean_all()` removes all worktrees; configurable `WORKTREE_BASE` and `BRANCH_PREFIX` via config
- **Backlog Adapter Improvements** — `source_url` field on all adapters; markdown adapter supports inline priority in title `[p:high]`, file existence check, better dependency regex; GitHub adapter filters `priority/*` labels, adds `--state open`; Linear adapter promotes URL to top-level field

### Changed

- **Config schema expanded** — New sections: `discovery`, `routing`, `worktrees`, `memory`, `safety` (with `max_file_changes`, `schema_migration_review`), `notifications`, `metrics`, `preprocessing` (future/deferred per ADR-003)
- **Orchestrator loop** — Agent discovery runs before main loop; task routing phase inserted between context injection and pipeline invocation; auto-cleanup respects `worktrees.auto_cleanup` config
- **Backlog item schema v2** — Added `source_url` field, relaxed `id` pattern for broader adapter compatibility

## [7.0.0] - 2026-04-13

### Added

- **Orchestrator feature isolated from skill** — orchestrator functionality decoupled from the core skill for independent operation and cleaner separation of concerns

## [6.2.0] - 2026-03-24

### Added

- **Skills CLI installation** — `npx skills add Viniciuscarvalho/Feature-marker` as recommended install method with `npx skills update` for updates
- **Sponsor badge** — GitHub Sponsors link in README header
- **SEO keyword tags** — visible keyword line in README for discoverability

### Changed

- **README GitHub SEO optimization** — expanded subtitle with full feature description, optimized banner alt text, richer intro paragraph
- **SKILL.md description overhaul** — comprehensive description covering all 5 execution modes, checkpoint/resume, git platform auto-detection, stack detection, and extensive trigger phrases for Claude Code skill discovery
- **PRD template** — expanded with richer structure and guidance
- **Tech Spec template** — expanded with richer structure and guidance

## [6.1.0] - 2026-03-20

### Added

- **Skill discovery optimization** — package.json, skill.json, and comprehensive SKILL.md with SEO keywords for better discoverability

### Changed

- **Build artifacts cleanup** — removed build artifacts from tracking and updated .gitignore

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

[7.3.0]: https://github.com/Viniciuscarvalho/Feature-marker/compare/v7.1.0...v7.3.0
[7.1.0]: https://github.com/Viniciuscarvalho/Feature-marker/compare/v7.0.0...v7.1.0
[7.0.0]: https://github.com/Viniciuscarvalho/Feature-marker/compare/v6.2.0...v7.0.0
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
