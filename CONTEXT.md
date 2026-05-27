# Feature Marker

Feature Marker is a portable LLM skill distribution for repeatable feature
delivery across Claude, Codex, and Gemini.

## Language

**Feature Marker**:
A skill-first workflow that turns one feature request into PRD, TechSpec, Tasks, verification, and branch handoff artifacts.
_Avoid_: CLI workflow engine, autonomous orchestrator

**Skill**:
The LLM-readable instruction file that owns the feature workflow.
_Avoid_: Binary runner, state machine

**Installer**:
The npm/npx package command that copies skill assets into supported runtime directories.
_Avoid_: Workflow CLI, task runner

**Artifact State**:
The feature's durable user-facing files under `tasks/{slug}/`.
_Avoid_: Checkpoint database, hidden workflow state

**Branch Handoff**:
The finish state where feature work is committed locally and exact push/PR commands are printed.
_Avoid_: Automatic PR creation, remote publish

**Runtime Adapter**:
The runtime-specific installed copy of the portable skill contract.
_Avoid_: Runtime-owned workflow engine, phase executor

## Relationships

- **Feature Marker** is distributed by the **Installer**.
- A **Runtime Adapter** is an installed copy of the **Skill** for one LLM runtime.
- The **Skill** reads and writes **Artifact State**.
- **Branch Handoff** ends the **Feature Marker** workflow without pushing or opening a PR.

## Example dialogue

> **Dev:** "Can I run Feature Marker with npx in this repo?"
> **Domain expert:** "Use npx only to install the Skill. Then ask Claude, Codex, or Gemini to use Feature Marker inside the project."

## Flagged ambiguities

- "CLI" previously meant both installer and workflow engine; resolved: **Installer** is setup only, and **Skill** owns the workflow.
- "State" previously meant checkpoint JSON and user artifacts; resolved: **Artifact State** under `tasks/{slug}/` is canonical.
