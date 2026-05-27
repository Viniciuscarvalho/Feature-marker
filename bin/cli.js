#!/usr/bin/env node
'use strict';

const { runCli } = require('../lib/feature-marker');

const exitCode = runCli(process.argv.slice(2));
process.exit(exitCode);
