# Session Context

## User Prompts

### Prompt 1

Eu possuo inúmeras tarefas para uma nova versão robusta do feature-marker que vai se lançada, porém eu preciso fazer isso de forma gradual e separada.
1) Buscar todas as features a serem executadas, https://github.com/Viniciuscarvalho/Feature-marker/issues
2) Cada uma das features possui detalhamento e os critérios de aceite bem definidos, esses critérios de aceite devem ser todos preenchidos em todas as tasks a serem realizadas
3) Ao finalizar cada uma das tasks deve realizar o /commit pa...

### Prompt 2

# Claude Command: Commit

This command helps you create well-formatted commits with conventional commit messages and emoji.

## Usage

To create a commit, just type:
```
/commit
```

Or with options:
```
/commit --no-verify
```

## What This Command Does

1. Unless specified with `--no-verify`, automatically runs pre-commit checks:
   - `pnpm lint` to ensure code quality
   - `pnpm build` to verify the build succeeds
   - `pnpm generate:docs` to update documentation
2. Checks which files are sta...

### Prompt 3

This session is being continued from a previous conversation that ran out of context. The summary below covers the earlier portion of the conversation.

Analysis:
Let me analyze this conversation thoroughly to create a comprehensive summary.

## User's Request
The user wants to implement a new v6.0.0 release of feature-marker by:
1. Fetching all GitHub issues from https://github.com/Viniciuscarvalho/Feature-marker/issues
2. Implementing each feature with all acceptance criteria fulfilled
3. Afte...

### Prompt 4

# Claude Command: Commit

This command helps you create well-formatted commits with conventional commit messages and emoji.

## Usage

To create a commit, just type:
```
/commit
```

Or with options:
```
/commit --no-verify
```

## What This Command Does

1. Unless specified with `--no-verify`, automatically runs pre-commit checks:
   - `pnpm lint` to ensure code quality
   - `pnpm build` to verify the build succeeds
   - `pnpm generate:docs` to update documentation
2. Checks which files are sta...

### Prompt 5

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

