---
name: feature-marker
description: "Automate complete feature development lifecycle: PRD → Tech Spec → Tasks → Implementation → Tests → PR. AI-powered skill for Claude Code with TUI and macOS menubar apps. Structured outputs: JSON specs, task templates, test cases, PR descriptions. Integrates with Linear, GitHub, Notion. Use when: defining features, creating technical specifications, breaking down work, generating test cases, automating documentation, planning feature launches. Triggers: '/feature-marker prd-[name]', 'Create feature spec', 'Feature lifecycle', 'Generate tech spec', 'Create task list'."
---

# Feature Marker Skill

**Automate your complete feature development lifecycle: PRD → Tech Spec → Tasks → Implementation → Tests → PR**

## Quick Start

### Claude Code

```bash
/feature-marker prd-user-authentication
# Interactive mode
/feature-marker --interactive prd-notifications
```

### Command Line (NPM)

```bash
npx @viniciuscarvalho/feature-marker install
feature-marker prd-dark-theme
```

### Homebrew (macOS/Linux)

```bash
brew tap viniciuscarvalho/tap
brew install feature-marker
feature-marker-install
feature-marker prd-api-caching
```

### TUI (Terminal UI)

```bash
feature-marker-tui
```

### macOS Menubar

Click the Feature Marker icon in your menubar to access workflows instantly.

---

## Overview

Feature Marker guides you through the complete feature development workflow with AI assistance at each phase:

### 📋 **Phase 1: PRD (Product Requirements Document)**
Define what you're building:
- Problem statement
- User stories
- Success metrics
- Acceptance criteria

**Output:** Structured PRD JSON

### 🏗️ **Phase 2: Tech Spec (Technical Specification)**
Design the technical solution:
- Architecture overview
- Technology choices
- Data models
- API contracts
- Integration points

**Output:** JSON tech spec with diagrams

### ✅ **Phase 3: Tasks (Work Breakdown)**
Break down into actionable tasks:
- Implementation tasks
- Testing requirements
- Documentation tasks
- Time estimates

**Output:** Task list (JSON, Markdown, Linear format)

### 💻 **Phase 4: Implementation**
Write the code while maintaining spec alignment:
- Auto-generated templates
- Code structure guidance
- Best practices enforcement

**Output:** Code skeleton, implementation guide

### 🧪 **Phase 5: Tests**
Generate and organize test cases:
- Unit test templates
- Integration tests
- End-to-end test scenarios
- Test coverage targets

**Output:** Test case specifications (XCTest, Swift Testing format)

### 🔀 **Phase 6: PR (Pull Request)**
Auto-generate PR descriptions:
- Summary of changes
- Testing instructions
- Deployment notes
- Review checklist

**Output:** Ready-to-use PR description

---

## Key Features

### 🤖 **AI-Powered at Every Step**
Claude analyzes your requirements and generates structured outputs with minimal manual effort.

### 📁 **Structured Outputs**
All outputs are generated in JSON, Markdown, and platform-specific formats:
- `spec.json` — Complete feature specification
- `tasks.json` — Task breakdown with estimates
- `tests.json` — Test case specifications
- `pr-description.md` — Ready-to-paste PR template

### 🔗 **Platform Integration**
- **Linear** — Auto-create issues from task breakdowns
- **GitHub** — Generate PR descriptions, manage workflows
- **Notion** — Sync specs and tasks to your workspace
- **Slack** — Notify teams of phase completions

### 📝 **Project-Aware**
Feature Marker learns from your:
- Existing specs (patterns, terminology)
- Coding standards (from `.claude/CLAUDE.md`)
- Architecture decisions
- Team conventions

### 🎯 **Use Cases**

| Scenario | Workflow |
|----------|----------|
| **New feature launch** | PRD → Tech Spec → Tasks → Tests → PR |
| **Quick bug fix** | Tech Spec (lite) → Tasks → PR |
| **API design review** | Tech Spec deep-dive → Architecture review |
| **Test planning** | PRD + existing code → Test generation → QA handoff |
| **Documentation** | PRD + Spec → Auto-generated docs |

---

## Installation & Setup

### 1. **Install via NPM (Fastest)**

```bash
npx @viniciuscarvalho/feature-marker install
```

This copies skills to `~/.claude/skills/feature-marker/`

### 2. **Verify Installation**

```bash
npx @viniciuscarvalho/feature-marker status
```

Expected output:
```
✅ Feature Marker v2.0.0 installed
✅ TUI available: feature-marker-tui
✅ Claude Code integration: ready
✅ Platform integrations: linear, github, notion
```

### 3. **(Optional) Homebrew Installation**

```bash
brew tap viniciuscarvalho/tap
brew install feature-marker
feature-marker-install
```

---

## Usage Examples

### Example 1: PRD for User Authentication

```bash
/feature-marker prd-user-authentication
```

**Feature Marker will generate:**
- `features/prd-user-authentication/prd.json`
- `features/prd-user-authentication/prd.md`

Output includes:
- User personas
- User stories
- Acceptance criteria
- Success metrics

### Example 2: Full Lifecycle for Dark Theme Support

```bash
/feature-marker --full prd-dark-theme
```

This auto-generates all 6 phases:
1. PRD
2. Tech Spec (SwiftUI dark mode implementation)
3. Tasks (frontend, backend, testing, docs)
4. Tests (unit tests for theme switching, snapshot tests)
5. PR description (ready to paste)

**Outputs in:** `features/prd-dark-theme/{prd,spec,tasks,tests,pr-description}.{json,md}`

### Example 3: Tech Spec Only (Existing Feature)

```bash
/feature-marker spec --from-code .
```

Feature Marker analyzes your existing code and generates a tech spec documenting:
- Current architecture
- Data models
- API contracts
- Dependencies

---

## Platform Integrations

### Linear Integration

Create Linear issues automatically from task breakdown:

```bash
/feature-marker prd-notifications --create-linear
```

Feature Marker will:
1. Generate task breakdown
2. Create Linear project
3. Link to GitHub PR
4. Update Linear cycle

### GitHub Integration

Auto-generate PR descriptions:

```bash
/feature-marker pr-description --pr 123
```

### Notion Integration

Sync feature specs to Notion:

```bash
/feature-marker --sync-notion prd-payments
```

---

## Output Structure

All features generate a consistent directory structure:

```
features/
├── prd-user-authentication/
│   ├── prd.json              # Structured PRD
│   ├── prd.md                # Human-readable PRD
│   ├── spec.json             # Technical specification
│   ├── spec.md               # Design documentation
│   ├── tasks.json            # Task breakdown (Linear-compatible)
│   ├── tasks.md              # Markdown task list
│   ├── tests.json            # Test case specifications
│   ├── tests.md              # Test plan (human-readable)
│   └── pr-description.md     # Ready-to-use PR template
└── prd-dark-theme/
    └── ... (same structure)
```

**Note:** All JSON files include schema validation and can be imported directly into Linear, GitHub, Notion, or your CI/CD pipeline.

---

## Customization

### Project-Specific Standards

Create `.feature-marker.json` in your repo root:

```json
{
  "companyName": "Acme Inc",
  "productName": "Mobile App",
  "teamSize": 8,
  "testingFramework": "Swift Testing",
  "documentationStyle": "markdown",
  "integrations": ["linear", "github", "notion"],
  "templates": {
    "prd": "custom/prd-template.md",
    "spec": "custom/tech-spec-template.md"
  }
}
```

Feature Marker will respect these settings and auto-fill values like company name, preferred tech stack, etc.

---

## Tips & Tricks

### Tip 1: Incremental Development
Don't do all 6 phases at once. Start with PRD + Tech Spec, then generate tasks once requirements are locked.

### Tip 2: Reuse Specs
Use `--from-existing` to reference previous features and keep consistency:

```bash
/feature-marker prd-new-feature --from-existing prd-dark-theme
```

### Tip 3: Team Collaboration
Generate specs, commit to GitHub, and share PR links with your team for review.

### Tip 4: Testing Early
Generate test specs early (Phase 5) to guide implementation and prevent scope creep.

---

## Troubleshooting

### Q: How do I uninstall?

```bash
npx @viniciuscarvalho/feature-marker uninstall
# or
brew uninstall feature-marker
```

### Q: Can I customize templates?

Yes! Create a `.feature-marker.json` file in your repo (see Customization section).

### Q: Does this work with existing projects?

Absolutely. Use `--from-code .` to analyze existing code and generate specs.

### Q: Can I run this in CI/CD?

Yes! Feature Marker is CI-friendly and outputs JSON for automation:

```bash
feature-marker prd-api --output json | jq .spec > spec.json
```

---

## Community & Support

- **Issues:** https://github.com/Viniciuscarvalho/Feature-marker/issues
- **Contributing:** See `CONTRIBUTING.md`
- **Changelog:** See `CHANGELOG.md`

---

## License

MIT — See `LICENSE` for details.

---

**Made with ❤️ by Vinicius Carvalho**

If Feature Marker saves you time, consider:
- ⭐ Starring on GitHub
- 🔗 Sharing with your team
- 💬 Giving feedback on issues
