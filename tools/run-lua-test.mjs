#!/usr/bin/env node
// Run addon logic outside the game: loads tools/wow-stub.lua, then every file listed in the addon's
// .toc (in order, each with the addon name and a shared namespace table as varargs, as the client
// does), then the test file. The test uses STUB.* helpers (Fire, Advance, Receive, sent, printed)
// and plain `assert`. Exit code 1 on any Lua error.
//   node tools/run-lua-test.mjs <addon-dir> <test.lua>
// First time: `npm install fengari` inside this tools folder.
import fs from 'node:fs';
import path from 'node:path';
import { createRequire } from 'node:module';
const require = createRequire(import.meta.url);
let fengari;
try { fengari = require('fengari'); } catch { console.error('fengari not found: run `npm install fengari` in the tools folder'); process.exit(2); }
const { lua, lauxlib, lualib, to_luastring } = fengari;

const [addonDir, testFile] = process.argv.slice(2);
if (!addonDir || !testFile) { console.error('usage: node tools/run-lua-test.mjs <addon-dir> <test.lua>'); process.exit(2); }
const here = path.dirname(new URL(import.meta.url).pathname.replace(/^\/([A-Za-z]:)/, '$1'));
const toc = fs.readdirSync(addonDir).find(f => f.endsWith('.toc'));
if (!toc) { console.error('no .toc in', addonDir); process.exit(2); }
const addonName = path.basename(toc, '.toc');
const files = fs.readFileSync(path.join(addonDir, toc), 'utf8').split(/\r?\n/).map(l => l.trim()).filter(l => l && !l.startsWith('#')).map(l => l.replace(/\\/g, '/'));

const L = lauxlib.luaL_newstate();
lualib.luaL_openlibs(L);
function run(file, ...varargs) {
  const src = fs.readFileSync(file, 'utf8');
  if (lauxlib.luaL_loadbuffer(L, to_luastring(src), src.length, to_luastring('@' + file)) !== lua.LUA_OK) {
    console.error('LOAD ERROR', file + ':', lua.lua_tojsstring(L, -1)); process.exit(1);
  }
  for (const v of varargs) { if (typeof v === 'string') lua.lua_pushstring(L, to_luastring(v)); else lua.lua_pushvalue(L, v); }
  if (lua.lua_pcall(L, varargs.length, 0, 0) !== lua.LUA_OK) {
    console.error('LUA ERROR in', file + ':', lua.lua_tojsstring(L, -1)); process.exit(1);
  }
}
run(path.join(here, 'wow-stub.lua'));
lua.lua_newtable(L); const nsIndex = lua.lua_gettop(L);   // the addon's private namespace table (second vararg)
for (const f of files) run(path.join(addonDir, f), addonName, nsIndex);
run(testFile, addonName, nsIndex);
console.log('ok', testFile);
