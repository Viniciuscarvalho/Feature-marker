# feature-marker

> Automate your feature development workflow with AI-powered checkpoints for Claude Code

[![npm version](https://img.shields.io/npm/v/feature-marker.svg)](https://www.npmjs.com/package/feature-marker)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](https://github.com/Viniciuscarvalho/Feature-marker/blob/main/LICENSE)

**feature-marker** is a Claude Code skill that guides you through the complete feature development lifecycle: PRD → Tech Spec → Tasks → Implementation → Tests → PR.

## Installation

```bash
# Install via npx (recommended)
npx @viniciuscarvalho/feature-marker install

# Or install globally
npm install -g @viniciuscarvalho/feature-marker
feature-marker install
```

## Usage

After installation, use in Claude Code:

```bash
# Start a new feature workflow
/feature-marker prd-user-authentication

# Interactive mode
/feature-marker --interactive prd-user-authentication

# Check status
/feature-marker --status prd-user-authentication
```

## Commands

| Command | Description |
|---------|-------------|
| `npx feature-marker install` | Install skill to ~/.claude |
| `npx feature-marker uninstall` | Remove skill from ~/.claude |
| `npx feature-marker status` | Check installation status |
| `npx feature-marker help` | Show help |

## Features

- **Artifact Generation** — Auto-generates PRD, Tech Spec, and Tasks from requirements
- **4-Phase Workflow** — Analysis → Implementation → Tests → Commit & PR
- **Checkpoint/Resume** — Pause anytime, resume where you left off
- **Platform Detection** — Auto-detects GitHub, Azure DevOps, GitLab for PR creation
- **Multiple Modes** — Full workflow, tasks-only, Ralph Loop, or Spec-Driven

## Requirements

Commands in `~/.claude/commands/`:
- `create-prd.md`
- `generate-spec.md`
- `generate-tasks.md`

Templates in `~/.claude/docs/specs/`:
- `prd-template.md`
- `techspec-template.md`
- `tasks-template.md`

> Get these from [mindkit](https://github.com/Viniciuscarvalho/mindkit) or create your own.

## License

MIT © [Vinicius Carvalho](https://github.com/Viniciuscarvalho)
