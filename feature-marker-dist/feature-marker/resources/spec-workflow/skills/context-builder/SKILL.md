---
name: context-builder
description: Build the execution context for a feature pipeline run. Assembles feature metadata, cross-feature context, behavioral rules from the knowledge base, and task routing hints into a single context file.
argument-hint: <feature-id> [--worktree-path <path>] [--include-routing] [--include-rules]
---

# Context Builder

Assembles all context needed for a feature pipeline run into a single file.
Replaces the inline context-building logic in `orchestrator.sh` section 3d
(~40 lines of bash/heredoc) with a skill that can be tested independently
and produces richer, better-structured context.

## When to use

- **Orchestrator**: invoked before each pipeline run to prepare `.orchestrator-context.md`
- **Manual**: build context for a feature you want to run outside the orchestrator
- **Debugging**: inspect what context a feature would receive without running the pipeline

---

## Inputs

| Source | Location | Content |
|--------|----------|---------|
| Feature metadata | `orchestration-backlog.json` or arguments | ID, title, priority, labels, deps, body |
| Cross-feature context | `.orchestrator/global-context.md` | Summaries from prior completed features |
| Behavioral rules | `.orchestrator/behavioral-rules.json` | Rules derived from error patterns |
| Task routing hints | `route-tasks.sh --context-mode` output | Agent recommendations per task |
| Environment manifest | `.orchestrator/environment.manifest.json` | Available runtimes and tools |

---

## Steps

### 1. Resolve feature metadata

Read from `orchestration-backlog.json` (filtered by feature ID) or from arguments:

```bash
node -e "
  const bl = JSON.parse(require('fs').readFileSync('.orchestrator/orchestration-backlog.json','utf-8'));
  const feat = bl.find(f => f.id === '$FEATURE_ID');
  if (feat) console.log(JSON.stringify(feat));
" 2>/dev/null
```

If the backlog file doesn't exist, use the arguments passed via `--title`, `--body`, etc.

### 2. Write feature section

```markdown
# <Feature Title>

## Source
- ID: <feature-id>
- Priority: <priority>
- Labels: <labels>
- Dependencies: <deps>
- From: orchestrator backlog (<adapter>)

## Description
<feature body>
```

### 3. Append cross-feature context

Read `.orchestrator/global-context.md` and append under `## Cross-Feature Context`.
If the file doesn't exist, write "No prior context available."

### 4. Append behavioral rules (if `--include-rules`)

Invoke `kb_apply_rules` or read `.orchestrator/behavioral-rules.json` directly:

```bash
source scripts/lib/knowledge.sh
kb_apply_rules "$CONTEXT_FILE"
```

Only include active rules (skip rules with `disabled: true`).
Format as actionable instructions, not just warnings.

### 5. Append routing hints (if `--include-routing`)

Run task routing in context mode:

```bash
bash scripts/route-tasks.sh --context-mode "$WT_PATH" \
  "$CONFIG_DIR/agent-manifest.json" "$TASK_DIR/tasks.md"
```

Appended as:

```markdown
## Task Routing Hints
The orchestrator recommends these agent approaches for tasks:
- Task 1: Setup database schema → approach: feature-marker (score: 85)
- Task 2: Write migration scripts → approach: feature-marker (score: 72)
```

### 6. Append environment summary

If `.orchestrator/environment.manifest.json` exists, add a compact summary:

```markdown
## Environment
- Node: v20.11.0 | npm: 10.2.4 | git: 2.43.0
- Package manager: npm
- Project: package.json detected
```

### 7. Write output files

1. `$STATE_DIR/$FEATURE_ID/context.md` — canonical context file
2. `$WT_PATH/.orchestrator-context.md` — copy for the worktree

### 8. Report summary

```
Context built for <feature-id>:
- Sections: 4 (metadata, cross-feature, rules, routing)
- Rules injected: 2 active (1 disabled, skipped)
- Routing hints: 6 tasks routed
- File: .orchestrator/state/<feature-id>/context.md
```

---

## Output: context.md structure

```markdown
# Feature Title

## Source
- ID: feat-001
- Priority: high
- Labels: backend, auth
- Dependencies: none

## Description
Implement JWT authentication middleware...

## Cross-Feature Context
### feat-000: Project setup (completed)
- Created: src/app.ts, package.json
- Stack: Express + TypeScript

## Behavioral Rules (derived from past errors)
1. **missing-dependency** (seen 5x): Scan imports and install missing packages before implementing
2. **test-failure** (seen 3x): Run tests before committing

## Task Routing Hints
- Task 1: Create auth middleware → approach: feature-marker (score: 90)
- Task 2: Add JWT validation → approach: feature-marker (score: 85)

## Environment
- Node: v20.11.0 | npm: 10.2.4 | git: 2.43.0
```

---

## Error handling

- Missing backlog: "Backlog file not found. Provide feature metadata via arguments."
- Missing worktree: "Worktree path does not exist. Create it first or pass --worktree-path."
- No rules available: Skip the rules section silently (not an error).
- No routing available: Skip the routing section silently.

---

## Testing

```bash
# Create mock data
echo '{"patterns":[],"rules":[]}' > .orchestrator/knowledge-base.json
echo "# Prior context" > .orchestrator/global-context.md

# Run skill directly
claude --skill context-builder "feat-test --worktree-path /tmp/test-wt --include-rules"

# Verify output
cat /tmp/test-wt/.orchestrator-context.md
```
