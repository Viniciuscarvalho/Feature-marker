# Session Context

## User Prompts

### Prompt 1

faça o merge desse PR na main, em seguida gere uma tag de release com 6.1.0, faça o push dessa tag adicione o /add-to-changelog added 6.1.0 "mcp awereness" e atualize a instalação do brew e também do NPM

### Prompt 2

# Update Changelog

This command adds a new entry to the project's CHANGELOG.md file.

## Usage

```
/add-to-changelog <version> <change_type> <message>
```

Where:
- `<version>` is the version number (e.g., "1.1.0")
- `<change_type>` is one of: "added", "changed", "deprecated", "removed", "fixed", "security"
- `<message>` is the description of the change

## Examples

```
/add-to-changelog 1.1.0 added "New markdown to BlockDoc conversion feature"
```

```
/add-to-changelog 1.0.2 fixed "Bug in H...

