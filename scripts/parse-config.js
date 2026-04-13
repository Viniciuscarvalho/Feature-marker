#!/usr/bin/env node

// scripts/parse-config.js
// Simple YAML config parser — outputs flat KEY=value pairs for shell consumption
// Usage: eval "$(node scripts/parse-config.js orchestrator/config.yml)"

const fs = require('fs');
const path = require('path');

const configPath = process.argv[2] || path.join(__dirname, '..', 'orchestrator', 'config.yml');

if (!fs.existsSync(configPath)) {
  console.error(`# Config not found: ${configPath}`);
  process.exit(1);
}

const content = fs.readFileSync(configPath, 'utf-8');
const config = {};
let currentSection = '';

for (const line of content.split('\n')) {
  // Skip comments and empty lines
  if (/^\s*#/.test(line) || /^\s*$/.test(line)) continue;

  // Section header (top-level key with no value or empty array)
  const sectionMatch = line.match(/^(\w[\w_]*)\s*:\s*(\[\])?\s*(#.*)?$/);
  if (sectionMatch) {
    currentSection = sectionMatch[1];
    if (sectionMatch[2] === '[]') {
      config[`CFG_${currentSection.toUpperCase()}`] = '';
    }
    continue;
  }

  // Top-level key with inline value
  const topMatch = line.match(/^(\w[\w_]*)\s*:\s*(.+)/);
  if (topMatch) {
    const [, key, val] = topMatch;
    const cleanVal = val.replace(/#.*$/, '').trim();
    currentSection = '';
    config[`CFG_${key.toUpperCase()}`] = cleanVal;
    continue;
  }

  // Nested key under section
  const nestedMatch = line.match(/^\s+(\w[\w_]*)\s*:\s*(.+)/);
  if (nestedMatch && currentSection) {
    const [, key, val] = nestedMatch;
    const cleanVal = val.replace(/#.*$/, '').trim();
    config[`CFG_${currentSection.toUpperCase()}_${key.toUpperCase()}`] = cleanVal;
  }
}

// Output as shell-safe export statements
for (const [key, val] of Object.entries(config)) {
  // Escape single quotes in values
  const safe = val.replace(/'/g, "'\\''");
  console.log(`${key}='${safe}'`);
}
