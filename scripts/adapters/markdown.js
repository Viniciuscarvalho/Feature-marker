#!/usr/bin/env node

// Parse: features.md into orchestration-backlog.json

// @ts-nocheck no external deps needed
const fs = require('fs');
const path = require('path');

const FEATURES_PATH = process.argv[2] || 'features.md';

// Parse the markdown structure into JSON

const content = fs.readFileSync(FEATURES_PATH, 'utf-8');
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
  const headerMatch = line.match(/^##\s*\[(\w+)\]\s*([\w-]+):\s*(.+)/);

  if (headerMatch) {
    if (current) items.push(current);
    const [, status, id, title] = headerMatch;
    current = {
      id,
      source_id: `features.md#${id}`,
      source: 'markdown',
      title: title.trim(),
      body: '',
      labels: [],
      priority: 'none',
      status: STATUS_MAP[status] || 'backlog',
      dependencies: [],
      metadata: {}
    };
    continue;
  }

  if (!current) continue;

  // try to detect inline metadata
  const labelMatch = line.match(/^-\s*labels?:\s*(.+)/i);
  if (labelMatch) {
    current.labels = labelMatch[1].split(',').map(l => l.trim());
    continue;
  }

  const prioMatch = line.match(/^-\s*priority:\s*(.+)/i);
  if (prioMatch) {
    current.priority = prioMatch[1].trim();
    continue;
  }

  const depMatch = line.match(/depends\s+on:\s*([\w-,\s]+)/i);
  if (depMatch) {
    current.dependencies = depMatch[1].split(',').map(d => d.trim());
    continue;
  }

  // everything else is body
  if (current) {
    current.body += line + '\n';
  }
}

// don't forget last item
if (current) items.push(current);

// trim body whitespace
items.forEach(item => {
  item.body = item.body.trim();
});

const output = JSON.stringify(items, null, 2);
const outPath = path.join(path.dirname(FEATURES_PATH), 'orchestration-backlog.json');
fs.writeFileSync(outPath, output);
console.log(`\u2713 Parsed ${items.length} features \u2192 ${outPath}`);
