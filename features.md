# Feature Backlog

## [FEAT] feat-001: Add Multi-Tenant Auth Group
This feature introduces multi-tenant authentication.
The system should support both user and domain-level access controls.
- The API endpoint that verifies user access currently only checks admin role
- labels: auth, multi-tenant
- priority: high

## [FEAT] feat-002: Dark mode toggle
Let user switch between light and dark themes
- labels: ui, theming
- priority: low

## [DONE] feat-003: Dark mode auto toggle
Already shipped

## [BLOCKED] feat-004: Billing auto toggle
Depends on: feat-001
- labels: billing, backend
- priority: medium
