'use strict';

const fs = require('fs');
const os = require('os');
const path = require('path');

const VERSION = '8.0.0';
const SUPPORTED_RUNTIMES = ['claude', 'codex', 'gemini'];
const WORKFLOW_COMMANDS = ['run', 'resume', 'status', 'capabilities'];

function runCli(argv = process.argv.slice(2), io = {}) {
  const stdout = io.stdout || process.stdout;
  const stderr = io.stderr || process.stderr;
  const env = io.env || process.env;
  const cwd = io.cwd || process.cwd();

  try {
    const parsed = parseArgs(argv);
    if (parsed.command === 'help') {
      stdout.write(helpText());
      return 0;
    }
    if (parsed.command === 'version') {
      stdout.write(`feature-marker ${VERSION}\n`);
      return 0;
    }
    if (parsed.command === 'install') {
      return installCommand(parsed, { cwd, env, stdout });
    }
    if (WORKFLOW_COMMANDS.includes(parsed.command)) {
      stderr.write(`${unsupportedWorkflowMessage(parsed.command)}\n`);
      return 1;
    }

    stderr.write(`Unknown command: ${parsed.command}\n\n${helpText()}`);
    return 1;
  } catch (error) {
    stderr.write(`${error.message}\n`);
    return 1;
  }
}

function parseArgs(argv) {
  if (argv.length === 0) return { command: 'help', options: {}, positionals: [] };

  const [command, ...rest] = argv;
  if (command === '--help' || command === '-h') return { command: 'help', options: {}, positionals: [] };
  if (command === '--version' || command === '-V' || command === 'version') return { command: 'version', options: {}, positionals: [] };

  const options = {};
  const positionals = [];
  for (let i = 0; i < rest.length; i += 1) {
    const arg = rest[i];
    if (!arg.startsWith('-')) {
      positionals.push(arg);
      continue;
    }

    const [key, inlineValue] = arg.split('=', 2);
    const normalized = key.replace(/^--?/, '').replace(/-/g, '_');
    if (normalized === 'dry_run') {
      options.dry_run = true;
      continue;
    }

    const value = inlineValue !== undefined ? inlineValue : rest[++i];
    if (!value) throw new Error(`Missing value for ${key}`);
    options[normalized] = value;
  }

  return { command, options, positionals };
}

function helpText() {
  return [
    'feature-marker',
    '',
    'Installer for the feature-marker LLM skill.',
    '',
    'Run without global install:',
    '  npx -y @viniciuscarvalho/feature-marker install --runtime claude|codex|gemini|all',
    '',
    'Usage:',
    '  feature-marker install --runtime claude|codex|gemini|all [--dry-run]',
    '  feature-marker --help',
    '  feature-marker --version',
    '',
    'After installing, invoke the workflow inside your LLM:',
    '  Use feature-marker to plan and implement <feature-slug>.',
    '',
    'This package does not run PRD/TechSpec/Tasks workflows from JavaScript.',
    ''
  ].join('\n');
}

function unsupportedWorkflowMessage(command) {
  return [
    `feature-marker ${command} is not a supported CLI workflow command.`,
    'feature-marker is skill-first: use the CLI only to install skill files, then invoke the skill inside Claude, Codex, or Gemini.',
    'Install with: npx -y @viniciuscarvalho/feature-marker install --runtime all',
    'Then prompt your LLM: Use feature-marker to plan and implement <feature-slug>.'
  ].join('\n');
}

function installCommand(parsed, ctx) {
  const runtime = parsed.options.runtime || 'all';
  const dryRun = Boolean(parsed.options.dry_run);
  const root = packageRoot(ctx.cwd);
  const home = ctx.env.HOME || os.homedir();
  const results = installRuntime(runtime, { root, home, dryRun });
  const runtimeList = results.map((result) => result.runtime).join(', ');
  ctx.stdout.write(`${dryRun ? 'Would install' : 'Installed'} feature-marker skill(s): ${runtimeList}\n`);
  for (const result of results) {
    ctx.stdout.write(`- ${result.runtime}: ${result.target}\n`);
    if (result.agentTarget) ctx.stdout.write(`- ${result.runtime} agent: ${result.agentTarget}\n`);
  }
  return 0;
}

function installRuntime(runtime, options = {}) {
  const root = options.root || packageRoot(process.cwd());
  const home = options.home || os.homedir();
  const dryRun = Boolean(options.dryRun);
  const runtimes = expandRuntime(runtime);
  const results = [];

  for (const selected of runtimes) {
    const target = adapterInstallTarget(selected, home);
    const source = adapterSource(selected, root);
    const result = { runtime: selected, source, target };
    if (!dryRun) {
      copySkill(source, target);
      copyTemplates(root, target);
    }

    if (selected === 'claude') {
      result.agentSource = path.join(root, 'feature-marker-dist', 'agents', 'feature-marker.md');
      result.agentTarget = path.join(home, '.claude', 'agents', 'feature-marker.md');
      if (!dryRun) copyFile(result.agentSource, result.agentTarget);
    }

    results.push(result);
  }

  return results;
}

function expandRuntime(runtime) {
  if (runtime === 'all') return [...SUPPORTED_RUNTIMES];
  if (!SUPPORTED_RUNTIMES.includes(runtime)) {
    throw new Error(`Unsupported runtime: ${runtime}. Expected claude, codex, gemini, or all.`);
  }
  return [runtime];
}

function adapterInstallTarget(runtime, home = os.homedir()) {
  const targetRoots = {
    claude: ['.claude', 'skills', 'feature-marker'],
    codex: ['.codex', 'skills', 'feature-marker'],
    gemini: ['.gemini', 'skills', 'feature-marker']
  };
  return path.join(home, ...targetRoots[runtime]);
}

function adapterSource(runtime, root) {
  if (runtime === 'claude') return path.join(root, 'feature-marker-dist', 'feature-marker');
  return path.join(root, 'feature-marker-dist', 'adapters', runtime);
}

function copySkill(sourceDir, targetDir) {
  const sourceSkill = path.join(sourceDir, 'SKILL.md');
  if (!fs.existsSync(sourceSkill)) throw new Error(`Missing skill source: ${sourceSkill}`);
  fs.mkdirSync(targetDir, { recursive: true });
  copyFile(sourceSkill, path.join(targetDir, 'SKILL.md'));

  const sourceMetadata = path.join(sourceDir, 'agents', 'openai.yaml');
  if (fs.existsSync(sourceMetadata)) {
    copyFile(sourceMetadata, path.join(targetDir, 'agents', 'openai.yaml'));
  }
}

function copyTemplates(root, targetDir) {
  const sourceTemplates = path.join(root, 'feature-marker-dist', 'feature-marker', 'templates');
  if (fs.existsSync(sourceTemplates)) {
    copyDir(sourceTemplates, path.join(targetDir, 'templates'));
  }
}

function copyDir(sourceDir, targetDir) {
  fs.mkdirSync(targetDir, { recursive: true });
  for (const entry of fs.readdirSync(sourceDir, { withFileTypes: true })) {
    const source = path.join(sourceDir, entry.name);
    const target = path.join(targetDir, entry.name);
    if (entry.isDirectory()) {
      copyDir(source, target);
    } else if (entry.isFile()) {
      copyFile(source, target);
    }
  }
}

function copyFile(source, target) {
  if (!fs.existsSync(source)) throw new Error(`Missing file source: ${source}`);
  fs.mkdirSync(path.dirname(target), { recursive: true });
  fs.copyFileSync(source, target);
}

function packageRoot(cwd) {
  let current = path.resolve(cwd);
  while (current !== path.dirname(current)) {
    if (fs.existsSync(path.join(current, 'package.json')) && fs.existsSync(path.join(current, 'feature-marker-dist'))) {
      return current;
    }
    current = path.dirname(current);
  }
  return path.resolve(__dirname, '..');
}

module.exports = {
  VERSION,
  SUPPORTED_RUNTIMES,
  adapterInstallTarget,
  expandRuntime,
  helpText,
  installRuntime,
  runCli,
  unsupportedWorkflowMessage
};
