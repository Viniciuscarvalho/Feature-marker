# ADR-008: Orchestrator Token-Economy, Block-Based Routing, Layered Learning, and Hard-Blocked Dependencies

- **Status:** Proposed
- **Date:** 2026-04-18
- **Supersedes / extends:** ADR-002 (Memory), ADR-003 (Preprocessing, deferred), ADR-006 (Agent Discovery and Task Routing)
- **Scope:** CLI orchestrator (`scripts/orchestrate.sh` and modules under `scripts/lib/`). The in-Claude `/feature-marker` skill is unchanged.

---

## Context

The orchestrator currently invokes `claude --skill feature-marker` once per feature in `full_auto` mode. For every phase (Inputs Gate, Planning, Implementation, Tests, Commit & PR), the full feature-marker agent runs. On large backlogs this has four observable problems:

1. **Token cost scales linearly with backlog size.** Even deterministic phases — reading existing artifacts, running tests, committing — consume Claude tokens because they flow through the agent.
2. **Routing is generic.** Phase 2 (Implementation) does not differentiate between an iOS task and a Node task; the same agent handles both, reducing specialization and accuracy.
3. **Errors are not retained.** `memory.error_pattern_window: 5` exists in `orchestrator/config.yml` but resets per-run. QA/review findings do not persist beyond the feature.
4. **Dependencies between features are parsed but not enforced.** `Depends on: feat-001` in `features.md` is recognized by the adapter but the orchestrator does not verify parent PR state before running a dependent feature — which risks merge conflicts and stacked drift.

The orchestrator needs a more economical, block-based, learning-aware, and dependency-aware execution model. The checkpoint model must also expose these properties so cost and state are observable.

## Decision

Adopt the following eight design choices, agreed via interview on 2026-04-18:

### 1. Phase 0 (Inputs Gate) — script-deterministic retrieval, Claude only for generation

`scripts/lib/runner.sh` reads `tasks/prd-{slug}/{prd,techspec,tasks}.md` directly. Claude is only invoked to run `/create-prd`, `/generate-spec`, `/generate-tasks` for artifacts that are genuinely missing. Existing artifacts no longer pay a token cost.

### 2. Phase 3 (Tests & Validation) — script-first, Claude only on failure

The orchestrator runs the stack-appropriate test command (`swift test`, `jest`, `cargo test`, `pytest`, `go test`) as a pure shell step. On failure, the orchestrator invokes Claude for a fix attempt. **Maximum 2 fix attempts per task.** After two failed attempts, the phase pauses for human review regardless of autonomy level.

### 3. Phase 2 (Implementation) — block-based routing via stack detection

Each task is routed to a specialized agent based on detected stack:

| Detected stack    | Agent                          |
| ----------------- | ------------------------------ |
| iOS / Swift       | `swift-expert`                 |
| Node / TypeScript | `typescript-pro`               |
| Python            | `python-pro` (when available)  |
| Rust              | `rust-expert` (when available) |
| Go                | `go-expert` (when available)   |

### 4. Multi-stack repos — detect primary stack per task by file path

When a repo contains more than one stack (e.g., `web/` in TypeScript + `api/` in Python), stack detection runs **per task** by inspecting the file paths the task will touch. Each task routes independently. The orchestrator caches the per-path mapping in `.orchestrator/stack-map.json` for the duration of a run.

### 5. Missing specialist — fall back to generic `feature-marker`

If the stack-matched agent is not installed, the orchestrator logs a warning to `.orchestrator/state/{feat-id}.log` and proceeds with the generic `feature-marker` agent. Orchestration never halts on a missing specialist; accuracy degrades gracefully.

### 6. Learning — 3-tier layered store

Error patterns, QA findings, and review outcomes persist across three tiers:

| Tier        | Location                                     | Lifetime                               |
| ----------- | -------------------------------------------- | -------------------------------------- |
| **Feature** | `.orchestrator/state/{feat-id}/learned.json` | Reset per feature                      |
| **Project** | `.claude/feature-state/learned.json`         | Survives across features in this repo  |
| **Global**  | `~/.claude/feature-marker/learned/`          | Shared across all repos on the machine |

- **Reads** walk up the stack: feature → project → global.
- **Writes** default to the **project** tier. Explicit promotion to global is a manual `feature-marker-orchestrate promote-learning <id>` step.
- Each entry has: `{ id, pattern, fix, confidence, created_at, hits, last_seen, tier }`.

### 7. Dependencies — hard block until parent PR merged to `main`

When a feature declares `Depends on: feat-001`, the orchestrator sets its state to `blocked` and refuses to run it until `feat-001`'s PR is merged to the base branch. Dependents stay in the backlog but are skipped on each run. They become `pending` automatically on the next run after the merge is detected.

### 8. Merge detection — poll git platform API before each feature run

Before starting any feature with dependencies, the orchestrator queries the platform CLI:

| Platform     | Command                                        |
| ------------ | ---------------------------------------------- |
| GitHub       | `gh pr view <parent-pr> --json state,mergedAt` |
| Azure DevOps | `az repos pr show --id <parent-pr>`            |
| GitLab       | `glab mr view <parent-pr>`                     |

Parent PR numbers are resolved from `.orchestrator/state/{parent-feat-id}.json` (written when the parent's Phase 4 completes).

---

## Revised Checkpoint Model

Each phase now exposes whether it is scripted (no Claude tokens) or Claude-driven on the happy path, plus its failure escalation.

| Phase                   | Happy-path engine                                  | Token cost                                                    | On failure                                 | Autonomy pauses                                                                              |
| ----------------------- | -------------------------------------------------- | ------------------------------------------------------------- | ------------------------------------------ | -------------------------------------------------------------------------------------------- |
| 0 — Inputs Gate         | Script reads artifacts                             | **Low** (generation only if missing)                          | Skill auto-installs, then retry            | `supervised`: after each generated artifact                                                  |
| 1 — Analysis & Planning | Claude (Opus via `opusplan`)                       | **Full**                                                      | Regenerate plan once, then pause           | `supervised`: before Phase 2                                                                 |
| 2 — Implementation      | Claude (stack-matched specialist, scoped per task) | **Scoped** (one specialist per task, not full feature-marker) | Agent retries 1x, then escalate            | `supervised`: after each task; `full_auto`: on breaking change or >`safety.max_file_changes` |
| 3 — Tests & Validation  | Script runs test/lint                              | **Zero** on pass                                              | Claude diagnosis + fix, **max 2 attempts** | Always pauses after 2 failed attempts                                                        |
| 4 — Commit & PR         | Claude (`/commit` + PR template)                   | Full                                                          | Retry once, then pause                     | `checkpoint`: human reviews PR; `full_auto`: auto-merge after CI                             |

Checkpoint records (`.claude/feature-state/{slug}/checkpoint.json`) gain three new fields:

```json
{
  "phase": 3,
  "engine": "script",
  "token_cost_estimate": 0,
  "fix_attempts": 1,
  "routed_agent": "typescript-pro",
  "dependencies_verified": ["feat-001"]
}
```

---

## Token-Cost Model (per feature, happy path)

Rough proportional costs (full feature-marker = 1.0 baseline):

| Phase            | Current (v7.4.0) | Proposed (v8)                              |
| ---------------- | ---------------- | ------------------------------------------ |
| 0 Inputs Gate    | 0.15             | **0.00** (if artifacts exist)              |
| 1 Analysis       | 0.25             | 0.25                                       |
| 2 Implementation | 0.40             | **0.30** (scoped specialist vs full agent) |
| 3 Tests          | 0.15             | **0.00** (happy path)                      |
| 4 Commit & PR    | 0.05             | 0.05                                       |
| **Total**        | **1.00**         | **0.60**                                   |

Expected savings per feature on the happy path: **~40%**. On a 20-feature backlog with the current model that's the difference between running and exhausting a quota.

---

## Implementation Phasing

This ADR captures the design only. Implementation lands in three follow-up PRs:

1. **PR-A — Checkpoint schema + Phase 0/3 scripting**
   - Extend `checkpoint.json` schema (`engine`, `token_cost_estimate`, `fix_attempts`, `routed_agent`, `dependencies_verified`).
   - Convert Phase 0 retrieval to script (`scripts/lib/runner.sh` — new `phase_0_inputs` function that skips Claude when artifacts exist).
   - Convert Phase 3 to script-first (`scripts/lib/runner.sh` — new `phase_3_tests` with stack-detected command, Claude-on-failure with 2-retry budget).

2. **PR-B — Block-based routing + specialist fallback**
   - New `scripts/lib/router.sh` module that maps detected stack → agent name.
   - Per-task file-path stack detection; cache in `.orchestrator/stack-map.json`.
   - Graceful fallback to generic `feature-marker` when specialist is absent; log to `.orchestrator/state/{feat-id}.log`.

3. **PR-C — Layered learning + hard-block dependencies**
   - New `scripts/lib/learning.sh` module with read-walks-up, write-to-project semantics.
   - Extend `scripts/lib/runner.sh` pre-feature hook to query platform CLI for parent PR merge state.
   - Parent PR number persisted to `.orchestrator/state/{feat-id}.json` at end of Phase 4.
   - New subcommand: `feature-marker-orchestrate promote-learning <id>`.

Each follow-up PR is independently revertable and ships its own CHANGELOG entry.

---

## Consequences

### Positive

- **~40% token reduction** on the happy path for a typical feature.
- **Better accuracy per task** through stack-specialized agents.
- **Persistent learning** survives across features and optionally across projects.
- **Zero dependency drift** — merge conflicts on stacked features become impossible because dependents cannot run until the parent is merged.
- **Observable cost** — `token_cost_estimate` in the checkpoint lets users see where budget is going.

### Negative / risks

- **More moving parts.** Three new modules (`router.sh`, `learning.sh`, merge polling) add complexity to the orchestrator.
- **Platform CLI coupling.** Merge polling depends on `gh`/`az`/`glab` being authenticated. Failure mode: if the CLI is not available, the orchestrator errs on the side of caution and keeps dependents blocked.
- **Specialist availability.** Full benefit requires specialized agents to be installed. Graceful fallback preserves correctness but erodes the promised token savings.
- **Per-task routing latency.** File-path analysis per task adds milliseconds per task; negligible at scale but measurable on small features.

### Deferred / out of scope

- Automatic global-tier promotion (requires a confidence metric; manual for now).
- Pre-processing model for cheaper classification (see ADR-003 — still deferred).
- Concurrent worktree execution (`execution.max_concurrent > 1` — stays at 1 in v8; revisit in v9).
- In-Claude skill changes — the `/feature-marker` slash command retains its current behavior.

---

## Open Questions

1. Should `token_cost_estimate` be computed or measured? Computed is cheaper but approximate; measured requires wrapping `claude` invocations.
2. Should the learning store have a TTL on entries? Stale fixes for deprecated APIs could pollute suggestions.
3. On a multi-stack feature where stacks appear in roughly equal proportion, should the orchestrator split the feature into stack-scoped sub-features or run a single task with a generic agent?

These are surfaced here for discussion in the PR; they do not block this design from landing.
