---
name: collect-results
description: Collect and structure pipeline results from a completed feature run. Reads logs, git diff, test output, and checkpoint state to produce a comprehensive results.json with actual data instead of placeholders.
argument-hint: <feature-id> [--worktree-path <path>] [--exit-code <n>]
---

# Collect Results

Replaces the placeholder results.json generation in `orchestrator.sh` section 3f
(~30 lines) with intelligent result collection that reads actual pipeline output.

The current shell code writes empty arrays for `files_created`, `files_modified`, etc.
This skill reads the real git state, parses test output, and classifies errors.

## When to use

- **Orchestrator**: invoked after pipeline completion to produce results.json
- **Manual**: reconstruct results for a feature that ran without the orchestrator
- **Debugging**: understand what a pipeline actually produced

---

## Inputs

| Source | How to read |
|--------|-------------|
| Feature logs | `.orchestrator/state/<feature-id>/logs/run-*.log` (latest) |
| Git diff | `git diff --stat` and `git diff --name-status` in worktree |
| Checkpoint | `<worktree>/.claude/feature-state/<feature-id>/checkpoint.json` |
| Test output | `<worktree>/test-output.log` or parsed from run log |
| PRD | `<worktree>/tasks/prd-<feature-id>/prd-seed.md` |
| Tasks | `<worktree>/tasks/prd-<feature-id>/tasks.md` |

---

## Steps

### 1. Determine feature status

Based on `--exit-code`:
- `0` → `completed`
- `10` → `paused` (supervised mode)
- Other → `failed`

### 2. Collect file changes from git

```bash
cd "$WT_PATH"

# Files created (new, untracked or added)
git diff --name-status --diff-filter=A HEAD~1 2>/dev/null || git status --porcelain | grep '^A'

# Files modified
git diff --name-status --diff-filter=M HEAD~1 2>/dev/null || git status --porcelain | grep '^M'
```

Classify into `files_created` and `files_modified` arrays.

### 3. Detect schema changes

Scan changed files for migration patterns:

```bash
# Look for migration files
git diff --name-only HEAD~1 | grep -iE '(migration|schema|\.sql)' 2>/dev/null

# Look for schema-changing statements in diffs
git diff HEAD~1 | grep -iE '(CREATE TABLE|ALTER TABLE|DROP TABLE|ADD COLUMN|DROP COLUMN)' 2>/dev/null
```

### 4. Detect new dependencies

```bash
# package.json changes
git diff HEAD~1 -- package.json | grep '^+.*"[^"]+":' | grep -v '"name"\|"version"\|"description"'

# requirements.txt additions
git diff HEAD~1 -- requirements.txt | grep '^+[^+]'

# Cargo.toml additions
git diff HEAD~1 -- Cargo.toml | grep '^+.*='
```

### 5. Detect breaking changes

Scan diffs for breaking change indicators:

- Removed or renamed exports
- Changed function signatures (parameter count/types)
- Removed API endpoints
- Changed response schemas

This is a best-effort heuristic. The `/safety-check` skill does deeper analysis.

### 6. Parse test output

Look for test results in logs:

```bash
# Jest/Vitest
grep -E '(Tests?:|test suites?:).*passed.*failed' "$LOG_FILE"

# pytest
grep -E '(passed|failed|error)' "$LOG_FILE" | tail -5

# Generic: count "PASS" and "FAIL" lines
```

Extract `passed` and `failed` counts.

### 7. Read checkpoint for pipeline phase status

```bash
cat "$WT_PATH/.claude/feature-state/$FEATURE_ID/checkpoint.json" 2>/dev/null
```

Map checkpoint phases to pipeline status:
- Phase 0 (inputs-gate) → prd completed
- Phase 1 (analysis-planning) → techspec completed
- Phase 2 (implementation) → implementation completed
- Phase 3 (tests-validation) → tests completed
- Phase 4 (commit-pr) → review completed

### 8. Parse errors from logs

```bash
# Extract error lines from log
grep -iE '(error|fatal|exception|failed|panic)' "$LOG_FILE" | head -10
```

Classify each error:
- `build-error`: compilation/transpilation failures
- `test-failure`: test assertion failures
- `lint-error`: linter/formatter violations
- `runtime-error`: uncaught exceptions, crashes
- `dependency-error`: missing modules, version conflicts

---

## Output: results.json (v2 schema)

```json
{
  "feature_id": "feat-001",
  "status": "completed",
  "title": "JWT Authentication Middleware",
  "pipeline": {
    "prd": { "status": "completed", "file": "tasks/prd-feat-001/prd-seed.md" },
    "techspec": { "status": "completed", "file": "tasks/prd-feat-001/techspec.md" },
    "tasks": { "status": "completed", "total": 6, "completed": 6 },
    "implementation": { "status": "completed", "files_changed": 12 },
    "tests": { "status": "completed", "passed": 8, "failed": 0 },
    "review": { "status": "pending", "pr_url": null }
  },
  "context_generated": {
    "files_created": [
      "src/middleware/auth.ts",
      "src/middleware/auth.test.ts",
      "src/types/auth.ts"
    ],
    "files_modified": [
      "src/app.ts",
      "src/routes/index.ts",
      "package.json",
      "package-lock.json"
    ],
    "schema_changes": [],
    "new_dependencies": [
      "jsonwebtoken@9.0.2",
      "@types/jsonwebtoken@9.0.5"
    ],
    "breaking_changes": []
  },
  "pr_url": null,
  "duration_seconds": 45,
  "errors": []
}
```

---

## Comparison with shell-only approach

| Field | Shell (orchestrator.sh 3f) | Skill (collect-results) |
|-------|---------------------------|------------------------|
| files_created | `[]` (empty) | Parsed from `git diff --name-status` |
| files_modified | `[]` (empty) | Parsed from `git diff --name-status` |
| schema_changes | `[]` (empty) | Detected from migration files + SQL in diffs |
| new_dependencies | `[]` (empty) | Parsed from package.json/requirements.txt diffs |
| breaking_changes | `[]` (empty) | Heuristic detection from removed exports/signatures |
| tests.passed/failed | `0/0` | Parsed from test output in logs |
| tasks.total/completed | `0/0` | Counted from tasks.md checkbox state |
| pipeline phases | All `pending` except prd | Read from checkpoint.json |

---

## Error handling

- Worktree doesn't exist: "Worktree not found. Provide --worktree-path."
- No git history: Fall back to `git status --porcelain` for file lists.
- No checkpoint: Mark all pipeline phases as `unknown`.
- No test output: Leave `tests.passed` and `tests.failed` as `null`.
- Log file missing: Write results with empty errors array and note the gap.
