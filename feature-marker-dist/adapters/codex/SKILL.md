---
name: feature-marker
description: Native Codex adapter instructions for the feature-marker CLI state machine.
---

# feature-marker for Codex

Use the repository CLI as the workflow authority:

```bash
feature-marker run <slug> --runtime codex --mode full
feature-marker resume <slug>
feature-marker status <slug>
```

The CLI owns worktree creation, checkpoints, phase order, and branch-only handoff.
Codex phase prompts are generated under `.feature-marker/features/<slug>/logs/`.
Do not write checkpoint state directly.
