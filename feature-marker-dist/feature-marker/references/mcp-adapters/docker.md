# Docker MCP Adapter

MCP adapter for Docker — provides container build verification and deployment validation.

## When to load

Load this adapter when `environment_manifest.json` contains an MCP entry with category `deployment` and adapter `references/mcp-adapters/docker.md`.

## Phase Integration

### Context Phase (context-gatherer)

Detect container infrastructure:

- Look for `Dockerfile`, `docker-compose.yml`, `docker-compose.yaml`
- Check for `.dockerignore`
- Identify multi-stage builds or service definitions

Add to `context.md`:

```
### Docker Infrastructure
- Dockerfile: {path}
- Compose: {path or "none"}
- Services: {list from compose}
```

### Implementation Phase (spec-executor per-task)

After tasks that modify infrastructure files (Dockerfile, docker-compose, nginx configs):

- Run `docker build` verification to catch build errors early
- **Non-blocking**: build failures are warnings

### Validation Phase (feature-marker Phase 4)

Run container build check before PR:

1. `docker build -t {project}-test .` — verify image builds
2. If compose exists: `docker compose config` — validate config
3. Report build status in PR description

## Fallback (CLI)

If Docker MCP is unavailable, fall back to CLI:

```bash
# Verify Dockerfile builds
docker build -t test-build . --no-cache

# Validate compose config
docker compose config

# Check image size
docker images test-build --format "{{.Size}}"
```
