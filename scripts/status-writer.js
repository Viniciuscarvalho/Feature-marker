#!/usr/bin/env node

// scripts/status-writer.js
// Atomically writes .orchestrator/status.json from per-feature state files.
// Also outputs a terminal progress display.
//
// Usage: node status-writer.js [--terminal] [--json]

const fs = require('fs');
const path = require('path');

const ROOT = process.env.ROOT_DIR || path.join(__dirname, '..');
const CONFIG_DIR = path.join(ROOT, '.orchestrator');
const STATE_DIR = path.join(CONFIG_DIR, 'state');
const STATUS_FILE = path.join(CONFIG_DIR, 'status.json');

const showTerminal = process.argv.includes('--terminal');
const showJson = process.argv.includes('--json') || !showTerminal;

// Collect feature states
const features = [];
const summary = { total: 0, done: 0, in_progress: 0, queued: 0, blocked: 0, failed: 0 };

if (fs.existsSync(STATE_DIR)) {
  for (const dir of fs.readdirSync(STATE_DIR)) {
    const statusFile = path.join(STATE_DIR, dir, 'status.json');
    if (!fs.existsSync(statusFile)) continue;

    const s = JSON.parse(fs.readFileSync(statusFile, 'utf-8'));

    // Read results if available
    let pr_url = null;
    let duration = 0;
    const resultsFile = path.join(STATE_DIR, dir, 'results.json');
    if (fs.existsSync(resultsFile)) {
      const r = JSON.parse(fs.readFileSync(resultsFile, 'utf-8'));
      pr_url = r.pr_url || null;
      duration = r.duration_seconds || 0;
    }

    features.push({
      id: s.feature_id,
      title: s.feature_id,
      status: s.status,
      phase: s.phase,
      pr_url,
      duration_seconds: duration,
      created_at: s.created_at,
      updated_at: s.updated_at,
    });

    summary.total++;
    switch (s.status) {
      case 'done':
      case 'pr-created':
        summary.done++;
        break;
      case 'in-progress':
        summary.in_progress++;
        break;
      case 'created':
      case 'ready':
        summary.queued++;
        break;
      case 'failed':
        summary.failed++;
        break;
      case 'blocked':
        summary.blocked++;
        break;
    }
  }
}

const statusObj = {
  updated_at: new Date().toISOString(),
  features,
  summary,
};

// Write status.json atomically
const tmpFile = STATUS_FILE + '.tmp';
fs.writeFileSync(tmpFile, JSON.stringify(statusObj, null, 2));
fs.renameSync(tmpFile, STATUS_FILE);

if (showJson) {
  console.log(JSON.stringify(statusObj, null, 2));
}

// Terminal progress display
if (showTerminal) {
  const PHASES = ['pending', 'analysis', 'implementation', 'tests', 'review', 'complete'];
  const BAR_LEN = 12;

  console.log('');
  console.log('feature-marker Orchestration');
  console.log('──────────────────────────────');
  console.log(
    `Active: ${summary.in_progress} | Blocked: ${summary.blocked} | ` +
    `Queued: ${summary.queued} | Done: ${summary.done} | Failed: ${summary.failed}`
  );
  console.log('');

  for (const f of features) {
    // Calculate progress bar
    let phaseIdx = PHASES.indexOf(f.phase);
    if (phaseIdx < 0) phaseIdx = 0;
    if (f.status === 'done' || f.status === 'pr-created') phaseIdx = PHASES.length - 1;
    const filled = Math.round((phaseIdx / (PHASES.length - 1)) * BAR_LEN);
    const bar = '█'.repeat(filled) + '░'.repeat(BAR_LEN - filled);

    // Status label
    let label = f.phase;
    if (f.status === 'done' || f.status === 'pr-created') label = 'done';
    if (f.status === 'failed') label = 'FAILED';

    // PR info
    const prInfo = f.pr_url ? ` (${f.pr_url})` : '';

    console.log(`  ${f.id.padEnd(12)} ${bar}  ${label.padEnd(16)}${prInfo}`);
  }

  console.log('');
}
