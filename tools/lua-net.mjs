// tools/lua-net.mjs: several LevelMates clients in one process, wired through a fake GUILD channel and whispers.
// Each client is its own fengari state with the stub, the addon (as listed in the .toc) and its own player name.
//   const net = new Net(['Ana', 'Ben']); net.advance(5); net.run('Ben', 'local _, ns = ...; return ...')
import fs from 'node:fs';
import path from 'node:path';
import { createRequire } from 'node:module';
const require = createRequire(import.meta.url);
const { lua, lauxlib, lualib, to_luastring } = require('fengari');
const here = path.dirname(new URL(import.meta.url).pathname.replace(/^\/([A-Za-z]:)/, '$1'));
const addonDir = path.join(here, '..', 'LevelMates');
const toc = fs.readdirSync(addonDir).find(f => f.endsWith('.toc'));
const files = fs.readFileSync(path.join(addonDir, toc), 'utf8').split(/\r?\n/).map(l => l.trim())
  .filter(l => l && !l.startsWith('#')).map(l => l.replace(/\\/g, '/'));

// Load and run a chunk; with nsIndex, it gets the addon's varargs (name, namespace). Returns its first value.
function load(L, file, src, nsIndex) {
  if (lauxlib.luaL_loadbuffer(L, to_luastring(src), src.length, to_luastring('@' + file)) !== lua.LUA_OK)
    throw new Error('LOAD ' + file + ': ' + lua.lua_tojsstring(L, -1));
  let n = 0;
  if (nsIndex) { lua.lua_pushstring(L, to_luastring('LevelMates')); lua.lua_pushvalue(L, nsIndex); n = 2; }
  if (lua.lua_pcall(L, n, 1, 0) !== lua.LUA_OK) throw new Error('LUA ' + file + ': ' + lua.lua_tojsstring(L, -1));
  const t = lua.lua_type(L, -1);
  const v = t === lua.LUA_TNUMBER ? lua.lua_tonumber(L, -1) : t === lua.LUA_TSTRING ? lua.lua_tojsstring(L, -1)
    : t === lua.LUA_TBOOLEAN ? lua.lua_toboolean(L, -1) : null;
  lua.lua_pop(L, 1);
  return v;
}

export class Net {
  constructor(names) {
    this.clients = new Map();
    this.gone = new Set();
    for (const name of names) {
      const L = lauxlib.luaL_newstate(); lualib.luaL_openlibs(L);
      load(L, 'wow-stub.lua', fs.readFileSync(path.join(here, 'wow-stub.lua'), 'utf8'));
      const roster = names.map(n => `[${JSON.stringify(n)}] = true`).join(', ');
      load(L, 'player', `STUB.player.name = ${JSON.stringify(name)}; STUB.guildMembers = { ${roster} }`);
      lua.lua_newtable(L); const ns = lua.lua_gettop(L);
      for (const f of files) load(L, f, fs.readFileSync(path.join(addonDir, f), 'utf8'), ns);
      this.clients.set(name, { L, ns });
      load(L, 'start', 'STUB.Fire("ADDON_LOADED", "LevelMates"); STUB.Fire("PLAYER_ENTERING_WORLD", true, false)');
    }
  }
  run(name, code) { const c = this.clients.get(name); return load(c.L, 'test', code, c.ns); }
  leave(name) { this.gone.add(name); }
  join(name) { this.gone.delete(name); }
  // Each client's sent messages since the last delivery: GUILD to everyone present, WHISPER to its target.
  deliver() {
    for (const [from, c] of this.clients) {
      const out = load(c.L, 'drain', 'return STUB.Drain()');
      if (!out || this.gone.has(from)) continue;
      for (const line of out.split('\n')) {
        const [prefix, chatType, target, ...rest] = line.split('\t');
        const msg = rest.join('\t');
        if (chatType !== 'GUILD' && chatType !== 'WHISPER') continue;
        for (const [to, d] of this.clients) {
          if (to === from || this.gone.has(to)) continue;
          if (chatType === 'WHISPER' && target.split('-')[0] !== to) continue;
          lua.lua_getglobal(d.L, to_luastring('STUB')); lua.lua_getfield(d.L, -1, to_luastring('Receive'));
          for (const s of [prefix, msg, chatType, from + '-Testrealm']) lua.lua_pushstring(d.L, to_luastring(s));
          if (lua.lua_pcall(d.L, 4, 0, 0) !== lua.LUA_OK) throw new Error('deliver to ' + to + ': ' + lua.lua_tojsstring(d.L, -1));
          lua.lua_pop(d.L, 1);
        }
      }
    }
  }
  // Advance every present client's clock in 0.2 s steps, delivering after each step.
  advance(seconds) {
    for (let t = 0; t < seconds - 1e-9; t += 0.2) {
      for (const [name, c] of this.clients) if (!this.gone.has(name)) load(c.L, 'tick', 'STUB.Advance(0.2)');
      this.deliver();
    }
  }
}
