# feature-marker Skill-First Health Report

## Run Metadata

| Field | Value |
| --- | --- |
| Date | 2026-05-27 |
| Scope | Installer-only remediation on `codex/native-adapter-remediation` |
| Test mode | Deterministic local installer and package checks |

## Installer Matrix

| Runtime | `install --dry-run` | temp `HOME` install |
| --- | --- | --- |
| Claude | Pass | Pass |
| Codex | Pass | Pass |
| Gemini | Pass | Pass |
| All | Pass | Pass |

## Deterministic Tests

Command:

```bash
npm test
```

Expected covered scenarios:

- dry-run install targets for Claude, Codex, Gemini, and all
- temp `HOME` installs into runtime-specific skill directories
- unsupported workflow command errors for `run`, `resume`, `status`, and `capabilities`
- static docs checks for npx install and LLM invocation examples
- package dry-run includes installer, skill assets, README, context, and ADR docs

## Known Limits

- The package does not run live Claude, Codex, or Gemini model calls.
- Workflow execution is intentionally delegated to the installed LLM skill.
- `spec-driven` and `ralph-loop` are out of scope for skill-first v1 unless rebuilt as explicit skill instructions.
- Branch handoff stops after a local commit and printed push/PR commands. It does not push or create a remote PR automatically.
