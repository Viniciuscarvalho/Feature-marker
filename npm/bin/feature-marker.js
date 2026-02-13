#!/usr/bin/env node
/**
 * feature-marker CLI
 * Installs the feature-marker skill for Claude Code
 */

import { fileURLToPath } from 'url';
import { dirname, join } from 'path';
import { existsSync, mkdirSync, cpSync, chmodSync, readdirSync } from 'fs';
import { homedir } from 'os';
import { execSync } from 'child_process';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
const PACKAGE_ROOT = join(__dirname, '..');

const VERSION = '4.0.0';

const COLORS = {
  reset: '\x1b[0m',
  bold: '\x1b[1m',
  green: '\x1b[32m',
  yellow: '\x1b[33m',
  blue: '\x1b[34m',
  cyan: '\x1b[36m',
  red: '\x1b[31m',
};

function log(msg, color = '') {
  console.log(`${color}${msg}${COLORS.reset}`);
}

function success(msg) {
  log(`✓ ${msg}`, COLORS.green);
}

function info(msg) {
  log(`ℹ ${msg}`, COLORS.blue);
}

function warn(msg) {
  log(`⚠ ${msg}`, COLORS.yellow);
}

function error(msg) {
  log(`✗ ${msg}`, COLORS.red);
}

function banner() {
  console.log(`
${COLORS.cyan}╔═══════════════════════════════════════════════════════════╗
║                                                               ║
║   ${COLORS.bold}feature-marker${COLORS.reset}${COLORS.cyan}                                            ║
║   AI-Powered Feature Development Workflow                     ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝${COLORS.reset}
`);
}

function showHelp() {
  banner();
  console.log(`${COLORS.bold}Usage:${COLORS.reset}
  npx feature-marker [command] [options]

${COLORS.bold}Commands:${COLORS.reset}
  install       Install feature-marker skill to ~/.claude
  uninstall     Remove feature-marker skill from ~/.claude
  status        Check installation status
  help          Show this help message

${COLORS.bold}Options:${COLORS.reset}
  --silent      Suppress output (for postinstall)
  --with-tui    Also install the TUI application (requires Rust)
  --dry-run     Show what would be installed without making changes
  --version     Show version

${COLORS.bold}Examples:${COLORS.reset}
  npx feature-marker install
  npx feature-marker install --with-tui
  npx feature-marker uninstall
  npx feature-marker status

${COLORS.bold}After installation:${COLORS.reset}
  In Claude Code, use: /feature-marker <feature-slug>
  Example: /feature-marker prd-user-authentication
`);
}

function getInstallPaths() {
  const home = homedir();
  return {
    skillDst: join(home, '.claude', 'skills', 'feature-marker'),
    agentDst: join(home, '.claude', 'agents', 'feature-marker.md'),
    skillSrc: join(PACKAGE_ROOT, 'dist', 'feature-marker'),
    agentSrc: join(PACKAGE_ROOT, 'dist', 'agents', 'feature-marker.md'),
  };
}

function checkStatus() {
  const paths = getInstallPaths();

  banner();
  log(`${COLORS.bold}Installation Status:${COLORS.reset}\n`);

  const skillInstalled = existsSync(paths.skillDst);
  const agentInstalled = existsSync(paths.agentDst);

  if (skillInstalled) {
    success(`Skill installed: ${paths.skillDst}`);
  } else {
    warn(`Skill not installed: ${paths.skillDst}`);
  }

  if (agentInstalled) {
    success(`Agent installed: ${paths.agentDst}`);
  } else {
    warn(`Agent not installed: ${paths.agentDst}`);
  }

  console.log('');

  if (skillInstalled && agentInstalled) {
    info('feature-marker is ready to use!');
    info('In Claude Code, use: /feature-marker <feature-slug>');
  } else {
    info('Run "npx feature-marker install" to install.');
  }
}

function install(options = {}) {
  const { silent = false, dryRun = false, withTui = false } = options;
  const paths = getInstallPaths();

  if (!silent) {
    banner();
    log(`${COLORS.bold}Installing feature-marker v${VERSION}${COLORS.reset}\n`);
  }

  // Validate source files
  if (!existsSync(paths.skillSrc)) {
    error(`Skill source not found: ${paths.skillSrc}`);
    error('Package may be corrupted. Try reinstalling.');
    process.exit(1);
  }

  if (!existsSync(paths.agentSrc)) {
    error(`Agent source not found: ${paths.agentSrc}`);
    error('Package may be corrupted. Try reinstalling.');
    process.exit(1);
  }

  if (dryRun) {
    info('Dry-run mode: No files will be copied.\n');
    log(`Would copy:`);
    log(`  ${paths.skillSrc}/ -> ${paths.skillDst}/`);
    log(`  ${paths.agentSrc} -> ${paths.agentDst}`);
    return;
  }

  // Create directories
  if (!silent) info('Creating directories...');
  mkdirSync(paths.skillDst, { recursive: true });
  mkdirSync(dirname(paths.agentDst), { recursive: true });

  // Copy skill files
  if (!silent) info('Copying skill files...');
  cpSync(paths.skillSrc, paths.skillDst, { recursive: true });

  // Copy agent file
  if (!silent) info('Copying agent file...');
  cpSync(paths.agentSrc, paths.agentDst);

  // Set permissions
  if (!silent) info('Setting permissions...');
  try {
    chmodSync(join(paths.skillDst, 'feature-marker.sh'), 0o755);
    const libDir = join(paths.skillDst, 'lib');
    if (existsSync(libDir)) {
      readdirSync(libDir)
        .filter(f => f.endsWith('.sh'))
        .forEach(f => chmodSync(join(libDir, f), 0o755));
    }
  } catch (e) {
    // Ignore permission errors on Windows
  }

  if (!silent) {
    console.log('');
    log(`${COLORS.green}${COLORS.bold}╔═══════════════════════════════════════╗${COLORS.reset}`);
    log(`${COLORS.green}${COLORS.bold}║       Installation Complete!          ║${COLORS.reset}`);
    log(`${COLORS.green}${COLORS.bold}╚═══════════════════════════════════════╝${COLORS.reset}`);
    console.log('');
    success(`Skill: ${paths.skillDst}`);
    success(`Agent: ${paths.agentDst}`);
    console.log('');
    info('In Claude Code, use: /feature-marker <feature-slug>');
    info('Example: /feature-marker prd-user-authentication');
    console.log('');
  }

  // Install TUI if requested
  if (withTui) {
    installTui(silent);
  }
}

function installTui(silent = false) {
  if (!silent) {
    console.log('');
    info('TUI installation requires Rust/Cargo and building from source.');
    info('To install TUI manually:');
    console.log('');
    log('  git clone https://github.com/Viniciuscarvalho/Feature-marker.git');
    log('  cd Feature-marker/feature-marker-tui');
    log('  cargo build --release');
    log('  cp target/release/feature-marker-tui ~/.local/bin/');
    console.log('');
  }
}

function uninstall(options = {}) {
  const { silent = false, dryRun = false } = options;
  const paths = getInstallPaths();

  if (!silent) {
    banner();
    log(`${COLORS.bold}Uninstalling feature-marker${COLORS.reset}\n`);
  }

  const skillExists = existsSync(paths.skillDst);
  const agentExists = existsSync(paths.agentDst);

  if (!skillExists && !agentExists) {
    if (!silent) warn('feature-marker is not installed.');
    return;
  }

  if (dryRun) {
    info('Dry-run mode: No files will be removed.\n');
    if (skillExists) log(`Would remove: ${paths.skillDst}`);
    if (agentExists) log(`Would remove: ${paths.agentDst}`);
    return;
  }

  if (skillExists) {
    if (!silent) info(`Removing skill: ${paths.skillDst}`);
    execSync(`rm -rf "${paths.skillDst}"`);
    if (!silent) success('Skill removed');
  }

  if (agentExists) {
    if (!silent) info(`Removing agent: ${paths.agentDst}`);
    execSync(`rm -f "${paths.agentDst}"`);
    if (!silent) success('Agent removed');
  }

  if (!silent) {
    console.log('');
    success('feature-marker has been uninstalled.');
  }
}

function main() {
  const args = process.argv.slice(2);
  const command = args.find(a => !a.startsWith('-')) || 'help';
  const options = {
    silent: args.includes('--silent'),
    dryRun: args.includes('--dry-run'),
    withTui: args.includes('--with-tui'),
  };

  if (args.includes('--version') || args.includes('-V')) {
    console.log(`feature-marker v${VERSION}`);
    return;
  }

  switch (command) {
    case 'install':
      install(options);
      break;
    case 'uninstall':
      uninstall(options);
      break;
    case 'status':
      checkStatus();
      break;
    case 'help':
    default:
      showHelp();
      break;
  }
}

// Helper function for path operations
function dirname(path) {
  return path.split('/').slice(0, -1).join('/') || '/';
}

main();
