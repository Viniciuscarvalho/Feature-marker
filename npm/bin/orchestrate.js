#!/usr/bin/env node
// npm/bin/orchestrate.js
// NPX wrapper — sets ORCHESTRATOR_HOME and calls orchestrate.sh

const { execSync } = require('child_process');
const path = require('path');

const orchestratorHome = path.join(__dirname, '..', '..', 'scripts');
const args = process.argv.slice(2).join(' ');

try {
  execSync(`bash "${orchestratorHome}/orchestrate.sh" ${args}`, {
    stdio: 'inherit',
    cwd: process.cwd(),
    env: { ...process.env, ORCHESTRATOR_HOME: orchestratorHome }
  });
} catch (e) {
  process.exit(e.status || 1);
}
