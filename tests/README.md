# Tests

The deterministic suite focuses on the installer-only package surface:

```bash
npm test
```

Coverage includes dry-run install targets, temp `HOME` installs for Claude,
Codex, and Gemini, unsupported workflow command errors, static documentation
checks, and package dry-run contents.
