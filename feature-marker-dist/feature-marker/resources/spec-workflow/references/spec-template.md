# Built-in Spec Template

Use this template when creating specification files. Users can override this by providing `.claude/spec-workflow/templates/spec.md` in their project.

---

```markdown
# [Feature Name] Specification

---
created: YYYY-MM-DD
author: [author]
status: Draft | Ready for Review | Approved | In Progress | Implemented
services: [list of affected services]
worktree: [worktree name if applicable]
branch: [branch name if applicable]
---

## TL;DR

[2-3 sentence overview of what this spec covers]

## Purpose

### Problem Statement

[What problem does this solve? Why now?]

### Goals

- [Goal 1]
- [Goal 2]

### Non-Goals (Out of Scope)

- [Explicitly excluded item 1]
- [Explicitly excluded item 2]

---

## Requirements

### Functional Requirements

1. [Requirement with acceptance criteria]
2. [Requirement with acceptance criteria]

### Non-Functional Requirements

- **Performance:** [Constraints]
- **Security:** [Considerations]
- **Compatibility:** [Breaking changes]

---

## Architecture & Design

### Overview

[High-level description with component relationships]

### Data Model

[Schema changes, new types, migrations]

### API Changes

[API additions/modifications, if applicable]

### Component Design

[Key modules and their responsibilities]

### Error Handling

[Failure modes and recovery]

---

## Implementation Steps

Sequential tasks organized for execution.

| Step | Task | Description | Depends On |
|------|------|-------------|------------|
| 1 | [Task name] | [Task description] | None |
| 2 | [Task name] | [Task description] | Step 1 |
| 3 | [Task name] | [Task description] | Step 2 |

---

## Validation & Testing Plan

### Unit Tests

- [ ] [Test scenario 1]
- [ ] [Test scenario 2]

### Integration Tests

- [ ] [Test scenario 1]

### Manual Testing

- [ ] [Verification step 1]
- [ ] [Verification step 2]

### Acceptance Criteria

- [ ] [Criterion 1]
- [ ] [Criterion 2]

---

## Sub-agent Parallelization Plan

> **Note:** Only include this section if the implementation has meaningful parallelization opportunities (multiple independent tasks, cross-service work, or 3+ steps with no dependencies between some). Omit for sequential or simple implementations.

Tasks grouped for concurrent execution by Claude Code sub-agents.

### Parallel Group 1: [Name]

**Can start immediately - no dependencies**

Tasks: [List task numbers]
Agents needed: [Number]
Description: [What these tasks accomplish together]

### Parallel Group 2: [Name]

**Requires: Group 1 complete**

Tasks: [List task numbers]
Agents needed: [Number]

### Execution Diagram

```
Group 1: [Task A] [Task B]  (parallel)
              |
              v
Group 2: [Task C] [Task D]  (parallel)
              |
              v
Sequential:  [Task E]
```

---

## Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| [Risk 1] | Low/Med/High | Low/Med/High | [Strategy] |

---

## Open Questions

- [ ] [Unresolved question 1]
- [ ] [Unresolved question 2]

---

## Appendix

### Related Files

- `path/to/file1` - [Relevance]
- `path/to/file2` - [Relevance]

---

## Review Discussion

> **Note:** This section is populated during the review process. Omit for initial drafts.

### Key Feedback Addressed

- **[Issue]** ([Reviewer]): [How it was resolved and why]

### Tradeoffs Considered

- **[Alternative approach]**: [Why it was rejected or deferred]

### Dissenting Perspectives

- **[Concern]** ([Reviewer]): [Acknowledged but not fully addressed because...]
```
