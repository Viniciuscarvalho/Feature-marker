'use strict';

const fs = require('fs');
const os = require('os');
const path = require('path');
const { execFileSync, spawnSync } = require('child_process');

const VERSION = '7.8.1';
const SUPPORTED_RUNTIMES = ['claude', 'codex', 'gemini'];
const SUPPORTED_MODES = {
  full: {
    phases: ['plan', 'implement', 'test', 'branch'],
    requiredArtifacts: []
  },
  'tasks-only': {
    phases: ['implement', 'test', 'branch'],
    requiredArtifacts: ['prd.md', 'techspec.md', 'tasks.md']
  },
  'test-only': {
    phases: ['test'],
    requiredArtifacts: []
  },
  'prd-only': {
    phases: ['plan'],
    requiredArtifacts: []
  }
};

const DEFAULT_CONFIG = {
  base_branch: null,
  worktrees_path: '.feature-marker/worktrees',
  branch_prefix: 'feature-marker',
  default_runtime: 'claude',
  mode_defaults: {},
  capabilities: {},
  docs_path: './tasks',
  state_path: '.feature-marker/features'
};

const CAPABILITY_MANIFEST = {
  version: 1,
  runtimes: {
    claude: {
      command: 'claude',
      required: ['headless-exec'],
      optional: ['native-skill-install']
    },
    codex: {
      command: 'codex',
      required: ['headless-exec'],
      optional: ['native-skill-install']
    },
    gemini: {
      command: 'gemini',
      required: ['headless-exec'],
      optional: ['native-skill-install']
    }
  },
  modes: {
    full: ['plan', 'implement', 'test', 'branch'],
    'tasks-only': ['implement', 'test', 'branch'],
    'test-only': ['test'],
    'prd-only': ['plan']
  }
};

function runCli(argv = process.argv.slice(2), io = {}) {
  const stdout = io.stdout || process.stdout;
  const stderr = io.stderr || process.stderr;
  const env = io.env || process.env;
  const cwd = io.cwd || process.cwd();

  try {
    const parsed = parseArgs(argv);
    switch (parsed.command) {
      case 'install':
        return installCommand(parsed, { cwd, env, stdout });
      case 'run':
        return runCommand(parsed, { cwd, env, stdout });
      case 'resume':
        return resumeCommand(parsed, { cwd, env, stdout });
      case 'status':
        return statusCommand(parsed, { cwd, stdout });
      case 'capabilities':
        stdout.write(`${JSON.stringify(CAPABILITY_MANIFEST, null, 2)}\n`);
        return 0;
      case 'help':
        stdout.write(helpText());
        return 0;
      case 'version':
        stdout.write(`feature-marker ${VERSION}\n`);
        return 0;
      default:
        stderr.write(`Unknown command: ${parsed.command}\n\n${helpText()}`);
        return 1;
    }
  } catch (error) {
    stderr.write(`${error.message}\n`);
    return 1;
  }
}

function parseArgs(argv) {
  if (argv.length === 0) {
    return { command: 'help', options: {} };
  }

  const [command, ...rest] = argv;
  if (command === '--help' || command === '-h') return { command: 'help', options: {} };
  if (command === '--version' || command === '-V' || command === 'version') return { command: 'version', options: {} };

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
    if (['dry_run', 'json'].includes(normalized)) {
      options[normalized] = true;
      continue;
    }
    const value = inlineValue !== undefined ? inlineValue : rest[++i];
    if (!value) throw new Error(`Missing value for ${key}`);
    options[normalized] = value;
  }

  return { command, positionals, options };
}

function helpText() {
  return [
    'feature-marker',
    '',
    'Run without global install:',
    '  npx -y @viniciuscarvalho/feature-marker install --runtime claude|codex|gemini|all',
    '  npx -y @viniciuscarvalho/feature-marker run <slug> --mode full|tasks-only|test-only|prd-only --runtime claude|codex|gemini',
    '',
    'Usage:',
    '  feature-marker install --runtime claude|codex|gemini|all',
    '  feature-marker run <slug> --mode full|tasks-only|test-only|prd-only --runtime claude|codex|gemini',
    '  feature-marker resume <slug>',
    '  feature-marker status <slug> [--json]',
    '  feature-marker capabilities',
    '',
    'Environment:',
    '  FEATURE_MARKER_ADAPTER_MOCK=1  Use deterministic local adapter output for tests and smoke runs.',
    ''
  ].join('\n');
}

function installCommand(parsed, ctx) {
  const runtime = parsed.options.runtime || 'all';
  const dryRun = Boolean(parsed.options.dry_run);
  const root = repoRoot(ctx.cwd, false) || ctx.cwd;
  const home = ctx.env.HOME || os.homedir();
  const installed = installRuntime(runtime, { root, home, dryRun });
  ctx.stdout.write(`${dryRun ? 'Would install' : 'Installed'} feature-marker adapter(s): ${installed.join(', ')}\n`);
  return 0;
}

function runCommand(parsed, ctx) {
  const slug = parsed.positionals[0];
  if (!slug) throw new Error('Feature slug is required.');
  const root = repoRoot(ctx.cwd, true);
  const config = loadProjectConfig(root);
  const mode = parsed.options.mode || config.mode_defaults.default || 'full';
  const runtime = parsed.options.runtime || config.default_runtime || 'claude';
  const result = runFeature({ slug, mode, runtime, root, env: ctx.env, dryRun: parsed.options.dry_run });
  ctx.stdout.write(formatRunResult(result));
  return 0;
}

function resumeCommand(parsed, ctx) {
  const slug = parsed.positionals[0];
  if (!slug) throw new Error('Feature slug is required.');
  const root = repoRoot(ctx.cwd, true);
  const checkpoint = loadCheckpoint(root, slug);
  if (!checkpoint) throw new Error(`No checkpoint found for ${slug}.`);
  const result = runFeature({
    slug,
    mode: checkpoint.mode,
    runtime: checkpoint.runtime,
    root,
    env: ctx.env,
    resume: true,
    dryRun: parsed.options.dry_run
  });
  ctx.stdout.write(formatRunResult(result));
  return 0;
}

function statusCommand(parsed, ctx) {
  const slug = parsed.positionals[0];
  if (!slug) throw new Error('Feature slug is required.');
  const root = repoRoot(ctx.cwd, true);
  const checkpoint = loadCheckpoint(root, slug);
  if (!checkpoint) throw new Error(`No checkpoint found for ${slug}.`);
  if (parsed.options.json) {
    ctx.stdout.write(`${JSON.stringify(checkpoint, null, 2)}\n`);
  } else {
    ctx.stdout.write([
      `Feature: ${checkpoint.slug}`,
      `Status: ${checkpoint.status}`,
      `Mode: ${checkpoint.mode}`,
      `Runtime: ${checkpoint.runtime}`,
      `Current phase: ${checkpoint.current_phase}`,
      `Worktree: ${checkpoint.worktree_path}`,
      `Branch: ${checkpoint.branch}`,
      ''
    ].join('\n'));
  }
  return 0;
}

function runFeature({ slug, mode, runtime, root, env = process.env, resume = false, dryRun = false }) {
  validateSlug(slug);
  validateMode(mode);
  validateRuntime(runtime);

  const config = loadProjectConfig(root);
  preflightRuntime(runtime, { env });

  let checkpoint = loadCheckpoint(root, slug);
  const isNew = !checkpoint;
  if (!checkpoint) {
    checkpoint = createCheckpoint({ slug, mode, runtime, root, config });
  } else {
    checkpoint.mode = mode || checkpoint.mode;
    checkpoint.runtime = runtime || checkpoint.runtime;
  }

  const modeSpec = SUPPORTED_MODES[checkpoint.mode];
  ensureRequiredArtifacts(root, config, slug, modeSpec.requiredArtifacts, checkpoint);

  const worktree = ensureWorktree(root, config, slug, checkpoint, { isNew, resume, dryRun });
  checkpoint.worktree_path = worktree.path;
  checkpoint.branch = worktree.branch;
  checkpoint.status = 'running';
  checkpoint.updated_at = now();
  saveCheckpoint(root, checkpoint);

  if (dryRun) {
    checkpoint.status = 'planned';
    checkpoint.updated_at = now();
    saveCheckpoint(root, checkpoint);
    return { checkpoint, phases: [] };
  }

  if (!dryRun) {
    syncArtifactsToWorktree(root, config, slug, worktree.path);
  }

  const platformContext = detectPlatform(worktree.path);
  checkpoint.platform_context = platformContext;
  writeJson(path.join(stateDir(root, slug), 'platform-context.json'), platformContext);
  saveCheckpoint(root, checkpoint);

  const completed = [];
  for (const phase of modeSpec.phases) {
    if (checkpoint.phases[phase] && checkpoint.phases[phase].status === 'completed') {
      continue;
    }

    checkpoint.current_phase = phase;
    checkpoint.phases[phase] = { status: 'running', started_at: now() };
    checkpoint.updated_at = now();
    saveCheckpoint(root, checkpoint);

    const promptPath = writePhasePrompt(root, checkpoint, phase);
    if (phase === 'branch') {
      checkpoint.branch_handoff = commitFeatureBranch(worktree.path, slug);
    } else {
      const adapterResult = invokeAdapter(runtime, {
        phase,
        promptPath,
        worktreePath: worktree.path,
        checkpoint,
        env
      });
      writeJson(path.join(stateDir(root, slug), 'logs', `${phase}.result.json`), adapterResult);
      if (env.FEATURE_MARKER_ADAPTER_MOCK === '1') {
        applyMockPhase(phase, { worktreePath: worktree.path, slug, mode: checkpoint.mode, root });
      }
    }

    checkpoint.phases[phase] = { status: 'completed', completed_at: now() };
    checkpoint.updated_at = now();
    completed.push(phase);
    saveCheckpoint(root, checkpoint);
  }

  checkpoint.status = 'completed';
  checkpoint.current_phase = modeSpec.phases[modeSpec.phases.length - 1] || checkpoint.current_phase;
  checkpoint.updated_at = now();
  saveCheckpoint(root, checkpoint);

  return { checkpoint, phases: completed };
}

function validateSlug(slug) {
  if (!/^[a-zA-Z0-9][a-zA-Z0-9._-]*$/.test(slug)) {
    throw new Error(`Invalid feature slug: ${slug}`);
  }
}

function validateMode(mode) {
  if (!SUPPORTED_MODES[mode]) {
    throw new Error(`Unsupported mode: ${mode}. Supported modes: ${Object.keys(SUPPORTED_MODES).join(', ')}`);
  }
}

function validateRuntime(runtime) {
  if (!SUPPORTED_RUNTIMES.includes(runtime)) {
    throw new Error(`Unsupported runtime: ${runtime}. Supported runtimes: ${SUPPORTED_RUNTIMES.join(', ')}`);
  }
}

function repoRoot(cwd, required) {
  try {
    return execFileSync('git', ['rev-parse', '--show-toplevel'], { cwd, encoding: 'utf8' }).trim();
  } catch (_) {
    if (required) throw new Error('feature-marker must be run inside a git repository.');
    return null;
  }
}

function loadProjectConfig(root) {
  const configPath = path.join(root, '.feature-marker.json');
  const config = fs.existsSync(configPath) ? readJson(configPath) : {};
  return { ...DEFAULT_CONFIG, ...config };
}

function createCheckpoint({ slug, mode, runtime, root, config }) {
  const phases = {};
  for (const phase of SUPPORTED_MODES[mode].phases) phases[phase] = { status: 'pending' };
  return {
    version: VERSION,
    slug,
    mode,
    runtime,
    status: 'pending',
    current_phase: SUPPORTED_MODES[mode].phases[0] || 'plan',
    root_path: root,
    artifacts_path: path.join(config.docs_path, slug),
    worktree_path: null,
    branch: null,
    phases,
    platform_context: null,
    branch_handoff: null,
    created_at: now(),
    updated_at: now()
  };
}

function loadCheckpoint(root, slug) {
  const file = path.join(stateDir(root, slug), 'checkpoint.json');
  return fs.existsSync(file) ? readJson(file) : null;
}

function saveCheckpoint(root, checkpoint) {
  writeJson(path.join(stateDir(root, checkpoint.slug), 'checkpoint.json'), checkpoint);
}

function stateDir(root, slug) {
  const config = loadProjectConfig(root);
  return path.resolve(root, config.state_path, slug);
}

function ensureRequiredArtifacts(root, config, slug, required, checkpoint) {
  if (!required.length) return;
  const missing = required.filter((file) => !fs.existsSync(path.join(root, config.docs_path, slug, file)));
  if (missing.length) {
    throw new Error(`Mode ${checkpoint.mode} requires missing artifact(s): ${missing.join(', ')}`);
  }
}

function syncArtifactsToWorktree(root, config, slug, worktreePath) {
  const source = path.join(root, config.docs_path, slug);
  if (!fs.existsSync(source)) return;
  const target = path.join(worktreePath, config.docs_path, slug);
  fs.mkdirSync(path.dirname(target), { recursive: true });
  fs.cpSync(source, target, { recursive: true });
}

function ensureWorktree(root, config, slug, checkpoint, options) {
  const worktreesRoot = path.resolve(root, config.worktrees_path);
  const worktreePath = path.join(worktreesRoot, slug);
  const branch = `${config.branch_prefix}/${slug}`;

  if (fs.existsSync(path.join(worktreePath, '.git'))) {
    if (options.isNew && isGitDirty(worktreePath)) {
      throw new Error(`Existing worktree for ${slug} has uncommitted changes. Refusing to attach a new feature run.`);
    }
    return { path: worktreePath, branch };
  }

  if (options.dryRun) return { path: worktreePath, branch };

  fs.mkdirSync(worktreesRoot, { recursive: true });
  const base = config.base_branch || determineBaseBranch(root);
  try {
    execFileSync('git', ['worktree', 'add', '-b', branch, worktreePath, base], { cwd: root, stdio: 'pipe' });
  } catch (firstError) {
    try {
      execFileSync('git', ['worktree', 'add', worktreePath, branch], { cwd: root, stdio: 'pipe' });
    } catch (_) {
      throw new Error(`Failed to create worktree ${worktreePath}: ${firstError.stderr ? firstError.stderr.toString().trim() : firstError.message}`);
    }
  }
  return { path: worktreePath, branch };
}

function determineBaseBranch(root) {
  const candidates = [
    ['rev-parse', '--abbrev-ref', '--symbolic-full-name', '@{u}'],
    ['rev-parse', '--verify', 'origin/main'],
    ['rev-parse', '--verify', 'main'],
    ['rev-parse', '--verify', 'HEAD']
  ];
  for (const args of candidates) {
    try {
      return execFileSync('git', args, { cwd: root, encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] }).trim();
    } catch (_) {}
  }
  throw new Error('Unable to determine a base branch for the feature worktree.');
}

function isGitDirty(cwd) {
  const status = execFileSync('git', ['status', '--porcelain'], { cwd, encoding: 'utf8' });
  return status.trim().length > 0;
}

function detectPlatform(worktreePath) {
  const platforms = [];
  const has = (file) => fs.existsSync(path.join(worktreePath, file));
  if (has('Package.swift') || globAny(worktreePath, ['.xcodeproj', '.xcworkspace'])) {
    platforms.push({
      type: 'ios',
      path: '.',
      confidence: 'high',
      test_command: 'swift test --parallel',
      lint_command: 'swiftlint'
    });
  }
  if (has('package.json')) {
    const pkg = readJson(path.join(worktreePath, 'package.json'), {});
    const pm = has('pnpm-lock.yaml') ? 'pnpm' : has('yarn.lock') ? 'yarn' : has('bun.lockb') ? 'bun' : 'npm';
    platforms.push({
      type: 'nodejs',
      path: '.',
      confidence: 'high',
      package_manager: pm,
      test_command: pkg.scripts && pkg.scripts.test ? `${pm} test` : `${pm} test`,
      lint_command: pkg.scripts && pkg.scripts.lint ? `${pm} run lint` : null,
      build_command: pkg.scripts && pkg.scripts.build ? `${pm} run build` : null
    });
  }
  if (has('Cargo.toml')) platforms.push({ type: 'rust', path: '.', confidence: 'high', test_command: 'cargo test', lint_command: 'cargo clippy -- -D warnings' });
  if (has('pyproject.toml') || has('requirements.txt') || has('setup.py')) platforms.push({ type: 'python', path: '.', confidence: 'high', test_command: 'pytest -v', lint_command: 'ruff check .' });
  if (has('go.mod')) platforms.push({ type: 'go', path: '.', confidence: 'high', test_command: 'go test ./...', lint_command: 'go vet ./...' });
  return {
    primary_platform: platforms[0] ? platforms[0].type : 'unknown',
    platforms,
    is_monorepo: platforms.length > 1,
    detected_at: now()
  };
}

function globAny(root, suffixes) {
  const entries = fs.readdirSync(root, { withFileTypes: true });
  return entries.some((entry) => suffixes.some((suffix) => entry.name.endsWith(suffix)));
}

function writePhasePrompt(root, checkpoint, phase) {
  const logsDir = path.join(stateDir(root, checkpoint.slug), 'logs');
  fs.mkdirSync(logsDir, { recursive: true });
  const promptPath = path.join(logsDir, `${phase}.prompt.md`);
  const prompt = [
    `# feature-marker phase: ${phase}`,
    '',
    `Feature slug: ${checkpoint.slug}`,
    `Mode: ${checkpoint.mode}`,
    `Runtime: ${checkpoint.runtime}`,
    `Worktree: ${checkpoint.worktree_path}`,
    `Artifacts: ${checkpoint.artifacts_path}`,
    '',
    'You are executing one phase of a CLI-owned state machine.',
    'Do not update checkpoint files directly.',
    'Keep all repository changes inside the feature worktree.',
    '',
    phaseInstructions(phase, checkpoint.mode)
  ].join('\n');
  fs.writeFileSync(promptPath, prompt);
  return promptPath;
}

function phaseInstructions(phase, mode) {
  if (phase === 'plan') {
    if (mode === 'prd-only') {
      return 'Create or update only tasks/{slug}/prd.md. Do not create techspec.md, tasks.md, implementation changes, tests, or PRs.';
    }
    return 'Create or update tasks/{slug}/prd.md, techspec.md, and tasks.md. Keep them implementation-ready and grounded in the repository.';
  }
  if (phase === 'implement') return 'Implement tasks/{slug}/tasks.md. Do not commit, push, or open a PR.';
  if (phase === 'test') return 'Run the platform-appropriate test and lint commands. Fix only failures caused by this feature.';
  return 'Prepare branch-only handoff. The CLI will create the commit and print push/PR commands.';
}

function invokeAdapter(runtime, { phase, promptPath, worktreePath, checkpoint, env }) {
  const prompt = fs.readFileSync(promptPath, 'utf8');
  if (env.FEATURE_MARKER_ADAPTER_MOCK === '1') {
    return { runtime, phase, status: 'mocked', output: `mock ${runtime} ${phase}` };
  }

  const args = adapterArgs(runtime, prompt, worktreePath);
  const command = args.shift();
  const result = spawnSync(command, args, {
    cwd: worktreePath,
    env,
    encoding: 'utf8',
    maxBuffer: 1024 * 1024 * 10
  });

  if (result.status !== 0) {
    throw new Error(`${runtime} adapter failed during ${phase}: ${(result.stderr || result.stdout || '').trim()}`);
  }
  return { runtime, phase, status: 'completed', output: result.stdout || '' };
}

function adapterArgs(runtime, prompt, worktreePath) {
  if (runtime === 'claude') return ['claude', '-p', prompt, '--permission-mode', 'auto'];
  if (runtime === 'codex') return ['codex', 'exec', '--cd', worktreePath, '--sandbox', 'workspace-write', prompt];
  return ['gemini', '-p', prompt, '--approval-mode', 'auto_edit'];
}

function applyMockPhase(phase, { worktreePath, slug, mode }) {
  const artifactDir = path.join(worktreePath, 'tasks', slug);
  if (phase === 'plan') {
    fs.mkdirSync(artifactDir, { recursive: true });
    writeIfMissing(path.join(artifactDir, 'prd.md'), `# PRD: ${slug}\n\nMock PRD generated by feature-marker.\n`);
    if (mode !== 'prd-only') {
      writeIfMissing(path.join(artifactDir, 'techspec.md'), `# TechSpec: ${slug}\n\nMock technical specification.\n`);
      writeIfMissing(path.join(artifactDir, 'tasks.md'), `# Tasks: ${slug}\n\n1. Implement ${slug}.\n`);
    }
  }
  if (phase === 'implement') {
    fs.writeFileSync(path.join(worktreePath, `${slug}.implementation.md`), `# ${slug}\n\nMock implementation output.\n`);
  }
}

function commitFeatureBranch(worktreePath, slug) {
  const status = execFileSync('git', ['status', '--porcelain'], { cwd: worktreePath, encoding: 'utf8' }).trim();
  const branch = execFileSync('git', ['branch', '--show-current'], { cwd: worktreePath, encoding: 'utf8' }).trim();
  const handoff = {
    branch,
    committed: false,
    commit: null,
    next_commands: [`git push -u origin ${branch}`, 'gh pr create --fill']
  };
  if (!status) return handoff;
  execFileSync('git', ['add', '-A'], { cwd: worktreePath, stdio: 'pipe' });
  execFileSync('git', ['commit', '-m', `feat(${slug}): implement feature workflow`], { cwd: worktreePath, stdio: 'pipe' });
  handoff.committed = true;
  handoff.commit = execFileSync('git', ['rev-parse', 'HEAD'], { cwd: worktreePath, encoding: 'utf8' }).trim();
  return handoff;
}

function preflightRuntime(runtime, { env }) {
  if (env.FEATURE_MARKER_ADAPTER_MOCK === '1') return;
  const command = CAPABILITY_MANIFEST.runtimes[runtime].command;
  const result = spawnSync(command, ['--version'], { encoding: 'utf8', env });
  if (result.error) {
    throw new Error(`Runtime ${runtime} requires command '${command}', but it was not found.`);
  }
}

function installRuntime(runtime, { root, home, dryRun = false }) {
  const runtimes = runtime === 'all' ? SUPPORTED_RUNTIMES : [runtime];
  for (const item of runtimes) validateRuntime(item);
  for (const item of runtimes) {
    const target = adapterInstallTarget(item, home);
    if (dryRun) continue;
    fs.mkdirSync(target.dir, { recursive: true });
    if (item === 'claude') {
      copyDir(path.join(root, 'feature-marker-dist', 'feature-marker'), target.dir);
      fs.mkdirSync(path.dirname(target.agent), { recursive: true });
      fs.copyFileSync(path.join(root, 'feature-marker-dist', 'agents', 'feature-marker.md'), target.agent);
    } else {
      copyDir(path.join(root, 'feature-marker-dist', 'adapters', item), target.dir);
    }
  }
  return runtimes;
}

function adapterInstallTarget(runtime, home) {
  if (runtime === 'claude') {
    return {
      dir: path.join(home, '.claude', 'skills', 'feature-marker'),
      agent: path.join(home, '.claude', 'agents', 'feature-marker.md')
    };
  }
  if (runtime === 'codex') return { dir: path.join(home, '.codex', 'skills', 'feature-marker') };
  return { dir: path.join(home, '.gemini', 'skills', 'feature-marker') };
}

function formatRunResult(result) {
  const checkpoint = result.checkpoint;
  const lines = [
    `Feature ${checkpoint.slug}: ${checkpoint.status}`,
    `Runtime: ${checkpoint.runtime}`,
    `Mode: ${checkpoint.mode}`,
    `Worktree: ${checkpoint.worktree_path}`,
    `Branch: ${checkpoint.branch}`
  ];
  if (checkpoint.branch_handoff) {
    lines.push('Branch handoff:');
    lines.push(...checkpoint.branch_handoff.next_commands.map((cmd) => `  ${cmd}`));
  }
  lines.push('');
  return lines.join('\n');
}

function readJson(file, fallback = null) {
  try {
    return JSON.parse(fs.readFileSync(file, 'utf8'));
  } catch (error) {
    if (fallback !== null) return fallback;
    throw error;
  }
}

function writeJson(file, data) {
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, `${JSON.stringify(data, null, 2)}\n`);
}

function writeIfMissing(file, content) {
  if (!fs.existsSync(file)) fs.writeFileSync(file, content);
}

function copyDir(src, dest) {
  if (!fs.existsSync(src)) throw new Error(`Missing adapter source: ${src}`);
  fs.rmSync(dest, { recursive: true, force: true });
  fs.mkdirSync(dest, { recursive: true });
  fs.cpSync(src, dest, { recursive: true });
}

function now() {
  return new Date().toISOString();
}

module.exports = {
  CAPABILITY_MANIFEST,
  DEFAULT_CONFIG,
  SUPPORTED_MODES,
  SUPPORTED_RUNTIMES,
  VERSION,
  detectPlatform,
  installRuntime,
  loadCheckpoint,
  loadProjectConfig,
  preflightRuntime,
  runCli,
  runFeature,
  validateMode,
  validateRuntime
};
