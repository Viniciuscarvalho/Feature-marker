# ADR-008: Orchestrator Economy — Token Cost, Smart Routing, Layered Learning, Feature Sizing

- **Status**: Accepted
- **Date**: 2026-04-18
- **Deciders**: Vinicius Carvalho
- **Supersedes**: —
- **Related**: ADR-002 (Memory), ADR-006 (Agent Discovery & Routing)

---

## Context

The orchestrator has reached a level of maturity where four systemic inefficiencies
need to be addressed in a single coordinated ADR:

1. **Token waste**: Phase 0 unconditionally invokes Claude even when all artifacts
   (prd.md, techspec.md, tasks.md) already exist in the worktree. Phase 3 has no
   scripted test runner — failures are discovered late and expensively.

2. **Undifferentiated routing**: Every task goes to the generic `feature-marker`
   agent regardless of the tech stack being modified. Stack-aware routing would
   improve first-attempt quality.

3. **Stateless error learning**: Error patterns are recorded (ADR-002 Layer 2) but
   never promoted into reusable fixes. Every recurrence pays the same retry cost.

4. **No feature-size safety valve**: A mis-scoped PRD can silently balloon into a
   change set that exceeds reasonable PR sizes, triggering review fatigue and
   partial merges.

---

## Decision

Implement four additive subsystems delivered across four logical PRs, all merged on
a single implementation branch:

### PR-A: Checkpoint Schema + Phase 0/3 Scripting + Token-Cost Estimator

**Phase 0 optimisation** — before invoking Claude for artifact generation, check
whether `tasks/prd-{slug}/{prd,techspec,tasks}.md` all exist in the worktree path.
If they do, skip the Claude call entirely and log
`"Phase 0: artifacts exist, skipping generation (cost: 0)"`.

**Phase 3 scripted tests** — introduce `run_phase3_tests(feat_id, wt_path)` in
`runner.sh`. Detects stack and runs the appropriate shell command:

| Stack  | Command         |
| ------ | --------------- |
| swift  | `swift test`    |
| node   | `jest`          |
| rust   | `cargo test`    |
| python | `pytest`        |
| go     | `go test ./...` |

If the command exits non-zero, Claude is invoked for a fix attempt. Maximum 2
attempts. On success, a learning entry is captured.

**Token-cost estimator** — `scripts/lib/cost.sh` accumulates per-phase token
estimates using baselines from `config.yml`:

```yaml
model:
  default: opusplan
  cost_baselines:
    phase_1_planning: 25000
    phase_2_per_task_specialist: 8000
    phase_2_per_task_generic: 12000
    phase_4_commit_pr: 5000
    fix_attempt_overhead: 3000
```

Phase 0 costs 0 (script-only unless generation is needed). Phase 3 costs 0 on the
happy path; each fix attempt adds `fix_attempt_overhead`.

New subcommand: `calibrate --sample N` — reads timing data from the last N features
and prints calibration guidance (placeholder in v1).

### PR-B: Block-Based Routing + Specialist Fallback

`scripts/lib/router.sh` provides per-task file-path stack detection, cached in
`.orchestrator/stack-map.json`.

**Stack detection** inspects file extensions within the task's affected paths:

| Extension(s)         | Stack  |
| -------------------- | ------ |
| `.swift`             | ios    |
| `.ts`, `.tsx`, `.js` | node   |
| `.py`                | python |
| `.rs`                | rust   |
| `.go`                | go     |

**Agent mapping**:

| Stack   | Agent            |
| ------- | ---------------- |
| ios     | `swift-expert`   |
| node    | `typescript-pro` |
| python  | `python-pro`     |
| rust    | `rust-expert`    |
| go      | `go-expert`      |
| (other) | `feature-marker` |

If the mapped agent is not installed under `.claude/agents/`, fall back to the
generic `feature-marker` agent. Installation check uses `router_agent_installed()`.

Results are cached in `.orchestrator/stack-map.json` so repeated runs within the
same worktree session do not re-detect.

### PR-C: Layered Learning + Hard-Block Dependencies

**Layered learning** — `scripts/lib/learning.sh` implements a 3-tier store:

| Tier    | Path                                            |
| ------- | ----------------------------------------------- |
| feature | `$STATE_DIR/{feat_id}/learned.json`             |
| project | `$ROOT_DIR/.claude/feature-state/learned.json`  |
| global  | `~/.claude/feature-marker/learned/learned.json` |

Entry schema:

```json
{
  "id": "learn-<random>",
  "pattern": "<error signature>",
  "fix": "<fix description>",
  "tier": "project",
  "created_at": "<ISO-8601>",
  "last_seen": "<ISO-8601>",
  "hits": 1,
  "success_count": 0,
  "failure_count": 0,
  "confidence": 0.5,
  "ttl_days": 90,
  "archived": false,
  "promotion_candidate": false
}
```

The complete loop:

1. **Capture** — `learning_write()` on Phase 3 fix-attempt success
2. **Apply** — `learning_read()` injects hint into next fix prompt
3. **Verify** — `learning_verify()` updates success/failure counts and confidence
4. **Prune** — `learning_prune_sweep()` archives entries with confidence < 0.5
   AND hits >= 3
5. **Promote** — `learning_promote()` copies a project-tier entry to global

TTL sweep moves entries older than `ttl_days` into `{path}/_archive/`.

New subcommands: `learning list [--candidates]`, `learning archive <id>`,
`promote-learning <id>`.

**Hard-block dependencies** — before each feature run, `dep_check_merge_state()`
polls the git platform CLI to verify all dependency PRs are merged:

| Platform | Command                                  |
| -------- | ---------------------------------------- |
| GitHub   | `gh pr view <num> --json state,mergedAt` |
| Azure    | `az repos pr show --id <num>`            |
| GitLab   | `glab mr view <num>`                     |

If any dependency PR is not in a merged state, the feature is set to `blocked` and
skipped for the current run.

### PR-D: Feature-Sizing Gate + Cycle-Completion Gate

**Feature-sizing gate** — `scripts/lib/size_gate.sh` reads metrics from PRD,
techspec, and tasks files:

- Acceptance criteria count (lines matching `^- ` or `^\d+\.` in prd.md
  acceptance section)
- Task count (lines matching `^\- \[` or headings in tasks.md)
- File-changes estimate (file paths in techspec.md "Files to Modify" section)

Thresholds (configurable in `config.yml`):

```yaml
safety:
  feature_size:
    max_acceptance_criteria: 15
    max_tasks: 20
    max_file_changes_estimate: 80
```

Behaviour by autonomy mode:

- `supervised`: prints warning, prompts user (`read -p "Proceed? [y/N]"`)
- `checkpoint` / `full_auto`: logs split signal to
  `.orchestrator/state/{feat_id}/size-exceeded.json`

**Cycle-completion gate** — `scripts/lib/cycle_gate.sh` asserts the current
feature completed its full cycle before the orchestrator advances to the next:

- All 5 phase checkpoints marked complete in
  `.orchestrator/state/{feat_id}/checkpoint.json`
- PR URL recorded in `.orchestrator/state/{feat_id}/results.json`
- `fix_attempts = 0` across all tasks

Bypass with `--skip-cycle-check` flag (sets `OPT_SKIP_CYCLE_CHECK=true`).

---

## Consequences

### Positive

- Phase 0 re-runs save ~25 000 tokens per feature where artifacts already exist.
- Stack-aware routing improves first-attempt pass rate for specialist stacks.
- Learning layer reduces repeated fix costs for recurring error patterns.
- Feature-sizing gate prevents unbounded PR scope from reaching code review.
- Hard-block dependencies prevent dependent features from running against
  unmerged upstream code.

### Negative / Trade-offs

- Added shell surface area: five new lib files (~600 lines total).
- `cost_calibrate` is a placeholder in v1 — actual calibration requires telemetry
  data that is only available after several real runs.
- Learning confidence model is heuristic; high-confidence bad fixes are possible
  until enough verify cycles accumulate.

### Neutral

- All behaviour is additive; no existing API contracts are broken.
- The cycle gate can always be bypassed with `--skip-cycle-check` for emergency
  deployments.

---

## Implementation Notes

All new shell modules live in `scripts/lib/`. JSON manipulation uses
`node -e` (Node.js is a declared runtime dependency of the orchestrator).
POSIX-compatible where possible; bash arrays avoided in favour of colon-delimited
strings.

Config variables exported by `cost.sh`:
`COST_PHASE_1_PLANNING`, `COST_PHASE_2_SPECIALIST`, `COST_PHASE_2_GENERIC`,
`COST_PHASE_4_COMMIT_PR`, `COST_FIX_ATTEMPT`

Config variables exported by `size_gate.sh`:
`SIZE_MAX_CRITERIA`, `SIZE_MAX_TASKS`, `SIZE_MAX_FILE_CHANGES`
