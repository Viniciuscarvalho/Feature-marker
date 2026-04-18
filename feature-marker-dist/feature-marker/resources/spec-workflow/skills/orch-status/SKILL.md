---
name: orch-status
description: Display orchestration status, per-feature progress, and benchmark metrics. Shows current run status, detailed feature info, or historical trends. Use to check what the orchestrator has done, what's pending, and what failed.
argument-hint: [--format=<terminal|json|md>] [--feature <id>] [--history]
---

# Orchestration Status

Interactive status dashboard for the orchestrator. Reads `.orchestrator/state/`
to display per-feature progress, aggregated metrics, and knowledge base health.

Replaces the inline summary generation in `orchestrator.sh` Steps 5-6 (~60 lines)
with a richer, independently-invokable skill.

## When to use

- **During a run**: check progress of active features
- **After a run**: review what succeeded, failed, or needs attention
- **Maintenance**: review historical trends and knowledge base health
- **Debugging**: drill into a specific feature's failure details

---

## Mode 1: Overview (default)

**Invocation**: `/orch-status`

### Steps

1. Scan `.orchestrator/state/*/status.json` for all feature states
2. Read `.orchestrator/status.json` for aggregated state (if available)
3. Read `.orchestrator/knowledge-base.json` for pattern/rule counts
4. Format as table:

```
## Orchestration Status

| Feature | Status | Phase | Duration | QA | Review |
|---------|--------|-------|----------|-----|--------|
| feat-001 | ✅ pr-created | complete | 45s | pass | pass |
| feat-003 | 🔄 in-progress | implementation | 12s | — | — |
| feat-005 | ❌ failed | testing | 30s | fail (retry 1/2) | — |
| feat-007 | ⏸ blocked | — | — | — | — |

**Summary**: 1 done, 1 in-progress, 1 failed, 1 blocked
**Total time**: 87s | **Avg per feature**: 29s
**Knowledge base**: 5 patterns, 2 active rules

💡 `/orch-status --feature feat-005` for failure details
💡 `/kb-query` to search error patterns
```

### Status icons

| Status | Icon |
|--------|------|
| done, pr-created, cleaned | ✅ |
| in-progress, retrying | 🔄 |
| failed | ❌ |
| paused, blocked | ⏸ |
| ready, pending | ⏳ |

---

## Mode 2: Feature Detail

**Invocation**: `/orch-status --feature feat-005`

### Steps

1. Read `.orchestrator/state/feat-005/status.json`
2. Read `.orchestrator/state/feat-005/results.json` (if exists)
3. Read `.orchestrator/state/feat-005/qa-report.json` (if exists)
4. Read `.orchestrator/state/feat-005/review-report.json` (if exists)
5. Read `.orchestrator/state/feat-005/logs/` for latest log
6. Format detailed view:

```
## feat-005: Rate limiting middleware

| Field | Value |
|-------|-------|
| Status | ❌ failed |
| Phase | testing |
| Duration | 30s |
| Retries | 1/2 |
| Worktree | .worktrees/feat-005 |

### Last Error
```
TypeError: rateLimit is not a function
    at Object.<anonymous> (src/middleware/rate-limit.ts:1:1)
```

### QA Analysis
- Root cause: missing-dependency (confidence: 0.8)
- Signature: Cannot find module 'express-rate-limit'
- Remediation: Install express-rate-limit before importing
- Should retry: yes

### Pipeline Progress
| Phase | Status |
|-------|--------|
| PRD | ✅ completed |
| TechSpec | ✅ completed |
| Tasks | ✅ completed (6/6) |
| Implementation | ✅ completed (8 files) |
| Tests | ❌ failed |
| Review | — |

### Files Changed
- Created: src/middleware/rate-limit.ts, src/middleware/rate-limit.test.ts
- Modified: src/app.ts, package.json

💡 `/kb-learn --from-qa feat-005` to teach this failure pattern
💡 `/kb-query "express-rate-limit"` to check if this is a known issue
```

---

## Mode 3: History

**Invocation**: `/orch-status --history`

### Steps

1. Scan `.orchestrator/state/` for all features with timestamps
2. Group by run date (from status.json timestamps)
3. Aggregate metrics per run:

```
## Run History

| Run | Date | Features | Succeeded | Failed | Retried | Avg Time |
|-----|------|----------|-----------|--------|---------|----------|
| latest | 2026-04-18 | 5 | 4 | 1 | 1 | 32s |
| prev | 2026-04-17 | 3 | 3 | 0 | 0 | 28s |
| 2 runs ago | 2026-04-16 | 4 | 2 | 2 | 2 | 45s |

**Trends**:
- Success rate: 75% → 100% → 80% (last 3 runs)
- Avg time improving: 45s → 28s → 32s
- Most common failure: missing-dependency (3 occurrences)

**Knowledge base growth**:
- Patterns: 3 → 5 → 8
- Active rules: 1 → 2 → 3
```

---

## Mode 4: JSON Output

**Invocation**: `/orch-status --format=json`

Raw JSON for programmatic consumption:

```json
{
  "timestamp": "2026-04-18T14:30:00Z",
  "features": [
    { "id": "feat-001", "status": "pr-created", "phase": "complete", "duration": 45 },
    { "id": "feat-005", "status": "failed", "phase": "testing", "duration": 30 }
  ],
  "summary": {
    "total": 4,
    "succeeded": 3,
    "failed": 1,
    "retried": 1,
    "blocked": 0,
    "total_duration": 87,
    "avg_duration": 29
  },
  "knowledge_base": {
    "patterns": 8,
    "active_rules": 3,
    "disabled_rules": 1
  }
}
```

---

## Mode 5: Markdown Export

**Invocation**: `/orch-status --format=md`

Full markdown report suitable for PR descriptions or documentation:

```markdown
## Orchestration Report — 2026-04-18

### Features Processed
1. **feat-001**: JWT Authentication — ✅ PR created
2. **feat-003**: Rate Limiting — ✅ PR created
3. **feat-005**: WebSocket Support — ❌ Failed (missing-dependency)

### Metrics
- Total duration: 87s
- Success rate: 67%
- Retries: 1

### Knowledge Base
- 8 patterns recorded
- 3 active rules
- Most common: missing-dependency (3x)
```

---

## Data sources

All data is read from the `.orchestrator/` directory:

```
.orchestrator/
├── state/
│   ├── feat-001/
│   │   ├── status.json          # { status, phase, updated_at }
│   │   ├── results.json         # Pipeline results (v2 schema)
│   │   ├── qa-report.json       # QA analysis (if run)
│   │   ├── review-report.json   # Code review (if run)
│   │   ├── retry-count          # Number of retries
│   │   └── logs/
│   │       ├── run-*.log        # Pipeline execution logs
│   │       └── phases.log       # Phase transition log
│   └── feat-005/
│       └── ...
├── status.json                  # Aggregated status
├── knowledge-base.json          # Error patterns
└── behavioral-rules.json        # Derived rules
```

---

## Error handling

- No state directory: "No orchestrator state found. Run the orchestrator first."
- State directory empty: "No features have been processed yet."
- Feature not found: "Feature '<id>' not found in state. Available: feat-001, feat-003, feat-005"
- Corrupted JSON: Skip the file, note it as "unreadable" in the output.
