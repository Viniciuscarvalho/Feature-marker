# Session Context

## User Prompts

### Prompt 1

Implement the following plan:

# Plan: MCP Awareness + Skill as Dispatcher

## Context

Feature-marker already has stack detection (`lib/stack-detector.sh`), context gathering, and prompt enrichment — but it has **zero MCP awareness** beyond a single boolean `xcodebuildmcp_available` in the iOS detector. The ios-workflow skill hardcodes XcodeBuildMCP usage but doesn't generalize to other MCPs.

This plan adds two interconnected features:

1. **MCP Awareness** — detect configured MCP servers ...

### Prompt 2

Essa feature de feed tem que está toda coberta por uma feature flag que eu consiga habilitar no Firebase Remote Config

