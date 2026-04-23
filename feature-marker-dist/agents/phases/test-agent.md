# Test Phase

Run platform-appropriate tests and lint, then save results.

---

## Setup

Load `.claude/feature-state/{slug}/platform-context.json` to get the detected platform and available commands.

---

## Test Execution

Select commands based on `primary_platform`:

| Platform  | Test command                              | Lint command                  |
| --------- | ----------------------------------------- | ----------------------------- |
| iOS/Swift | `swift test --parallel`                   | `swiftlint` (if available)    |
| Node.js   | `jest --findRelatedTests` or `vitest run` | `{pm} run lint`               |
| Rust      | `cargo test`                              | `cargo clippy -- -D warnings` |
| Python    | `pytest -v`                               | `ruff check .` or `flake8`    |
| Go        | `go test ./...`                           | `go vet ./...`                |
| Unknown   | skip with warning                         | —                             |

Run the test command. Analyze the output — distinguish compilation failures, test failures, and flaky tests.

Run the lint command if available. Report lint errors but do not block on them unless the project's `CLAUDE.md` requires it.

If tests fail:

1. Show the failure output clearly
2. Ask the user: "Fix failures now or continue to PR anyway?"
3. On "fix now": wait for the user to make changes, then re-run the tests
4. On "continue": note the failures in results and proceed

---

## iOS — XcodeBuildMCP (conditional)

Run only when `primary_platform == "ios"` AND `xcodebuildmcp_available == true` in platform context.

Discover the Xcode project, configure the session, build and run on the simulator. Non-blocking — continue with a warning on failure, do not block the PR phase.

---

## Test-Only Variant

When entering directly at the test phase (no prior implement phase):

Identify source files that lack corresponding test files:

- iOS: `.swift` files without a matching `*Tests.swift`
- Node.js: `src/**/*.ts` without a matching `*.test.ts`
- Rust: modules without `#[cfg(test)]`
- Python: `*.py` without a matching `test_*.py`
- Go: `*.go` without a matching `*_test.go`

Ask the user which files to generate tests for before creating any.

---

## Outputs

Save `.claude/feature-state/{slug}/test-results.md` with:

- Test command run and full output summary
- Pass/fail counts
- Lint status
- Any failures with file and line references

Update checkpoint: `current_phase=test`, `phase_status=completed`.
