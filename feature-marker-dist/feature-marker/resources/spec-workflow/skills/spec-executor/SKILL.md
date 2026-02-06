---
name: spec-executor
description: Execute implementation specs with batched checkpoints. Follows specs exactly, stops on blockers, supports parallelization.
argument-hint: <spec-file> [--batch-size=<n>] [--no-checkpoint] [--dry-run] [--resume]
---

# Spec Executor

Executes implementation specs (typically created by the spec-writer skill). Follows specs exactly with batched execution, checkpoints for user feedback, and parallelization support.

## Arguments

- `spec-file` (required): Path to the spec file to execute
- `--batch-size=<n>`: Steps per checkpoint (overrides config)
- `--no-checkpoint`: Run without pausing for checkpoints
- `--dry-run`: Show what would be done without making changes
- `--resume`: Resume from last checkpoint
- `--parallel=<true|false>`: Enable/disable parallelization

## Configuration

Check for `.claude/spec-workflow/config.yaml`:

```yaml
paths:
  worktrees: "./worktrees"

services:
  backend:
    path: "./backend"
    build: "npm run build"
    test: "npm test"
    lint: "npm run lint"
  frontend:
    path: "./frontend"
    build: "npm run build"
    test: "npm test"

execution:
  batchSize: 5
  checkpoint:
    behavior: "smart"           # "pause" | "continue" | "smart"
  parallel:
    enabled: true
    maxAgents: 3
```

If no config, auto-detect services and use defaults.

## Core Philosophy

**Follow the spec. Stop on blockers. Never guess.**

This skill prioritizes:

1. **Spec-driven execution** - Follow spec instructions exactly, don't improvise
2. **Stop on blockers** - Pause and ask rather than guess when something is unclear
3. **Parallelization-aware** - Use sub-agents for concurrent work when spec indicates
4. **Leveraging git worktrees** - Isolate spec work in dedicated worktrees

---

## Phase 1: Environment Setup

Before executing, verify the environment is ready:

### Check for worktree (if specified in spec)

If spec frontmatter contains `worktree`:

1. Verify worktree exists at configured path (default: `./worktrees/[name]`)
2. Ensure we're working in that worktree
3. Verify branch matches frontmatter

If worktree doesn't exist:

1. Notify user: "Spec references worktree that doesn't exist. Create it?"
2. If yes, invoke `/create-worktree [name] --spec=[spec-path]`
3. Continue once created

### If no worktree specified

Proceed in current directory, but warn user that changes won't be isolated.

---

## Phase 2: Load & Review

1. **Read the full spec file**

2. **Parse the spec**
   - Extract Implementation Steps table
   - Identify parallelization groups (if present)
   - Note any Open Questions or unresolved items
   - Check spec status

3. **Review critically before starting**

   Present a summary:
   ```
   **Spec Review: [Feature Name]**

   **Tasks:** [N] implementation steps
   **Parallelization:** [Yes/No - describe groups if present]
   **Dependencies:** [List any external dependencies]
   **Estimated scope:** [Small/Medium/Large based on task count]

   **Concerns before starting:**
   - [Any unclear instructions]
   - [Any unresolved Open Questions from spec]
   - [Any missing information]

   **Parallelization Plan:**
   [Describe how tasks will be parallelized if applicable]

   Ready to proceed?
   ```

If `--dry-run`, stop here after showing the plan.

---

## Phase 3: Execute Batch

### Task Execution

For each task in the current batch:

1. **Mark task in_progress** in todo list
2. **Read related files** mentioned in spec's Appendix
3. **Execute the task** following spec instructions exactly
4. **Run verification** if specified (tests, lint, build)
5. **Mark task completed**

### Parallelization

If spec includes a Sub-agent Parallelization Plan:

1. **Identify independent tasks** in current group
2. **Launch sub-agents** using Task tool for parallel execution
3. **Wait for all agents** to complete before proceeding
4. **Collect results** and verify all succeeded

```
Launching parallel execution for Group 1:

Agent 1: Task 1.1 - [Description]
Agent 2: Task 1.2 - [Description]

Waiting for completion...
```

Respect `execution.parallel.maxAgents` from config.

### Following the Spec

**DO:**
- Follow Implementation Steps in order (respecting dependencies)
- Use patterns described in Architecture & Design section
- Implement exactly what's specified in Requirements
- Run verifications specified in Validation & Testing Plan

**DON'T:**
- Add features not in the spec
- Skip steps or combine tasks arbitrarily
- Ignore the spec's design decisions
- Proceed past blockers without asking

---

## Phase 4: Report & Checkpoint

After each batch (based on `batchSize`):

```
**Checkpoint: Batch [N] Complete**

**Completed tasks:**
- [x] Task 1: [Brief description of what was done]
- [x] Task 2: [Brief description of what was done]

**Verification results:**
- Tests: [Pass/Fail - details]
- Lint: [Pass/Fail]
- Build: [Pass/Fail]

**Files modified:**
- `path/to/file1` - [What changed]
- `path/to/file2` - [What changed]

**Next batch:** Tasks [N+1] through [N+3]
```

Checkpoint behavior (from config or argument):
- `pause`: Always pause for user review
- `continue`: Auto-continue if no issues
- `smart`: Pause on warnings/errors, continue otherwise

---

## Phase 5: Continue

1. **Apply feedback** from previous checkpoint
2. **Execute next batch** following Phase 3 process
3. **Report progress** following Phase 4 process
4. **Repeat** until all tasks complete

---

## Phase 6: Finalize

After all tasks complete:

1. **Run full validation**

   For each service in spec's `services` frontmatter (or all configured services if not specified):

   ```
   # Use commands from config, or auto-detect
   [service.build command]
   [service.lint command]
   [service.test command]
   ```

2. **Update spec status**
   - Edit spec file frontmatter to change status to "Implemented"
   - Add completion date

3. **Final summary**
   ```
   **Spec Execution Complete: [Feature Name]**

   **Tasks completed:** [N] of [N]
   **Files modified:** [Count]
   **Tests:** [Pass/Fail]
   **Build:** [Pass/Fail]

   **Summary of changes:**
   - [High-level description of what was implemented]

   **Next steps:**
   - [ ] Manual testing per spec's Validation Plan
   - [ ] Code review
   - [ ] Commit and PR
   ```

---

## Critical Stop Points

**STOP and ask the user when:**

1. **Blockers encountered**
   - Missing dependency or file
   - Failed test that can't be fixed after several attempts
   - Unclear instruction in spec

2. **Spec gaps**
   - Implementation step references non-existent file
   - Missing information needed to proceed
   - Conflicting instructions

3. **Scope questions**
   - Discovering additional work not in spec
   - Edge cases not covered by spec

### Stop Format

```
**Execution Paused: [Reason]**

**Context:** [What I was trying to do]
**Issue:** [What went wrong or is unclear]
**Question:** [Specific question for user]

Options:
A) [Suggested resolution 1]
B) [Suggested resolution 2]
C) Skip this task and continue
D) Stop execution entirely

How should I proceed?
```

---

## Progress Tracking

### Managing TODOs

Mirror spec's Implementation Steps in todo list:

```
Todos:
- [x] Step 1: [Task from spec]
- [x] Step 2: [Task from spec]
- [ ] Step 3: [Task from spec] (in_progress)
- [ ] Step 4: [Task from spec] (pending)
```

### Spec File Updates

Update checkboxes in spec's Validation & Testing Plan as tests are written/pass.

---

## Workflow Summary

```
spec-file
     │
     ▼
┌─────────────────────────────────┐
│ PHASE 1: ENVIRONMENT SETUP      │
│ • Check/create worktree         │
│ • Verify environment ready      │
└─────────────────────────────────┘
     │
     ▼
┌─────────────────────────────────┐
│ PHASE 2: LOAD & REVIEW          │
│ • Parse spec                    │
│ • Flag concerns                 │
│ • Confirm ready to proceed      │
└─────────────────────────────────┘
     │
     ▼
┌─────────────────────────────────┐
│ PHASE 3: EXECUTE BATCH          │
│ • Follow spec exactly           │
│ • Use sub-agents if parallel    │
│ • Track tasks                   │
└─────────────────────────────────┘
     │
     ▼
┌─────────────────────────────────┐
│ PHASE 4: CHECKPOINT             │
│ • Report progress               │
│ • Show verification results     │
└─────────────────────────────────┘
     │
     ▼
┌─────────────────────────────────┐
│ PHASE 5: CONTINUE               │
│ • Next batch → Phase 3          │
└─────────────────────────────────┘
     │
     ▼
┌─────────────────────────────────┐
│ PHASE 6: FINALIZE               │
│ • Full validation               │
│ • Update spec status            │
│ • Summary & next steps          │
└─────────────────────────────────┘
     │
     ▼
   Feature Implemented
```

---

## Upon Implementation Completion

1. Ask the user if they would like to commit the changes now.
2. If yes, create a commit with a summary of changes made.
3. If committed, ask if they would like to open a PR for review.
4. If yes, create a PR with appropriate title and description.
