# feature-marker Native Adapter Health Report

## Run Metadata

| Field | Value |
| --- | --- |
| Date | 2026-05-27 |
| Repo SHA | `164e6dd` plus working tree native-adapter remediation |
| Claude Code version | `2.1.152` |
| Codex CLI version | `codex-cli 0.130.0` |
| Gemini CLI version | `0.31.0` |
| Test mode | Deterministic adapter mock via `FEATURE_MARKER_ADAPTER_MOCK=1` |

## Mode Matrix

Pass means the CLI created/resumed neutral state, used an isolated worktree, and
completed the expected phase list in a throwaway git repo.

| Runtime | `full` | `tasks-only` | `test-only` | `prd-only` |
| --- | --- | --- | --- | --- |
| Claude | Pass | Pass | Pass | Pass |
| Codex | Pass | Pass | Pass | Pass |
| Gemini | Pass | Pass | Pass | Pass |

## Deterministic Tests

Command:

```bash
npm test
```

Result:

```text
1..9
# tests 9
# pass 9
# fail 0
```

Covered scenarios:

- mode validation rejects `spec-driven` and `ralph-loop`
- neutral checkpoint creation
- worktree creation and resume
- `tasks-only` artifact preflight and worktree sync
- dirty existing worktree refusal
- platform-context generation
- runtime capability preflight
- Claude, Codex, and Gemini adapter asset installation

## Adapter Matrix Smoke

Command shape:

```bash
FEATURE_MARKER_ADAPTER_MOCK=1 feature-marker run <slug> --mode <mode> --runtime <runtime>
feature-marker status <slug> --json
```

Result:

```text
smoke-ok
```

The smoke matrix covered all combinations of:

- runtimes: `claude`, `codex`, `gemini`
- modes: `full`, `tasks-only`, `test-only`, `prd-only`

## Known Limits

- The matrix verifies CLI state-machine behavior with mocked adapter execution; it does not spend real Claude/Codex/Gemini model calls.
- `spec-driven` and `ralph-loop` are intentionally unsupported in native-adapter v1.
- Branch handoff stops after a local commit and prints push/PR commands. It does not push or create a remote PR automatically.
