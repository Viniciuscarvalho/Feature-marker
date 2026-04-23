#!/usr/bin/env node
// sanitize-backlog.js — Centralized injection-sanitization post-processor.
//
// Reads orchestration-backlog.json, runs each item's title/body/labels through
// the sanitization rules defined in lib/sanitize.sh (via child_process), and
// rewrites the file with cleaned items. Items that score above the quarantine
// threshold are flagged with a "quarantined" property and their body replaced
// with a safe placeholder.
//
// Usage:
//   node scripts/sanitize-backlog.js [backlog-path]
//
// Respects SANITIZE_MODE env var (strict|relaxed|off).

'use strict';
const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');

const BACKLOG_PATH = process.argv[2] || path.join(process.cwd(), '.orchestrator', 'orchestration-backlog.json');
const SANITIZE_SCRIPT = path.join(__dirname, 'lib', 'sanitize.sh');
const SANITIZE_MODE = process.env.SANITIZE_MODE || 'strict';
const SCORE_THRESHOLD = 2;

if (SANITIZE_MODE === 'off') {
  process.exit(0);
}

if (!fs.existsSync(BACKLOG_PATH)) {
  process.stderr.write(`sanitize-backlog: no backlog at ${BACKLOG_PATH}\n`);
  process.exit(0);
}

let items;
try {
  items = JSON.parse(fs.readFileSync(BACKLOG_PATH, 'utf-8'));
} catch (e) {
  process.stderr.write(`sanitize-backlog: failed to parse backlog: ${e.message}\n`);
  process.exit(1);
}

if (!Array.isArray(items)) {
  process.stderr.write('sanitize-backlog: backlog is not an array, skipping\n');
  process.exit(0);
}

function detectInjectionScore(text) {
  if (!text) return 0;
  const patterns = [
    /ignore\s+(all\s+)?(previous|prior|above)\s+instructions?/i,
    /you are now/i,
    /disregard\s+(your|all)/i,
    /forget\s+(everything|all)\s+(you|above)/i,
    /act as\s+(if you are|a|an)\s/i,
    /pretend\s+(you are|to be)/i,
    /your\s+(new|real|true)\s+(role|persona|instructions?)\s+(is|are)/i,
    /from now on[,.]\s*(you|always|never|do)/i,
    /(DAN|STAN|AIM|JAILBREAK):/i,
    /override\s+(safety|security|ethical)\s+(guidelines|rules|constraints)/i,
    /===RULES===|===SYSTEM===|===OVERRIDE===/,
    /\[SYSTEM\]|\[ADMIN\]|\[ASSISTANT\]/,
    /IGNORE_PREVIOUS|NEW_INSTRUCTIONS/,
  ];
  const exfilPatterns = [
    /cat\s+~\/\.(ssh|claude|gnupg|aws|config)/i,
    /\/etc\/passwd|\/etc\/shadow/,
    /\bid_rsa\b/,
    /\.(pem|p12|pfx|key)\b/,
    /\$HOME\/\./,
  ];

  let score = 0;
  for (const pat of patterns) {
    if (pat.test(text)) score += 1;
  }
  for (const pat of exfilPatterns) {
    if (pat.test(text)) score += 2;
  }
  // Unicode direction overrides
  if (/[‮﻿​]/.test(text)) score += 1;
  return score;
}

function stripInjectionMarkers(text) {
  if (!text) return text;
  return text
    .split('\n')
    .filter(line => {
      return ![
        /ignore\s+(all\s+)?(previous|prior|above)\s+instructions?/i,
        /you are now/i,
        /===RULES===|===SYSTEM===|===OVERRIDE===/,
        /\[SYSTEM\]|\[ADMIN\]|\[ASSISTANT\]/,
        /IGNORE_PREVIOUS|NEW_INSTRUCTIONS/,
        /cat\s+~\/\.(ssh|claude|gnupg|aws|config)/i,
        /\/etc\/passwd|\/etc\/shadow/,
        /pretend\s+(you are|to be)/i,
        /from now on[,.]\s*(you|always|never|do)/i,
        /(DAN|STAN|AIM|JAILBREAK):/i,
      ].some(pat => pat.test(line));
    })
    .join('\n')
    .replace(/[‮﻿​]/g, '');
}

let dirty = false;
const sanitized = items.map(item => {
  const titleScore = detectInjectionScore(item.title || '');
  const bodyScore = detectInjectionScore(item.body || '');
  const totalScore = titleScore + bodyScore;

  if (totalScore === 0) return item;

  dirty = true;
  process.stderr.write(
    `sanitize-backlog: item "${(item.id || item.title || '').slice(0, 40)}" injection score=${totalScore}\n`
  );

  if (SANITIZE_MODE === 'strict' && totalScore >= SCORE_THRESHOLD) {
    process.stderr.write(
      `sanitize-backlog: QUARANTINED item "${(item.id || '').slice(0, 40)}" (score ${totalScore} >= ${SCORE_THRESHOLD})\n`
    );
    return {
      ...item,
      title: stripInjectionMarkers(item.title || ''),
      body: `[QUARANTINED: injection markers detected, score=${totalScore}]`,
      labels: Array.isArray(item.labels) ? item.labels : [],
      quarantined: true,
      quarantine_score: totalScore,
    };
  }

  return {
    ...item,
    title: stripInjectionMarkers(item.title || ''),
    body: stripInjectionMarkers(item.body || ''),
  };
});

if (dirty) {
  const tmp = BACKLOG_PATH + '.tmp.' + process.pid;
  fs.writeFileSync(tmp, JSON.stringify(sanitized, null, 2));
  fs.renameSync(tmp, BACKLOG_PATH);
  process.stderr.write(`sanitize-backlog: rewrote ${BACKLOG_PATH}\n`);
} else {
  process.stderr.write('sanitize-backlog: no injection markers found\n');
}
