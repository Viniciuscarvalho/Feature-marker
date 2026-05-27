'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const test = require('node:test');
const { execFileSync } = require('node:child_process');

const {
  detectPlatform,
  installRuntime,
  loadCheckpoint,
  preflightRuntime,
  runFeature,
  validateMode
} = require('../lib/feature-marker');

function makeRepo() {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'fm-test-'));
  execFileSync('git', ['init', '-q'], { cwd: root });
  execFileSync('git', ['config', 'user.email', 'test@example.com'], { cwd: root });
  execFileSync('git', ['config', 'user.name', 'Feature Marker Test'], { cwd: root });
  fs.writeFileSync(path.join(root, 'package.json'), JSON.stringify({ scripts: { test: 'node --test', lint: 'node --check index.js' } }, null, 2));
  execFileSync('git', ['add', 'package.json'], { cwd: root });
  execFileSync('git', ['commit', '-m', 'init', '-q'], { cwd: root });
  return root;
}

function mockEnv() {
  return { ...process.env, FEATURE_MARKER_ADAPTER_MOCK: '1' };
}

test('mode validation rejects removed and unsupported modes', () => {
  assert.throws(() => validateMode('spec-driven'), /Unsupported mode/);
  assert.throws(() => validateMode('ralph-loop'), /Unsupported mode/);
});

test('full run creates neutral checkpoint, isolated worktree, artifacts, and branch handoff', () => {
  const root = makeRepo();
  const result = runFeature({ root, slug: 'native-adapters', mode: 'full', runtime: 'codex', env: mockEnv() });

  assert.equal(result.checkpoint.status, 'completed');
  assert.equal(result.checkpoint.runtime, 'codex');
  assert.equal(result.checkpoint.mode, 'full');
  assert.match(result.checkpoint.worktree_path, /\.feature-marker\/worktrees\/native-adapters$/);
  assert.equal(result.checkpoint.branch, 'feature-marker/native-adapters');
  assert.equal(result.checkpoint.branch_handoff.committed, true);

  const checkpoint = loadCheckpoint(root, 'native-adapters');
  assert.equal(checkpoint.phases.plan.status, 'completed');
  assert.equal(checkpoint.phases.implement.status, 'completed');
  assert.equal(checkpoint.phases.test.status, 'completed');
  assert.equal(checkpoint.phases.branch.status, 'completed');

  const artifactDir = path.join(checkpoint.worktree_path, 'tasks', 'native-adapters');
  assert.equal(fs.existsSync(path.join(artifactDir, 'prd.md')), true);
  assert.equal(fs.existsSync(path.join(artifactDir, 'techspec.md')), true);
  assert.equal(fs.existsSync(path.join(artifactDir, 'tasks.md')), true);
});

test('resume reuses existing checkpoint and does not create a second worktree', () => {
  const root = makeRepo();
  const first = runFeature({ root, slug: 'resume-flow', mode: 'prd-only', runtime: 'claude', env: mockEnv() });
  const second = runFeature({ root, slug: 'resume-flow', mode: 'prd-only', runtime: 'claude', env: mockEnv(), resume: true });

  assert.equal(second.checkpoint.worktree_path, first.checkpoint.worktree_path);
  assert.equal(second.checkpoint.status, 'completed');
});

test('tasks-only requires existing artifacts', () => {
  const root = makeRepo();
  assert.throws(
    () => runFeature({ root, slug: 'missing-tasks', mode: 'tasks-only', runtime: 'gemini', env: mockEnv() }),
    /requires missing artifact/
  );
});

test('tasks-only syncs existing artifacts into the isolated worktree', () => {
  const root = makeRepo();
  const artifactDir = path.join(root, 'tasks', 'existing-tasks');
  fs.mkdirSync(artifactDir, { recursive: true });
  fs.writeFileSync(path.join(artifactDir, 'prd.md'), '# PRD\n');
  fs.writeFileSync(path.join(artifactDir, 'techspec.md'), '# TechSpec\n');
  fs.writeFileSync(path.join(artifactDir, 'tasks.md'), '# Tasks\n');

  const result = runFeature({ root, slug: 'existing-tasks', mode: 'tasks-only', runtime: 'gemini', env: mockEnv() });

  assert.equal(fs.existsSync(path.join(result.checkpoint.worktree_path, 'tasks', 'existing-tasks', 'tasks.md')), true);
  assert.equal(result.checkpoint.phases.implement.status, 'completed');
});

test('dirty existing worktree is refused for a new feature run', () => {
  const root = makeRepo();
  const worktreeRoot = path.join(root, '.feature-marker', 'worktrees');
  const worktree = path.join(worktreeRoot, 'dirty-flow');
  fs.mkdirSync(worktreeRoot, { recursive: true });
  execFileSync('git', ['worktree', 'add', '-b', 'feature-marker/dirty-flow', worktree, 'HEAD'], { cwd: root, stdio: 'pipe' });
  fs.writeFileSync(path.join(worktree, 'dirty.txt'), 'uncommitted');

  assert.throws(
    () => runFeature({ root, slug: 'dirty-flow', mode: 'prd-only', runtime: 'claude', env: mockEnv() }),
    /uncommitted changes/
  );
});

test('platform context detects Node projects', () => {
  const root = makeRepo();
  const context = detectPlatform(root);
  assert.equal(context.primary_platform, 'nodejs');
  assert.equal(context.platforms[0].package_manager, 'npm');
  assert.equal(context.platforms[0].test_command, 'npm test');
});

test('runtime preflight fails clearly when command is unavailable', () => {
  assert.throws(
    () => preflightRuntime('codex', { env: { ...process.env, PATH: '/no/such/path' } }),
    /requires command 'codex'/
  );
});

test('installRuntime installs native adapter assets into runtime-specific homes', () => {
  const root = path.resolve(__dirname, '..');
  const home = fs.mkdtempSync(path.join(os.tmpdir(), 'fm-home-'));
  const installed = installRuntime('all', { root, home });

  assert.deepEqual(installed, ['claude', 'codex', 'gemini']);
  assert.equal(fs.existsSync(path.join(home, '.claude', 'skills', 'feature-marker', 'SKILL.md')), true);
  assert.equal(fs.existsSync(path.join(home, '.claude', 'agents', 'feature-marker.md')), true);
  assert.equal(fs.existsSync(path.join(home, '.codex', 'skills', 'feature-marker', 'SKILL.md')), true);
  assert.equal(fs.existsSync(path.join(home, '.gemini', 'skills', 'feature-marker', 'SKILL.md')), true);
});
