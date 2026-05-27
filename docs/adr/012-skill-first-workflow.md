# Keep Feature Marker Skill-First

Feature Marker remains a portable LLM skill instead of becoming a JavaScript-owned workflow engine. The npm package installs Claude, Codex, and Gemini skill assets, while the skill itself owns PRD, TechSpec, Tasks, implementation, verification, and branch handoff through artifact state under `tasks/{slug}/`.

**Status:** accepted

**Considered Options**

- Skill-first workflow with installer-only npm package.
- CLI-owned workflow engine with run, resume, status, checkpoints, and mandatory worktrees.

**Consequences**

- Users install with `npx -y @viniciuscarvalho/feature-marker install --runtime ...`, then invoke Feature Marker inside their LLM.
- JavaScript no longer owns phase state, checkpoint JSON, implementation execution, or PR handoff.
- Worktrees remain optional for dirty checkouts or explicit user requests, not mandatory isolation for every feature.
