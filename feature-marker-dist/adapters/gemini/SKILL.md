---
name: feature-marker
description: Native Gemini adapter instructions for the feature-marker CLI state machine.
---

# feature-marker for Gemini

Use the repository CLI as the workflow authority:

```bash
feature-marker run <slug> --runtime gemini --mode full
feature-marker resume <slug>
feature-marker status <slug>
```

The CLI owns worktree creation, checkpoints, phase order, and branch-only handoff.
Gemini phase prompts are generated under `.feature-marker/features/<slug>/logs/`.
Do not write checkpoint state directly.
