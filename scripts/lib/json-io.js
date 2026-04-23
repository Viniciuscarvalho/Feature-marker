#!/usr/bin/env node
// json-io.js — Safe JSON I/O for shell scripts.
// All user-supplied values are passed via process.argv, never interpolated
// into JavaScript source code, eliminating command injection via JSON fields.
//
// Operations:
//   init <file>                                  — create {"created_at":"...","entries":{}} if absent
//   set-entry <file> <key> [field val ...]       — upsert entries[key] with given field/value pairs
//   get-entry <file> <key> <field>               — print entries[key][field] or empty string
//   count-array <file> <dot.path>                — print length of array at path
//   read-path <file> <dot.path>                  — print value at dot-path (string coercion)
//   stringify                                    — read stdin as text, write JSON-encoded string
//   write-results <file> [field val ...]         — write a results.json with given top-level fields

'use strict';
const fs = require('fs');
const path = require('path');

const [, , op, ...args] = process.argv;

function readJSON(file) {
  try {
    return JSON.parse(fs.readFileSync(file, 'utf-8'));
  } catch (_) {
    return null;
  }
}

function writeJSON(file, data) {
  const dir = path.dirname(file);
  if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
  const tmp = file + '.tmp.' + process.pid;
  fs.writeFileSync(tmp, JSON.stringify(data, null, 2));
  fs.renameSync(tmp, file);
}

function resolvePath(obj, dotPath) {
  return dotPath.split('.').reduce((acc, k) => (acc != null ? acc[k] : undefined), obj);
}

switch (op) {
  case 'init': {
    const [file] = args;
    if (!fs.existsSync(file)) {
      writeJSON(file, { created_at: new Date().toISOString(), entries: {} });
    }
    break;
  }

  case 'set-entry': {
    const [file, key, ...pairs] = args;
    let data = readJSON(file) || { created_at: new Date().toISOString(), entries: {} };
    if (!data.entries) data.entries = {};
    const entry = data.entries[key] || {};
    for (let i = 0; i < pairs.length - 1; i += 2) {
      entry[pairs[i]] = pairs[i + 1];
    }
    entry.cached_at = new Date().toISOString();
    data.entries[key] = entry;
    writeJSON(file, data);
    break;
  }

  case 'get-entry': {
    const [file, key, field] = args;
    const data = readJSON(file);
    const entry = data && data.entries && data.entries[key];
    if (entry && field in entry) {
      process.stdout.write(String(entry[field]));
    }
    break;
  }

  case 'count-array': {
    const [file, dotPath] = args;
    const data = readJSON(file);
    const val = data ? resolvePath(data, dotPath) : null;
    process.stdout.write(String(Array.isArray(val) ? val.length : 0));
    break;
  }

  case 'read-path': {
    const [file, dotPath] = args;
    const data = readJSON(file);
    const val = data ? resolvePath(data, dotPath) : undefined;
    if (val !== undefined && val !== null) {
      process.stdout.write(String(val));
    }
    break;
  }

  case 'stringify': {
    const chunks = [];
    process.stdin.on('data', c => chunks.push(c));
    process.stdin.on('end', () => {
      const text = Buffer.concat(chunks).toString('utf-8').trimEnd();
      process.stdout.write(JSON.stringify(text));
    });
    return;
  }

  case 'write-results': {
    const [file, ...pairs] = args;
    const obj = {};
    for (let i = 0; i < pairs.length - 1; i += 2) {
      const k = pairs[i];
      const raw = pairs[i + 1];
      // Attempt numeric coercion for known integer fields
      if (k === 'duration_seconds' || k === 'exit_code') {
        obj[k] = parseInt(raw, 10);
      } else if (k === 'status_ok') {
        obj['status'] = raw === '0' ? 'completed' : (raw === '2' || raw === '10' ? 'paused' : 'failed');
      } else {
        obj[k] = raw;
      }
    }
    // Merge with existing if present
    const existing = readJSON(file) || {};
    writeJSON(file, Object.assign(existing, obj));
    break;
  }

  default:
    process.stderr.write('json-io.js: unknown op: ' + op + '\n');
    process.exit(1);
}
