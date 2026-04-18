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

Adopt the following ten design choices. Decisions 1–8 were agreed via the 2026-04-18 design interview; decisions 9–10 and the extensions to #6 resolve the original open questions during review.

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

#### 6a. Entry schema (extended)

Each learning entry carries lifecycle and confidence fields so the store self-maintains instead of silently rotting:

```json
{
  "id": "learn-a1b2",
  "pattern": "<error signature or fingerprint>",
  "fix": "<applied fix description or diff reference>",
  "tier": "project",
  "created_at": "2026-04-18T12:00:00Z",
  "last_seen": "2026-05-02T09:30:00Z",
  "hits": 7,
  "success_count": 6,
  "failure_count": 1,
  "confidence": 0.86,
  "ttl_days": 90,
  "archived": false,
  "promotion_candidate": true
}
```

#### 6b. TTL and archival

- Default TTL: **90 days** since `last_seen`, configurable via `learning.ttl_days` in `orchestrator/config.yml`.
- `last_seen` refreshes on every hit, so actively useful entries never expire.
- Entries whose `last_seen` is older than the TTL are **archived** (moved to `{tier}/_archive/`), never hard-deleted. Archived entries are preserved for audit and for re-surfacing if the exact same pattern recurs (re-surfaced entries return with lower priority and `hits` reset).
- Feature-tier archival is a no-op — the tier resets on every feature.

#### 6c. Complete learning loop

Learning is not just capture; it must verify fixes and prune failures.

1. **Capture** — when a Phase 3 retry succeeds, the orchestrator writes `(error_signature → fix_applied)` to the project tier with `success_count: 1`.
2. **Apply** — on future runs, when a test failure matches an existing pattern, the learning module injects the known fix as a hint into Claude's fix-attempt prompt.
3. **Verify** — after the fix attempt runs, `success_count` or `failure_count` is incremented based on whether tests now pass.
4. **Prune** — entries with `confidence < 0.5` after `hits ≥ 3` are auto-archived. This removes regression-prone "fixes" that looked right the first time but don't generalize.
5. **Promote** — entries with `confidence ≥ 0.8 AND hits ≥ 5 AND tier == project` are flagged `promotion_candidate: true`. Users review the list via `feature-marker-orchestrate learning list --candidates` and promote explicitly with `promote-learning <id>`.

This closes the loop: errors become learned fixes, fixes get verified, bad ones are pruned, good ones graduate.

#### 6d. Embedding-based similarity (optional backend)

Exact-string matching on `pattern` misses fuzzy duplicates — the same underlying error expressed with different stack addresses or slightly different messages. An optional embedding backend addresses this.

- **Config key**: `learning.similarity.backend: exact | embedding` (default: `exact`, preserving current behavior).
- **Storage**: When `embedding` is active, each entry's `pattern` is embedded once at write-time. The vector is stored in a sibling file `learned.embeddings.jsonl` alongside the tier's `learned.json` — one line per entry: `{"id": "learn-a1b2", "vector": [...]}`. No external vector DB; the store stays git-friendly and auditable.
- **Retrieval**: On a new error, embed the error signature and compare against the tier's embedding file using cosine similarity. Default match threshold: `0.85`, configurable via `learning.similarity.threshold`. Both project and global tiers participate in embedding-based retrieval; the feature tier retains exact-match only (it resets per feature, so embedding cost is unwarranted).
- **Model source**: The embedding model is supplied by `local_model.embedding_model` (see ADR-009). If ADR-009's `local_model.enabled` is `false`, this backend is inactive regardless of the `learning.similarity.backend` setting.
- **Fallback**: If the embedding backend is configured but the endpoint is unreachable at runtime, retrieval silently falls back to exact match and logs a one-time warning to `.orchestrator/state/{feat-id}.log`. Orchestration is never blocked.
- **Ships in**: PR-C (same PR that delivers the learning store), gated behind config. Default `exact` means zero behavioral change for users who do not opt in.

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

### 9. Token cost — estimated (computed from config baselines), not measured

`token_cost_estimate` on each checkpoint is **computed** from per-phase baseline constants, not measured by wrapping `claude` invocations. Rationale: good-enough for budgeting, zero coupling to Claude CLI internals, no runtime overhead.

Baselines live in `orchestrator/config.yml`:

```yaml
model:
  cost_baselines:
    phase_1_planning: 25000 # rough tokens per Phase 1 run
    phase_2_per_task_specialist: 8000
    phase_2_per_task_generic: 12000 # generic feature-marker fallback costs more
    phase_4_commit_pr: 5000
    fix_attempt_overhead: 3000 # added per Phase 3 fix attempt
  # Phases 0 and 3 happy-path cost is 0 — script-only.
```

- Running total is written to the checkpoint on every phase boundary.
- Feature-level total written to `.orchestrator/state/{feat-id}.json` at Phase 4 completion.
- Re-calibration: `feature-marker-orchestrate calibrate --sample N` reads the last N completed features' actual token counts (if Claude telemetry is available) and rewrites the baselines in `config.yml`. Manual step — not run automatically.

### 10. Feature-sizing gate + cycle-completion gate — prevent oversized features and orphan state

Two guards run around Phase 2 to stop the orchestrator from silently accumulating half-done work.

#### 10a. Feature-sizing gate (before Phase 2)

After Phase 1 produces the plan, the orchestrator reads metrics off the PRD and techspec:

- Acceptance criteria count (parsed from PRD)
- Task count (from `tasks.md`)
- Estimated file-change count (from the techspec "Files to Modify" section)

Thresholds in `orchestrator/config.yml`:

```yaml
safety:
  feature_size:
    max_acceptance_criteria: 15
    max_tasks: 20
    max_file_changes_estimate: 80
```

If any threshold is exceeded, the orchestrator emits a `feature_too_large` signal:

| Autonomy     | Behavior                                                                                                                   |
| ------------ | -------------------------------------------------------------------------------------------------------------------------- |
| `supervised` | Pauses, shows which thresholds were exceeded, asks user to split or force-proceed                                          |
| `checkpoint` | Auto-splits by acceptance-criterion group or techspec section, labels sub-features as `{slug}-sub01`, `{slug}-sub02`, etc. |
| `full_auto`  | Auto-splits, same as `checkpoint`. Never silently proceeds with an oversized feature.                                      |

Sub-features inherit the parent's slug with a numbered suffix, get `parent_feature_id` in state, and enter the backlog as a dependency chain (parent feature waits on all children via Decision #7 semantics).

#### 10b. Cycle-completion gate (between features)

Before picking the next backlog feature, the orchestrator asserts the current feature has truly completed its full cycle:

- All 5 phase checkpoints marked `complete`
- Phase 4 recorded a PR URL in `.orchestrator/state/{feat-id}.json`
- `fix_attempts` counter on every task is 0 (no tasks left pending a retry)
- If the feature has sub-features (from 10a), all sub-features satisfy the above recursively

If any assertion fails: the feature stays `in_progress`, the orchestrator **halts** with a diagnostic instead of advancing to the next feature. This prevents the orphan pattern where a feature is left half-done, the next one starts, and the first one silently requires rework later.

Override: `feature-marker-orchestrate run --skip-cycle-check` is available as an escape hatch for when a feature genuinely can't finish (external blocker) but the user wants to proceed. The skipped feature stays in the backlog with an `incomplete` tag.

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

Checkpoint records (`.claude/feature-state/{slug}/checkpoint.json`) gain new fields for engine, cost, routing, learning, and size gating:

```json
{
  "phase": 3,
  "engine": "script",
  "token_cost_estimate": 0,
  "token_cost_cumulative": 33000,
  "fix_attempts": 1,
  "routed_agent": "typescript-pro",
  "dependencies_verified": ["feat-001"],
  "learning_hits": ["learn-a1b2"],
  "feature_size": {
    "acceptance_criteria": 8,
    "tasks": 12,
    "estimated_file_changes": 34,
    "within_thresholds": true
  },
  "parent_feature_id": null,
  "sub_feature_ids": []
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

This ADR captures the design only. Implementation lands in **four** follow-up PRs:

1. **PR-A — Checkpoint schema + Phase 0/3 scripting + token-cost estimator**
   - Extend `checkpoint.json` schema with every new field from the schema example above.
   - Convert Phase 0 retrieval to script (`scripts/lib/runner.sh` — new `phase_0_inputs` that skips Claude when artifacts exist).
   - Convert Phase 3 to script-first (`scripts/lib/runner.sh` — new `phase_3_tests` with stack-detected command, Claude-on-failure with 2-retry budget).
   - Add `model.cost_baselines` to `orchestrator/config.yml`; implement `scripts/lib/cost.sh` that accumulates `token_cost_estimate` and `token_cost_cumulative` on phase boundaries.
   - New subcommand: `feature-marker-orchestrate calibrate --sample N` (baseline re-calibration — manual).

2. **PR-B — Block-based routing + specialist fallback**
   - New `scripts/lib/router.sh` module that maps detected stack → agent name.
   - Per-task file-path stack detection; cache in `.orchestrator/stack-map.json`.
   - Graceful fallback to generic `feature-marker` when specialist is absent; log to `.orchestrator/state/{feat-id}.log`.

3. **PR-C — Layered learning (with TTL + complete-loop) + hard-block dependencies**
   - New `scripts/lib/learning.sh` module with read-walks-up, write-to-project semantics.
   - Implements the full entry schema including `success_count`, `failure_count`, `confidence`, `ttl_days`, `archived`, `promotion_candidate`.
   - TTL sweep runs at the start of each orchestrator run: moves expired entries to `{tier}/_archive/`.
   - Verify step runs after every Phase 3 fix attempt: increments `success_count` or `failure_count`, recomputes `confidence`, auto-archives when `confidence < 0.5 AND hits ≥ 3`.
   - New subcommands: `learning list [--candidates]`, `learning archive <id>`, `promote-learning <id>`.
   - Extend `scripts/lib/runner.sh` pre-feature hook to query platform CLI for parent PR merge state; parent PR number persisted to `.orchestrator/state/{feat-id}.json` at end of Phase 4.
   - Optional embedding backend (Decision #6d): when `learning.similarity.backend: embedding`, write-path embeds each entry's pattern and appends to `learned.embeddings.jsonl`; retrieval path computes cosine similarity against that file. Gated behind config; `exact` default preserves current behavior.

4. **PR-D — Feature-sizing gate + cycle-completion gate**
   - New `scripts/lib/size_gate.sh` module: reads PRD/techspec/tasks metrics, compares to `safety.feature_size` thresholds, emits `feature_too_large` when exceeded.
   - Auto-split logic in `checkpoint`/`full_auto`; user prompt in `supervised`.
   - New `scripts/lib/cycle_gate.sh` module: runs between features in `scripts/lib/runner.sh`'s main loop; halts orchestrator if current feature's cycle is incomplete.
   - New flag: `--skip-cycle-check` escape hatch.
   - Sub-feature chain linked via `parent_feature_id` / `sub_feature_ids` in state; reuses Decision #7 dependency semantics.

Each follow-up PR is independently revertable and ships its own CHANGELOG entry.

---

## Consequences

### Positive

- **~40% token reduction** on the happy path for a typical feature.
- **Better accuracy per task** through stack-specialized agents.
- **Self-maintaining learning store** — TTL + confidence tracking stops suggestion quality from rotting over time; bad fixes get pruned automatically, good ones graduate to global.
- **Zero dependency drift** — merge conflicts on stacked features become impossible because dependents cannot run until the parent is merged.
- **No oversized features silently proceeding** — sizing gate catches features that outgrew their PRD/techspec estimates and forces a split before Phase 2 tokens are spent.
- **No orphan features** — cycle-completion gate halts the orchestrator instead of moving on when a feature isn't truly done, eliminating the rework pattern.
- **Observable cost** — `token_cost_estimate` and `token_cost_cumulative` on every checkpoint let users see exactly where budget is going.

### Negative / risks

- **More moving parts.** Five new modules (`router`, `learning`, `cost`, `size_gate`, `cycle_gate`) add complexity to the orchestrator. Mitigated by shipping them across 4 independent PRs.
- **Platform CLI coupling.** Merge polling depends on `gh`/`az`/`glab` being authenticated. Failure mode: if the CLI is not available, the orchestrator errs on the side of caution and keeps dependents blocked.
- **Specialist availability.** Full benefit requires specialized agents to be installed. Graceful fallback preserves correctness but erodes the promised token savings.
- **Per-task routing latency.** File-path analysis per task adds milliseconds per task; negligible at scale but measurable on small features.
- **Cost-baseline drift.** Estimated token costs diverge from reality as models and prompts change. Mitigated by the manual `calibrate` subcommand; accepted as a tradeoff vs measurement wrapping.
- **Auto-split heuristic error.** Sizing gate may split features that would have fit together well, or miss features that are technically under threshold but high-complexity. Mitigated by `supervised` mode prompting before splitting and by the user's ability to manually merge sub-features in the backlog.

### Deferred / out of scope

- Automatic global-tier promotion (requires a confidence metric; manual for now).
- Pre-processing model for cheaper classification (see ADR-003 — still deferred).
- Concurrent worktree execution (`execution.max_concurrent > 1` — stays at 1 in v8; revisit in v9).
- In-Claude skill changes — the `/feature-marker` slash command retains its current behavior.

---

## Resolutions During Review

The three open questions originally raised have been answered and are now part of the design:

| #   | Original question                                | Resolution                                                                                                                                                                                                                                  | Where it lands      |
| --- | ------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------- |
| 1   | `token_cost_estimate` computed or measured?      | **Computed (estimated)** from per-phase baselines in `model.cost_baselines`; manual `calibrate` subcommand for drift correction.                                                                                                            | Decision #9         |
| 2   | TTL on learning entries?                         | **Yes** — 90-day default, refreshed on `last_seen`. Archive (not delete) on expiry. Pairs with a complete learning loop: capture → apply → verify → prune → promote, using `success_count` / `failure_count` / `confidence`.                | Decision #6b, #6c   |
| 3   | How to handle multi-stack or oversized features? | Feature-sizing gate before Phase 2 splits oversized features into sub-features along PRD/techspec boundaries; cycle-completion gate prevents advancing to the next backlog feature before the current one's full cycle has completed.       | Decision #10a, #10b |
| 4   | Scope expansion: fuzzy learning-store lookup?    | **Added** — optional embedding-similarity backend (Decision #6d). Default `exact` backend unchanged; opt-in via `learning.similarity.backend: embedding`. Model source delegated to ADR-009's `local_model.embedding_model`. Ships in PR-C. | Decision #6d        |

No remaining blockers to landing the design.
