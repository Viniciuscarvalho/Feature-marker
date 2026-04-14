#!/bin/bash
# scripts/route-tasks.sh
# Routes tasks to agents from agents-manifest.json
#
# Reads tasks.md, extracts task blocks with tags, matches against
# discovered agents, outputs a routing JSON array.
#
# Routing rules (priority order):
#   1. Phase exact match: phase=testing agent always gets testing-tagged tasks
#   2. Phase exact match: phase=review agent always gets review-tagged tasks
#   3. Capability match: agent capabilities intersect task tags
#   4. Capability count: most matching capabilities = higher score
#   5. Fallback: no match → "feature-marker" handles the task generically
#
# Planning phases (PRD, TechSpec, task generation) are NEVER routed —
# they always use feature-marker. Only implementation, testing, and
# review tasks are routable.
#
# Usage: route-tasks.sh <project_root> <manifest_file> <tasks_file>

set -euo pipefail

ROOT_DIR="${1:-$PWD}"
MANIFEST_FILE="${2:-$ROOT_DIR/.orchestrator/agents-manifest.json}"
TASKS_FILE="${3:-}"

# Find tasks.md if not provided
if [ -z "$TASKS_FILE" ] || [ ! -f "$TASKS_FILE" ]; then
  TASKS_FILE=$(find "$ROOT_DIR" -name "tasks.md" -path "*/prd-*" 2>/dev/null | head -1)
fi

if [ -z "$TASKS_FILE" ] || [ ! -f "$TASKS_FILE" ]; then
  echo "[]"
  exit 0
fi

if [ ! -f "$MANIFEST_FILE" ]; then
  echo "[]"
  exit 0
fi

node -e "
const fs = require('fs');
const path = require('path');

const tasksContent = fs.readFileSync('$TASKS_FILE', 'utf-8');
const manifest = JSON.parse(fs.readFileSync('$MANIFEST_FILE', 'utf-8'));
const agents = manifest.agents || [];

// Parse tasks from tasks.md — extract ## Task N: title + tags line
const tasks = [];
let current = null;

for (const line of tasksContent.split('\n')) {
  // Match task headers: ## Task N: title  or  ## N. title
  const taskMatch = line.match(/^##\s+(?:Task\s+)?(\d+)[.:]\s*(.+)/i);
  if (taskMatch) {
    if (current) tasks.push(current);
    current = {
      task_id: taskMatch[1],
      title: taskMatch[2].trim(),
      tags: [],
      body: ''
    };
    continue;
  }

  if (!current) continue;

  // Extract tags line
  const tagMatch = line.match(/^-?\s*tags?:\s*(.+)/i);
  if (tagMatch) {
    current.tags = tagMatch[1].split(',').map(t => t.trim().toLowerCase()).filter(Boolean);
    continue;
  }

  current.body += line + '\n';
}
if (current) tasks.push(current);

// Infer tags from task content if none explicitly set
tasks.forEach(task => {
  if (task.tags.length > 0) return;

  const text = (task.title + ' ' + task.body).toLowerCase();

  // Phase inference
  if (/\btest|spec|assert|expect|verify\b/.test(text)) task.tags.push('testing');
  else if (/\breview|audit|check|lint\b/.test(text)) task.tags.push('review');
  else task.tags.push('implementation');

  // Language/framework inference
  if (/\bswift|swiftui|uikit|xctest\b/.test(text)) task.tags.push('swift');
  if (/\breact|next|vue|angular|tsx?\b/.test(text)) task.tags.push('react');
  if (/\bpython|django|flask|pytest\b/.test(text)) task.tags.push('python');
  if (/\brust|cargo\b/.test(text)) task.tags.push('rust');
  if (/\bgo\s|golang|goroutine\b/.test(text)) task.tags.push('go');
});

// Route each task to best agent
const routing = tasks.map(task => {
  let bestAgent = null;
  let bestScore = 0;

  for (const agent of agents) {
    let score = 0;

    // Rule 1+2: Phase exact match (highest priority)
    if (agent.phase === 'testing' && task.tags.includes('testing')) score += 100;
    if (agent.phase === 'review' && task.tags.includes('review')) score += 100;
    if (agent.phase === 'implementation' && task.tags.includes('implementation')) score += 50;

    // Rule 3+4: Capability overlap
    const caps = agent.capabilities || [];
    const overlap = task.tags.filter(t => caps.includes(t));
    score += overlap.length * 10;

    // Phase=any gets a small bonus for any capability match
    if (agent.phase === 'any' && overlap.length > 0) score += 5;

    if (score > bestScore) {
      bestScore = score;
      bestAgent = agent;
    }
  }

  return {
    task_id: task.task_id,
    title: task.title,
    tags: task.tags,
    agent: bestAgent ? bestAgent.name : 'feature-marker',
    agent_path: bestAgent ? bestAgent.path : null,
    score: bestScore
  };
});

console.log(JSON.stringify(routing, null, 2));
"
