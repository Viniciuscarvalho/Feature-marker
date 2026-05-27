'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const test = require('node:test');
const { spawnSync } = require('node:child_process');

const {
  adapterInstallTarget,
  helpText,
  installRuntime,
  runCli,
  unsupportedWorkflowMessage
} = require('../lib/feature-marker');

const root = path.resolve(__dirname, '..');

function bufferIo(extra = {}) {
  return {
    stdout: { text: '', write(chunk) { this.text += chunk; } },
    stderr: { text: '', write(chunk) { this.text += chunk; } },
    ...extra
  };
}

test('install --runtime all --dry-run reports runtime-specific targets', () => {
  const home = fs.mkdtempSync(path.join(os.tmpdir(), 'fm-home-'));
  const results = installRuntime('all', { root, home, dryRun: true });

  assert.deepEqual(results.map((result) => result.runtime), ['claude', 'codex', 'gemini']);
  assert.equal(results[0].target, adapterInstallTarget('claude', home));
  assert.equal(results[1].target, adapterInstallTarget('codex', home));
  assert.equal(results[2].target, adapterInstallTarget('gemini', home));
  assert.equal(fs.existsSync(path.join(home, '.codex')), false);
});

test('install copies canonical skill assets into runtime-specific homes', () => {
  const home = fs.mkdtempSync(path.join(os.tmpdir(), 'fm-home-'));
  const results = installRuntime('all', { root, home });

  assert.deepEqual(results.map((result) => result.runtime), ['claude', 'codex', 'gemini']);
  assert.equal(fs.existsSync(path.join(home, '.claude', 'skills', 'feature-marker', 'SKILL.md')), true);
  assert.equal(fs.existsSync(path.join(home, '.claude', 'skills', 'feature-marker', 'agents', 'openai.yaml')), true);
  assert.equal(fs.existsSync(path.join(home, '.claude', 'skills', 'feature-marker', 'templates', 'prd-template.md')), true);
  assert.equal(fs.existsSync(path.join(home, '.claude', 'skills', 'feature-marker', 'templates', 'techspec-template.md')), true);
  assert.equal(fs.existsSync(path.join(home, '.claude', 'skills', 'feature-marker', 'templates', 'tasks-template.md')), true);
  assert.equal(fs.existsSync(path.join(home, '.claude', 'agents', 'feature-marker.md')), true);
  assert.equal(fs.existsSync(path.join(home, '.codex', 'skills', 'feature-marker', 'SKILL.md')), true);
  assert.equal(fs.existsSync(path.join(home, '.codex', 'skills', 'feature-marker', 'agents', 'openai.yaml')), true);
  assert.equal(fs.existsSync(path.join(home, '.codex', 'skills', 'feature-marker', 'templates', 'prd-template.md')), true);
  assert.equal(fs.existsSync(path.join(home, '.codex', 'skills', 'feature-marker', 'templates', 'techspec-template.md')), true);
  assert.equal(fs.existsSync(path.join(home, '.codex', 'skills', 'feature-marker', 'templates', 'tasks-template.md')), true);
  assert.equal(fs.existsSync(path.join(home, '.gemini', 'skills', 'feature-marker', 'SKILL.md')), true);
  assert.equal(fs.existsSync(path.join(home, '.gemini', 'skills', 'feature-marker', 'agents', 'openai.yaml')), true);
  assert.equal(fs.existsSync(path.join(home, '.gemini', 'skills', 'feature-marker', 'templates', 'prd-template.md')), true);
  assert.equal(fs.existsSync(path.join(home, '.gemini', 'skills', 'feature-marker', 'templates', 'techspec-template.md')), true);
  assert.equal(fs.existsSync(path.join(home, '.gemini', 'skills', 'feature-marker', 'templates', 'tasks-template.md')), true);

  const codexSkill = fs.readFileSync(path.join(home, '.codex', 'skills', 'feature-marker', 'SKILL.md'), 'utf8');
  assert.match(codexSkill, /Use this skill from inside Codex prompts/);
});

test('unsupported workflow commands fail with skill-first guidance', () => {
  for (const command of ['run', 'resume', 'status', 'capabilities']) {
    const io = bufferIo({ cwd: root, env: process.env });
    const code = runCli([command, 'billing-observability'], io);

    assert.equal(code, 1);
    assert.match(io.stderr.text, /not a supported CLI workflow command/);
    assert.match(io.stderr.text, /invoke the skill inside Claude, Codex, or Gemini/);
  }
});

test('help keeps the CLI installer-only', () => {
  const text = helpText();

  assert.match(text, /install --runtime claude\|codex\|gemini\|all/);
  assert.match(text, /Use feature-marker to plan and implement/);
  assert.doesNotMatch(text, /run <slug>/);
  assert.doesNotMatch(text, /resume <slug>/);
  assert.doesNotMatch(text, /status <slug>/);
});

test('installer command works through runCli', () => {
  const home = fs.mkdtempSync(path.join(os.tmpdir(), 'fm-home-'));
  const io = bufferIo({ cwd: root, env: { ...process.env, HOME: home } });
  const code = runCli(['install', '--runtime', 'codex', '--dry-run'], io);

  assert.equal(code, 0);
  assert.match(io.stdout.text, /Would install feature-marker skill\(s\): codex/);
  assert.match(io.stdout.text, /\.codex\/skills\/feature-marker/);
});

test('README and skill docs describe npx install plus LLM invocation', () => {
  const readme = read('README.md');
  const rootSkill = read('SKILL.md');
  const distSkill = read('feature-marker-dist/feature-marker/SKILL.md');
  const codexSkill = read('feature-marker-dist/adapters/codex/SKILL.md');
  const geminiSkill = read('feature-marker-dist/adapters/gemini/SKILL.md');
  const distReadme = read('feature-marker-dist/README.md');
  const claudeAgent = read('feature-marker-dist/agents/feature-marker.md');
  const wrapper = read('feature-marker-dist/feature-marker/feature-marker.sh');
  const docs = [readme, rootSkill, distSkill, codexSkill, geminiSkill, distReadme, claudeAgent, wrapper].join('\n');

  assert.match(readme, /npx -y @viniciuscarvalho\/feature-marker install --runtime all/);
  assert.match(readme, /npx -y @viniciuscarvalho\/feature-marker install --runtime claude/);
  assert.match(readme, /Claude prompt:/);
  assert.match(readme, /Use feature-marker to implement billing-observability/);
  assert.match(readme, /Use feature-marker to plan and implement/);
  assert.match(docs, /Interactive mode is not required and is not the v1 path/);
  assert.match(docs, /PRD -> TechSpec -> Tasks -> implementation grill ->\s+implementation -> verification/);
  assert.match(docs, /Run an implementation grill pass before coding/);
  assert.match(docs, /Resolve grill findings in .*before implementation/);
  assert.match(docs, /templates\/prd-template\.md` -> `tasks\/\{slug\}\/prd\.md/);
  assert.match(docs, /templates\/techspec-template\.md` -> `tasks\/\{slug\}\/techspec\.md/);
  assert.match(docs, /templates\/tasks-template\.md` -> `tasks\/\{slug\}\/tasks\.md/);
  assert.match(docs, /Replace `\{slug\}` and `\{feature_title\}`/);
  assert.match(docs, /Stop only for true ambiguity, unrelated dirty work, or blocked verification/i);
  assert.match(docs, /asks? the user only\s+when a finding changes scope or requires a product decision/i);
  assert.doesNotMatch(docs, /without stopping for artifact approval/i);
  assert.doesNotMatch(docs, /CLI owns the state machine/i);
  assert.doesNotMatch(docs, /feature-marker run\s/);
  assert.doesNotMatch(docs, /\.feature-marker\/features/);
  assert.doesNotMatch(docs, /interactive mode is required/i);
  assert.match(docs, /spec-driven` and `ralph-loop` are out of scope/);
});

test('package dry-run includes installer, skills, README, and docs', () => {
  const packed = spawnSync('npm', ['pack', '--dry-run', '--json'], {
    cwd: root,
    encoding: 'utf8'
  });

  assert.equal(packed.status, 0, packed.stderr);
  const [entry] = JSON.parse(packed.stdout);
  const files = entry.files.map((file) => file.path);

  assert(files.includes('bin/cli.js'));
  assert(files.includes('lib/feature-marker.js'));
  assert(files.includes('SKILL.md'));
  assert(files.includes('agents/openai.yaml'));
  assert(files.includes('feature-marker-dist/feature-marker/SKILL.md'));
  assert(files.includes('feature-marker-dist/feature-marker/agents/openai.yaml'));
  assert(files.includes('feature-marker-dist/feature-marker/templates/prd-template.md'));
  assert(files.includes('feature-marker-dist/feature-marker/templates/techspec-template.md'));
  assert(files.includes('feature-marker-dist/feature-marker/templates/tasks-template.md'));
  assert(files.includes('feature-marker-dist/adapters/codex/SKILL.md'));
  assert(files.includes('feature-marker-dist/adapters/codex/agents/openai.yaml'));
  assert(files.includes('feature-marker-dist/adapters/gemini/SKILL.md'));
  assert(files.includes('feature-marker-dist/adapters/gemini/agents/openai.yaml'));
  assert(files.includes('README.md'));
  assert(files.includes('CONTEXT.md'));
  assert(files.includes('docs/adr/012-skill-first-workflow.md'));
  assert.equal(files.some((file) => file.startsWith('feature-marker-dist/feature-marker/lib/')), false);
  assert.equal(files.some((file) => file.startsWith('feature-marker-dist/feature-marker/resources/')), false);
  assert.equal(files.some((file) => file.startsWith('feature-marker-dist/agents/phases/')), false);
  assert.equal(files.some((file) => file.startsWith('feature-marker-dist/scripts/')), false);
});

test('artifact templates provide slug-aware PRD, TechSpec, and Tasks structure', () => {
  const prd = read('feature-marker-dist/feature-marker/templates/prd-template.md');
  const techspec = read('feature-marker-dist/feature-marker/templates/techspec-template.md');
  const tasks = read('feature-marker-dist/feature-marker/templates/tasks-template.md');

  for (const template of [prd, techspec, tasks]) {
    assert.match(template, /\{slug\}/);
    assert.match(template, /\{feature_title\}/);
  }

  assert.match(prd, /## Acceptance Criteria/);
  assert.match(techspec, /## Implementation Grill Findings/);
  assert.match(tasks, /## Implementation Grill/);
  assert.match(tasks, /tasks\/\{slug\}\/prd\.md/);
  assert.match(tasks, /tasks\/\{slug\}\/techspec\.md/);
});

test('unsupportedWorkflowMessage points to install and LLM prompt', () => {
  const text = unsupportedWorkflowMessage('status');

  assert.match(text, /install --runtime all/);
  assert.match(text, /Use feature-marker to plan and implement/);
});

function read(relativePath) {
  return fs.readFileSync(path.join(root, relativePath), 'utf8');
}
