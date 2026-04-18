---
name: kb-learn
description: Teach the knowledge base a new error pattern, prevention strategy, or behavioral rule. Use after discovering a failure, or to manually add institutional knowledge. Can learn from QA reports, manual input, or interactively.
argument-hint: [--from-qa <feature-id>] [--pattern "error text"] [--category <cat>] [--teach "prevention advice"]
---

# Knowledge Base Learn

Record new error patterns, resolutions, and prevention strategies into the
orchestrator's structured knowledge base. Patterns that recur automatically
generate behavioral rules that are injected into future feature contexts.

## When to use

- After a feature fails: record the root cause and prevention
- After a QA agent produces analysis: persist findings into the knowledge base
- Proactively: teach known anti-patterns from team experience
- After debugging: record what you learned so the system avoids this next time

---

## Mode 1: Learn from QA Report

**Invocation**: `/kb-learn --from-qa feat-001`

### Steps

1. Read `.orchestrator/state/feat-001/qa-report.json`
2. Extract fields:
   - `root_cause.category` → pattern category
   - `root_cause.signature` → error signature
   - `remediation` → resolution text
   - `prevention` → prevention strategy
3. Invoke `kb_record_pattern` via shell:
   ```bash
   source scripts/lib/knowledge.sh
   kb_record_pattern "feat-001" "$category" "$signature" "$resolution" "$prevention"
   ```
4. Invoke `kb_derive_rules` to check if new rules should be generated
5. Report what was learned:

```
## Learned from feat-001 QA Report

| Field | Value |
|-------|-------|
| Category | missing-dependency |
| Signature | Cannot find module 'express-rate-limit' |
| Resolution | Install express-rate-limit before importing |
| Prevention | Scan techspec for new deps, install in Phase 1 |

Pattern recorded as err-007 (frequency: 1)
```

If the pattern already exists, show the frequency increment instead:

```
Pattern err-003 updated (frequency: 3 → 4, added feat-001 to affected features)
```

If a new rule was derived:

```
🆕 New behavioral rule derived!
  rule-004: missing-dependency (freq ≥ 2)
  → "Scan techspec for new deps, install in Phase 1"
  This rule will be injected into all future feature contexts.
```

### Error handling

- QA report doesn't exist: "No QA report found for feat-001. Run the QA agent first, or use `/kb-learn --pattern` to record manually."
- QA report missing root_cause: "QA report exists but has no root_cause. Use `/kb-learn --pattern` to record manually."

---

## Mode 2: Manual Pattern

**Invocation**: `/kb-learn --pattern "CORS error on /api/connect" --category "config-error" --teach "Add CORS middleware before route registration"`

### Steps

1. Validate the category against known categories in the knowledge base
   - If the category is new, confirm: "Category 'config-error' is new. Create it? [y/n]"
   - If it looks like a typo of an existing category, suggest: "Did you mean 'configuration-error'?"
2. Record the pattern:
   ```bash
   source scripts/lib/knowledge.sh
   kb_record_pattern "manual" "$category" "$pattern" "" "$teach"
   ```
3. Derive rules
4. Confirm:

```
✅ Learned: "CORS error on /api/connect"
  Category: config-error
  Prevention: Add CORS middleware before route registration
  Pattern ID: err-008
```

### Required fields

- `--pattern` is required (the error signature to match)
- `--category` is required (used for grouping and rule derivation)
- `--teach` is optional but recommended (the prevention strategy)

---

## Mode 3: Interactive

**Invocation**: `/kb-learn` (no arguments)

### Conversation flow

1. Ask: "What error or issue did you encounter? Paste the error message or describe the problem."
2. Ask: "What category does this belong to?"
   - Show existing categories with counts:
     ```
     Existing categories: missing-dependency (4), test-failure (3), config-error (2), type-error (2)
     Or enter a new category name:
     ```
3. Ask: "How should this be prevented in future features? (optional — press Enter to skip)"
4. If a resolution is known, ask: "What's the fix when this occurs? (optional)"
5. Record, derive rules, confirm

---

## Integration points

### Used by orchestrator feedback loop

In `scripts/orchestrator.sh` section 3i, when a Claude session is available:

```bash
if [ -n "${CLAUDE_SESSION:-}" ]; then
  claude --skill kb-learn "--from-qa $FEATURE_ID"
else
  # Shell-only fallback
  kb_record_pattern "$FEATURE_ID" "$cat" "$sig" "$res" "$prev"
  kb_derive_rules
fi
```

### Used by QA agent

After `qa_analyze_failure` produces a report, the orchestrator invokes `/kb-learn --from-qa`
to persist findings. The QA agent itself does NOT call this skill — the orchestrator does,
keeping the QA agent stateless.

### Used by feature-marker agent

During implementation, if the agent encounters a new error pattern not in the knowledge base,
it can call `/kb-learn` to record it before retrying.

---

## Storage details

All data is stored in `.orchestrator/knowledge-base.json` via the shell functions in
`scripts/lib/knowledge.sh`. This skill is an interactive layer on top of those functions —
it does not bypass them or use a separate storage mechanism.

Pattern IDs are auto-generated as `err-NNN` (zero-padded, monotonically increasing).
Rule IDs are auto-generated as `rule-NNN` by `kb_derive_rules`.
