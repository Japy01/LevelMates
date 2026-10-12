# Sync v2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace LevelMates' owner-only resend sync with a shared record layer:
- protocol v2 with a clean cut from 0.3.x;
- a two-lane queue that holds messages inside instances;
- chunked blobs;
- versioned records with tombstones, relayed by everyone for board data;
- a herd-proof catch-up for newcomers;
- coalesced redraws.

Ships as 0.4.0.

**Architecture:**
- `Comm.lua` stays the wire and transport. It gains the v2 prefix, lanes, holding, whispers and blobs.
- A new `Scheduler.lua` gives one ticker for periodic jobs and coalesced redraws.
- A new `Sync.lua` is the record store. Modules declare record types with `Sync.Define` and call `Sync.Put` / `Sync.Remove`; Sync owns sending, relaying, expiry, tombstones, pending resends and catch-up.
- Board modules (meetups, goals, wall, questions, recruit, market offers) move onto Sync. Personal modules keep their messages but use Sync's personal records for pending and resend.
- A multi-client test harness runs several addon instances wired through a fake GUILD channel.

**Tech Stack:**
- Lua 5.1 (WoW Forever 1.60.1, interface 16001).
- Tests in node + fengari with `tools/wow-stub.lua`.
- `npm test` runs everything; one test: `node tools/run-lua-test.mjs LevelMates tests/X.test.lua`.

**Spec:** `docs/superpowers/specs/2026-10-12-levelmates-sync-v2-design.md` (research: `docs/research/2026-10-12-guild-sync-practices.md`).

## Global Constraints

- **Interface and code:** WoW Forever 1.60.1, interface 16001, Lua 5.1 (no `goto`, no integer division `//`, no `table.unpack` in addon code; use `unpack`).
- **Prefixes:** the new addon prefix is `LVLM2`, protocol version string `"2"`. The old prefix `LVLM` is only listened to for legacy detection.
- **Sizes:**
  - single message ≤ 240 bytes, else a blob;
  - blob chunk payload ≤ 150 chars;
  - incomplete blob dropped after 30 s.
- **Queue:**
  - lanes `urgent` (help, helpok, helpgo, lfg, lfgx, lfj, lfjx, and Sync records of meetups and joins) ahead of `normal`;
  - cap 300; drop the oldest normal message, then the oldest urgent one;
  - inside an instance, hold instead of dropping: urgent 10 min, normal 60 min;
  - resume 2 s after `ZONE_CHANGED_NEW_AREA`, `PLAYER_REGEN_ENABLED` or `PLAYER_ENTERING_WORLD`.
- **Records:**
  - `rev` = `GetServerTime()` at the owner's change;
  - accept only if newer;
  - reject `rev` more than 300 s in the future;
  - tombstones expire with the record's lifetime;
  - personal types are never relayed.
- **Catch-up:**
  - `hi` at login +3 s;
  - responders wait a random 1–6 s, broadcast a claim, then whisper the records;
  - at most 20 per batch, oldest first;
  - the wall relays only the last 48 h, at most 40 entries.
- **Redraw:** at most once per 0.5 s per view, and only while it is visible.
- **No external libraries, no network, no other addons' files.** Nothing posts to visible chat.
- **The user tests in game before any release.** Ask before pushing or tagging.

## Review Focus

1. **Records arriving before the owner's heartbeat.** Today modules drop data from senders without `R.mates[name]`; relayed records of offline owners must use `R.IsGuildmate(owner)` instead. Expect them to show.
2. **A tombstone arriving before its record**, through a relay in a different order: the record must not appear afterwards.
3. **Clock skew between clients:** `rev` from a client whose clock is 2 minutes off must still order correctly against its own later changes. Only `rev` > now + 300 is rejected.
4. **SavedVariables from 0.3.2** (meetups, goals, wall, questions, recruit templates, offers): they must survive the upgrade without errors and without duplicates.
5. **A `/reload` inside a dungeon:** held messages are lost with the Lua state. Pending records must be re-marked from SavedVariables and sent after leaving.

---

## File map

| File | Change |
|---|---|
| `tools/lua-net.mjs` (new) | Multi-client harness: N Lua states, lockstep clock, message delivery |
| `tests/run-all.mjs` | Also runs `tests/*.net.mjs` |
| `LevelMates/Scheduler.lua` (new; .toc after Core.lua) | `ns.Every(name, seconds, fn)`, `ns.Dirty(view)`, `ns.OnRedraw(view, isVisible, fn)` |
| `LevelMates/Comm.lua` | v2 prefix, legacy listener, lanes, hold, cap, whisper, blobs |
| `LevelMates/Sync.lua` (new; .toc after Roster.lua) | Record store, relay, tombstones, pending, prune, catch-up |
| `LevelMates/Roster.lua` | Change-only `LM_ROSTER_CHANGED`; `hi` replaces `ping`; legacy version mark |
| `LevelMates/Board.lua`, `MateCard.lua`, `DungeonPanel.lua`, `GroupXP.lua` | Redraw through `ns.Dirty` |
| `LevelMates/Meetups.lua`, `Goals.lua`, `Feed.lua`, `Ask.lua`, `Recruit.lua`, `Gifts.lua` | Records on Sync |
| `LevelMates/Wishlist.lua`, `Professions.lua`, `Builds.lua`, `Macros.lua`, `Alts.lua`, `Points.lua`, `Achievements.lua`, `Personal.lua`, `Rested.lua`, `Partner.lua`(pal) | Pending and resend through `Sync.Personal` |
| `LevelMates/Report.lua`, `Settings.lua` (`/lm debug`) | Queue drops, held, bad records, memory before/after a collect |
| `tests/*.lua` | `"LVLM"` → `"LVLM2"` in `STUB.Receive`; new tests per task |
| `CHANGELOG.md`, `README.md`, `.toc` | 0.4.0 |

---

### Task 1: Multi-client test harness

**Files:**
- Create: `tools/lua-net.mjs`
- Create: `tests/net_smoke.net.mjs`
- Modify: `tests/run-all.mjs`
- Modify: `tools/wow-stub.lua` (a `STUB.Drain()` helper)

**Interfaces:**
- Produces:
  - `new Net(names)`;
  - `net.run(name, luaCode)`, which returns the code's single return value as a JS string or number;
  - `net.advance(seconds)`, which advances all clients in 0.2 s steps, delivering each step's GUILD messages to everyone else and WHISPER messages to their target;
  - `net.leave(name)`, which stops delivering to and from that client.

- [ ] **Step 1: Write the smoke test first**

```js
// tests/net_smoke.net.mjs: two clients see each other's heartbeat through the harness
import { Net } from '../tools/lua-net.mjs';
const net = new Net(['Ana', 'Ben']);
net.advance(5);
const seen = net.run('Ben', 'local _, ns = ...; return ns.Roster.mates["Ana"] and ns.Roster.mates["Ana"].level or 0');
if (seen !== 20) { console.error('Ben does not see Ana:', seen); process.exit(1); }
console.log('ok tests/net_smoke.net.mjs');
```

- [ ] **Step 2: Run it and watch it fail**

Run: `node tests/net_smoke.net.mjs`
Expected: fails with "Cannot find module" (no harness yet).

- [ ] **Step 3: Add `STUB.Drain` to the stub**

At the end of `tools/wow-stub.lua`:

```lua
-- For the multi-client harness: hand over what this client sent since the last drain, one line per message,
-- "prefix\tchatType\ttarget\tmsg" (messages never hold tabs or newlines: the wire forbids control characters
-- except the unit separator).
STUB.drained = 0
function STUB.Drain()
	local out = {}
	for i = STUB.drained + 1, #STUB.sent do
		local s = STUB.sent[i]
		out[#out + 1] = table.concat({ s.prefix, s.chatType or "", tostring(s.target or ""), s.msg }, "\t")
	end
	STUB.drained = #STUB.sent
	return table.concat(out, "\n")
end
```

- [ ] **Step 4: Write the harness**

```js
// tools/lua-net.mjs: several LevelMates clients in one process, wired through a fake GUILD channel and whispers.
// Each client is its own fengari state with the stub, the addon (as listed in the .toc) and its own player name.
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
      load(L, 'player', `STUB.player.name = ${JSON.stringify(name)}; STUB.guildMembers = {}`);
      for (const other of names) load(L, 'roster', `STUB.guildMembers[${JSON.stringify(other)}] = true`);
      lua.lua_newtable(L); const ns = lua.lua_gettop(L);
      for (const f of files) load(L, f, fs.readFileSync(path.join(addonDir, f), 'utf8'), ns);
      this.clients.set(name, { L, ns });
      load(L, 'start', 'STUB.Fire("ADDON_LOADED", "LevelMates"); STUB.Fire("PLAYER_ENTERING_WORLD", true, false)', ns);
    }
  }
  run(name, code) { const c = this.clients.get(name); return load(c.L, 'test', code, c.ns); }
  leave(name) { this.gone.add(name); }
  deliver() {
    for (const [from, c] of this.clients) {
      const out = load(c.L, 'drain', 'return STUB.Drain()');
      if (!out || this.gone.has(from)) continue;
      for (const line of out.split('\n')) {
        const [prefix, chatType, target, ...rest] = line.split('\t');
        const msg = rest.join('\t');
        for (const [to, d] of this.clients) {
          if (to === from || this.gone.has(to)) continue;
          if (chatType === 'WHISPER' && target.split('-')[0] !== to) continue;
          if (chatType !== 'GUILD' && chatType !== 'WHISPER') continue;
          lua.lua_getglobal(d.L, to_luastring('STUB')); lua.lua_getfield(d.L, -1, to_luastring('Receive'));
          for (const s of [prefix, msg, chatType, from + '-Testrealm']) lua.lua_pushstring(d.L, to_luastring(s));
          if (lua.lua_pcall(d.L, 4, 0, 0) !== lua.LUA_OK) throw new Error('deliver to ' + to + ': ' + lua.lua_tojsstring(d.L, -1));
          lua.lua_pop(d.L, 1);
        }
      }
    }
  }
  advance(seconds) {
    for (let t = 0; t < seconds; t += 0.2) {
      for (const [name, c] of this.clients) if (!this.gone.has(name)) load(c.L, 'tick', 'STUB.Advance(0.2)');
      this.deliver();
    }
  }
}
```

In `tests/run-all.mjs`, after the `.test.lua` loop:

```js
for (const t of fs.readdirSync('tests').filter(f => f.endsWith('.net.mjs'))) {
  const r = spawnSync('node', ['tests/' + t], { stdio: 'inherit' }); if (r.status) fail++;
}
```

- [ ] **Step 5: Run the smoke test**

Run: `node tests/net_smoke.net.mjs`
Expected: `ok tests/net_smoke.net.mjs`. If `ns` is nil in `run`, check that `load` pushes the ns table as the second vararg.

- [ ] **Step 6: Run the whole suite**

Run: `npm test`
Expected: exit 0, 171 ok lines.

- [ ] **Step 7: Commit**

```bash
git add tools/lua-net.mjs tools/wow-stub.lua tests/net_smoke.net.mjs tests/run-all.mjs
git commit -m "test: multi-client harness (several addon instances on a fake guild channel)"
```

---

### Task 2: Protocol v2 and the clean cut

**Files:**
- Modify: `LevelMates/Comm.lua` (`C.VERSION`, `C.PREFIX`, `C.MAX_BYTES`, a legacy listener)
- Modify: `LevelMates/Roster.lua` (the `legacy` mark on mates)
- Modify: every `tests/*.lua` that calls `STUB.Receive("LVLM", …)`
- Test: `tests/protocol_v2.test.lua`

**Interfaces:**
- Produces:
  - `C.PREFIX = "LVLM2"`, `C.VERSION = "2"`, `C.MAX_BYTES = 240`;
  - `C.LEGACY_PREFIX = "LVLM"`;
  - `R.mates[name].legacy = true` for guildmates heard only on the old prefix;
  - `C.stats.legacy` counter.

- [ ] **Step 1: Move the tests to the new prefix**

The tests feed the old prefix in 353 places. Run this script (node, from the repo root):

```js
const fs = require('fs');
for (const f of fs.readdirSync('tests').filter(f => f.endsWith('.lua'))) {
  const p = 'tests/' + f; const s = fs.readFileSync(p, 'utf8');
  const t = s.split('STUB.Receive("LVLM",').join('STUB.Receive("LVLM2",');
  if (t !== s) fs.writeFileSync(p, t);
}
```

- [ ] **Step 2: Write the failing protocol test**

```lua
-- tests/protocol_v2.test.lua
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local C, R = ns.Comm, ns.Roster
assert(C.PREFIX == "LVLM2" and STUB.prefixes["LVLM2"] and STUB.prefixes["LVLM"], "both prefixes registered")
for _, s in ipairs(STUB.sent) do assert(s.prefix == "LVLM2", "everything goes out on v2") end
-- a v2 heartbeat is understood
STUB.Receive("LVLM2", C.Encode("hb", { l = 21, z = 1412, c = "MAGE" }), "GUILD", "Mario-Testrealm")
assert(R.mates["Mario"] and R.mates["Mario"].level == 21, "v2 heard")
-- a v1 heartbeat is not data: Ana is only marked as using an old version, and gets one old-style heartbeat
local n = #STUB.sent
STUB.Receive("LVLM", "v1\031hb\031c=MAGE;l=15;v=0.3.2;z=1412", "GUILD", "Ana-Testrealm")
assert(not (R.mates["Ana"] and R.mates["Ana"].level), "no v1 data")
assert(R.legacy["Ana"], "Ana marked as old")
local old
for i = n + 1, #STUB.sent do if STUB.sent[i].prefix == "LVLM" then old = STUB.sent[i] end end
assert(old and old.msg:find("^v1\031hb\031") and old.msg:find("v=" .. ns.VERSION, 1, true), "one old-style heartbeat with my version")
-- at most once every 5 minutes
n = #STUB.sent
STUB.Receive("LVLM", "v1\031hb\031c=MAGE;l=15;v=0.3.2;z=1412", "GUILD", "Ana-Testrealm")
for i = n + 1, #STUB.sent do assert(STUB.sent[i].prefix ~= "LVLM", "not again so soon") end
STUB.Advance(301)
STUB.Receive("LVLM", "v1\031hb\031c=MAGE;l=15;v=0.3.2;z=1412", "GUILD", "Ana-Testrealm")
local again = false
for i = n + 1, #STUB.sent do if STUB.sent[i].prefix == "LVLM" then again = true end end
assert(again, "again after 5 minutes")
-- over 240 bytes is refused, never cut
assert(not C.Encode("ask", { id = "a1", x = string.rep("x", 120) }) or #C.Encode("ask", { id = "a1", x = string.rep("x", 120) }) <= 240, "limit 240")
```

- [ ] **Step 3: Run it and watch it fail**

Run: `node tools/run-lua-test.mjs LevelMates tests/protocol_v2.test.lua`
Expected: FAIL at "both prefixes registered".

- [ ] **Step 4: Implement**

In `Comm.lua`:
- `C.VERSION = "2"`, `C.PREFIX = "LVLM2"`, `C.MAX_BYTES = 240`, `C.LEGACY_PREFIX = "LVLM"`.
- In `C.Start` also call `C_ChatInfo.RegisterAddonMessagePrefix(C.LEGACY_PREFIX)`.
- In `onAddonMessage`, before the prefix check, route the old prefix:

```lua
-- 0.3.x clients: not data any more (clean cut). Mark them, and give them one old-style heartbeat with my version
-- every 5 minutes, so their own "a newer LevelMates exists" notice tells them to update.
local lastLegacyHb = -math.huge
local function onLegacy(text, channel, sender)
	if channel ~= "GUILD" then return end
	local name = ns.ShortName(sender)
	if isMe(sender, name) then return end
	C.stats.legacy = (C.stats.legacy or 0) + 1
	ns.Fire("LM_LEGACY_SEEN", name)
	if GetTime() - lastLegacyHb < 300 then return end
	lastLegacyHb = GetTime()
	local level, mapId = UnitLevel("player"), C_Map.GetBestMapForUnit("player") or 0
	local _, class = UnitClass("player")
	local text1 = "v1" .. US .. "hb" .. US .. "c=" .. esc(class or "") .. ";l=" .. level .. ";v=" .. esc(ns.VERSION) .. ";z=" .. mapId
	C_ChatInfo.SendAddonMessage(C.LEGACY_PREFIX, text1, "GUILD")
end
```

and at the top of `onAddonMessage`: `if prefix == C.LEGACY_PREFIX then onLegacy(text, channel, sender); return end`.

In `Roster.lua`:

```lua
R.legacy = {}
ns.On("LM_LEGACY_SEEN", function(name) R.legacy[name] = GetTime() end)
```

The card (`MateCard.Lines`) adds `L.CARD_OLD_VERSION` when `R.legacy[name]` is set. Add the strings:
- enUS: `L.CARD_OLD_VERSION = "Uses an old LevelMates (0.3): they need to update to see you."`
- esES: `L.CARD_OLD_VERSION = "Usa un LevelMates antiguo (0.3): tiene que actualizar para veros."`

The `ns.VERSION` field must exist. Check `Version.lua`; if it is named differently, use that name in the test and here.

- [ ] **Step 5: Run the test, then the suite**

Run: `node tools/run-lua-test.mjs LevelMates tests/protocol_v2.test.lua`, then `npm test`.
Expected: PASS; suite green. Fix tests that build raw `"v1\031..."` strings or check `STUB.sent[i].prefix == "LVLM"` by switching them to v2.

- [ ] **Step 6: Commit**

```bash
git add -A && git commit -m "feat(comm): protocol v2 on its own prefix; 0.3.x clients get an update hint"
```

---

### Task 3: Scheduler and coalesced redraws

**Files:**
- Create: `LevelMates/Scheduler.lua` (in the `.toc` right after `Core.lua`)
- Modify: `Roster.lua` (change-only event), `Rested.lua` (throttle), `Help.lua` (expiry fires only on a change)
- Modify: `Board.lua`, `MateCard.lua`, `DungeonPanel.lua`, `GroupXP.lua` (listeners call `ns.Dirty`)
- Test: `tests/scheduler.test.lua`

**Interfaces:**
- Produces:
  - `ns.Every(key, seconds, fn)`: one job per key, run by a single 0.2 s ticker;
  - `ns.Cancel(key)`;
  - `ns.OnRedraw(view, isVisibleFn, redrawFn)`;
  - `ns.Dirty(view)`: redraws at once if this view has not been redrawn in the last 0.5 s, else once at the end of that window, and never while hidden.

- [ ] **Step 1: Write the failing test**

```lua
-- tests/scheduler.test.lua
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
-- jobs on the one ticker
local n = 0
ns.Every("t", 1, function() n = n + 1 end)
STUB.Advance(3.05)
assert(n == 3, "every second: " .. n)
ns.Cancel("t"); STUB.Advance(2); assert(n == 3, "cancelled")
-- a burst of dirties: one redraw now, one at the end of the window
local shown, draws = true, 0
ns.OnRedraw("v", function() return shown end, function() draws = draws + 1 end)
ns.Dirty("v"); assert(draws == 1, "the first at once")
for i = 1, 30 do ns.Dirty("v") end
assert(draws == 1, "the rest wait")
STUB.Advance(0.6); assert(draws == 2, "one more at the end of the window: " .. draws)
STUB.Advance(2); assert(draws == 2, "nothing left")
shown = false; ns.Dirty("v"); STUB.Advance(1); assert(draws == 2, "hidden: no redraw")
-- the roster event only on a real change
local C = ns.Comm
local fired = 0
ns.On("LM_ROSTER_CHANGED", function() fired = fired + 1 end)
STUB.Receive("LVLM2", C.Encode("hb", { l = 21, z = 1412, c = "MAGE" }), "GUILD", "Mario-Testrealm")
local f1 = fired
STUB.Receive("LVLM2", C.Encode("hb", { l = 21, z = 1412, c = "MAGE" }), "GUILD", "Mario-Testrealm")
assert(fired == f1, "the same heartbeat again: no event")
STUB.Receive("LVLM2", C.Encode("hb", { l = 22, z = 1412, c = "MAGE" }), "GUILD", "Mario-Testrealm")
assert(fired == f1 + 1, "a new level: an event")
```

- [ ] **Step 2: Run it and watch it fail**

Run: `node tools/run-lua-test.mjs LevelMates tests/scheduler.test.lua`
Expected: FAIL (`ns.Every` is nil).

- [ ] **Step 3: Implement `Scheduler.lua`**

```lua
-- Scheduler.lua: one ticker for the addon's periodic jobs, and redraws that coalesce: a burst of changes redraws a
-- view once at once and once more at the end of a half-second window, never while it is hidden.
local _, ns = ...
local jobs, order, ticker = {}, {}, nil
local function tick()
	local now = GetTime()
	for _, key in ipairs(order) do
		local j = jobs[key]
		if j and now >= j.due then j.due = now + j.every; j.fn() end
	end
end
function ns.Every(key, seconds, fn)
	if not jobs[key] then order[#order + 1] = key end
	jobs[key] = { every = seconds, fn = fn, due = GetTime() + seconds }
	if not ticker then ticker = C_Timer.NewTicker(0.2, tick) end
end
function ns.Cancel(key)
	jobs[key] = nil
	for i, k in ipairs(order) do if k == key then table.remove(order, i); break end end
end

ns.REDRAW_GAP = 0.5
local views = {}
function ns.OnRedraw(view, isVisible, redraw) views[view] = { visible = isVisible, redraw = redraw, last = -math.huge } end
function ns.Dirty(view)
	local v = views[view]
	if not v or not v.visible() then return end
	local now = GetTime()
	if now - v.last >= ns.REDRAW_GAP and not v.waiting then
		v.last = now; v.redraw(); return
	end
	if v.waiting then return end
	v.waiting = true
	C_Timer.After(math.max(0, v.last + ns.REDRAW_GAP - now), function()
		v.waiting = false
		if v.visible() then v.last = GetTime(); v.redraw() end
	end)
end
```

`Roster.lua` `hb` handler: compare `level`, `mapId`, `inGroup`, `hasSlot`, `class` and `xph` before and after. Fire `LM_ROSTER_CHANGED` only if one differs or the mate is new. Positions alone fire `LM_MATE_MOVED`, which `GuildMap.lua` listens to instead.

`Rested.lua`: replace the direct fire on `PLAYER_XP_UPDATE` with `ns.Dirty`-like gating: fire `LM_RESTED_CHANGED` at most once per 2 s (a pending flag plus `C_Timer.After(2, …)`).

`Help.lua` expiry ticker: count the removals; fire `LM_HELP_CHANGED` only if the count is above 0.

Board: in `Board.lua` replace each `ns.On("LM_…", B.Refresh)` style listener with `ns.On("LM_…", function() ns.Dirty("board") end)`, and register:

```lua
ns.OnRedraw("board", function() return B.frame and B.frame:IsShown() end, function() B.Refresh() end)
```

Do the same for `MateCard` (`"card"`), `DungeonPanel` (`"dungeon"`) and `GroupXP` (`"groupxp"`, whose visibility check is "in a group with a guildmate", because it shows itself).

Direct calls after a click (`B.ShowTab`, `B.SetTab`, `B.TurnPage`) keep calling `B.Refresh()` directly.

- [ ] **Step 4: Run the test, then the suite**

Run: `node tools/run-lua-test.mjs LevelMates tests/scheduler.test.lua`, then `npm test`.
Expected: PASS.

Existing tests that receive two messages at the same `STUB.now` and then assert on the board need `STUB.Advance(0.6)` before the assert. Add it where they fail; do not change the gap.

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "perf: one scheduler ticker; views redraw at most twice a second, only on real changes"
```

---

### Task 4: Queue v2: lanes, cap, holding in instances, whispers

**Files:**
- Modify: `LevelMates/Comm.lua` (`pump`, `C.Send`, new `C.Whisper`, held items, resume events)
- Test: `tests/queue_v2.test.lua`

**Interfaces:**
- Produces:
  - `C.Send(kind, fields, prio)`, where prio is `"urgent"` | `"normal"` (`"now"` is kept as an alias of `"urgent"`);
  - `C.Whisper(kind, fields, target, prio)`;
  - `C.URGENT` (the kinds that default to urgent);
  - `C.stats.dropped` and `C.stats.held`;
  - the event `LM_COMM_DROPPED(kind)` is kept;
  - held items carry `heldAt`.

- [ ] **Step 1: Write the failing test**

```lua
-- tests/queue_v2.test.lua
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(30)
local C = ns.Comm
local function lastKinds(from) local out = {}; for i = from + 1, #STUB.sent do out[#out + 1] = (C.Decode(STUB.sent[i].msg)) end; return out end
-- urgent goes ahead of normal
STUB.throttleNext = 0
for i = 1, 12 do C.Send("pal", { p = 1 }) end   -- normal, uses up the burst
local n = #STUB.sent
C.Send("pt", { t = 1 }); C.Send("help", { t = "x", z = 1412, x = 1, y = 1, id = "h1" })
STUB.Advance(1.1)
assert(lastKinds(n)[1] == "help", "the help request first")
-- inside an instance: held, not dropped; out after leaving
STUB.Advance(30)
STUB.inInstance = true
n = #STUB.sent
C.Send("pt", { t = 2 })
STUB.Advance(5)
assert(#STUB.sent == n, "nothing out inside")
assert(C.stats.held >= 1, "held")
STUB.inInstance = false
STUB.Fire("ZONE_CHANGED_NEW_AREA"); STUB.Advance(3)
local out = lastKinds(n)
local found = false; for _, k in ipairs(out) do if k == "pt" then found = true end end
assert(found, "out after leaving")
-- held normal messages expire after an hour
STUB.inInstance = true
C.Send("pt", { t = 3 }); STUB.Advance(3601)
STUB.inInstance = false; n = #STUB.sent
STUB.Fire("ZONE_CHANGED_NEW_AREA"); STUB.Advance(3)
for _, k in ipairs(lastKinds(n)) do assert(k ~= "pt", "an hour old: gone") end
-- the cap: 300; the oldest normal goes first
STUB.inInstance = true
for i = 1, 305 do C.Send("fe", { k = "lvl", a = i, t = 1 }) end
assert(C.stats.queued <= 300 and C.stats.dropped >= 5, "capped")
STUB.inInstance = false
-- whispers
n = #STUB.sent
C.Whisper("pal", { p = 1 }, "Mario")
STUB.Advance(1)
local w = STUB.sent[#STUB.sent]
assert(w.chatType == "WHISPER" and w.target == "Mario", "whisper to the bare name")
```

Check how the stub reports `IsInInstance`. If it has no `STUB.inInstance`, add `function IsInInstance() return STUB.inInstance == true, STUB.inInstance and "party" or "none" end` to the stub.

- [ ] **Step 2: Run it and watch it fail**

Run: `node tools/run-lua-test.mjs LevelMates tests/queue_v2.test.lua`
Expected: FAIL at "the help request first" or on `C.Whisper` being nil.

- [ ] **Step 3: Implement**

- **Queue items:** `{ text, kind, lane, target, at }`.
- **Insertion:** urgent items go after the last urgent item and before the first normal one.
- **`C.URGENT`:** `{ help = true, helpok = true, helpgo = true, lfg = true, lfgx = true, lfj = true, lfjx = true }`. Sync passes the lane explicitly.
- **`C.Send`:**
  - remove the `inInstance` refusal; always queue;
  - `prio == "now"` maps to `"urgent"`;
  - the cap: while `#queue > 300`, remove the first normal item (else the first item), `C.stats.dropped += 1`, fire `LM_COMM_DROPPED(kind)`.
- **`pump`:**
  - in an instance, items are kept; the first time an item is seen inside, stamp `heldAt = GetTime()` and update `C.stats.held`;
  - expire held items: urgent after 600 s, normal after 3600 s (counted as dropped, with the event fired);
  - the help kinds (`INSTANCE_OK`) still go out inside.
- **Resume:** register `ZONE_CHANGED_NEW_AREA`, `PLAYER_REGEN_ENABLED` and `PLAYER_ENTERING_WORLD` on the Comm frame; on each, `C_Timer.After(2, pump)`.
- **`rawSend(text, target)`:** with a target, send `C_ChatInfo.SendAddonMessage(C.PREFIX, text, "WHISPER", target)`.
- **`C.Whisper(kind, fields, target, prio)`:**
  - encode;
  - `target = ns.ShortName(target):match("^[^%-]+")` (bare name; keep spaces);
  - queue with `target`.
- **Receiving:** `onAddonMessage` accepts `channel == "WHISPER"` only from guildmates (`ns.Roster.IsGuildmate(name)`).
- **The pump:** replace `C_Timer.NewTicker(0.2, pump)` with `ns.Every("comm", 0.2, pump)`. `pump` returns at once when the queue is empty.
- **`C.SendImmediate`:** keeps its instance refusal (goodbyes only).

- [ ] **Step 4: Run the test, then the suite**

Expected: PASS; suite green. Tests that relied on "dropped inside an instance" (search `LM_COMM_DROPPED` in tests) change to "held, sent after leaving".

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat(comm): urgent and normal lanes, a 300 cap, held inside instances, whispers"
```

---

### Task 5: Blobs (chunked payloads)

**Files:**
- Modify: `LevelMates/Comm.lua`
- Test: `tests/blob.test.lua`

**Interfaces:**
- Produces:
  - `C.SendBig(kind, fields, prio, target)`: sends one message if the encoded text fits in 240, else a blob of kind `bl` chunks;
  - the receiver reassembles the text and handles it as if it had arrived as one message (same handlers);
  - `C.SCHEMA.bl = { k = word(8), i = chunkIndex(7), p = text(150) }`.

Payload text inside `p` is the encoded inner message with the US separators replaced by `\001`? No: `text()` forbids control characters. Use `C.Encode`'s escaping instead: the inner message's US becomes `~`, and the inner message is `kind~fields`. Escaping `%;=` already happens for `p` as a field value.

- [ ] **Step 1: Write the failing test**

```lua
-- tests/blob.test.lua
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(30)
local C = ns.Comm
-- a big message goes out as chunks and comes back whole, in any order, duplicates ignored
local got
C.SCHEMA.zz = { x = function(v) return type(v) == "string" and #v <= 2000 end }
C.REQUIRED.zz = { "x" }
C.OnMessage("zz", function(f, name) got = { f.x, name } end)
local big = string.rep("abcdefghij", 60)   -- 600 chars
local n = #STUB.sent
C.SendBig("zz", { x = big })
STUB.Advance(20)
local chunks = {}
for i = n + 1, #STUB.sent do chunks[#chunks + 1] = STUB.sent[i].msg end
assert(#chunks >= 4, "chunked: " .. #chunks)
for _, m in ipairs(chunks) do assert(#m <= 240, "each chunk fits") end
for i = #chunks, 1, -1 do STUB.Receive("LVLM2", chunks[i], "GUILD", "Mario-Testrealm") end   -- reversed
STUB.Receive("LVLM2", chunks[1], "GUILD", "Mario-Testrealm")                                   -- a duplicate
assert(got and got[1] == big and got[2] == "Mario", "whole again")
-- incomplete: dropped after 30 s
got = nil
C.SendBig("zz", { x = big .. "!" }); STUB.Advance(20)
local again = {}
for i = n + #chunks + 1, #STUB.sent do again[#again + 1] = STUB.sent[i].msg end
for i = 1, #again - 1 do STUB.Receive("LVLM2", again[i], "GUILD", "Mario-Testrealm") end
STUB.Advance(31)
STUB.Receive("LVLM2", again[#again], "GUILD", "Mario-Testrealm")
assert(got == nil, "the start was dropped: no half message")
-- a small one is one plain message
n = #STUB.sent
C.SendBig("zz", { x = "short" }); STUB.Advance(2)
assert(#STUB.sent == n + 1 and (C.Decode(STUB.sent[#STUB.sent].msg)) == "zz", "small: one message")
```

`C.REQUIRED` must be exposed (today it is a local `REQUIRED`): rename it to `C.REQUIRED` and keep a local alias.

- [ ] **Step 2: Run it and watch it fail**

Expected: FAIL (`C.SendBig` is nil).

- [ ] **Step 3: Implement**

```lua
------------------------------------------------------------------ blobs
-- A message too big for one goes as chunks of kind "bl": k = blob id, i = "index/total", p = up to 150 chars of the
-- inner message ("kind~k=v;k=v", escaped as any field). Reassembled in any order, duplicates ignored, and an
-- incomplete blob is dropped after 30 s. No acknowledgements: whatever is lost goes again on the next occasion.
C.SCHEMA.bl = { k = word(8), i = chunkIndex(7), p = function(v) return type(v) == "string" and #v >= 1 and #v <= 150 end }
C.REQUIRED.bl = { "k", "i", "p" }
local blobSeq = 0
local function innerText(kind, fields)
	local ok, why = C.Validate(kind, fields)
	if not ok then return nil, why end
	local keys, parts = {}, {}
	for k in pairs(fields) do keys[#keys + 1] = k end
	table.sort(keys)
	for _, k in ipairs(keys) do parts[#parts + 1] = k .. "=" .. esc(fields[k]) end
	return kind .. "~" .. table.concat(parts, ";")
end
function C.SendBig(kind, fields, prio, target)
	local one = C.Encode(kind, fields)
	if one then
		if target then return C.Whisper(kind, fields, target, prio) end
		return C.Send(kind, fields, prio)
	end
	local inner, why = innerText(kind, fields)
	if not inner then ns.Log("blob %s: %s", kind, tostring(why)); return false end
	blobSeq = (blobSeq + 1) % 46656
	local id = string.format("%04x%s", math.floor(GetTime()) % 65536, string.format("%03d", blobSeq % 1000)):sub(1, 8)
	local total = math.ceil(#inner / 150)
	if total > 99 then return false end
	for i = 1, total do
		local f = { k = id, i = i .. "/" .. total, p = inner:sub((i - 1) * 150 + 1, i * 150) }
		if not C.Encode("bl", f) then return false end   -- escaping made a chunk too long: send nothing rather than half
	end
	for i = 1, total do
		local f = { k = id, i = i .. "/" .. total, p = inner:sub((i - 1) * 150 + 1, i * 150) }
		if target then C.Whisper("bl", f, target, prio) else C.Send("bl", f, prio) end
	end
	return true
end

local buffers = {}   -- [sender .. id] = { total, parts = {}, have, at }
local function deliver(kind, fields, name, sender)
	C.stats.received = C.stats.received + 1
	for _, fn in ipairs(handlers[kind] or {}) do fn(fields, name, sender) end
end
local function onChunk(f, name, sender)
	local idx, total = f.i:match("^(%d+)/(%d+)$")
	idx, total = tonumber(idx), tonumber(total)
	if not idx or idx < 1 or idx > total then return end
	local key = name .. ":" .. f.k
	local b = buffers[key]
	if b and (b.total ~= total or GetTime() - b.at > 30) then b = nil end
	if not b then b = { total = total, parts = {}, have = 0, at = GetTime() }; buffers[key] = b end
	if b.parts[idx] then return end
	b.parts[idx] = f.p; b.have = b.have + 1
	if b.have < b.total then return end
	buffers[key] = nil
	local inner = table.concat(b.parts)
	local kind, body = inner:match("^([%w_]+)~(.*)$")
	if not kind or kind == "bl" then C.stats.bad = C.stats.bad + 1; return end
	local fields = {}
	for pair in (body .. ";"):gmatch("([^;]*);") do
		if pair ~= "" then
			local k, v = pair:match("^([%w_]+)=(.*)$")
			if not k then C.stats.bad = C.stats.bad + 1; return end
			fields[k] = unesc(v)
		end
	end
	local schema = C.SCHEMA[kind]
	if schema then for k, v in pairs(fields) do if NUMERIC[schema[k]] and v:match(CANON) then fields[k] = tonumber(v) end end end
	if not C.Validate(kind, fields) then C.stats.bad = C.stats.bad + 1; return end
	deliver(kind, fields, name, sender)
end
handlers.bl = { onChunk }
ns.Every("blobs", 10, function() for k, b in pairs(buffers) do if GetTime() - b.at > 30 then buffers[k] = nil end end end)
```

In `onAddonMessage`, replace the final handler loop with `deliver(kind, fields, name, sender)`. Move `deliver` above `onAddonMessage`.

- [ ] **Step 4: Run the test, then the suite**

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat(comm): big messages go as chunks and come back whole"
```

---

### Task 6: Sync record store

**Files:**
- Create: `LevelMates/Sync.lua` (`.toc` after `Roster.lua`)
- Test: `tests/sync_store.test.lua`, `tests/sync_relay.net.mjs`

**Interfaces:**
- Consumes: `C.Send`, `C.SendBig`, `C.Whisper` (Task 4/5), `ns.Every` (Task 3), `R.IsGuildmate`, `ns.Me()`.
- Produces:
  - `S.Define(type, spec)`. The spec holds:
    - `class = "board" | "personal"`;
    - `life = seconds`;
    - `fields = { name = validator }` and `required = { … }` (validators from `ns.Comm.V`, exported in this task);
    - `lane = "urgent" | "normal"`;
    - `may = function(rec, sender) return bool end` (who may change it; defaults to "the owner");
    - `max = n` (per type);
    - `onChange = function(rec, old, how)` with `how` one of `"live" | "catchup" | "mine" | "expired"`.
  - `S.Put(type, id, data [, owner])`. The owner defaults to me, and a different owner is allowed only if `may` accepts me. The function sets `rev = max(GetServerTime(), old.rev + 1)` and `exp = now + life`, or `data._exp` when given, which must be at most `now + life`.
  - `S.Remove(type, id)`, which writes a tombstone.
  - `S.Get(type, id)` and `S.List(type, filterFn)`, which return live, non-tombstone records sorted by rev.
  - `S.Digest(type)`, which returns `count, sum`.
  - A record is `{ t, id, o, v, e, dead, d = data }`.
  - The wire kind is the type name itself. Its fields are the type's fields plus `id`, `o` (sent only when relaying, i.e. owner ≠ me), `v` and `e`. A tombstone uses kind `x` with `t`, `id`, `o?`, `v` and `e`.

- [ ] **Step 1: Write the failing unit test**

```lua
-- tests/sync_store.test.lua
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(30)
local S, C, V = ns.Sync, ns.Comm, ns.Comm.V
local changes = {}
S.Define("tst", { class = "board", life = 3600, fields = { n = V.text(40) }, required = { "n" },
	onChange = function(rec, old, how) changes[#changes + 1] = { rec, old, how } end })
local function last(kind) for i = #STUB.sent, 1, -1 do local k, f = C.Decode(STUB.sent[i].msg); if k == kind then return f end end end
-- mine: stored and sent
S.Put("tst", "a1", { n = "hola" }); STUB.Advance(2)
local f = last("tst")
assert(f and f.id == "a1" and f.n == "hola" and f.v and f.e and f.o == nil, "sent without owner (it is me)")
assert(S.Get("tst", "a1").d.n == "hola", "stored")
-- someone else's, live
STUB.Receive("LVLM2", C.Encode("tst", { id = "b1", n = "de Mario", v = GetServerTime(), e = GetServerTime() + 600 }), "GUILD", "Mario-Testrealm")
assert(S.Get("tst", "b1") and S.Get("tst", "b1").o == "Mario" and changes[#changes][3] == "live", "Mario's")
-- older copy: ignored; newer: taken
STUB.Receive("LVLM2", C.Encode("tst", { id = "b1", n = "vieja", v = GetServerTime() - 100, e = GetServerTime() + 600 }), "GUILD", "Mario-Testrealm")
assert(S.Get("tst", "b1").d.n == "de Mario", "older ignored")
-- relayed by Luis for Mario: accepted (board), owner stays Mario
STUB.Receive("LVLM2", C.Encode("tst", { id = "c1", o = "Mario", n = "reenviada", v = GetServerTime(), e = GetServerTime() + 600 }), "GUILD", "Luis-Testrealm")
assert(S.Get("tst", "c1") and S.Get("tst", "c1").o == "Mario", "relay keeps the owner")
-- Luis cannot change Mario's record as himself
STUB.Receive("LVLM2", C.Encode("tst", { id = "b1", n = "pirata", v = GetServerTime() + 5, e = GetServerTime() + 600 }), "GUILD", "Luis-Testrealm")
assert(S.Get("tst", "b1").d.n == "de Mario", "an id belongs to its owner")
-- tombstone: removed, and an older copy cannot bring it back
STUB.Receive("LVLM2", C.Encode("x", { t = "tst", id = "b1", v = GetServerTime() + 10, e = GetServerTime() + 600 }), "GUILD", "Mario-Testrealm")
assert(not S.Get("tst", "b1"), "removed")
STUB.Receive("LVLM2", C.Encode("tst", { id = "b1", o = "Mario", n = "de Mario", v = GetServerTime(), e = GetServerTime() + 600 }), "GUILD", "Luis-Testrealm")
assert(not S.Get("tst", "b1"), "not resurrected by a relay")
-- a tombstone before its record
STUB.Receive("LVLM2", C.Encode("x", { t = "tst", id = "d1", o = "Ana", v = GetServerTime() + 10, e = GetServerTime() + 600 }), "GUILD", "Luis-Testrealm")
STUB.Receive("LVLM2", C.Encode("tst", { id = "d1", n = "tarde", v = GetServerTime(), e = GetServerTime() + 600 }), "GUILD", "Ana-Testrealm")
assert(not S.Get("tst", "d1"), "the tombstone came first: still gone")
-- from the future: rejected
STUB.Receive("LVLM2", C.Encode("tst", { id = "e1", n = "futuro", v = GetServerTime() + 1000, e = GetServerTime() + 2000 }), "GUILD", "Mario-Testrealm")
assert(not S.Get("tst", "e1"), "future rejected")
-- personal: never from someone else
S.Define("tsp", { class = "personal", life = 3600, fields = { n = V.text(40) }, required = { "n" } })
STUB.Receive("LVLM2", C.Encode("tsp", { id = "Mario", o = "Mario", n = "x", v = GetServerTime(), e = GetServerTime() + 600 }), "GUILD", "Luis-Testrealm")
assert(not S.Get("tsp", "Mario"), "personal: not relayed")
-- expiry: pruned by the shared job, with an "expired" change
STUB.Advance(700)
assert(not S.Get("tst", "c1"), "expired")
-- not in the guild: ignored
STUB.Receive("LVLM2", C.Encode("tst", { id = "z1", o = "Extraño", n = "x", v = GetServerTime(), e = GetServerTime() + 600 }), "GUILD", "Luis-Testrealm")
assert(not S.Get("tst", "z1"), "owner not in the guild")
-- pending: put while not ready, sent at the next heartbeat
ns.Comm.Stop()
S.Put("tst", "p1", { n = "luego" })
ns.Comm.Start(); STUB.Advance(40)
assert(last("tst") and last("tst").id == "p1", "pending sent later")
-- saved per guild
assert(ns.db.sync and ns.db.sync["Test Guild"] and ns.db.sync["Test Guild"].tst["a1"], "saved")
```

- [ ] **Step 2: Run it and watch it fail**

Expected: FAIL (`ns.Sync` is nil).

- [ ] **Step 3: Implement `Sync.lua`**

In `Comm.lua` export the validators: `C.V = { text = text, word = word, int = int, num = num, idlist = idlist, itemids = itemids, oneOf = oneOf, roles = roles }`. Add `C.SCHEMA.x = { t = word(12), id = word(24), o = text(48), v = int(0, 4000000000), e = int(0, 4000000000) }` and `C.REQUIRED.x = { "t", "id", "v", "e" }`.

```lua
-- Sync.lua: shared records. Each is { t, id, o = owner, v = rev (server time of the owner's change), e = expiry,
-- dead = tombstone, d = data }. Board types are kept by everyone and relayed to newcomers; personal types come only
-- from their owner. Newer rev wins; a tombstone keeps a record from coming back until it expires.
local _, ns = ...
local S = {}
ns.Sync = S
local C, R = ns.Comm, ns.Roster
local types = {}
local FUTURE = 300
local COMMON = { "id", "o", "v", "e" }

local function now() return GetServerTime() end
local function me() return ns.Me() end
local function store(t)
	ns.db.sync = ns.db.sync or {}
	local g = GetGuildInfo("player") or "?"
	ns.db.sync[g] = ns.db.sync[g] or {}
	ns.db.sync[g][t] = ns.db.sync[g][t] or {}
	return ns.db.sync[g][t]
end
S.Store = store

function S.Define(t, spec)
	spec.class = spec.class or "board"
	spec.may = spec.may or function(rec, who) return rec.o == who end
	types[t] = spec
	local schema = { id = C.V.word(24), o = C.V.text(48), v = C.V.int(0, 4000000000), e = C.V.int(0, 4000000000) }
	for k, fn in pairs(spec.fields or {}) do schema[k] = fn end
	C.SCHEMA[t] = schema
	local req = { "id", "v", "e" }
	for _, k in ipairs(spec.required or {}) do req[#req + 1] = k end
	C.REQUIRED[t] = req
	C.OnMessage(t, function(f, name) S.Receive(t, f, name, false) end)
end

local function wire(rec)
	local f = { id = rec.id, v = rec.v, e = rec.e }
	if rec.o ~= me() then f.o = rec.o end
	for k, v in pairs(rec.d or {}) do f[k] = v end
	return f
end
local function send(rec, target)
	local spec = types[rec.t]
	local ok
	if rec.dead then
		local f = { t = rec.t, id = rec.id, v = rec.v, e = rec.e }
		if rec.o ~= me() then f.o = rec.o end
		ok = target and C.Whisper("x", f, target, spec.lane) or (not target and C.Send("x", f, spec.lane))
	else
		ok = C.SendBig(rec.t, wire(rec), spec.lane, target)
	end
	return ok
end
S.SendRecord = send

local function fire(spec, rec, old, how) if spec.onChange then spec.onChange(rec, old, how) end end

function S.Put(t, id, data, owner)
	local spec = types[t]
	owner = owner or me()
	local s = store(t)
	local old = s[id]
	if old and not spec.may(old, me()) then return false end
	local rev = math.max(now(), (old and old.v or 0) + 1)
	local exp = math.min(now() + spec.life, data._exp or (now() + spec.life))
	data._exp = nil
	local rec = { t = t, id = id, o = owner, v = rev, e = exp, d = data }
	s[id] = rec
	rec.pending = not (C.IsReady() and send(rec)) or nil
	fire(spec, rec, old, "mine")
	return true
end

function S.Remove(t, id)
	local spec = types[t]
	local s = store(t)
	local old = s[id]
	if not old or not spec.may(old, me()) then return false end
	local rec = { t = t, id = id, o = old.o, v = math.max(now(), old.v + 1), e = old.e, dead = true }
	s[id] = rec
	rec.pending = not (C.IsReady() and send(rec)) or nil
	fire(spec, rec, old, "mine")
	return true
end

function S.Receive(t, f, sender, catchup)
	local spec = types[t]
	if not spec then return end
	local owner = f.o or sender
	if owner ~= sender and spec.class == "personal" then return end
	if owner == me() then return end
	if not (R.IsGuildmate(owner) or R.mates[owner]) then return end
	if f.v > now() + FUTURE or f.e < now() then return end
	local s = store(t)
	local old = s[f.id]
	if old and old.o ~= owner and not spec.may(old, sender) then return end   -- an id belongs to its owner
	if old and old.v >= f.v then return end
	if owner ~= sender and not (sender == owner or spec.may({ o = owner }, sender) or f.o) then return end
	local d = {}
	for k, v in pairs(f) do if k ~= "id" and k ~= "o" and k ~= "v" and k ~= "e" then d[k] = v end end
	if spec.max and not old then
		local n = 0; for _, r in pairs(s) do if not r.dead then n = n + 1 end end
		if n >= spec.max then return end
	end
	local rec = { t = t, id = f.id, o = owner, v = f.v, e = f.e, d = d }
	s[f.id] = rec
	fire(spec, rec, old, catchup and "catchup" or "live")
end

C.OnMessage("x", function(f, sender)
	local spec = types[f.t]
	if not spec then return end
	local owner = f.o or sender
	if owner == me() then return end
	if f.v > now() + FUTURE or f.e < now() then return end
	local s = store(f.t)
	local old = s[f.id]
	if old and old.v >= f.v then return end
	if old and not spec.may(old, owner) and not spec.may(old, sender) then return end
	s[f.id] = { t = f.t, id = f.id, o = old and old.o or owner, v = f.v, e = f.e, dead = true }
	if old and not old.dead then fire(spec, s[f.id], old, "live") end
end)

function S.Get(t, id)
	local r = store(t)[id]
	if r and not r.dead and r.e >= now() then return r end
end
function S.List(t, keep)
	local out = {}
	for _, r in pairs(store(t)) do if not r.dead and r.e >= now() and (not keep or keep(r)) then out[#out + 1] = r end end
	table.sort(out, function(a, b) if a.v ~= b.v then return a.v < b.v end; return a.id < b.id end)
	return out
end
function S.Digest(t)
	local n, sum = 0, 0
	for _, r in pairs(store(t)) do if r.e >= now() then n = n + 1; sum = (sum + r.v + (r.dead and 7 or 0)) % 2147483647 end end
	return n, sum
end
function S.Types(class) local out = {}; for t, spec in pairs(types) do if not class or spec.class == class then out[#out + 1] = t end end; table.sort(out); return out end
function S.Spec(t) return types[t] end

-- Expired records and tombstones go once a minute (never while a list is read).
ns.Every("sync-prune", 60, function()
	for t, spec in pairs(types) do
		local s = store(t)
		for id, r in pairs(s) do
			if r.e < now() then s[id] = nil; if not r.dead then fire(spec, r, r, "expired") end end
		end
	end
end)
-- Whatever could not go out goes with the next heartbeat.
ns.On("LM_HB_SENT", function()
	for t in pairs(types) do
		for _, r in pairs(store(t)) do if r.pending and r.o == me() and send(r) then r.pending = nil end end
	end
end)
```

The relay acceptance line (`if owner ~= sender and not (…)`) is deliberately permissive for board types: any guildmate may relay a board record that names its owner. The checks that matter are guild membership, the rev, and the "owner may change it" rule on `old`. Simplify that line to `-- relays of board records: anyone in the guild may carry them` and remove it if the test passes without it.

- [ ] **Step 4: Run the unit test**

Expected: PASS. If `R.IsGuildmate("Extraño")` is true in the stub, the guild set is `STUB.guildMembers`: leave Extraño out of it.

- [ ] **Step 5: Write and run the multi-client relay test**

```js
// tests/sync_relay.net.mjs: a board record outlives its owner's session
import { Net } from '../tools/lua-net.mjs';
const net = new Net(['Ana', 'Ben', 'Cris']);
const define = 'local _, ns = ...; ns.Sync.Define("tst", { class = "board", life = 3600, fields = { n = ns.Comm.V.text(40) }, required = { "n" } })';
for (const n of ['Ana', 'Ben', 'Cris']) net.run(n, define);
net.leave('Cris');
net.advance(5);
net.run('Ana', 'local _, ns = ...; ns.Sync.Put("tst", "q1", { n = "Minas 21:00" })');
net.advance(5);
const ben = net.run('Ben', 'local _, ns = ...; local r = ns.Sync.Get("tst", "q1"); return r and r.d.n or ""');
if (ben !== 'Minas 21:00') { console.error('Ben did not get it:', ben); process.exit(1); }
console.log('ok tests/sync_relay.net.mjs (live part)');
```

The catch-up half of this test (Ana leaves, Cris comes, Ben hands it over) is added in Task 7.

- [ ] **Step 6: Run the suite and commit**

```bash
npm test
git add -A && git commit -m "feat(sync): shared records with owner, rev, expiry and tombstones"
```

---

### Task 7: Catch-up (hello, claim, whispered batches)

**Files:**
- Modify: `LevelMates/Sync.lua`, `LevelMates/Roster.lua` (`hi` replaces `ping` in `announce`; the `ping` handler is removed)
- Modify: the modules listening to `LM_PING_ANSWERED` (they listen to `LM_HELLO_ANSWERED`, which Roster fires after its heartbeat, exactly where `LM_PING_ANSWERED` was fired)
- Test: `tests/sync_catchup.net.mjs`, `tests/sync_catchup.test.lua`

**Interfaces:**
- Produces:
  - wire kinds:
    - `hi { s = "type:count:sum,…" }`, at most 200 chars (the board types only);
    - `hc { to = name, t = type }`, a claim on GUILD;
    - `hw { t = type, s = "count:sum" }`, a want whisper;
  - the event `LM_HELLO_ANSWERED`;
  - `onChange` is called with how = `"catchup"` for whispered records.

- [ ] **Step 1: Write the failing multi-client test**

```js
// tests/sync_catchup.net.mjs: Ana posts and leaves; Cris logs in later and gets it from Ben, and only Ben or Dani
// answers (one claim).
import { Net } from '../tools/lua-net.mjs';
const names = ['Ana', 'Ben', 'Cris', 'Dani'];
const net = new Net(names);
const define = 'local _, ns = ...; ns.Sync.Define("tst", { class = "board", life = 3600, fields = { n = ns.Comm.V.text(40) }, required = { "n" } })';
for (const n of names) net.run(n, define);
net.leave('Cris');
net.advance(5);
net.run('Ana', 'local _, ns = ...; ns.Sync.Put("tst", "q1", { n = "Minas 21:00" }); ns.Sync.Put("tst", "q2", { n = "Borrada" })');
net.advance(3);
net.run('Ana', 'local _, ns = ...; ns.Sync.Remove("tst", "q2")');
net.advance(3);
net.leave('Ana');
net.gone.delete('Cris');
net.run('Cris', 'local _, ns = ...; ns.Roster.Announce()');   // as a login: hello with my (empty) digest
net.advance(15);
const got = net.run('Cris', 'local _, ns = ...; local r = ns.Sync.Get("tst", "q1"); return r and (r.d.n .. "|" .. r.o) or ""');
if (got !== 'Minas 21:00|Ana') { console.error('Cris did not catch up:', got); process.exit(1); }
const dead = net.run('Cris', 'local _, ns = ...; return ns.Sync.Get("tst", "q2") and "alive" or "gone"');
if (dead !== 'gone') { console.error('the removed one came back'); process.exit(1); }
const answers = net.run('Ben', 'local _, ns = ...; return ns.Sync.stats.answered or 0') + net.run('Dani', 'local _, ns = ...; return ns.Sync.stats.answered or 0');
if (answers !== 1) { console.error('answers:', answers); process.exit(1); }
console.log('ok tests/sync_catchup.net.mjs');
```

`ns.Roster.Announce` is the existing `announce` local, exposed for this. If the harness keeps `gone` private, add a `net.join(name)` that deletes from `gone`.

- [ ] **Step 2: Run it and watch it fail**

Expected: FAIL ("Cris did not catch up").

- [ ] **Step 3: Implement in `Sync.lua`**

```lua
------------------------------------------------------------------ catch-up
-- At login I say hello with a digest of every board type. Whoever holds something different waits 1-6 s; the first
-- to finish claims the answer on GUILD (hc) and whispers me that type's records and tombstones, oldest first, 20 a
-- batch; the others hear the claim and stay quiet. If my digest still differs after a batch, I ask one of them (hw).
S.stats = { answered = 0 }
C.SCHEMA.hi = { s = C.V.text(200) }; C.REQUIRED.hi = { "s" }
C.SCHEMA.hc = { to = C.V.text(48), t = C.V.word(12) }; C.REQUIRED.hc = { "to", "t" }
C.SCHEMA.hw = { t = C.V.word(12), s = C.V.text(40) }; C.REQUIRED.hw = { "t", "s" }

local function digestString()
	local parts = {}
	for _, t in ipairs(S.Types("board")) do local n, sum = S.Digest(t); parts[#parts + 1] = t .. ":" .. n .. ":" .. sum end
	return table.concat(parts, ",")
end
function S.Hello() C.Send("hi", { s = digestString() }, "urgent") end

local claimed = {}   -- [requester .. ":" .. type] = time somebody claimed it
local function batch(t, to)
	local spec = types[t]
	local list = {}
	for _, r in pairs(store(t)) do if r.e >= now() and (not spec.relayKeep or spec.relayKeep(r)) then list[#list + 1] = r end end
	table.sort(list, function(a, b) return a.v < b.v end)
	local limit = spec.relayMax or #list
	local first = math.max(1, #list - limit + 1)
	for i = first, #list do send(list[i], to) end
end
local function answer(t, to)
	local key = to .. ":" .. t
	if claimed[key] and GetTime() - claimed[key] < 30 then return end
	claimed[key] = GetTime()
	C.Send("hc", { to = to, t = t }, "urgent")
	S.stats.answered = S.stats.answered + 1
	batch(t, to)
end
C.OnMessage("hi", function(f, name)
	for part in f.s:gmatch("[^,]+") do
		local t, n, sum = part:match("^([%w_]+):(%d+):(%d+)$")
		if t and types[t] and types[t].class == "board" then
			local mn, msum = S.Digest(t)
			if mn > 0 and (mn ~= tonumber(n) or msum ~= tonumber(sum)) then
				C_Timer.After(1 + math.random() * 5, function() answer(t, name) end)
			end
		end
	end
	ns.Fire("LM_HELLO_HEARD", name)
end)
C.OnMessage("hc", function(f) claimed[f.to .. ":" .. f.t] = GetTime() end)
C.OnMessage("hw", function(f, name)
	if types[f.t] and types[f.t].class == "board" then batch(f.t, name) end
end)
```

Whispered records reach `S.Receive` through the same `C.OnMessage(t, …)` handler. To mark them as catch-up, make `Comm.deliver` pass `channel` as a fourth argument, and have the `Define` handler call `S.Receive(t, f, name, channel == "WHISPER")`.

The "ask again if it still differs" follow-up (`hw`): 12 s after `S.Hello`, compare the digests reported by claimers. Since `hc` does not carry the claimer's digest, implement it simply: if no record of a type arrived and someone claimed that type, send `hw` once to the claimer.

In `Roster.lua`:
- `announce()` sends `S.Hello()` at +3 s (instead of `ping`);
- the heartbeat goes first;
- expose `R.Announce = announce`;
- the `ping` handler body (jittered heartbeat + quests + `LM_PING_ANSWERED`) moves to a listener on `LM_HELLO_HEARD`, firing `LM_HELLO_ANSWERED`.

Rename every `LM_PING_ANSWERED` listener to `LM_HELLO_ANSWERED`:

```bash
grep -l LM_PING_ANSWERED LevelMates/*.lua tests/*.lua
```

Personal types: `S.Personal` (Task 10) resends on `LM_HELLO_ANSWERED`.

- [ ] **Step 4: Add the catch-up half to the relay test and run both**

Run: `node tests/sync_catchup.net.mjs`, then `npm test`.
Expected: `ok …`; suite green. Unit tests that called `STUB.Receive(... C.Encode("ping", {}) ...)` change to `C.Encode("hi", { s = "" })`. `hi` requires `s`; allow an empty string by making `s` a `C.V.text(200)` that accepts "": use `function(v) return type(v) == "string" and #v <= 200 and not v:find("[%c|]") end`.

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat(sync): newcomers catch up from one guildmate, by whisper, without a flood"
```

---

### Task 8: Meetups on Sync

**Files:**
- Modify: `LevelMates/Meetups.lua`
- Test: `tests/meetups.test.lua` (existing, adapted), `tests/meetups_sync.net.mjs` (new)

**Interfaces:**
- Consumes: `S.Define`, `S.Put`, `S.Remove`, `S.Get`, `S.List`.
- Produces:
  - unchanged public API: `M.List(d)`, `M.Create`, `M.Cancel`, `M.Join`, `M.Leave`, `M.MyRole`, `M.When`, `M.Tick`;
  - meetup tables keep the shape `{ id, d, at, n, by, joined = { [name] = role } }`;
  - record types:
    - `qd`: board, urgent, `life = 8 days`, fields `d`, `at`, `n`, id = meetup id;
    - `qj`: board, urgent, `life = 8 days`, fields `r`, id = `meetupId .. "." .. joinerShortKey` (see below).

The id field is a `word(24)`. A name with a space cannot go into an id. Use `ns.NameKey(name)` = `name:gsub("[^%w]", "")` truncated to 12 characters, and keep the full name as the record owner. Read the joiner from `rec.o`.

- [ ] **Step 1: Write the failing net test**

```js
// tests/meetups_sync.net.mjs: a meetup outlives its creator's session; a late login sees it with its joiners
import { Net } from '../tools/lua-net.mjs';
const net = new Net(['Ana', 'Ben', 'Cris']);
net.leave('Cris');
net.advance(5);
net.run('Ana', 'local _, ns = ...; ns.Meetups.Create(1, ns.Meetups.Now() + 120, "traed pociones")');
net.advance(3);
net.run('Ben', 'local _, ns = ...; local m = ns.Meetups.List()[1]; ns.Meetups.Join(m.id, "H")');
net.advance(3);
net.leave('Ana');
net.gone.delete('Cris');
net.run('Cris', 'local _, ns = ...; ns.Roster.Announce()');
net.advance(15);
const got = net.run('Cris', 'local _, ns = ...; local m = ns.Meetups.List()[1]; return m and (m.by .. "|" .. (m.joined["Ben"] or "-") .. "|" .. (m.n or "")) or ""');
if (got !== 'Ana|H|traed pociones') { console.error('Cris sees:', got); process.exit(1); }
console.log('ok tests/meetups_sync.net.mjs');
```

- [ ] **Step 2: Run it and watch it fail**

Expected: FAIL (Cris sees nothing: today only Ana resends her meetups).

- [ ] **Step 3: Rewrite the storage and messages of `Meetups.lua`**

```lua
local S = ns.Sync
local LIFE = 8 * 86400
local function key(name) return (tostring(name):gsub("[^%w]", "")):sub(1, 12) end
S.Define("qd", { class = "board", life = LIFE, lane = "urgent", max = M.MAX,
	fields = { d = ns.Comm.V.int(1, 99), at = ns.Comm.V.int(0, 100000000), n = ns.Comm.V.text(40) }, required = { "d", "at" },
	onChange = function(rec, old, how)
		if how == "live" and not old and ns.db.settings.lfgNotices and not rec.dead then
			ns.Notice(L.MEET_NEW, rec.o, D.Name(rec.d.d), M.When({ at = rec.d.at }))
		end
		changed()
	end })
S.Define("qj", { class = "board", life = LIFE, lane = "urgent",
	fields = { r = ns.Comm.V.oneOf("T", "H", "D") }, required = { "r" },
	onChange = function(rec, old, how)
		local mid = rec.id:match("^([^%.]+)%.")
		local m = mid and S.Get("qd", mid)
		if how == "live" and not old and not rec.dead and m and m.o == me() then
			ns.Notice(L.MEET_JOINED, rec.o, D.Name(m.d.d), M.When(m.d), L["ROLE_" .. rec.d.r])
		end
		changed()
	end })

-- The meetups as the rest of the addon knows them, from the records.
local function view(rec)
	local m = { id = rec.id, d = rec.d.d, at = rec.d.at, n = rec.d.n, by = rec.o, joined = {} }
	for _, j in ipairs(S.List("qj", function(r) return r.id:sub(1, #rec.id + 1) == rec.id .. "." end)) do m.joined[j.o] = j.d.r end
	return m
end
function M.List(dungeonId)
	local out = {}
	for _, rec in ipairs(S.List("qd")) do
		if M.Now() <= rec.d.at + M.KEEP and (not dungeonId or rec.d.d == dungeonId) then out[#out + 1] = view(rec) end
	end
	table.sort(out, function(a, b) if a.at ~= b.at then return a.at < b.at end; return a.id < b.id end)
	return out
end
```

Then:
- `M.Create` checks the per-person and total limits over `M.List()` and calls `S.Put("qd", id, { d = d, at = at, n = clean, _exp = (at + M.KEEP) * 60 })`, wrapped in `if not C.IsReady() then … end` as now.
- `M.Cancel` calls `S.Remove("qd", id)`.
- `M.Join` calls `S.Put("qj", id .. "." .. key(me()), { r = role })`.
- `M.Leave` calls `S.Remove("qj", id .. "." .. key(me()))`.
- `M.MyRole(id)` reads `S.Get("qj", id .. "." .. key(me()))`.
- Remove the old `store()`, `myJoins()`, `prune()` and the `qd`/`qdx`/`qj`/`qjx` handlers, plus the `LM_PING_ANSWERED` listener. Delete `qdx` and `qjx` from `C.SCHEMA` and `C.REQUIRED`.
- `/lm sim quedada` (in `Sim.lua`) puts records with `S.Put(..., owner)`. To keep sim records local, add `sim = true` in the data and skip sending when `data.sim`. `Sync.Put`: `if data.sim then rec.pending = nil; s[id] = rec; fire(...); return true end` before sending.

**Migration of 0.3.2 data**, once, at `LM_LOADED`:

```lua
ns.On("LM_LOADED", function()
	if ns.db.meetups and not ns.db.meetupsMigrated then
		for _, list in pairs(ns.db.meetups) do
			for id, m in pairs(list) do
				if m.by and m.at and m.d and not m.sim then
					local s = S.Store("qd")
					s[id] = s[id] or { t = "qd", id = id, o = m.by, v = 1, e = (m.at + M.KEEP) * 60, d = { d = m.d, at = m.at, n = m.n } }
				end
			end
		end
		ns.db.meetupsMigrated = true
	end
end)
```

The store is per guild while the old data is keyed by guild too. Only migrate the current guild's list (`ns.db.meetups[GetGuildInfo("player")]`) and do it on `LM_WORLD`, when the guild is known.

- [ ] **Step 4: Adapt `tests/meetups.test.lua`**

Messages are now `qd`/`qj` records with `v` and `e`, and `qdx`/`qjx` are tombstones of kind `x`:
- every `C.Encode("qd", { id = …, d = …, at = …, n = … })` gains `v = GetServerTime(), e = GetServerTime() + 86400`;
- every `C.Encode("qdx", { id = X })` becomes `C.Encode("x", { t = "qd", id = X, v = GetServerTime() + 1, e = GetServerTime() + 86400 })`;
- `qj` ids become `meetupId .. "." .. key(name)`.

Keep every behaviour assertion.

- [ ] **Step 5: Run the tests**

Run: `node tests/meetups_sync.net.mjs`, `node tools/run-lua-test.mjs LevelMates tests/meetups.test.lua`, then `npm test`.
Expected: all pass.

- [ ] **Step 6: Commit**

```bash
git add -A && git commit -m "feat(meetups): kept and handed over by everyone; a late login sees them with their joiners"
```

---

### Task 9: Goals, wall, questions, recruit templates and offers on Sync

Same shape as Task 8, one module per commit. For each:
1. Write a `.net.mjs` test: owner posts, owner leaves, a late login sees it.
2. Watch it fail.
3. Define the type(s) and point the module's list and create/remove at Sync.
4. Migrate the 0.3.2 saved data once on `LM_WORLD`.
5. Adapt the module's existing `.test.lua` encodes (`v`/`e` added; removals as `x`).
6. Run the module's tests, then `npm test`.
7. Commit.

**Interfaces:**

| Module | Type(s) | Class / lane | Life | Fields | Id | `may` | Notes |
|---|---|---|---|---|---|---|---|
| `Goals.lua` | `go` (goal), `gc` (my contribution), `gd` (my dungeon done) | board / normal | goal end + 1 day | `go`: `ty`, `a`, `w`, `s`, `e`; `gc`: `n`; `gd`: none | `go`: goal id; `gc`/`gd`: `goalId .. "." .. key(me)` | `go`: owner or `R.IsOfficer(who)`; others: owner | `gx` becomes `S.Remove("go", id)`. Progress is the sum of `gc`/`gd` records under the goal. |
| `Feed.lua` | `fe` | board / normal | 7 days | `k`, `a`, `b`, `t` | `key(me) .. t .. k` (unique per author and second) | owner | `relayKeep = function(r) return r.v > now() - 48 * 3600 end`, `relayMax = 40` |
| `Ask.lua` | `ask` | board / normal | 24 h | `x` | the question id | owner | |
| `Recruit.lua` | `rt` (template i), `rc` (last post) | board / normal | 30 days | `rt`: `i`, `x`; `rc`: `t` | `rt`: `"t" .. i`; `rc`: `"last"` | `R.IAmOfficer`-style check on the sender: `may = function(_, who) return R.IsOfficer(who) end` | The newest wins already through `v`; the old `v` field of `rt` becomes the record rev. |
| `Gifts.lua` | `gv` (my free offers), `sl` (my priced offers) | board / normal | 14 days | as today (`ids` / `p`) | owner key | owner | One record per owner. `gr`/`gro` stay plain messages for now (a reservation is a moment between two people). |

**Tests to write first** (one per module, same pattern as `tests/meetups_sync.net.mjs`):
- `tests/goals_sync.net.mjs`: an officer Ana creates a level goal and leaves; Cris logs in; `ns.Goals.List()[1].by == "Ana"`. In the harness, make Ana an officer: `STUB.officers = { Ana = true }` before her actions, or whatever `R.IsOfficer` reads in the stub.
- `tests/feed_sync.net.mjs`: Ana levels up (`ns.Fire("PLAYER_LEVEL_UP", 21)` or the Feed entry point) and leaves; Cris sees the wall entry.
- `tests/ask_sync.net.mjs`: Ana asks her class and leaves; Cris, of the same class, sees the question. All harness clients default to the stub class; that is fine.
- `tests/recruit_sync.net.mjs`: officer Ana edits template 2 and leaves; officer Cris logs in and gets template 2.
- `tests/gifts_sync.net.mjs`: Ana offers an item and leaves; Cris sees it on the market.

- [ ] **Step 1:** Goals (test, implement, migrate, adapt, run, commit `feat(goals): …`)
- [ ] **Step 2:** Feed (same; commit `feat(wall): …`)
- [ ] **Step 3:** Ask (same; commit `feat(ask): …`)
- [ ] **Step 4:** Recruit (same; commit `feat(recruit): …`)
- [ ] **Step 5:** Gifts offers (same; commit `feat(market): …`)

After each step: `npm test` green before committing.

---

### Task 10: Personal records (wishes, professions, build, macros, alts, points, achievements, personal goal, rested, partner)

**Files:**
- Modify: `LevelMates/Sync.lua` (`S.Personal`)
- Modify: `Wishlist.lua`, `Professions.lua`, `Builds.lua`, `Macros.lua`, `Alts.lua`, `Points.lua`, `Achievements.lua`, `Personal.lua`, `Rested.lua`, the partner module (`pal`; find it with `grep -l '"pal"' LevelMates/*.lua`)
- Test: `tests/sync_personal.test.lua`

**Interfaces:**
- Produces: `S.Personal(kind, buildFieldsFn, opts)`, which returns `{ Mark = fn() }`. Calling `Mark()` means "my state changed". The helper:
  - sends `kind` with `buildFieldsFn()` (or a list of field tables for multi-message kinds such as macros), using `C.SendBig`;
  - keeps it pending if not ready, and retries on `LM_HB_SENT`;
  - resends on `LM_HELLO_ANSWERED`, coalesced so several hellos within 10 s give one resend;
  - honours `opts.enabled()` (the module's share setting);
  - on `LM_COMM_DROPPED(kind)` marks it pending again.

The kinds keep their current wire fields; they are not records with rev. The owner is the sender, the latest wins, and that is unchanged. Only the copied "pending / resend / dropped" code moves.

- [ ] **Step 1: Write the failing test**

```lua
-- tests/sync_personal.test.lua
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(30)
local S, C = ns.Sync, ns.Comm
local state = 1
local P = S.Personal("pal", function() return { p = state } end, { enabled = function() return true end })
local function count(kind, from) local n = 0; for i = from + 1, #STUB.sent do if (C.Decode(STUB.sent[i].msg)) == kind then n = n + 1 end end; return n end
local n = #STUB.sent
P.Mark(); STUB.Advance(2)
assert(count("pal", n) == 1, "sent on change")
-- three hellos close together: one resend
n = #STUB.sent
for i = 1, 3 do STUB.Receive("LVLM2", C.Encode("hi", { s = "" }), "GUILD", "Mario-Testrealm") end
STUB.Advance(12)
assert(count("pal", n) == 1, "one resend for a burst of hellos: " .. count("pal", n))
-- dropped: sent again with the next heartbeat
n = #STUB.sent
ns.Fire("LM_COMM_DROPPED", "pal")
STUB.Advance(40)
assert(count("pal", n) >= 1, "resent after a drop")
```

- [ ] **Step 2: Run it and watch it fail.**

- [ ] **Step 3: Implement `S.Personal`**

```lua
-- Personal state (my wishes, professions, build…): whole-state messages from their owner. One helper for what each
-- module used to copy: send on change, keep it pending while it cannot go, resend to newcomers once per burst.
function S.Personal(kind, build, opts)
	opts = opts or {}
	local P, pending, resendAt = {}, false, nil
	local function enabled() return not opts.enabled or opts.enabled() end
	local function go()
		if not enabled() then pending = false; return end
		if not C.IsReady() then pending = true; return end
		local fields = build()
		if not fields then pending = false; return end
		local list = fields[1] and fields or { fields }
		local ok = true
		for _, f in ipairs(list) do ok = C.SendBig(kind, f) and ok end
		pending = not ok
	end
	function P.Mark() go() end
	ns.On("LM_HB_SENT", function() if pending then go() end end)
	ns.On("LM_COMM_DROPPED", function(k) if k == kind then pending = true end end)
	ns.On("LM_HELLO_ANSWERED", function()
		if resendAt then return end
		resendAt = GetTime()
		C_Timer.After(math.random() * 5, function() resendAt = nil; go() end)
	end)
	return P
end
```

- [ ] **Step 4: Move each module onto it, one commit per module**

For each module: replace its `pending`, `resend` and `sentAt` locals and its `LM_PING_ANSWERED` / `LM_ANNOUNCED` / `LM_HB_SENT` / `LM_COMM_DROPPED` listeners with one `S.Personal(...)`, and call `P.Mark()` where it used to call `send()`. Run the module's own tests after each.

- [ ] **Step 5: Run the suite and commit**

```bash
npm test
git add -A && git commit -m "refactor(sync): one helper for personal state instead of eight copies"
```

---

### Task 11: Debug, report, docs and 0.4.0

**Files:**
- Modify: `Settings.lua` (`/lm debug`), `Report.lua`, `CHANGELOG.md`, `README.md`
- Test: `tests/report.test.lua` (extend)

- [ ] **Step 1: Write the failing test**

```lua
-- appended to tests/report.test.lua
local text = ns.Report.Text()
assert(text:find("held", 1, true) and text:find("dropped", 1, true) and text:find("records", 1, true), "queue and records in the report")
```

- [ ] **Step 2: Run it and watch it fail.**

- [ ] **Step 3: Implement**

`Report.Text()` gains:
- a line `queue: N queued, N held, N dropped, N bad`;
- a line `records: type=count …`;
- the legacy clients seen (`R.legacy` names).

`/lm debug` prints the same, plus memory: `UpdateAddOnMemoryUsage(); before = GetAddOnMemoryUsage("LevelMates"); collectgarbage("collect"); UpdateAddOnMemoryUsage(); after = …`, printed as `memory: X KB (Y KB after a collect)`.

CHANGELOG `## 0.4.0` (English):
- **New sync:** meetups, guild goals, the wall, class questions, recruit templates and market offers are kept by everyone and handed to whoever logs in later, even when their author is offline. Removed things stay removed.
- What you do inside a dungeon goes out when you leave instead of being lost; help requests and groups go first.
- The book redraws at most twice a second and only when something really changed.
- Characters with a surname (Forever's "Name Surname") are recognised as themselves.
- Achievements count your real journal; long Mates and calendar lists have pages.
- **Clean cut:** 0.4.0 and 0.3.x no longer see each other. Guildmates on 0.3.x are told to update.

README: one line in the sync section about guildmates on 0.3.x needing to update.

- [ ] **Step 4: Run the suite**

Run: `npm test`
Expected: green.

- [ ] **Step 5: Commit, then copy to the game for the in-game test**

```bash
git add -A && git commit -m "docs: 0.4.0 changelog; queue and records in the report"
D="/c/Program Files (x86)/World of Warcraft/_classic_beta_/Interface/AddOns/LevelMates"; rm -rf "$D"; cp -r LevelMates "$D"
```

Do **not** tag or push. Ask the user to test in game first, with two characters or a guildmate if possible.

---

## Self-review notes

- **Spec coverage:**
  - protocol and clean cut: Task 2;
  - blobs: Task 5;
  - queue: Task 4;
  - store with tombstones, versions and authority: Task 6;
  - catch-up: Task 7;
  - identity: done before this plan (`ns.Me`), plus whisper and guild checks in Task 4;
  - module table: Tasks 8–10;
  - saved-data migration: inside Tasks 8 and 9;
  - performance: Task 3;
  - errors and report: Task 11;
  - tests: every task.
- **Ruling against the spec:**
  - The spec mutes notices for 20 s after login. This plan mutes notices from **catch-up** records instead (`how == "catchup"`). Live notices in the first seconds are real, and many existing tests rely on them.
  - Group ads (`lfg`/`lfj`) stay presence-bound plain messages: an ad from someone who logged off should vanish, as today. Project 2 replaces them with runs.
- **Interface consistency:**
  - `S.Receive(t, f, sender, catchup)` is used by Define's handler (Task 6) and by whispers (Task 7: channel passed through `deliver`);
  - `C.REQUIRED` and `C.V` are exported in Task 5/6 and used in Tasks 6–9;
  - `LM_HELLO_ANSWERED` replaces `LM_PING_ANSWERED` in Task 7 and is used in Task 10.
