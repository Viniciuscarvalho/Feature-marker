#!/usr/bin/env node

// scripts/adapters/github.js
// Fetches issues by label via gh CLI and outputs backlog.json

const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');

const LABEL = process.argv[2] || 'feature-marker';
const OUTPUT = 'orchestration-backlog.json';

let issues;
try {
  const raw = execSync(
    `gh issue list --label "${LABEL}" --json number,title,body,labels,milestone,assignees --limit 100`,
    { encoding: 'utf-8' }
  );
  issues = JSON.parse(raw);
} catch (e) {
  console.error('✗ Failed to fetch issues. Is `gh` installed and authenticated?');
  process.exit(1);
}

const items = issues.map(issue => ({
  id: `issue-${issue.number}`,
  source_id: `#${issue.number}`,
  source: 'github',
  title: issue.title,
  body: issue.body || '',
  labels: (issue.labels || []).map(l => l.name).filter(l => l !== LABEL),
  priority: issue.labels?.some(l => l.name === 'priority/high') ? 'high'
          : issue.labels?.some(l => l.name === 'priority/medium') ? 'medium'
          : issue.labels?.some(l => l.name === 'priority/low') ? 'low' : 'none',
  status: 'backlog',
  dependencies: [],
  metadata: {
    assignees: issue.assignees?.map(a => a.login) || [],
    milestone: issue.milestone?.title || null,
  }
}));

const output = JSON.stringify(items, null, 2);
fs.writeFileSync(OUTPUT, output);
console.log(`\u2713 Fetched ${items.length} issues with label "${LABEL}" \u2192 ${OUTPUT}`);
