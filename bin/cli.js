#!/usr/bin/env node
'use strict';

const { execFileSync } = require('child_process');
const fs = require('fs');
const os = require('os');
const path = require('path');

const pkg = require('../package.json');
const newVersion = pkg.version;
const skillDir = path.join(os.homedir(), '.claude', 'skills', 'feature-marker');
const versionFile = path.join(skillDir, 'version');
const installSh = path.join(__dirname, '..', 'feature-marker-dist', 'feature-marker', 'install.sh');

let existingVersion = null;
try {
  existingVersion = fs.readFileSync(versionFile, 'utf8').trim();
} catch (_) {}

if (existingVersion && existingVersion !== newVersion) {
  console.log(`Upgrading v${existingVersion} → v${newVersion}`);
} else if (!existingVersion) {
  console.log(`Installing v${newVersion}`);
} else {
  console.log(`Reinstalling v${newVersion}`);
}

if (!fs.existsSync(installSh)) {
  console.error(`Cannot find install.sh at: ${installSh}`);
  process.exit(1);
}

try {
  fs.chmodSync(installSh, 0o755);
} catch (_) {}

try {
  execFileSync(installSh, { stdio: 'inherit' });
} catch (_) {
  console.error('Installation failed.');
  process.exit(1);
}

fs.mkdirSync(skillDir, { recursive: true });
fs.writeFileSync(versionFile, newVersion + '\n');
