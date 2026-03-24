#!/usr/bin/env node
/**
 * Bundle script - copies feature-marker dist files into npm package
 * This runs during `npm prepare` before publishing
 */

import { cpSync, mkdirSync, existsSync } from 'fs';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
const PACKAGE_ROOT = join(__dirname, '..');
const REPO_ROOT = join(PACKAGE_ROOT, '..');

const SOURCE_SKILL = join(REPO_ROOT, 'feature-marker-dist', 'feature-marker');
const SOURCE_AGENT = join(REPO_ROOT, 'feature-marker-dist', 'agents');

const DEST_SKILL = join(PACKAGE_ROOT, 'dist', 'feature-marker');
const DEST_AGENTS = join(PACKAGE_ROOT, 'dist', 'agents');

console.log('Bundling feature-marker for npm...\n');

// Check source exists
if (!existsSync(SOURCE_SKILL)) {
  console.error(`ERROR: Source skill not found: ${SOURCE_SKILL}`);
  process.exit(1);
}

if (!existsSync(SOURCE_AGENT)) {
  console.error(`ERROR: Source agents not found: ${SOURCE_AGENT}`);
  process.exit(1);
}

// Create dist directory
mkdirSync(join(PACKAGE_ROOT, 'dist'), { recursive: true });

// Copy skill
console.log(`Copying skill: ${SOURCE_SKILL}`);
cpSync(SOURCE_SKILL, DEST_SKILL, { recursive: true });

// Copy agents
console.log(`Copying agents: ${SOURCE_AGENT}`);
cpSync(SOURCE_AGENT, DEST_AGENTS, { recursive: true });

console.log('\nBundle complete!');
console.log(`  Skill: ${DEST_SKILL}`);
console.log(`  Agents: ${DEST_AGENTS}`);
