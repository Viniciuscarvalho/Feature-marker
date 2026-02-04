# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.6.0] - 2026-02-04

### Added
- **Smart Dependency Management**: Auto-installation of missing skills and commands
- **Phase 1**: Product Manager skill auto-install
  - Checks for `~/.claude/skills/product-manager/SKILL.md`
  - Auto-installs via `npx skills add https://github.com/aj-geddes/claude-code-bmad-skills --skill product-manager`
  - Non-blocking: continues without it if unavailable
  - Always uses user's existing skill if already installed
- **Phase 4**: Enhanced commit command auto-install
  - Checks for `~/.claude/commands/commit.md`
  - Auto-installs from bundled `resources/commit.md`
  - Professional commit workflow with pre-commit validation, commit splitting, and conventional commits with emojis
  - Falls back to standard commit if unavailable
  - Always uses user's existing command if already installed
- **Bundled Resources**: `resources/commit.md` included in installation
- **dependency-installer.sh**: New helper script for managing skills and commands
- Enhanced documentation in README.md and SKILL.md explaining auto-installation

### Changed
- Phase 1 now checks and installs product-manager skill before analysis
- Phase 4 now checks and installs enhanced commit command before committing
- Installation script now copies resources directory
- Updated agent documentation with detailed auto-install workflow
- Updated version to v1.6.0 in install.sh

### Technical Details
- Auto-installation is non-intrusive: user's existing tools always have priority
- Product Manager skill enhances PRD analysis and requirements management
- Enhanced commit command provides:
  - Pre-commit checks (lint, build, docs generation)
  - Intelligent commit splitting for multiple logical changes
  - Conventional commit format with semantic emojis
  - Smart staging (uses staged files or auto-stages all)
  - No Co-Authored-By footer (as per command design)
- All auto-installations are optional and non-blocking
- Graceful fallbacks ensure workflow continues even if installations fail

## [1.5.0] - 2026-01-30

### Added
- XcodeBuildMCP integration in Phase 3 (Tests & Validation)
- iOS simulator build and run validation after tests pass
- Automatic XcodeBuildMCP skill detection (`~/.claude/skills/xcodebuildmcp/SKILL.md`)
- Auto-configuration of XcodeBuildMCP session defaults
- `build_run_sim` command integration for iOS projects
- Enhanced test-results.md format with simulator validation section

### Changed
- Phase 3 now validates iOS apps on simulator when XcodeBuildMCP is available
- Build failures are non-blocking - workflow continues to Phase 4 with warning
- test-results.md includes simulator build/run results for iOS projects

### Technical Details
- XcodeBuildMCP integration is optional and only runs for Swift/Xcode projects
- Automatic project discovery using `discover_projs`
- Session defaults configured automatically with `session_set_defaults`
- Simulator validation skipped gracefully if skill not found or project is not iOS

## [1.4.0] - 2026-01-30

### Added
- Clarify documentation: Added comprehensive documentation for template locations and usage
- Templates section in SKILL.md explaining `~/.claude/docs/specs/` directory structure
- Template Setup Guide with verification steps
- File generation flow diagrams showing how templates, commands, and generated files interact
- Enhanced Project Structure section with visual references to template sources
- Error handling documentation for missing templates

### Changed
- Updated SKILL.md Prerequisites section to include Templates subsection
- Updated agents/feature-marker.md Inputs & Commands Gate section with template flow details
- Improved documentation clarity for where files are stored and generated

## [1.3.0] - 2026-01-30

### Added
- AskUserQuestion support for interactive mode in Claude CLI

## [1.2.0] - 2026-01-30

### Added
- Menu interactive works and path for templates

## [1.1.0] - 2026-01-30

### Added
- TTY detection for interactive menu mode

## [1.0.0] - 2026-01-30

### Added
- Initial release of feature-marker
- 4-phase workflow automation (Inputs Gate, Analysis & Planning, Implementation, Tests & Validation, Commit & PR)
- Checkpoint and resume functionality
- Interactive mode with execution mode selection
- Platform detection for PR creation
- State management system
