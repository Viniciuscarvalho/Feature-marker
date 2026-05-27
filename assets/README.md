# Assets

This folder contains README visuals.

## Current Public Assets

- `banner.svg`: header banner.
- `skill-first-flow.svg`: usage diagram for the current skill-first workflow.

These are the assets that should be referenced from the README.

## Demo Guidance

Any future GIF or screenshot must show the current v1 path:

1. Install once:

   ```bash
   npx -y @viniciuscarvalho/feature-marker install --runtime all
   ```

2. Invoke from inside the LLM prompt:

   ```text
   Use feature-marker to implement billing-observability.
   ```

3. Show the generated artifact state:

   ```text
   tasks/{slug}/prd.md
   tasks/{slug}/techspec.md
   tasks/{slug}/tasks.md
   ```

4. Show the local branch handoff:

   ```bash
   git push -u origin feature-marker/billing-observability
   gh pr create --base main --head feature-marker/billing-observability
   ```

Do not show `/feature-marker`, an interactive menu, checkpoint JSON,
mandatory worktrees, automatic push, automatic PR creation, Ralph Loop, or
spec-driven mode as supported v1 behavior.
