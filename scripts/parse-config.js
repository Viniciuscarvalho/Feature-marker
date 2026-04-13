#!/usr/bin/env node

// scripts/parse-config.js
// Simple YAML config parser — outputs flat KEY=value pairs for shell consumption
// Supports up to 3 levels of nesting: section.subsection.key
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
let section = '';      // 0-indent section
let subsection = '';   // 2-indent subsection

for (const line of content.split('\n')) {
  if (/^\s*#/.test(line) || /^\s*$/.test(line)) continue;

  // Measure indent
  const indent = line.match(/^(\s*)/)[1].length;

  // Top-level key (indent 0)
  if (indent === 0) {
    const m = line.match(/^(\w[\w_]*)\s*:\s*(.*)/);
    if (!m) continue;
    const [, key, rawVal] = m;
    const val = rawVal.replace(/#.*$/, '').trim();
    if (val && val !== '[]' && val !== '{}') {
      // Top-level key with value
      section = '';
      subsection = '';
      config[`CFG_${key.toUpperCase()}`] = val;
    } else {
      // Section header
      section = key;
      subsection = '';
      if (val === '[]') config[`CFG_${key.toUpperCase()}`] = '';
    }
    continue;
  }

  // Level 1 nested (indent 2)
  if (indent >= 2 && indent <= 3 && section) {
    const m = line.match(/^\s{2,3}(\w[\w_]*)\s*:\s*(.*)/);
    if (!m) continue;
    const [, key, rawVal] = m;
    const val = rawVal.replace(/#.*$/, '').trim();
    if (val && val !== '[]' && val !== '{}') {
      // Key with value under section
      subsection = '';
      config[`CFG_${section.toUpperCase()}_${key.toUpperCase()}`] = val;
    } else {
      // Subsection header (e.g., source.markdown:)
      subsection = key;
      if (val === '[]') config[`CFG_${section.toUpperCase()}_${key.toUpperCase()}`] = '';
    }
    continue;
  }

  // Level 2 nested (indent 4+)
  if (indent >= 4 && section && subsection) {
    const m = line.match(/^\s{4,}(\w[\w_]*)\s*:\s*(.+)/);
    if (!m) continue;
    const [, key, rawVal] = m;
    const val = rawVal.replace(/#.*$/, '').trim();
    config[`CFG_${section.toUpperCase()}_${subsection.toUpperCase()}_${key.toUpperCase()}`] = val;
  }
}

for (const [key, val] of Object.entries(config)) {
  const safe = val.replace(/'/g, "'\\''");
  console.log(`${key}='${safe}'`);
}
