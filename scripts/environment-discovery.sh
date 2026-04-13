#!/usr/bin/env bash
# scripts/environment-discovery.sh
# Discovers the current development environment and outputs JSON manifest.
# Re-run between features to detect newly installed deps/tools.

set -euo pipefail

node -e "
const { execSync } = require('child_process');
const fs = require('fs');

function cmd(c) {
  try { return execSync(c, { encoding: 'utf-8', timeout: 5000 }).trim(); }
  catch { return null; }
}

const manifest = {
  timestamp: new Date().toISOString(),
  node: cmd('node --version'),
  npm: cmd('npm --version'),
  git: cmd('git --version'),
  gh: cmd('gh --version 2>/dev/null')?.split('\\n')[0] || null,
  python: cmd('python3 --version') || cmd('python --version'),
  rust: cmd('rustc --version'),
  go: cmd('go version'),
  swift: cmd('swift --version 2>/dev/null')?.split('\\n')[0] || null,
  package_managers: {
    npm: !!cmd('which npm'),
    yarn: !!cmd('which yarn'),
    pnpm: !!cmd('which pnpm'),
    bun: !!cmd('which bun'),
    pip: !!cmd('which pip3') || !!cmd('which pip'),
    cargo: !!cmd('which cargo'),
  },
  project_files: {
    package_json: fs.existsSync('package.json'),
    cargo_toml: fs.existsSync('Cargo.toml'),
    requirements_txt: fs.existsSync('requirements.txt'),
    go_mod: fs.existsSync('go.mod'),
    package_swift: fs.existsSync('Package.swift'),
  }
};

console.log(JSON.stringify(manifest, null, 2));
"
