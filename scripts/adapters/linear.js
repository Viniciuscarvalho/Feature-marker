#!/usr/bin/env node

// scripts/adapters/linear.js
// Fetches Linear issues by project/team and outputs backlog.json
// Usage: LINEAR_API_KEY=... node linear.js <TEAM_KEY>

const https = require('https');
const fs = require('fs');

const API_KEY = process.env.LINEAR_API_KEY;
const TEAM = process.argv[2] || 'ENG';
const OUTPUT = 'orchestration-backlog.json';

if (!API_KEY) {
  console.error('\u2717 LINEAR_API_KEY env var is not set');
  process.exit(1);
}

const PRIO_MAP = { 0: 'none', 1: 'high', 2: 'high', 3: 'medium', 4: 'low' };

const STATE_MAP = {
  'started': 'in-progress',
  'unstarted': 'backlog',
  'completed': 'done',
  'cancelled': 'done',
  'backlog': 'backlog',
};

const query = JSON.stringify({
  query: `{
    issues(filter: { team: { key: { eq: "${TEAM}" } } }) {
      nodes {
        id
        identifier
        title
        description
        url
        priority
        state { name type }
        labels { nodes { name } }
      }
    }
  }`
});

const options = {
  hostname: 'api.linear.app',
  path: '/graphql',
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'Authorization': API_KEY,
  }
};

const req = https.request(options, (res) => {
  let data = '';
  res.on('data', chunk => data += chunk);
  res.on('end', () => {
    try {
      const parsed = JSON.parse(data);

      if (parsed.errors) {
        console.error('\u2717 Linear API error:', parsed.errors[0].message);
        process.exit(1);
      }

      const nodes = parsed.data.issues.nodes;

      const items = nodes.map(issue => ({
        id: issue.identifier,
        source_id: issue.identifier,
        source: 'linear',
        source_url: issue.url || null,
        title: issue.title,
        body: issue.description || '',
        labels: issue.labels.nodes.map(l => l.name),
        priority: PRIO_MAP[issue.priority] || 'none',
        status: STATE_MAP[issue.state.type] || 'backlog',
        dependencies: [],
        metadata: { url: issue.url }
      }));

      fs.writeFileSync(OUTPUT, JSON.stringify(items, null, 2));
      console.log(`\u2713 Fetched ${items.length} issues from Linear team "${TEAM}" \u2192 ${OUTPUT}`);
    } catch (e) {
      console.error('\u2717 Failed to parse Linear response:', e.message);
      process.exit(1);
    }
  });
});

req.on('error', (e) => {
  if (e.message.includes('ECONNREFUSED') || e.message.includes('getaddrinfo')) {
    console.error('\u2717 Cannot reach Linear API. Check your network connection.');
  } else {
    console.error('\u2717 Linear API request failed:', e.message);
  }
  process.exit(1);
});

req.write(query);
req.end();
