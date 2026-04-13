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

## [FEAT] feat-003: Webhook event handler
Create a webhook processing system for third-party integrations.
Should handle retries, signature verification, and event deduplication.
- labels: api, webhooks, integration
- priority: high

## [FEAT] feat-004: User analytics dashboard
Build a real-time analytics dashboard showing active users,
feature usage metrics, and conversion funnels.
- labels: analytics, dashboard, ui
- priority: medium

## [FEAT] feat-005: Rate limiting middleware
Implement configurable rate limiting per API endpoint.
Support sliding window and token bucket algorithms.
- labels: api, security, middleware
- priority: high

## [DONE] feat-006: Initial project setup
Already shipped

## [BLOCKED] feat-007: Billing integration
Depends on: feat-001
- labels: billing, payments
- priority: medium
