# Session Context

## User Prompts

### Prompt 1

Foi feito uma atualização de versão e preciso realizar o lançamento da versão via homebrew e também via NPX. Para isso utilize /add-to-changelog 5.2.0 added "prompt area on TUI and Kanban visualization", além disso é necessário criar a tag atualizada para 5.2.0 e gerar uma release nova no github.

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

