# Playwright MCP Adapter

MCP adapter for Playwright — provides browser automation for E2E testing and visual validation.

## When to load

Load this adapter when `environment_manifest.json` contains an MCP entry with category `test` and adapter `references/mcp-adapters/playwright.md`.

## Phase Integration

### Context Phase (context-gatherer)

Detect E2E test infrastructure:

- Look for `playwright.config.ts` / `playwright.config.js`
- Check for existing E2E test files in `e2e/` or `tests/`
- Detect dev server configuration (port, start command)

Add to `context.md`:

```
### Playwright E2E Infrastructure
- Config: {config path}
- Base URL: {dev server URL}
- Existing tests: {count} files
```

### Tasks Phase (spec-writer)

When generating tasks, include E2E test criteria:

- Add browser assertion requirements for user-facing features
- Specify which pages/flows need E2E coverage
- Include visual regression checkpoints

### Implementation Phase (spec-executor per-task)

After implementing UI-facing tasks, use Playwright MCP for validation:

- `browser_navigate` — open the relevant page
- `browser_click` — interact with new UI elements
- `browser_screenshot` — capture visual state for verification

**Important**: E2E validation is non-blocking. Unit tests are the primary gate.

### Validation Phase (feature-marker Phase 4)

Run visual regression checks before PR:

1. Navigate to affected pages
2. Take screenshots of key states
3. Compare against baseline (if available)
4. Include screenshots in PR description

## Tool Reference

| Tool                 | Purpose                      | Phase                       |
| -------------------- | ---------------------------- | --------------------------- |
| `browser_navigate`   | Open URL in browser          | Implementation / Validation |
| `browser_click`      | Click elements on page       | Implementation / Validation |
| `browser_screenshot` | Capture page screenshot      | Implementation / Validation |
| `browser_type`       | Type text into inputs        | Implementation              |
| `browser_wait`       | Wait for elements/conditions | Implementation              |

## Fallback

If Playwright MCP is unavailable:

- Skip E2E validation
- Rely on unit tests and integration tests
- Suggest manual testing in PR description:

```
### Manual Testing Required
- [ ] Navigate to {page}
- [ ] Verify {expected behavior}
- [ ] Check responsive layout
```
