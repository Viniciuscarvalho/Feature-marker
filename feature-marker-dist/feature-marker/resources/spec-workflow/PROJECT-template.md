# Project DNA

> This file provides permanent context about the project to all phases of the feature-marker workflow.
> Commit it to your repository so it is shared with the entire team.
> Path: `.claude/spec-workflow/PROJECT.md`

## Stack

<!-- Describe your runtime, language, and key infrastructure -->

- Language/Runtime: [e.g., Swift/iOS 17, TypeScript/Next.js 14, Rust]
- Database: [e.g., Firestore, PostgreSQL, SQLite, none]
- Auth: [e.g., Firebase Auth — always use ID token in Authorization header]
- Key dependencies: [e.g., Stripe, Firebase Admin SDK, RevenueCat, Prisma]

## Architecture Rules (MANDATORY)

<!-- These rules are injected into every spec, review, and implementation phase.
     Violations are flagged as blockers during validation. -->

- [e.g., iOS: always follow MVVM + Use Cases + Repository pattern]
- [e.g., API: soft delete only — never hard delete, use status: 'archived']
- [e.g., All user-facing features must be behind a feature flag]
- [e.g., All API routes must call verifyAuthRequest() before any operation]
- [e.g., Never commit secrets — use environment variables only]

## Code Conventions

<!-- Naming and structural conventions used throughout the codebase -->

- Naming: [e.g., Firebase UIDs stored as 'uid', never 'userId' or 'id']
- File structure: [e.g., feature folder per domain under Presentation/Features/]
- Error handling: [e.g., always return { error: string } on failure, never throw]
- API responses: [e.g., always wrap in { data, error, meta }]

## Known Constraints & Tech Debt

<!-- Things the AI must NOT assume are in place or working -->

- [e.g., Stripe webhook not yet configured — do not assume it runs in production]
- [e.g., FCM token required for push — may not be present for all users]
- [e.g., iOS feature flags sourced from Firebase Remote Config, default false]
- [e.g., Background jobs use cron, not a queue — no retry logic]

## What "Done" Looks Like

<!-- These criteria are used to validate tasks and ACs during the workflow -->

- [ ] Unit tests for all use cases / business logic
- [ ] Integration tested at the API boundary
- [ ] Feature flag added if user-facing
- [ ] No hardcoded strings (use constants or localization keys)
- [ ] PR includes screenshots for UI changes
- [ ] Security rules / permissions updated (Firestore, RLS, etc.)
- [ ] Documentation updated if public API changed

## Out of Scope (Always)

<!-- Things that should NEVER be included in any spec for this project -->

- [e.g., Android support — not in roadmap]
- [e.g., Offline mode — not currently supported]
- [e.g., Multi-tenancy — single organization only]
- [e.g., Real-time sync via WebSockets — polling only for now]

## Security (machine-readable — ADR-011, do not remove)

<!--
  Read by scripts/guardrails.sh to emit per-worktree .claude/settings.json.
  allowed_write_paths and allowed_commands supplement the stack-default allowlist.
  denied_paths and denied_commands are merged into the deny list.
  sanitize_mode: strict (default) | relaxed | off
-->

```yaml
security:
  allowed_write_paths:
    - "Sources/**"
    - "Tests/**"
    - "tasks/prd-*/**"
  denied_paths:
    - ".github/workflows/**"
    - "Secrets/**"
    - "**/*.pem"
    - "**/*.p12"
    - "fastlane/Appfile"
  allowed_commands: []
  sanitize_mode: strict
```
