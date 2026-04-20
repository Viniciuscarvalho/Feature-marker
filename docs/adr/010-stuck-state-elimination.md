# ADR-010: Stuck-State Elimination

## Status

Accepted

## Context

A system audit against the ADR-008 + ADR-009 codebase revealed several confirmed hang risks:

| Risk                                                                                      | Location                | Severity |
| ----------------------------------------------------------------------------------------- | ----------------------- | -------- |
| `\| while` pipe subshell: `break`/`continue`/mutations silently don't propagate to parent | `runner.sh:99`          | HIGH     |
| Unbounded `read -p` prompt in supervised mode                                             | `size_gate.sh:168`      | HIGH     |
| `--resume` flag parsed but never wired up; paused features have no operator path back     | `orchestrate.sh:79,111` | HIGH     |
| Background ingest jobs: no PID file, no reaper, zombies accumulate                        | `ingest.sh:220`         | MEDIUM   |
| `claude --skill` invocation has no timeout                                                | `runner.sh:377`         | MEDIUM   |
| `gh pr view`, `gh run view --log-failed` have no timeout                                  | `ingest.sh:58-75`       | MEDIUM   |
| Sentinel files (`retry-count`, `phase3-fix-attempts`) survive across runs silently        | `runner.sh:417-465`     | MEDIUM   |
| JSON injection: `node -p "JSON.stringify('$var')"` breaks on single quotes                | multiple                | LOW      |

## Decisions

### D1 — Portable timeout helper (`op_timeout` in `scripts/lib/util.sh`)

`op_timeout <seconds> <command...>` wraps every external call that can block: `claude --skill`, `gh pr view`, `gh run view --log-failed`. Falls back from `timeout` → `gtimeout` → `perl alarm`.

The `claude --skill` call in `runner.sh` is wrapped with a configurable `SKILL_TIMEOUT_SECONDS` (default 1800). The existing `local_model.sh` `curl --max-time` pattern is unchanged (already timed).

### D2 — Subshell-pipe fix (`runner.sh` main loop)

Replace:

```bash
echo "$items" | node -e "..." | while IFS= read -r item_json; do
  break  # only breaks subshell — parent loop continues
done
```

With process substitution:

```bash
while IFS= read -r item_json; do
  break  # breaks parent loop correctly
done < <(echo "$items" | node -e "...")
```

All `| while` patterns in `scripts/lib/` are audited and fixed where loop-control or variable mutation crosses the pipe.

### D3 — `--resume-paused <feat-id>` operator command

The dead `OPT_RESUME` boolean is removed. A real `--resume-paused <feat-id>` subcommand re-enters `runner.sh` at the checkpoint phase for a paused feature. Human-class pauses require `--ack`.

### D4 — Pause taxonomy (`pause_kind: human | transient`)

Every pause record in `.orchestrator/state/<feat-id>/pause.json` carries a `pause_kind` field:

- `human` — requires operator decision (size gate declined, breaking change, supervised checkpoint). `--skip-blocked` skips these. `--resume-paused` requires `--ack`.
- `transient` — pipeline error that may resolve on retry. Auto-retried on next run with backoff.

The size gate prompt gets `read -t 120` so unattended runs auto-decline (recorded as `pause_kind:"human", action:"timeout_skipped"`) instead of hanging indefinitely.

### D5 — Background ingest reaping (`scripts/lib/ingest.sh`)

`ingest_trigger_if_merged` now writes a PID file to `.orchestrator/state/<feat-id>/ingest.pid`. `ingest_reap_stale` (called at `sub_run` startup) walks all PID files, checks liveness with `kill -0`, and cleans up finished jobs. `ingest-status` subcommand lists active jobs.

### D6 — Sentinel cleanup on resume

`runner_clear_sentinels <feat-id> <class>` removes `retry-count` and `phase3-fix-attempts` sentinel files. On `--resume-paused` for a `transient` pause, transient sentinels are cleared; human sentinels are preserved until `--ack` is passed.

### D7 — JSON-injection hardening (high-risk sites in `ingest.sh` and `learning.sh`)

The fragile `node -p "JSON.stringify('$var')"` pattern is replaced at the highest-risk sites by piping values through Node via stdin, eliminating the shell-injection vector.

## Alternatives Considered

**Bash skill registry** — rejected. Claude Code already discovers SKILL.md files under `~/.claude/skills/`, loads them into its catalog, and decides when to activate them based on the `description` field. Building a parallel registry in bash (`skills_init`, `skill_invoke_hook`, `skill-registry.json`) duplicates a solved problem and moves the activation decision from Claude to the orchestrator. The `learning-curator` skill lives as a nested sub-skill at `resources/skills/learning-curator/` and is invoked by Claude via the `Skill` tool when review or CI signals are present — no bash dispatcher needed.

## Consequences

- `full_auto` and `checkpoint` modes can run unattended without operator intervention to unstick them.
- `--resume-paused <feat-id>` gives operators a clean, typed recovery path.
- Background ingest jobs no longer accumulate as zombies across long sessions.
- `ingest-status` subcommand provides operational visibility into active background work.
- `util.sh` is a shared module; all future shell modules that make external calls should source it.

## Compatibility

ADR-009 modules (`local_model.sh`, full `ingest.sh`) are sourced conditionally (`[ -f ... ] && source ...`). ADR-010 degrades gracefully when ADR-009 is not present.
