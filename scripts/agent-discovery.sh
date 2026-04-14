#!/bin/bash
# scripts/agent-discovery.sh
# Scans the project for agents and builds agents-manifest.json
#
# Scan locations (in order, following symlinks):
#   .claude/agents/*.md
#   .claude/agents/**/*.md
#
# Each file must have YAML frontmatter with at least `name` and `description`.
# Optional: `capabilities` list and `phase` mapping.

set -euo pipefail

PROJECT_ROOT="${1:-$PWD}"
MANIFEST="${2:-$PROJECT_ROOT/.orchestrator/agents-manifest.json}"

AGENT_DIR="$PROJECT_ROOT/.claude/agents"

if [ ! -d "$AGENT_DIR" ]; then
  echo "[]" | node -e "
    const agents = { discovered_at: new Date().toISOString(), project_root: '$PROJECT_ROOT', agents: [] };
    require('fs').mkdirSync('$(dirname "$MANIFEST")', { recursive: true });
    require('fs').writeFileSync('$MANIFEST', JSON.stringify(agents, null, 2));
  "
  echo "  [discovery] No agents directory found at $AGENT_DIR — empty manifest"
  exit 0
fi

# Use node for reliable YAML frontmatter parsing
node -e "
const fs = require('fs');
const path = require('path');

const projectRoot = '$PROJECT_ROOT';
const agentDir = '$AGENT_DIR';
const manifestPath = '$MANIFEST';

// Recursively find all .md files
function findMdFiles(dir) {
  const results = [];
  if (!fs.existsSync(dir)) return results;
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      results.push(...findMdFiles(full));
    } else if (entry.name.endsWith('.md')) {
      results.push(full);
    }
  }
  return results;
}

// Extract YAML frontmatter between --- markers
function extractFrontmatter(content) {
  if (!content.startsWith('---')) return null;
  const end = content.indexOf('---', 3);
  if (end === -1) return null;
  return content.substring(3, end).trim();
}

// Parse simple YAML key-value pairs and lists
function parseFrontmatter(fm) {
  const result = {};
  let currentKey = null;
  let currentList = null;

  for (const line of fm.split('\n')) {
    // List item under current key
    const listMatch = line.match(/^\s+-\s+(.+)/);
    if (listMatch && currentKey) {
      if (!currentList) currentList = [];
      currentList.push(listMatch[1].trim());
      continue;
    }

    // Flush previous list
    if (currentList && currentKey) {
      result[currentKey] = currentList;
      currentList = null;
    }

    // Key: value pair
    const kvMatch = line.match(/^(\w[\w_-]*)\s*:\s*(.*)/);
    if (kvMatch) {
      currentKey = kvMatch[1];
      const val = kvMatch[2].trim();
      if (val && !val.startsWith('>')) {
        // Check for inline array [a, b, c]
        const inlineArr = val.match(/^\[(.+)\]$/);
        if (inlineArr) {
          result[currentKey] = inlineArr[1].split(',').map(s => s.trim().replace(/[\"']/g, ''));
        } else {
          result[currentKey] = val.replace(/^[\"']|[\"']$/g, '');
        }
        currentKey = null;
      }
      // If val is empty or >, expect list items next
    }
  }

  // Flush final list
  if (currentList && currentKey) {
    result[currentKey] = currentList;
  }

  return result;
}

const agents = [];
const files = findMdFiles(agentDir);

for (const file of files) {
  const content = fs.readFileSync(file, 'utf-8');
  const fmRaw = extractFrontmatter(content);
  if (!fmRaw) continue;

  const fm = parseFrontmatter(fmRaw);
  if (!fm.name) continue;

  const relPath = path.relative(projectRoot, file);

  agents.push({
    name: fm.name,
    description: fm.description || '',
    path: relPath,
    capabilities: Array.isArray(fm.capabilities) ? fm.capabilities : [],
    phase: fm.phase || 'any'
  });
}

const manifest = {
  discovered_at: new Date().toISOString(),
  project_root: projectRoot,
  agents
};

fs.mkdirSync(path.dirname(manifestPath), { recursive: true });
fs.writeFileSync(manifestPath, JSON.stringify(manifest, null, 2));
console.log('  [discovery] Found ' + agents.length + ' agents → ' + manifestPath);
agents.forEach(a => console.log('    - ' + a.name + ' [' + a.phase + '] (' + a.capabilities.join(', ') + ')'));
"
