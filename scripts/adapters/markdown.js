#!/usr/bin/env node

// scripts/adapters/markdown.js
// Parses features.md into orchestration-backlog.json

const fs = require('fs');
const path = require('path');

const INPUT = process.argv[2] || 'features.md';

if (!fs.existsSync(INPUT)) {
  console.error(`\u2717 File not found: ${INPUT}`);
  process.exit(1);
}

const content = fs.readFileSync(INPUT, 'utf-8');
const lines = content.split('\n');
const items = [];

let current = null;
const STATUS_MAP = {
  'FEAT': 'backlog',
  'WIP': 'in-progress',
  'DONE': 'done',
  'BLOCKED': 'blocked'
};

for (const line of lines) {
  // Parse header: ## [STATUS] id: title
  const match = line.match(/^##\s*\[(\w+)\]\s*([\w-]+):\s*(.+)/);

  if (match) {
    if (current) items.push(current);
    const [, rawStatus, id, title] = match;
    current = {
      id,
      source_id: `${path.basename(INPUT)}#${id}`,
      source: 'markdown',
      source_url: null,
      title: title.trim(),
      body: '',
      labels: [],
      priority: 'none',
      status: STATUS_MAP[rawStatus] || 'backlog',
      dependencies: [],
      metadata: {}
    };
    continue;
  }

  if (!current) continue;

  // Inline metadata
  const labelMatch = line.match(/^-\s*labels?:\s*(.+)/i);
  if (labelMatch) {
    current.labels = labelMatch[1].split(',').map(l => l.trim()).filter(Boolean);
    continue;
  }

  const prioMatch = line.match(/^-\s*priority:\s*(.+)/i);
  if (prioMatch) {
    current.priority = prioMatch[1].trim().toLowerCase();
    continue;
  }

  const depMatch = line.match(/^-?\s*depends?\s+on:\s*([\w-,\s]+)/i);
  if (depMatch) {
    current.dependencies = depMatch[1].split(',').map(d => d.trim()).filter(Boolean);
    continue;
  }

  // Everything else is body
  current.body += line + '\n';
}

if (current) items.push(current);

// Trim body, extract inline priority from title [p:high]
items.forEach(item => {
  item.body = item.body.trim();
  const prioInTitle = item.title.match(/\[p:(high|medium|low)\]/i);
  if (prioInTitle && item.priority === 'none') {
    item.priority = prioInTitle[1].toLowerCase();
    item.title = item.title.replace(/\s*\[p:\w+\]/i, '').trim();
  }
});

const output = JSON.stringify(items, null, 2);
const outPath = path.join(path.dirname(INPUT), 'orchestration-backlog.json');
fs.writeFileSync(outPath, output);
console.log(`\u2713 Parsed ${items.length} features from ${INPUT}`);
