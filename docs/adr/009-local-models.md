# ADR-009: Local-Model Integration for Cost Reduction and Resilience

- **Status:** Proposed
- **Date:** 2026-04-18
- **Depends on:** ADR-008 (Orchestrator Token-Economy — Decision #6d for embedding similarity)
- **Reopens:** ADR-003 (Preprocessing, previously deferred)
- **Scope:** CLI orchestrator (`scripts/orchestrate.sh` and modules under `scripts/lib/`). The in-Claude `/feature-marker` skill is unchanged.

---

## Context

ADR-008 reduces Claude token consumption _within_ Claude by scripting deterministic phases, routing to specialists, and building a self-maintaining learning store. That ADR's thesis is economy through smarter use of Claude.

A complementary approach is **model tier switching**: delegate work that does not require Claude-grade reasoning to a locally-hosted model (Ollama, LM Studio, llama.cpp). The target roles are:

- **Embedding** — producing float vectors for learning-store similarity (ADR-008 Decision #6d).
- **Classification** — routing tasks to the right specialist agent.
- **Summarization** — extracting actionable fixes from unstructured text (PR review comments, CI failure logs).
- **Generation** — optional full replacement of Phase 2/3 code generation (high risk, opt-in only).

Using a local model for these roles reduces Claude API spend, adds resilience during Claude API outages, and supports local-first / offline-first deployments.

This ADR introduces the provider abstraction, config surface, per-phase engine selection, and four follow-up implementation PRs (E–H). Quality tradeoffs and operational costs are explicit consequences, not afterthoughts.

---

## Decisions

### D1. Provider abstraction — `scripts/lib/local_model.sh`

A thin shell adapter module exposes four functions:

```
local_model::embed   <text>         → JSON float array
local_model::classify <text> <labels> → label string
local_model::summarize <text>       → summary string
local_model::generate <prompt>      → generated text
```

Initial supported providers:

| Provider    | Base URL default         |
| ----------- | ------------------------ |
| `ollama`    | `http://localhost:11434` |
| `lm-studio` | `http://localhost:1234`  |
| `llama-cpp` | `http://localhost:8080`  |

Provider selection via `local_model.provider` in `orchestrator/config.yml`. Adding a new provider is a single function-map entry in `local_model.sh` — no changes to callers.

### D2. Config surface

New `local_model` block in `orchestrator/config.yml`:

```yaml
local_model:
  enabled: false # opt-in; default keeps pure-Claude behavior
  provider: ollama
  endpoint: http://localhost:11434
  embedding_model: nomic-embed-text
  classifier_model: llama3.2:3b
  summarizer_model: llama3.2:3b
  generator_model: null # opt-in for full Phase 2/3 replacement
  timeout_seconds: 10
  fail_open: true # on endpoint error, degrade to Claude / exact-match
```

All keys are optional. Unset keys default to the values shown. `enabled: false` (the default) makes every other key a no-op — zero behavioral change for users who do not configure this block.

### D3. Per-phase engine selection

The checkpoint `engine` field introduced in ADR-008 currently holds `script | claude`. This ADR extends the enum:

```
engine: script | claude | local | hybrid
```

A new config key maps phases to preferred engine:

```yaml
local_model:
  engine_per_phase:
    phase_0: script # always script — no model needed
    phase_1: claude # planning requires Opus-grade reasoning
    phase_2: claude # default; set to local to enable D8
    phase_3: script # test runner; local on fix-attempt is a future option
    phase_4: claude # commit + PR template generation
```

`hybrid` is used when the phase uses both a local model (e.g., classification) and Claude (e.g., implementation). Checkpoint records with `engine: hybrid` include a `local_model_role` field naming the task delegated locally.

### D4. Embedding role (depends on ADR-008 Decision #6d)

When `local_model.enabled: true`, `local_model::embed` backs the learning-store similarity retrieval described in ADR-008 #6d. The embedding model (`embedding_model`) is called once per write (to build `learned.embeddings.jsonl`) and once per retrieval (to embed the incoming error signature).

If `local_model.enabled: false`, ADR-008 #6d's embedding backend is inactive regardless of `learning.similarity.backend`. The dependency is one-way: embedding similarity requires local-model enablement; local-model enablement does not require embedding similarity.

### D5. Classifier role

An optional replacement for the file-path heuristic in ADR-008 Decisions #3 and #4. When enabled, `local_model::classify` receives the task description and returns a label from a fixed taxonomy:

```
ui | api | db | infra | test | unknown
```

The label refines routing beyond file-path detection — for example, an API task in a TypeScript repo routes to `typescript-pro` with a REST-specific system prompt rather than the generic specialist. Falls back to the file-path heuristic when:

- `local_model.enabled: false`
- classifier endpoint is unreachable
- returned label is `unknown`

Classification result is cached in `.orchestrator/stack-map.json` alongside the existing per-path stack entries.

### D6. Summarizer role

`local_model::summarize` extracts structured, actionable fixes from free-form text. Primary sources:

1. **PR review comments** — reviewer inline comments pulled via `gh pr view --comments` (or platform equivalent).
2. **Post-merge CI failure logs** — test/lint output from the CI run that ran against the merged commit.

Output format expected from the summarizer prompt:

```json
{
  "fixes": [
    { "pattern": "<error or anti-pattern>", "fix": "<corrective action>" }
  ],
  "confidence": 0.82
}
```

Only fixes with `confidence ≥ 0.7` are written to the learning store. Fixes below threshold are logged to `.orchestrator/state/{feat-id}.log` for human review.

### D7. Phase 4.5 — Review-ingest step

A new post-merge step that feeds the summarizer's output into the project-tier learning store.

**Trigger**: Immediately after the orchestrator detects that a feature's PR has been merged to the base branch (already polled in ADR-008 Decision #8).

**Steps**:

1. Fetch PR review comments via platform CLI.
2. Fetch post-merge CI results (first failed run after merge, if any).
3. Run `local_model::summarize` over each source independently.
4. Write high-confidence extractions to `.claude/feature-state/learned.json` (project tier) as new entries:
   - `tier: project`
   - `success_count: 0`, `failure_count: 0`, `confidence: null` — unverified until the pattern triggers a future match.
5. Append a `review_ingest` record to `.orchestrator/state/{feat-id}.json`.

**Scheduling**: Background pass triggered on the next orchestrator run that follows a merge detection, not synchronously at Phase 4 completion. This avoids blocking Phase 4 on network calls to CI APIs.

**Manual / backfill**: `feature-marker-orchestrate ingest-reviews <feat-id>` runs the step on demand.

### D8. Optional full generator replacement (opt-in)

Setting `local_model.generator_model` to a capable coder model (e.g., `qwen2.5-coder:32b`) routes Phase 2 implementation generation and Phase 3 fix attempts to the local model instead of Claude.

**This is explicitly opt-in and not recommended for production backlogs.** Quality tradeoffs are real:

- Local coder models produce correct code for well-scoped tasks but miss implicit project conventions and context that Claude infers from multi-turn conversation.
- Prompt drift: as the local model version changes, behavior drifts without the orchestrator knowing. Claude model changes are versioned and announced.
- Latency: large local models (32B+) may be slower than Claude API calls on typical developer hardware.

When `generator_model` is set, `engine_per_phase.phase_2` defaults to `local` and can be overridden back to `claude` per-feature via checkpoint metadata.

### D9. Startup health check

On every `feature-marker-orchestrate run`, before processing any feature, the orchestrator pings the configured endpoint:

```
GET {endpoint}/api/tags   (ollama)
GET {endpoint}/v1/models  (openai-compat: lm-studio, llama-cpp)
```

| `fail_open` | Endpoint unreachable | Behavior                                                      |
| ----------- | -------------------- | ------------------------------------------------------------- |
| `true`      | Yes                  | Log one-time warning; proceed with Claude-only / exact-match. |
| `false`     | Yes                  | Halt with diagnostic: endpoint URL, provider, suggested fix.  |
| Either      | No                   | Log endpoint + available models at DEBUG level; continue.     |

The health check result is written to `.orchestrator/state/local_model_health.json` and reused within a run (no repeated pings per feature).

---

## Consequences

### Positive

- **Further cost reduction** beyond ADR-008's ~40% savings: embedding, classification, and summarization move off Claude entirely.
- **Resilience**: Claude API outages no longer halt the learning loop or similarity retrieval when a local model is available.
- **Local-first privacy**: teams with data-residency requirements can run the learning store without sending error patterns to external APIs.
- **Review-ingest closes a feedback gap**: previously, PR review comments were human-readable but never re-entered the learning system. Phase 4.5 automates this.

### Negative / risks

- **Operational complexity**: teams must manage a local model server (install, start, keep updated). This is new infrastructure the orchestrator didn't require before.
- **Quality regression risk for D8**: full generator replacement with a local model is the highest-risk decision. Mitigated by opt-in flag and explicit documentation that this is experimental.
- **Version drift**: local model behavior changes with model upgrades; prompts written against `llama3.2:3b` may degrade silently when the model is replaced. No automated detection.
- **Cold-start latency**: first invocation of a large local model can take 10–30 seconds for model load. `timeout_seconds: 10` default will cause `fail_open` degradation on cold starts. Teams should pre-warm the model or increase the timeout.

### Deferred / out of scope

- **Model evaluation harness**: deciding which local model performs best per role (embedding accuracy, classification precision, summarizer quality) requires a test dataset and offline benchmark harness. This belongs in ADR-010 if pursued.
- **Remote (non-local) open-source API**: pointing the adapter at a hosted Ollama endpoint (e.g., a team server) is architecturally identical — just a different `endpoint` URL. No code change needed; explicitly supported but not documented as a first-class mode.
- **Concurrent local-model calls**: the adapter is synchronous per call. Parallelizing embedding writes across tiers is deferred to a follow-up.

---

## Open Questions

These are intentionally left open for PR discussion:

1. **Summarizer confidence vs. Phase 3 verified confidence**: Should extracted fixes from review-ingest start at `confidence: null` (unverified) or at the summarizer's reported confidence value? **Proposal**: start at `null`; treat summarizer confidence as an internal signal, not an orchestrator confidence score. The entry earns its confidence through Phase 3 match-and-verify cycles.

2. **Review-ingest timing**: Synchronous at Phase 4 completion or background on the next run? **Proposal**: background. Phase 4 should not block on CI API availability; the ingest runs opportunistically.

---

## Implementation Phasing

Follow-up PRs after ADR-008's PRs (A–D) merge:

1. **PR-E — Provider abstraction + config + startup health check**
   - New `scripts/lib/local_model.sh`: `embed`, `classify`, `summarize`, `generate` functions with provider dispatch.
   - `local_model` block in `orchestrator/config.yml` (defaults all disabled).
   - Startup health check in `scripts/orchestrate.sh`; result cached to `local_model_health.json`.
   - Config key `local_model.engine_per_phase`; checkpoint `engine` enum extended to include `local` and `hybrid`.

2. **PR-F — Embedding similarity wiring (depends on ADR-008 PR-C)**
   - Wire `local_model::embed` into `scripts/lib/learning.sh` write-path (append to `learned.embeddings.jsonl`).
   - Wire into retrieval path: cosine similarity against embedding file, threshold from `learning.similarity.threshold`.
   - Unit tests: embed → store → retrieve round-trip with a mock endpoint.

3. **PR-G — Classifier + summarizer + Phase 4.5 review-ingest**
   - Wire `local_model::classify` into `scripts/lib/router.sh`; cache result in `stack-map.json`.
   - Wire `local_model::summarize` into new `scripts/lib/ingest.sh` module.
   - Merge-detection hook (ADR-008 Decision #8) triggers background ingest pass.
   - New subcommand: `feature-marker-orchestrate ingest-reviews <feat-id>`.

4. **PR-H — Optional full generator replacement**
   - When `local_model.generator_model` is set, Phase 2 and Phase 3 fix-attempt prompts route through `local_model::generate`.
   - Checkpoint records `engine: local` for affected phases.
   - Explicit quality-warning banner printed at orchestrator start when this flag is active.

Each PR is independently revertable. PRs F–H each depend on PR-E. PR-F additionally depends on ADR-008 PR-C.

---

## Cross-References

- **ADR-008 Decision #6d** — defines the embedding storage format and retrieval contract that PR-F implements.
- **ADR-008 Decision #3/#4** — file-path stack detection that the classifier (D5) optionally augments.
- **ADR-008 Decision #8** — merge detection hook that triggers Phase 4.5 review-ingest (D7).
- **ADR-008 Revised Checkpoint Model** — `engine` field extended here with `local` and `hybrid` values.
- **ADR-003** — preprocessing deferred in 2025; Phase 4.5 review-ingest (D7) and the classifier (D5) reopen that door with a concrete, lower-risk implementation path.
