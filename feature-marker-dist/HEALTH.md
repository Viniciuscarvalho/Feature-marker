# feature-marker v7 Health Report

> **Instructions:** Run the execution recipe in `scripts/` against a throwaway repo, then fill in each section.
> See plan at `.claude/plans/i-need-to-check-curried-grove.md` for the full recipe.

---

## 1. Run Metadata

| Field               | Value                                                   |
| ------------------- | ------------------------------------------------------- |
| Date                | —                                                       |
| Fixture description | Add `--mode prd-only` flag parsing to feature-marker.sh |
| Repo SHA            | —                                                       |
| Claude Code version | —                                                       |
| Codex CLI version   | —                                                       |
| Gemini CLI version  | —                                                       |

---

## 2. Mode Matrix

Pass / Fail / Skipped / N/A per phase per mode.

| Mode        | Plan — PRD | Plan — Spec | Plan — Tasks | Implement | Test    | PR      |
| ----------- | ---------- | ----------- | ------------ | --------- | ------- | ------- |
| full        | —          | —           | —            | —         | —       | —       |
| tasks-only  | N/A        | N/A         | N/A          | —         | —       | —       |
| spec-driven | —          | —           | —            | —         | —       | —       |
| test-only   | N/A        | N/A         | N/A          | N/A       | —       | —       |
| prd-only    | —          | Skipped     | Skipped      | Skipped   | Skipped | Skipped |

---

## 3. Token Usage

Run `scripts/scrape-tokens.sh <session-id> <project-path>` for each mode.

| Mode        | Session ID | Input tokens | Output tokens | Total | Δ vs full |
| ----------- | ---------- | ------------ | ------------- | ----- | --------- |
| full        | —          | —            | —             | —     | baseline  |
| tasks-only  | —          | —            | —             | —     | —         |
| spec-driven | —          | —            | —             | —     | —         |
| test-only   | —          | —            | —             | —     | —         |
| prd-only    | —          | —            | —             | —     | —         |

**Pass criterion:** prd-only total < 50% of full total.
**Partial pass:** prd-only total between 50%–75% of full (document in §6).

---

## 4. Artifact Portability

Run `scripts/lint-artifacts.sh <mode-artifacts-dir>` for each mode.

| Mode        | Lint result                  | Leaked patterns (if any) |
| ----------- | ---------------------------- | ------------------------ |
| full        | —                            | —                        |
| tasks-only  | —                            | —                        |
| spec-driven | —                            | —                        |
| test-only   | N/A (no artifacts generated) | —                        |
| prd-only    | —                            | —                        |

---

## 5. Codex + Gemini Smoke

Artifacts used: `full` mode (only mode guaranteed to produce all three docs from one drafter run).

Invocation:

```bash
cat prd.md techspec.md tasks.md scripts/smoke-prompt.txt | codex exec -
cat prd.md techspec.md tasks.md scripts/smoke-prompt.txt | gemini -p -
```

### Codex CLI

- Version: —
- Response:

```
(paste verbatim)
```

- Result: Pass / Fail / Skipped (CLI not installed)

### Gemini CLI

- Version: —
- Response:

```
(paste verbatim)
```

- Result: Pass / Fail / Skipped (CLI not installed)

**Pass criterion:** both runtimes return exactly three numbered lines matching `tasks.md`'s top-level task order.

---

## 6. Known Gaps

<!-- Add any failures, partial passes, or observed regressions here. -->

- [ ] Ralph-Loop option removed from menu (option 3 dropped; would require restoring agent mode table to re-enable).
- [ ] Spec-driven lazy install requires `~/.claude/skills/feature-marker/resources/spec-workflow/skills/` to exist — pre-flight before running mode #3.
- [ ] JSONL schema for session transcripts is undocumented — scraper fails loudly if shape changes.
