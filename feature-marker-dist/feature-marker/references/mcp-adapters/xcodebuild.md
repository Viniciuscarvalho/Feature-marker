# XcodeBuildMCP Adapter

MCP adapter for XcodeBuildMCP — provides Xcode project discovery, build configuration, and simulator execution.

## When to load

Load this adapter when `environment_manifest.json` contains an MCP entry with category `build` and adapter `references/mcp-adapters/xcodebuild.md`.

## Phase Integration

### Context Phase (context-gatherer)

Use `discover_projs` to gather project structure:

- Discover `.xcodeproj` / `.xcworkspace` files
- Extract available schemes and targets
- Identify build configurations (Debug/Release)

Add to `context.md`:

```
### XcodeBuildMCP Project Info
- Project: {project_name}
- Schemes: {list of schemes}
- Targets: {list of targets}
```

### Tasks Phase (spec-writer / spec-executor)

Use `session_set_defaults` to configure the build environment:

- Set scheme to the appropriate target
- Set destination to iOS Simulator
- Set configuration to Debug for development

### Implementation Phase (spec-executor per-task)

After each task that modifies Swift files, run `build_run_sim` as a **non-blocking** verification:

- Build the project targeting iOS Simulator
- Launch on simulator if build succeeds
- Report build errors for immediate feedback

**Important**: Build failures are warnings, not blockers. Unit tests passing is sufficient.

### Validation Phase (ios-workflow / feature-marker Phase 4)

Run full build verification before PR:

1. `session_set_defaults` — ensure correct scheme/destination
2. `build_run_sim` — full build + simulator launch
3. Capture build output for PR description

## Tool Reference

| Tool                   | Purpose                               | Phase                       |
| ---------------------- | ------------------------------------- | --------------------------- |
| `discover_projs`       | Find Xcode projects and schemes       | Context                     |
| `session_set_defaults` | Configure scheme, destination, config | Tasks / Validation          |
| `build_run_sim`        | Build and run on iOS Simulator        | Implementation / Validation |

## Fallback (CLI)

If XcodeBuildMCP is unavailable, fall back to CLI:

```bash
# Discover
xcodebuild -list

# Build
xcodebuild build -scheme {scheme} -destination 'platform=iOS Simulator,name=iPhone 16'

# Test
xcodebuild test -scheme {scheme} -destination 'platform=iOS Simulator,name=iPhone 16'
```
