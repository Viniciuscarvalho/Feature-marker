# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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

[1.1.0]: https://github.com/Viniciuscarvalho/Feature-marker/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/Viniciuscarvalho/Feature-marker/releases/tag/v1.0.0
