# Tests

The previous Bats files targeted removed `scripts/lib/*` shell modules and some
hardcoded private checkout paths. Native-adapter coverage now lives in
`feature-marker.test.js` and runs with:

```bash
npm test
```

The suite uses `FEATURE_MARKER_ADAPTER_MOCK=1` to validate the CLI state
machine, worktree isolation, checkpoint transitions, capability preflight, and
runtime adapter installation without making model calls.
