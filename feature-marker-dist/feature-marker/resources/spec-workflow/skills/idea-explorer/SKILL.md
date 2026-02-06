---
name: idea-explorer
description: Collaborative exploration to refine ideas into clear requirements before spec writing. Explores user intent, requirements and design through iterative dialogue.
argument-hint: [topic] [--depth=<quick|normal|thorough>] [--output=<path>]
allowed-tools:
  - Read
  - Grep
  - Glob
  - Bash(git diff:*)
  - Bash(git status:*)
  - Bash(git log:*)
  - Bash(ls *)
  - Write
---

# Idea Explorer

Explore, understand and refine ideas ready to be turned into designs and specs.

## Overview

Through collaboration, help turn ideas into better understood initiatives and goals that can be used by the spec-orchestrator or spec-writer skill to create detailed specifications and implementation plans.

Start by understanding the current project context, then ask questions one at a time to refine the idea. Once you understand what you're building, present the approach and understanding as a succinct summary (200-500 words), checking after each section whether it looks right so far.

## Arguments

- `topic` (positional): The idea or topic to explore
- `--depth=<quick|normal|thorough>`: How deep to explore (default: normal)
  - `quick`: Minimal questions, faster to refined idea
  - `normal`: Balanced exploration
  - `thorough`: Deep dive with more alternatives explored
- `--output=<path>`: Write the refined idea to a file

## Configuration

Check for `.claude/spec-workflow/config.yaml` in the project. If present, use configured paths:

```yaml
paths:
  specs: "./specs"  # Where to save output if --output not specified
```

If no config exists, default to `./specs/`.

### Philosophy Injection

If `.claude/spec-workflow/philosophy/exploration.md` exists, read it and incorporate its guidance into your exploration process. This file contains the user's philosophy about what makes exploration complete, what questions to always ask, and what red flags to surface.

## The Process

**1. Understand the context:**

Check out the current project state first by reading the repository contents, docs, recent commits.

**2. Understanding the idea and develop the intention, problem space and opportunity:**

This purpose of this step is to narrow down and clarify the idea, its purpose, constraints and success criteria.

- Ask questions one at a time to refine the idea
- Prefer multiple choice questions when possible, but open-ended is fine too
- Only one question per message - if a topic needs more exploration, break it into multiple questions
- Where possible, provide 2-4 options to choose from
- Evaluate the options yourself before presenting them and provide a recommendation with reasoning
- Focus on understanding: problem to be solved, constraints, success criteria and the minimum viable solution
- Avoid feature creep - ruthlessly apply YAGNI (You Ain't Gonna Need It) to remove unnecessary features

Adjust depth based on `--depth` argument:
- `quick`: 2-3 key questions only
- `normal`: 4-6 questions covering core aspects
- `thorough`: 8+ questions, explore more alternatives

**3. High level solutionizing:**

Think deeply about the discussion that's been had so far and propose a high level approach to solving the problem.

- Propose 2-4 different approaches with trade-offs
- Present options conversationally with your recommendation and reasoning
- Lead with your recommended option and explain why

**4. Presenting the refined idea:**

Now that you understand the idea, problem, success criteria and what we're building, present the agreed design.

- Break it into sections of 100-200 words
- Ask after each section whether it looks right so far
- Key areas to cover are: architecture, components, data flow, error handling, testing
- Be ready to go back and clarify if something doesn't make sense

## After the Design

**Saving the output:**

If `--output` was specified, write the refined idea to that path.

**Handing over to the next stage:**

Ask the user if they'd like to hand this idea discovery to the spec-orchestrator skill to formalize as a spec. If they prefer to skip the review cycle, they can use spec-writer directly.

## Key Principles

- **One question at a time** - Don't overwhelm with multiple questions
- **Multiple choice preferred** - Easier to answer than open-ended when possible
- **YAGNI ruthlessly** - Remove unnecessary features from all designs
- **Explore alternatives** - Always propose 2-4 approaches before settling
- **Incremental validation** - Present design in sections, validate each
- **Be flexible** - Go back and clarify when something doesn't make sense
