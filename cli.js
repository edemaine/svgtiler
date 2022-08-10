#!/usr/bin/env node
// Cross-platform launcher for Node with source-map support
require('child_process').spawnSync('node', [
  '--enable-source-maps',
  require('path').join(__dirname, 'lib/svgtiler.js'),
  ...process.argv.slice(2)
], {
  stdio: 'inherit'
});
