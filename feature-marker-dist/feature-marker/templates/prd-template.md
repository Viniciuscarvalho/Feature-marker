# Product Requirements Document (PRD)

**Project Name:** {{PROJECT_NAME}}
**Feature:** {{FEATURE_NAME}}
**Version:** {{VERSION}}
**Date:** {{DATE}}
**Status:** {{STATUS}}

---

## Prompt Context

### Original User Prompt
> {{ORIGINAL_PROMPT}}

### Enriched Prompt
> {{ENRICHED_PROMPT}}
> _(Ambiguities resolved, constraints injected, scope clarified)_

### CLAUDE.md Constraints Applied
- {{CONSTRAINT_1}}
- {{CONSTRAINT_2}}
- {{CONSTRAINT_3}}

### Codebase Context
| Attribute | Value |
|-----------|-------|
| Stack | {{STACK}} |
| Language(s) | {{LANGUAGES}} |
| Framework(s) | {{FRAMEWORKS}} |
| Package Manager | {{PACKAGE_MANAGER}} |
| Test Framework | {{TEST_FRAMEWORK}} |
| Relevant Entry Points | {{ENTRY_POINTS}} |

### Environment Manifest
| Tool / MCP Server | Available | Notes |
|--------------------|-----------|-------|
| {{TOOL_1}} | Yes/No | {{TOOL_1_NOTES}} |
| {{TOOL_2}} | Yes/No | {{TOOL_2_NOTES}} |

---

## Executive Summary

**Problem Statement:**
{{PROBLEM_STATEMENT}}

**Proposed Solution:**
{{SOLUTION_OVERVIEW}}

**Business Value:**
{{BUSINESS_VALUE}}

**Success Metrics:**
| Metric | Baseline | Target | How to Measure |
|--------|----------|--------|----------------|
| {{METRIC_1}} | {{BASELINE_1}} | {{TARGET_1}} | {{METHOD_1}} |
| {{METRIC_2}} | {{BASELINE_2}} | {{TARGET_2}} | {{METHOD_2}} |

---

## Project Overview

### Background
{{BACKGROUND}}

### Current State
{{CURRENT_STATE}}

### Desired State
{{DESIRED_STATE}}

### Existing Codebase Patterns
_Patterns detected in the project that the implementation MUST follow:_

- **Naming conventions:** {{NAMING_CONVENTIONS}}
- **File structure:** {{FILE_STRUCTURE_PATTERN}}
- **Error handling:** {{ERROR_HANDLING_PATTERN}}
- **Logging:** {{LOGGING_PATTERN}}
- **Config management:** {{CONFIG_PATTERN}}

---

## User Personas

### Primary Persona: {{PERSONA_1_NAME}}

| Attribute | Detail |
|-----------|--------|
| Role | {{ROLE}} |
| Technical Level | {{TECH_LEVEL}} |
| Primary Goal | {{PRIMARY_GOAL}} |
| Key Pain Point | {{KEY_PAIN_POINT}} |
| Usage Context | {{USAGE_CONTEXT}} |

### Secondary Persona: {{PERSONA_2_NAME}}
_(Same structure as above)_

---

## Functional Requirements

### FR-001: {{FR_1_TITLE}} [MUST]

**Description:**
{{FR_1_DESCRIPTION}}

**Acceptance Criteria (Given/When/Then):**
1. **Given** {{PRECONDITION_1}}, **When** {{ACTION_1}}, **Then** {{EXPECTED_RESULT_1}}
2. **Given** {{PRECONDITION_2}}, **When** {{ACTION_2}}, **Then** {{EXPECTED_RESULT_2}}

**Negative Cases:**
1. **Given** {{INVALID_PRECONDITION}}, **When** {{INVALID_ACTION}}, **Then** {{ERROR_BEHAVIOR}}

**Priority:** MUST
**Traced to Epic:** EPIC-001
**Traced to Stories:** STORY-001, STORY-002

---

### FR-002: {{FR_2_TITLE}} [MUST/SHOULD/COULD]

_(Same structure as FR-001)_

---

## Non-Functional Requirements

### NFR-001: Performance [MUST]
**Requirement:** {{NFR_PERF_DESCRIPTION}}
**Target:** {{NFR_PERF_TARGET}}
**Measurement:** {{NFR_PERF_MEASUREMENT}}
**Validation Command:** `{{NFR_PERF_VALIDATION_CMD}}`

### NFR-002: Security [MUST]
**Requirement:** {{NFR_SEC_DESCRIPTION}}
**Constraints:** {{NFR_SEC_CONSTRAINTS}}
**Validation:** {{NFR_SEC_VALIDATION}}

### NFR-003: Compatibility [MUST]
**Backward Compatibility:** {{BACKWARD_COMPAT_REQUIREMENTS}}
**Breaking Changes Allowed:** Yes/No
**Migration Path (if breaking):** {{MIGRATION_PATH}}

### NFR-004: Code Quality [MUST]
**Test Coverage Target:** {{COVERAGE_TARGET}}%
**Lint Rules:** Follow existing project config
**Documentation:** {{DOC_REQUIREMENTS}}

---

## Epics and User Stories

### EPIC-001: {{EPIC_1_NAME}}

**Business Value:** {{EPIC_1_VALUE}}
**Related Requirements:** FR-001, FR-002, NFR-001

#### STORY-001: {{STORY_1_TITLE}}

```
As a {{USER_TYPE}},
I want {{CAPABILITY}},
So that {{BENEFIT}}.
```

**Acceptance Criteria:**
1. Given {{CONTEXT}}, when {{ACTION}}, then {{OUTCOME}}
2. Given {{CONTEXT}}, when {{ACTION}}, then {{OUTCOME}}

**Edge Cases:**
- {{EDGE_CASE_1}}: {{EXPECTED_BEHAVIOR_1}}
- {{EDGE_CASE_2}}: {{EXPECTED_BEHAVIOR_2}}

**Priority:** {{PRIORITY}}
**Complexity Estimate:** S / M / L
**Traced to FR:** FR-001

---

#### STORY-002: {{STORY_2_TITLE}}

_(Same structure as STORY-001)_

---

### EPIC-002: {{EPIC_2_NAME}}

_(Same structure as EPIC-001)_

---

## User Flows

### Flow 1: {{FLOW_1_NAME}} (Happy Path)

```
[Step 1: {{STEP_1}}]
    ↓
[Step 2: {{STEP_2}}]
    ↓ (success) / ↓ (failure → {{ERROR_HANDLING}})
[Step 3: {{STEP_3}}]
    ↓
[Step 4: {{STEP_4}} → Done]
```

**Entry Point:** {{ENTRY_POINT}}
**Exit Point:** {{EXIT_POINT}}
**Error States:** {{ERROR_STATES}}

---

## Assumptions and Dependencies

### Assumptions
1. {{ASSUMPTION_1}}
2. {{ASSUMPTION_2}}
3. {{ASSUMPTION_3}}

### Dependencies

| Dependency | Type | Required Before | Risk if Unavailable |
|------------|------|-----------------|---------------------|
| {{DEP_1}} | Internal/External | {{PHASE}} | {{RISK}} |
| {{DEP_2}} | Internal/External | {{PHASE}} | {{RISK}} |

---

## Constraints

### Hard Constraints (Non-Negotiable)
- {{HARD_CONSTRAINT_1}}
- {{HARD_CONSTRAINT_2}}

### Soft Constraints (Preferred)
- {{SOFT_CONSTRAINT_1}}
- {{SOFT_CONSTRAINT_2}}

---

## Out of Scope

| Feature / Capability | Reason | Future Phase? |
|----------------------|--------|---------------|
| {{OUT_1}} | {{REASON_1}} | Yes / No |
| {{OUT_2}} | {{REASON_2}} | Yes / No |

---

## Release Planning

### Phase 1: MVP
**Scope:** FR-001, FR-002
**Success Gate:** {{PHASE_1_GATE}}

### Phase 2: Enhancement
**Scope:** FR-003, FR-004
**Success Gate:** {{PHASE_2_GATE}}

---

## Risks and Mitigations

| Risk | Impact (H/M/L) | Probability (H/M/L) | Mitigation | Owner |
|------|-----------------|----------------------|------------|-------|
| {{RISK_1}} | {{IMPACT}} | {{PROB}} | {{MITIGATION}} | {{OWNER}} |
| {{RISK_2}} | {{IMPACT}} | {{PROB}} | {{MITIGATION}} | {{OWNER}} |

---

## Traceability Matrix

| FR ID | Business Goal | Epic | Stories | NFR Dependencies | Test Scenarios |
|-------|---------------|------|---------|------------------|----------------|
| FR-001 | {{GOAL}} | EPIC-001 | STORY-001, STORY-002 | NFR-001, NFR-003 | {{SCENARIOS}} |
| FR-002 | {{GOAL}} | EPIC-001 | STORY-003 | NFR-002 | {{SCENARIOS}} |

---

## PRD Validation Checklist

_This section MUST be verified against the actual codebase before the document is considered complete._

- [ ] All FRs have Given/When/Then acceptance criteria
- [ ] All FRs have at least one negative/edge case
- [ ] Every Story traces back to at least one FR
- [ ] Codebase patterns section reflects actual project conventions
- [ ] No FR contradicts existing CLAUDE.md constraints
- [ ] Out of scope items are explicit and justified
- [ ] NFRs have measurable targets with validation methods
- [ ] Backward compatibility impact is assessed
- [ ] Dependencies are verified as available in the environment

---

## Glossary

| Term | Definition |
|------|------------|
| {{TERM_1}} | {{DEFINITION_1}} |
| {{TERM_2}} | {{DEFINITION_2}} |

---

**Document End**
