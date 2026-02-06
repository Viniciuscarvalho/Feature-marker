# Spec Writer Integration Contract

This document defines the contract between spec-orchestrator and spec-writer skills.

## Overview

The orchestrator invokes the spec writer in two scenarios:

1. **Autonomous draft**: Given a problem/request, produce a spec without user interaction
2. **Revision**: Given a spec + feedback, produce an updated spec

The spec-writer also supports an **interactive mode** for direct user invocation, but that's not used by the orchestrator.

## Input Contract

### For Autonomous Draft

The orchestrator provides:

```
{
  mode: "autonomous",
  request: string,       // The original user request or problem statement
  context?: string       // Optional additional context
}
```

### For Revision

The orchestrator provides:

```
{
  mode: "revision",
  currentSpec: string,   // The current spec content
  iteration: number,     // Which revision round this is (1, 2, 3...)
  feedback: {
    summary: string,           // 2-3 sentence overview
    mustAddress: string[],     // Blocking issues (with reviewer attribution)
    shouldConsider: string[],  // Important but non-blocking
    minorOptional: string[],   // Polish items
    disagreements?: string[]   // Reviewer conflicts, if any
  }
}
```

## Output Contract

The spec writer must return a valid spec in both cases.

### For Autonomous Draft

Return the complete spec following the template. Include:

- All standard sections
- Documented reasoning for design decisions made
- Alternatives considered (in Architecture & Design section)

### For Revision

Return the updated spec with:

1. **Review Discussion section** — updated with feedback addressed
2. **Revision Notes** — appended at the end

```markdown
[... updated spec content ...]

---

## Revision Notes (Iteration N)

### Addressed

- [Feedback item]: [How it was addressed]
- [Feedback item]: [How it was addressed]

### Intentionally Not Addressed

- [Feedback item]: [Why it was not addressed — this will be reviewed]

### Other Changes

- [Any additional improvements made]
```

## Handling Feedback

### Must Address Items

These are blocking. The spec writer should:

1. Address each one, OR
2. Provide a compelling reason why it should not be addressed

If the spec writer believes feedback is incorrect or misguided:

- Still acknowledge the concern in Revision Notes
- Explain why they chose not to address it
- Accept that this may trigger escalation to human review

### Should Consider Items

These are important but not blocking. The spec writer should:

1. Address if straightforward
2. Note in "Intentionally Not Addressed" with reasoning if skipped

### Minor/Optional Items

Address as quick wins if easy. Otherwise, can be ignored.

### Maintaining Review Discussion

The spec writer must maintain a **Review Discussion** section in the spec that captures:

1. **Key Feedback Addressed** — Significant issues raised and how they were resolved
2. **Tradeoffs Considered** — Alternatives discussed, why rejected or deferred
3. **Dissenting Perspectives** — Concerns acknowledged but not fully addressed, with reasoning

This section should be updated with each revision, accumulating the discussion history.

## Revision Behavior Guidelines

When revising based on feedback:

1. **Be receptive, not defensive**
   - Reviewers are trying to improve the spec, not attack it
   - If feedback is valid, incorporate it gracefully

2. **Address the intent, not just the letter**
   - If a reviewer asks "what about error handling?" don't just add a sentence
   - Think about why they asked and whether the concern is deeper

3. **Maintain coherence**
   - Don't just append fixes — integrate them
   - A revision should read as a unified document, not a patchwork

4. **Be honest about tradeoffs**
   - If addressing one concern creates a new issue, note it
   - If you're making a judgment call, say so

5. **Know when to escalate**
   - If you genuinely believe feedback is wrong, say so clearly
   - Provide your reasoning
   - Accept that a human may need to decide

6. **Don't gold-plate**
   - Address the feedback, but don't use revision as an excuse to expand scope
   - Stay focused on the issues raised
