#!/usr/bin/env node
// Syntax check for WoW addon Lua files (Lua 5.1 grammar) with luaparse.
//   node tools/check-lua.mjs <file.lua|dir> ...
// First time: `npm install luaparse` inside this tools folder (or pass NODE_PATH to another install).
import fs from 'node:fs';
import path from 'node:path';
import { createRequire } from 'node:module';
const require = createRequire(import.meta.url);
let luaparse;
try { luaparse = require('luaparse'); } catch { console.error('luaparse not found: run `npm install luaparse` in', path.dirname(new URL(import.meta.url).pathname)); process.exit(2); }
const files = [];
function walk(d) {
  for (const e of fs.readdirSync(d, { withFileTypes: true })) {
    if (e.name === 'node_modules') continue;
    const p = path.join(d, e.name);
    if (e.isDirectory()) walk(p);
    else if (e.name.endsWith('.lua')) files.push(p);
  }
}
for (const a of process.argv.slice(2)) {
  if (fs.statSync(a).isDirectory()) walk(a);
  else files.push(a);
}
let bad = 0;
for (const f of files) {
  try { luaparse.parse(fs.readFileSync(f, 'utf8'), { luaVersion: '5.1', comments: false }); console.log('ok  ', f); }
  catch (e) { bad++; console.error('FAIL', f + ':', e.message); }
}
process.exit(bad ? 1 : 0);
