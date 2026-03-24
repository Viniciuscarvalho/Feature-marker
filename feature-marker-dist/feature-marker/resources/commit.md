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

1. Unless specified with `--no-verify`, automatically runs platform-appropriate pre-commit checks
   (see **Pre-Commit Checks by Platform** section below)
2. Checks which files are staged with `git status`
3. If 0 files are staged, automatically adds all modified and new files with `git add`
4. Performs a `git diff` to understand what changes are being committed
5. Analyzes the diff to determine if multiple distinct logical changes are present
6. If multiple distinct changes are detected, suggests breaking the commit into multiple smaller commits
7. For each commit (or the single commit if not split), creates a commit message using emoji conventional commit format

## Best Practices for Commits

- **Verify before committing**: Ensure code is linted, builds correctly, and documentation is updated
- **Atomic commits**: Each commit should contain related changes that serve a single purpose
- **Split large changes**: If changes touch multiple concerns, split them into separate commits
- **Conventional commit format**: Use the format `<type>: <description>` where type is one of:
  - `feat`: A new feature
  - `fix`: A bug fix
  - `docs`: Documentation changes
  - `style`: Code style changes (formatting, etc)
  - `refactor`: Code changes that neither fix bugs nor add features
  - `perf`: Performance improvements
  - `test`: Adding or fixing tests
  - `chore`: Changes to the build process, tools, etc.
- **Present tense, imperative mood**: Write commit messages as commands (e.g., "add feature" not "added feature")
- **Concise first line**: Keep the first line under 72 characters
- **Emoji**: Each commit type is paired with an appropriate emoji:
  - ✨ `feat`: New feature
  - 🐛 `fix`: Bug fix
  - 📝 `docs`: Documentation
  - 💄 `style`: Formatting/style
  - ♻️ `refactor`: Code refactoring
  - ⚡️ `perf`: Performance improvements
  - ✅ `test`: Tests
  - 🔧 `chore`: Tooling, configuration
  - 🚀 `ci`: CI/CD improvements
  - 🗑️ `revert`: Reverting changes
  - 🧪 `test`: Add a failing test
  - 🚨 `fix`: Fix compiler/linter warnings
  - 🔒️ `fix`: Fix security issues
  - 👥 `chore`: Add or update contributors
  - 🚚 `refactor`: Move or rename resources
  - 🏗️ `refactor`: Make architectural changes
  - 🔀 `chore`: Merge branches
  - 📦️ `chore`: Add or update compiled files or packages
  - ➕ `chore`: Add a dependency
  - ➖ `chore`: Remove a dependency
  - 🌱 `chore`: Add or update seed files
  - 🧑‍💻 `chore`: Improve developer experience
  - 🧵 `feat`: Add or update code related to multithreading or concurrency
  - 🔍️ `feat`: Improve SEO
  - 🏷️ `feat`: Add or update types
  - 💬 `feat`: Add or update text and literals
  - 🌐 `feat`: Internationalization and localization
  - 👔 `feat`: Add or update business logic
  - 📱 `feat`: Work on responsive design
  - 🚸 `feat`: Improve user experience / usability
  - 🩹 `fix`: Simple fix for a non-critical issue
  - 🥅 `fix`: Catch errors
  - 👽️ `fix`: Update code due to external API changes
  - 🔥 `fix`: Remove code or files
  - 🎨 `style`: Improve structure/format of the code
  - 🚑️ `fix`: Critical hotfix
  - 🎉 `chore`: Begin a project
  - 🔖 `chore`: Release/Version tags
  - 🚧 `wip`: Work in progress
  - 💚 `fix`: Fix CI build
  - 📌 `chore`: Pin dependencies to specific versions
  - 👷 `ci`: Add or update CI build system
  - 📈 `feat`: Add or update analytics or tracking code
  - ✏️ `fix`: Fix typos
  - ⏪️ `revert`: Revert changes
  - 📄 `chore`: Add or update license
  - 💥 `feat`: Introduce breaking changes
  - 🍱 `assets`: Add or update assets
  - ♿️ `feat`: Improve accessibility
  - 💡 `docs`: Add or update comments in source code
  - 🗃️ `db`: Perform database related changes
  - 🔊 `feat`: Add or update logs
  - 🔇 `fix`: Remove logs
  - 🤡 `test`: Mock things
  - 🥚 `feat`: Add or update an easter egg
  - 🙈 `chore`: Add or update .gitignore file
  - 📸 `test`: Add or update snapshots
  - ⚗️ `experiment`: Perform experiments
  - 🚩 `feat`: Add, update, or remove feature flags
  - 💫 `ui`: Add or update animations and transitions
  - ⚰️ `refactor`: Remove dead code
  - 🦺 `feat`: Add or update code related to validation
  - ✈️ `feat`: Improve offline support

## Guidelines for Splitting Commits

When analyzing the diff, consider splitting commits based on these criteria:

1. **Different concerns**: Changes to unrelated parts of the codebase
2. **Different types of changes**: Mixing features, fixes, refactoring, etc.
3. **File patterns**: Changes to different types of files (e.g., source code vs documentation)
4. **Logical grouping**: Changes that would be easier to understand or review separately
5. **Size**: Very large changes that would be clearer if broken down

## Examples

Good commit messages:
- ✨ feat: add user authentication system
- 🐛 fix: resolve memory leak in rendering process
- 📝 docs: update API documentation with new endpoints
- ♻️ refactor: simplify error handling logic in parser
- 🚨 fix: resolve linter warnings in component files
- 🧑‍💻 chore: improve developer tooling setup process
- 👔 feat: implement business logic for transaction validation
- 🩹 fix: address minor styling inconsistency in header
- 🚑️ fix: patch critical security vulnerability in auth flow
- 🎨 style: reorganize component structure for better readability
- 🔥 fix: remove deprecated legacy code
- 🦺 feat: add input validation for user registration form
- 💚 fix: resolve failing CI pipeline tests
- 📈 feat: implement analytics tracking for user engagement
- 🔒️ fix: strengthen authentication password requirements
- ♿️ feat: improve form accessibility for screen readers

Example of splitting commits:
- First commit: ✨ feat: add new solc version type definitions
- Second commit: 📝 docs: update documentation for new solc versions
- Third commit: 🔧 chore: update package.json dependencies
- Fourth commit: 🏷️ feat: add type definitions for new API endpoints
- Fifth commit: 🧵 feat: improve concurrency handling in worker threads
- Sixth commit: 🚨 fix: resolve linting issues in new code
- Seventh commit: ✅ test: add unit tests for new solc version features
- Eighth commit: 🔒️ fix: update dependencies with security vulnerabilities

## Pre-Commit Checks by Platform

Before committing, detect the project platform and run the appropriate checks.

### Platform Detection

Detect by presence of lock files and config files in the project root:

1. **iOS / Swift**
   - Detected by: `*.xcodeproj`, `*.xcworkspace`, or `Package.swift`
   - lint: `swiftlint` (only if `swiftlint` is installed — `command -v swiftlint`)
   - build: `xcodebuild build -scheme {detected-scheme} -quiet` (only if XcodeBuildMCP available)
   - test: skipped by default (use `--test` flag to enable)

2. **Node.js** — detect package manager from lock files:
   - `pnpm-lock.yaml` → `pnpm`
   - `yarn.lock` → `yarn`
   - `bun.lockb` → `bun`
   - `package-lock.json` or fallback → `npm`
   - lint: `{pm} run lint` (only if `scripts.lint` exists in `package.json`)
   - build: `{pm} run build` (only if `scripts.build` exists in `package.json`)
   - docs: `{pm} run generate:docs` (only if `scripts["generate:docs"]` exists)

3. **Rust**
   - Detected by: `Cargo.toml`
   - lint: `cargo clippy -- -D warnings`
   - build: `cargo build`

4. **Python**
   - Detected by: `pyproject.toml`, `setup.py`, or `requirements.txt`
   - lint: `ruff check .` (if available) or `flake8 .` (if available)
   - build: `python -m build` (only if `pyproject.toml` exists)

5. **Go**
   - Detected by: `go.mod`
   - lint: `go vet ./...`
   - build: `go build ./...`

6. **No platform detected** — skip pre-commit checks with a warning:
   ```
   ⚠️ No known platform detected. Skipping pre-commit checks.
   ```

### Conditional Execution Rules

- **Only run a check if the tool/script exists** — never fail hard on a missing optional tool
- **Each check must report its result** — never fail silently
- Example output:
  ```
  Running pre-commit checks (Node.js / pnpm)...
  ✅ pnpm run lint — passed
  ✅ pnpm run build — passed
  ⚠️ generate:docs — script not found, skipping
  ```

### Manual Override via `.feature-marker.json`

If `.feature-marker.json` exists with a `commit.pre_commit` section, use those commands instead:

```json
{
  "commit": {
    "pre_commit": {
      "lint": "swiftlint --strict",
      "build": "xcodebuild build -scheme MyApp -quiet",
      "test": null
    }
  }
}
```

If a value is `null`, skip that step. If the key is missing, use platform auto-detection.

## Command Options

- `--no-verify`: Skip running all pre-commit checks entirely

## Important Notes

- By default, platform-appropriate pre-commit checks run to ensure code quality
- If these checks fail, you'll be asked if you want to proceed with the commit anyway or fix the issues first
- Pre-commit failures are never silent — always report the reason and which step failed
- If specific files are already staged, the command will only commit those files
- If no files are staged, it will automatically stage all modified and new files
- The commit message will be constructed based on the changes detected
- Before committing, the command will review the diff to identify if multiple commits would be more appropriate
- If suggesting multiple commits, it will help you stage and commit the changes separately
- Always reviews the commit diff to ensure the message matches the changes
- Do NOT add Claude co-authorship footer to commits
