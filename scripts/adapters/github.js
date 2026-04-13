#!/usr/bin/env node

// scripts/adapters/github.js
// Fetches open issues by label via gh CLI

const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');

const LABEL = process.argv[2] || 'feature-marker';
const OUTPUT = 'orchestration-backlog.json';

let repoUrl = '';
try {
  repoUrl = execSync('gh repo view --json url -q .url', { encoding: 'utf-8' }).trim();
} catch { /* ignore — source_url will be null */ }

let raw;
try {
  raw = execSync(
    `gh issue list --label "${LABEL}" --state open --json number,title,body,labels,milestone,assignees,url --limit 100`,
    { encoding: 'utf-8' }
  );
} catch (e) {
  if (e.stderr && e.stderr.includes('not logged in')) {
    console.error('\u2717 gh is not authenticated. Run: gh auth login');
  } else {
    console.error('\u2717 Failed to fetch issues. Is `gh` installed and authenticated?');
  }
  process.exit(1);
}

const issues = JSON.parse(raw);

const items = issues.map(issue => ({
  id: `issue-${issue.number}`,
  source_id: `#${issue.number}`,
  source: 'github',
  source_url: issue.url || null,
  title: issue.title,
  body: issue.body || '',
  labels: (issue.labels || []).map(l => l.name).filter(l => !l.startsWith('priority/')),
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

fs.writeFileSync(OUTPUT, JSON.stringify(items, null, 2));
console.log(`\u2713 Fetched ${items.length} issues with label "${LABEL}" \u2192 ${OUTPUT}`);
