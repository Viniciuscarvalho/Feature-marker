---
name: kb-query
description: Search the orchestrator's knowledge base for learned error patterns and behavioral rules. Use when checking for known issues before implementing, or to understand what the system has learned from prior failures.
argument-hint: [search-text] [--category=<cat>] [--show-rules] [--json]
---

# Knowledge Base Query

Search the orchestrator's structured learning system for known error patterns
and behavioral rules derived from past feature runs.

## When to use

- Before implementing: check if known patterns relate to your feature's tech stack
- During debugging: search for a specific error message to find prior resolutions
- During planning: check which categories have recurring issues
- Reviewing system state: `--show-rules` to see what rules are active

## Data sources

- `.orchestrator/knowledge-base.json` — error patterns with frequency, resolution, prevention
- `.orchestrator/behavioral-rules.json` — derived rules that change orchestrator behavior

---

## Mode 1: Text Search (default)

**Invocation**: `/kb-query "Cannot find module"`

### Steps

1. Read `.orchestrator/knowledge-base.json`
2. Match patterns where `signature` contains the search text (case-insensitive substring)
3. Also match patterns where `category` contains the search text
4. Sort results by frequency (most common first)

### Output format

```
## Knowledge Base: N patterns match "search text"

| # | Category | Signature | Freq | Prevention | Features |
|---|----------|-----------|------|------------|----------|
| 1 | missing-dependency | Cannot find module express | 3 | Scan imports first | feat-001, feat-003 |
| 2 | missing-dependency | Cannot find module dotenv | 1 | Check .env setup | feat-005 |

💡 Use `/kb-learn` to teach a new prevention strategy
💡 Use `/kb-rules` to see active behavioral rules
```

If no matches: show all available categories with pattern counts so the user can refine.

---

## Mode 2: Category Filter

**Invocation**: `/kb-query --category=missing-dependency`

1. Read knowledge base
2. Filter patterns where `category` exactly matches the provided value
3. Show all patterns in that category sorted by frequency
4. If category not found, list existing categories with counts

---

## Mode 3: Show Rules

**Invocation**: `/kb-query --show-rules` or `/kb-query "module" --show-rules`

Adds a behavioral rules section to the output:

```
## Active Behavioral Rules

| Rule | Category | Freq Threshold | Instruction | Patterns |
|------|----------|----------------|-------------|----------|
| rule-001 | missing-dependency | ≥2 | Before implementing, scan imports and install missing packages | err-001, err-002 |
| rule-002 | test-failure | ≥2 | Run tests before committing | err-003, err-004 |

Rules are injected into feature context before each pipeline run.
💡 Use `/kb-rules toggle <rule-id>` to disable/enable a rule
```

---

## Mode 4: JSON Output

**Invocation**: `/kb-query "module" --json`

Output raw JSON for programmatic consumption by other skills or agents:

```json
{
  "query": "module",
  "matches": [...],
  "rules": [...],
  "total_patterns": 12,
  "total_rules": 3
}
```

---

## Mode 5: Full Summary (no search text)

**Invocation**: `/kb-query`

Show a summary of the entire knowledge base:

```
## Knowledge Base Summary

**Patterns**: 12 total across 5 categories
**Rules**: 3 active, 1 disabled

| Category | Patterns | Total Freq | Has Rule? |
|----------|----------|------------|-----------|
| missing-dependency | 4 | 8 | ✅ rule-001 |
| test-failure | 3 | 5 | ✅ rule-002 |
| config-error | 2 | 3 | ✅ rule-003 |
| type-error | 2 | 2 | ❌ (freq < threshold) |
| build-error | 1 | 1 | ❌ |

💡 Use `/kb-query --category=<name>` to drill into a category
💡 Use `/kb-learn` to teach new patterns
```

---

## Implementation

Use `Bash` to invoke the shell functions from `scripts/lib/knowledge.sh`:

```bash
# Source the library
source scripts/lib/knowledge.sh

# Query patterns
kb_query "search text"

# Get rules
kb_get_rules
```

For advanced queries not covered by the shell functions, read the JSON files directly:

```bash
cat .orchestrator/knowledge-base.json
cat .orchestrator/behavioral-rules.json
```

Parse and format the results as markdown tables for the user.

---

## Edge cases

- **Knowledge base doesn't exist**: Show "No knowledge base found. Run the orchestrator at least once, or use `/kb-learn` to create it."
- **Empty knowledge base**: Show "Knowledge base is empty — no patterns recorded yet."
- **Legacy error-patterns.json only**: Note that legacy patterns exist and suggest running `kb_init` to migrate.
