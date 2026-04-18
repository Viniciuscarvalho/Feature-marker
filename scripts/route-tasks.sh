#!/usr/bin/env bash
# scripts/route-tasks.sh
# Routes tasks to agents based on manifest capabilities.
# Two modes:
#   Default:        outputs JSON for agent dispatch
#   --context-mode: outputs markdown for context injection (zero extra invocations)
#
# Usage:
#   route-tasks.sh [--context-mode] <project_root> <manifest_file> <tasks_file>

set -euo pipefail

CONTEXT_MODE=false
if [ "${1:-}" = "--context-mode" ]; then
  CONTEXT_MODE=true
  shift
fi

PROJECT_ROOT="${1:?project_root required}"
MANIFEST_FILE="${2:?manifest_file required}"
TASKS_FILE="${3:?tasks_file required}"

if [ ! -f "$MANIFEST_FILE" ]; then
  echo "[]"
  exit 0
fi

if [ ! -f "$TASKS_FILE" ]; then
  echo "[]"
  exit 0
fi

# Extract tasks from tasks.md (simple parser: lines starting with "- [ ]" or "### Task")
TASKS_JSON=$(node -e "
  const fs = require('fs');
  const content = fs.readFileSync('$TASKS_FILE', 'utf-8');
  const tasks = [];
  const lines = content.split('\n');
  let currentTask = null;

  for (const line of lines) {
    const taskMatch = line.match(/^###?\s+(?:Task\s+)?(\S+)[:\s]+(.*)/i);
    if (taskMatch) {
      if (currentTask) tasks.push(currentTask);
      currentTask = { task_id: taskMatch[1], title: taskMatch[2].trim(), labels: [] };
    }
    const labelMatch = line.match(/labels?:\s*(.+)/i);
    if (labelMatch && currentTask) {
      currentTask.labels = labelMatch[1].split(',').map(l => l.trim());
    }
  }
  if (currentTask) tasks.push(currentTask);
  console.log(JSON.stringify(tasks));
" 2>/dev/null || echo "[]")

# Route tasks against manifest
ROUTING_JSON=$(node -e "
  const fs = require('fs');
  const manifest = JSON.parse(fs.readFileSync('$MANIFEST_FILE', 'utf-8'));
  const tasks = JSON.parse('$(echo "$TASKS_JSON" | sed "s/'/\\\\'/g")');
  const agents = manifest.agents || manifest || [];

  const routing = tasks.map(task => {
    let bestAgent = 'feature-marker';
    let bestScore = 0;

    for (const agent of agents) {
      const caps = agent.capabilities || [];
      const labels = task.labels || [];
      const overlap = labels.filter(l => caps.includes(l)).length;
      const score = overlap * 100 / Math.max(labels.length, 1);
      if (score > bestScore) {
        bestScore = score;
        bestAgent = agent.name || 'feature-marker';
      }
    }

    return {
      task_id: task.task_id,
      title: task.title,
      agent: bestAgent,
      score: Math.round(bestScore)
    };
  });

  console.log(JSON.stringify(routing, null, 2));
" 2>/dev/null || echo "[]")

if [ "$CONTEXT_MODE" = "true" ]; then
  # Output markdown for context injection
  ROUTING_COUNT=$(echo "$ROUTING_JSON" | node -p "JSON.parse(require('fs').readFileSync('/dev/stdin','utf-8')).length" 2>/dev/null || echo "0")
  if [ "$ROUTING_COUNT" -gt 0 ]; then
    echo ""
    echo "## Task Routing Hints"
    echo "The orchestrator recommends these agent approaches for tasks:"
    echo "$ROUTING_JSON" | node -e "
      const r = JSON.parse(require('fs').readFileSync('/dev/stdin','utf-8'));
      r.forEach(t => console.log('- Task ' + t.task_id + ': ' + t.title + ' → approach: ' + t.agent + ' (score: ' + t.score + ')'));
    " 2>/dev/null || true
  fi
else
  echo "$ROUTING_JSON"
fi
