# Homebrew Installation for feature-marker

## Quick Install

```bash
brew tap viniciuscarvalho/tap
brew install feature-marker
```

## Commands

| Command | Description |
|---------|-------------|
| `feature-marker-install` | Install skill to ~/.claude |
| `feature-marker-uninstall` | Remove skill from ~/.claude |
| `feature-marker-orchestrate` | Run the orchestrator (new in v7.1) |
| `feature-marker-orchestrate init` | Scaffold config in your project |
| `feature-marker-orchestrate status` | Check orchestrator state |
| `feature-marker-orchestrate --help` | See all options |

## Upgrade

```bash
brew update
brew upgrade feature-marker
# Now feature-marker-orchestrate is available
# Existing feature-marker-install still works identically
```

## Uninstall

```bash
feature-marker-uninstall
brew uninstall feature-marker
brew untap viniciuscarvalho/tap
```
