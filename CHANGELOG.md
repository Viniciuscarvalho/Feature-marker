# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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

[1.3.0]: https://github.com/Viniciuscarvalho/Feature-marker/compare/v1.2.0...v1.3.0
[1.2.0]: https://github.com/Viniciuscarvalho/Feature-marker/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/Viniciuscarvalho/Feature-marker/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/Viniciuscarvalho/Feature-marker/releases/tag/v1.0.0
