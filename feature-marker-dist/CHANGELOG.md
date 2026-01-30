# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
