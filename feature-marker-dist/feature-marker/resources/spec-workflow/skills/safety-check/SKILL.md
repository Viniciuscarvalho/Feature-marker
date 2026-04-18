---
name: safety-check
description: Analyze a feature's results.json for safety concerns — breaking changes, schema migrations, excessive file changes, and security anti-patterns. Returns a structured verdict (pass/warn/block) with reasoning.
argument-hint: <feature-id> [--strict] [--auto-approve-minor]
---

# Safety Check

Post-pipeline safety analysis that classifies risks and produces a structured
verdict. Unlike the raw shell checks in orchestrator.sh section 3g (which
blindly pause on any `breaking_changes.length > 0`), this skill reasons
about which changes are actually dangerous.

## When to use

- **Orchestrator**: invoked after pipeline completion, before PR creation
- **Manual**: review a completed feature's safety profile
- **CI**: structured JSON output for automated gates

---

## Inputs

| Source | Location |
|--------|----------|
| Results | `.orchestrator/state/<feature-id>/results.json` |
| Config | `orchestrator/config.yml` safety section |
| Git diff | `git diff` in the feature worktree |

---

## Checks

### Check 1: Breaking Changes

Read `results.json → context_generated.breaking_changes`.

**Classification** (the skill reasons about each change, not just counts):

| Change Type | Examples | Verdict |
|-------------|----------|---------|
| API signature change | Renamed parameter, removed field, changed return type | block |
| New required field | Added non-optional field to request body | block |
| New optional field | Added optional field to response | warn |
| Internal refactor | Renamed private function, moved internal module | pass |
| Type narrowing | Changed `string` to `string literal union` | warn |

With `--auto-approve-minor`: optional field additions and type narrowings auto-pass.

### Check 2: Schema Changes

Read `results.json → context_generated.schema_changes`.

| Change Type | Examples | Verdict |
|-------------|----------|---------|
| Add column/table | `ALTER TABLE ADD COLUMN`, `CREATE TABLE` | warn |
| Drop column/table | `DROP TABLE`, `ALTER TABLE DROP` | block |
| Rename | `RENAME TABLE`, `RENAME COLUMN` | block |
| Data migration | Backfill required, data transformation | block |
| Index change | `CREATE INDEX`, `DROP INDEX` | warn |

### Check 3: File Count

Read file lists from `results.json → context_generated`:
- `files_created.length + files_modified.length`
- Compare against `MAX_FILE_CHANGES` from config (default: 50)

| Condition | Verdict |
|-----------|---------|
| ≤ 80% of limit | pass |
| 80-100% of limit | warn |
| > limit | block |

### Check 4: Security Scan

If the worktree path is available, scan the git diff for anti-patterns:

```bash
git diff --cached --diff-filter=AM -- '*.ts' '*.js' '*.py' '*.go' '*.rs'
```

| Pattern | What it catches | Verdict |
|---------|-----------------|---------|
| Hardcoded secrets | `password = "..."`, `API_KEY = "..."`, `token: "sk-..."` | block |
| Dangerous eval | `eval(`, `exec(`, `Function(` with user input | block |
| SQL injection | String concatenation in SQL queries | warn |
| Missing validation | `req.body.` or `req.params.` without validation/sanitization | warn |
| Disabled security | `// eslint-disable`, `# nosec`, `@SuppressWarnings` on security rules | warn |

---

## Output

### Structured verdict

```json
{
  "feature_id": "feat-001",
  "verdict": "warn",
  "checks": [
    {
      "name": "breaking_changes",
      "status": "warn",
      "detail": "1 minor: new optional field 'avatar_url' in GET /api/users response",
      "items": [{ "type": "optional_field_added", "location": "GET /api/users response", "severity": "minor" }]
    },
    {
      "name": "schema_changes",
      "status": "pass",
      "detail": "No schema changes detected"
    },
    {
      "name": "file_count",
      "status": "pass",
      "detail": "12 files changed (limit: 50)"
    },
    {
      "name": "security_scan",
      "status": "pass",
      "detail": "No security anti-patterns detected"
    }
  ],
  "recommendation": "Proceed with PR — optional field addition is backward-compatible",
  "should_pause": false
}
```

### Human-readable summary

```
## Safety Check: feat-001

| Check | Status | Detail |
|-------|--------|--------|
| Breaking changes | ⚠️ warn | 1 minor: new optional field in API response |
| Schema changes | ✅ pass | No schema changes |
| File count | ✅ pass | 12/50 files |
| Security scan | ✅ pass | Clean |

**Verdict**: ⚠️ warn — proceed with PR (optional field is backward-compatible)
```

---

## Verdict logic

The overall verdict is the **most severe** individual check:

```
block > warn > pass
```

`should_pause` is true when:
- Any check is `block`
- `--strict` flag is set AND any check is `warn`

---

## Comparison with shell-only approach

| Aspect | Shell (orchestrator.sh 3g) | Skill (safety-check) |
|--------|---------------------------|---------------------|
| Breaking change detection | `length > 0` → pause | Classifies major vs minor |
| Schema analysis | Has migration → pause | Classifies additive vs destructive |
| Security | Not checked | Scans diff for anti-patterns |
| Output | Status update only | Structured JSON + recommendation |
| Testable | Requires full orchestrator run | Independent invocation |

---

## Error handling

- Results file missing: "No results.json found for feat-001. Run the pipeline first."
- Empty context_generated: "No context data in results.json — pipeline may not have completed."
- Git diff unavailable: Skip security scan, note in output.
