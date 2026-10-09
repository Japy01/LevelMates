# LevelMates: Dungeon Group Finder Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. Every task also REQUIRES the `wow-forever-addons` skill (API facts, tools, policy).

**Goal:** A guildmate can post "looking for group" for a dungeon with roles and a short note; other guildmates see it in a new "Dungeons" tab of the board, get a chat line when it fits their level, and can invite or whisper from the list.

**Architecture:** Two new addon-message kinds (`lfg`, `lfgx`) validated by the existing `Comm` schema. A new `LFG.lua` module owns the ads (own and received), their 20-minute clock and the rules; `Dungeons.lua` holds the dungeon table; `Board.lua` gains a second tab that reuses the same row frames; `LfgDialog.lua` is the click-only posting dialog. Nothing is sent without a click; nothing is sent inside instances (the existing `INSTANCE_OK` gate in `Comm.lua` already refuses every kind except `help` and `helpok`).

**Tech Stack:** Lua 5.1 (WoW Forever client, interface 16001), the repo's fengari test harness (`node tools/run-lua-test.mjs LevelMates tests/<name>.test.lua`), `npm test` for the whole suite.

**Spec:** `docs/superpowers/specs/2026-10-09-levelmates-lfg-design.md`

## Global Constraints

- Posting and cancelling an ad happen only from a click handler (button or slash command); invite and whisper stay in the row context menu.
- Requires "Appear on the board" (`ns.db.settings.share`) on; with it off the addon sends and shows nothing.
- Inside an instance only `help` and `helpok` are sent (`INSTANCE_OK` in `Comm.lua` stays exactly that).
- Messages: `lfg` fields `d` (int 1-99), `r` (subset of `T`,`H`,`D`, no repeats, max 3), `n` (text ≤ 40, optional), `id` (word ≤ 8), `m` (int 1-20); `lfgx` field `id`. Required in `lfg`: `d`, `r`, `id`, `m`. A message is ≤ 255 bytes.
- An ad lasts at most 20 minutes (`m` = minutes left; a re-send carries the minutes that remain and never extends the clock). One ad per player; one new ad per player per 30 s; at most 50 ads in a receiver's list. Only the author can withdraw an ad.
- The poster's level and class are never in the message; they come from the roster (`ns.Roster.mates[name]`). An ad from a name the roster does not know is ignored.
- The dungeon list starts with the six confirmed in the user's journal: Hall of Thanes 13-20, Ragefire Chasm 13-18, Ruins of Lordaeron 15-22, Wailing Caverns 15-24, The Deadmines 17-26, Shadowfang Keep 20-30 (Spanish names: Salón de los Feudales, Sima Ígnea, Ruinas de Lordaeron, Cuevas de los Lamentos, Minas de la Muerte, Castillo de Colmillo Oscuro).
- Every player-visible string goes through `L` (enUS base, esES complete).
- Tests run from the repo root. `npm test` must be green after every task.

## Review Focus

1. A guildmate on an older addon never sends `lfg`, and one on a newer addon may send a dungeon id this version does not know: both must be ignored without an error or a notice (Task 2 test `unknown dungeon id ignored`; Task 1 decode of unknown kinds is already covered by v1).
2. Spoofing: a player the roster does not know posts an ad, or a different player sends `lfgx` for someone else's ad: both ignored (Task 2 `lfg.test.lua` stranger; `lfg_life.test.lua` author-only withdrawal).
3. Flooding: one player posting a new ad every second, or 60 players posting at once: only one new ad per player per 30 s, list capped at 50, and a player who already has an ad can still replace it when the list is full (Task 2 `lfg.test.lua`).
4. The clock: a re-sent ad must not live longer than the original 20 minutes; an ad whose time ran out must disappear even if nobody opens the board (Task 2 `lfg_life.test.lua`).
5. Posting in a state where it must not happen: sharing off, inside an instance, with no valid role, or twice within 30 s, and the group reaching 5 people closing the ad (Task 2 `lfg.test.lua`, `lfg_life.test.lua`; Task 4 dialog stays open when the post is refused).

---

## File Structure

| File | Responsibility |
|---|---|
| `LevelMates/Dungeons.lua` (new) | The dungeon table and lookups: `ns.Dungeons.list/Get/Name/Fits`. No state. |
| `LevelMates/LFG.lua` (new) | Own ad, received ads, 20-minute clock, rules, notices, group-full close, wipe on sharing off. No UI. |
| `LevelMates/LfgDialog.lua` (new) | The click-only "Find a group" dialog. Calls `ns.LFG.Post`. |
| `LevelMates/Comm.lua` (modify) | Schema entries for `lfg` and `lfgx`. |
| `LevelMates/Core.lua` (modify) | `ns.CutUtf8` (moved from `Help.lua`), `lfgNotices` default. |
| `LevelMates/Help.lua` (modify) | Uses `ns.CutUtf8`. |
| `LevelMates/Board.lua` (modify) | Tabs, the Dungeons list, button swap, `B.ShowTab`, `/lm lfg`. |
| `LevelMates/Settings.lua`, `Locales/*.lua`, `Sim.lua`, `LevelMates.toc` (modify) | Option, strings, simulation, load order. |
| `tools/wow-stub.lua` (modify) | `SetEnabled`, `SetAutoFocus`, `SetMaxLetters` no-op/recorders. |
| `tests/*.test.lua`, `tests/policy.test.mjs` | One test file per task, plus a static locale-key check. |

TOC load order after this plan: `Locales\enUS.lua`, `Locales\esES.lua`, `Core.lua`, `Dungeons.lua`, `Comm.lua`, `Roster.lua`, `Settings.lua`, `Board.lua`, `MinimapButton.lua`, `Questie.lua`, `Match.lua`, `Help.lua`, `LFG.lua`, `LfgDialog.lua`, `Sim.lua`.

---

### Task 1: Dungeon table and wire format

**Files:**
- Create: `LevelMates/Dungeons.lua`, `tests/dungeons.test.lua`
- Modify: `LevelMates/Comm.lua`, `LevelMates/Locales/enUS.lua`, `LevelMates/Locales/esES.lua`, `LevelMates/LevelMates.toc`, `tests/comm_format.test.lua`, `tests/comm_transport.test.lua`, `tests/policy.test.mjs`

**Interfaces:**
- Produces: `ns.Dungeons.list` (array of `{ id, key, min, max }`), `ns.Dungeons.Get(id) -> entry|nil`, `ns.Dungeons.Name(id) -> localized string` (`"#<id>"` when unknown), `ns.Dungeons.Fits(id, level) -> boolean`. `Comm.SCHEMA.lfg` / `lfgx`.
- Consumes: `ns.L`.

- [ ] **Step 1: Write the failing tests**

`tests/dungeons.test.lua`:

```lua
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
local D, L = ns.Dungeons, ns.L
assert(#D.list == 6, "six confirmed dungeons, got " .. #D.list)
assert(D.Get(2).min == 13 and D.Get(2).max == 18, "Ragefire Chasm is 13-18 in the journal")
assert(D.Get(1).min == 13 and D.Get(1).max == 20, "Hall of Thanes 13-20")
assert(D.Get(6).min == 20 and D.Get(6).max == 30, "Shadowfang Keep 20-30")
assert(D.Get(99) == nil, "unknown id")
assert(D.Name(2) == L.DUNGEON_RAGEFIRE_CHASM and D.Name(2) ~= "DUNGEON_RAGEFIRE_CHASM", "name goes through the locale")
assert(D.Name(99) == "#99", "unknown id has a visible fallback")
assert(D.Fits(2, 13) and D.Fits(2, 18) and not D.Fits(2, 12) and not D.Fits(2, 19), "range is inclusive")
assert(not D.Fits(99, 15), "unknown never fits")
for _, d in ipairs(D.list) do assert(d.id >= 1 and d.id <= 99 and d.min <= d.max, "ids fit the wire format: " .. d.key) end
```

Append to `tests/comm_format.test.lua` just before the final `print("ok")`:

```lua
-- group finder messages
local kl, fl = C.Decode(C.Encode("lfg", { d = 2, r = "TD", n = "voy con agua", id = "ab12cd34", m = 20 }))
assert(kl == "lfg" and fl.d == 2 and fl.r == "TD" and fl.n == "voy con agua" and fl.id == "ab12cd34" and fl.m == 20, "lfg roundtrip")
assert(C.Validate("lfg", { d = 2, r = "H", id = "x1", m = 5 }) == true, "note is optional")
for _, bad in ipairs({ "", "X", "TT", "THDT", "t", "T,D" }) do
	assert(C.Validate("lfg", { d = 2, r = bad, id = "x1", m = 5 }) == false, "roles refused: '" .. bad .. "'")
end
assert(C.Validate("lfg", { d = 0, r = "T", id = "x1", m = 5 }) == false and C.Validate("lfg", { d = 100, r = "T", id = "x1", m = 5 }) == false, "dungeon id range")
assert(C.Validate("lfg", { d = 2, r = "T", id = "x1", m = 0 }) == false and C.Validate("lfg", { d = 2, r = "T", id = "x1", m = 21 }) == false, "minutes range")
assert(C.Validate("lfg", { d = 2, r = "T", id = "x1", m = 5, n = string.rep("x", 41) }) == false, "note longer than 40")
assert(C.Validate("lfg", { d = 2, r = "T", m = 5 }) == false, "id required")
local kx, fx = C.Decode(C.Encode("lfgx", { id = "ab12cd34" }))
assert(kx == "lfgx" and fx.id == "ab12cd34", "lfgx roundtrip")
assert(C.Validate("lfgx", {}) == false, "lfgx needs an id")
```

In `tests/comm_transport.test.lua`, inside the instance block, right after the line `assert(C.Send("ping", {}) == false and C.Send("q", { i = "1/1", ids = "1" }) == false, "ping and q refused in an instance")` add:

```lua
assert(C.Send("lfg", { d = 2, r = "T", id = "in02", m = 20 }) == false and C.Send("lfgx", { id = "in02" }) == false, "group finder messages refused in an instance")
```

In `tests/policy.test.mjs`, add before the final line `if (bad) process.exit(1); else console.log('ok policy');`:

```js
// every dungeon name key must exist in both locale files
const dungeonsFile = path.join(dir, 'Dungeons.lua');
if (fs.existsSync(dungeonsFile)) {
  const keys = [...fs.readFileSync(dungeonsFile, 'utf8').matchAll(/key\s*=\s*"([A-Z0-9_]+)"/g)].map(m => m[1]);
  for (const loc of ['enUS.lua', 'esES.lua']) {
    const text = fs.readFileSync(path.join(dir, 'Locales', loc), 'utf8');
    for (const k of keys) if (!new RegExp(`L\\.${k}\\s*=`).test(text)) { bad++; console.error(`${loc} lacks ${k}`); }
  }
}
```

- [ ] **Step 2: Run the tests to see them fail**

Run: `node tools/run-lua-test.mjs LevelMates tests/dungeons.test.lua`
Expected: LUA ERROR `attempt to index a nil value (field 'Dungeons')`.
Run: `node tools/run-lua-test.mjs LevelMates tests/comm_format.test.lua`
Expected: LUA ERROR at `lfg roundtrip`.
Run: `node tools/run-lua-test.mjs LevelMates tests/comm_transport.test.lua`
Expected: `ok`. This new assertion passes even before the implementation (an unknown kind makes `Send` return false), so it is a regression guard, not a red test: it pins that `INSTANCE_OK` keeps refusing the new kinds once they exist. The red tests of this task are the first two.

- [ ] **Step 3: Implement**

Create `LevelMates/Dungeons.lua`:

```lua
-- Dungeons.lua: the dungeons the group finder knows. Starts with the six confirmed in the Forever journal;
-- to add one, append a row here and add its DUNGEON_* name to both locale files (tests/policy.test.mjs checks that).
local _, ns = ...
local D = {}
ns.Dungeons = D

D.list = {
	{ id = 1, key = "DUNGEON_HALL_OF_THANES",      min = 13, max = 20 },
	{ id = 2, key = "DUNGEON_RAGEFIRE_CHASM",      min = 13, max = 18 },
	{ id = 3, key = "DUNGEON_RUINS_OF_LORDAERON",  min = 15, max = 22 },
	{ id = 4, key = "DUNGEON_WAILING_CAVERNS",     min = 15, max = 24 },
	{ id = 5, key = "DUNGEON_DEADMINES",           min = 17, max = 26 },
	{ id = 6, key = "DUNGEON_SHADOWFANG_KEEP",     min = 20, max = 30 },
}

local byId = {}
for _, d in ipairs(D.list) do byId[d.id] = d end

function D.Get(id) return byId[id] end
function D.Name(id) local d = byId[id]; return d and ns.L[d.key] or ("#" .. tostring(id)) end
function D.Fits(id, level) local d = byId[id]; return d ~= nil and type(level) == "number" and level >= d.min and level <= d.max end
```

In `LevelMates/Locales/enUS.lua` append:

```lua
L.DUNGEON_HALL_OF_THANES = "Hall of Thanes"; L.DUNGEON_RAGEFIRE_CHASM = "Ragefire Chasm"; L.DUNGEON_RUINS_OF_LORDAERON = "Ruins of Lordaeron"
L.DUNGEON_WAILING_CAVERNS = "Wailing Caverns"; L.DUNGEON_DEADMINES = "The Deadmines"; L.DUNGEON_SHADOWFANG_KEEP = "Shadowfang Keep"
```

In `LevelMates/Locales/esES.lua` append:

```lua
L.DUNGEON_HALL_OF_THANES = "Salón de los Feudales"; L.DUNGEON_RAGEFIRE_CHASM = "Sima Ígnea"; L.DUNGEON_RUINS_OF_LORDAERON = "Ruinas de Lordaeron"
L.DUNGEON_WAILING_CAVERNS = "Cuevas de los Lamentos"; L.DUNGEON_DEADMINES = "Minas de la Muerte"; L.DUNGEON_SHADOWFANG_KEEP = "Castillo de Colmillo Oscuro"
```

In `LevelMates/LevelMates.toc` insert the line `Dungeons.lua` right after `Core.lua`.

In `LevelMates/Comm.lua`, add the validator after the `chunkIndex` definition:

```lua
-- roles: any non-empty subset of T (tank), H (healer), D (damage), each at most once
local function roles(v)
	if type(v) ~= "string" or #v < 1 or #v > 3 or not v:match("^[THD]+$") then return false end
	local seen = {}
	for ch in v:gmatch(".") do if seen[ch] then return false end; seen[ch] = true end
	return true
end
```

then extend `C.SCHEMA` and `REQUIRED`:

```lua
	lfg  = { d = int(1, 99), r = roles, n = text(40), id = word(8), m = int(1, 20) },
	lfgx = { id = word(8) },
```
and in `REQUIRED` add `lfg = { "d", "r", "id", "m" }, lfgx = { "id" },`.

- [ ] **Step 4: Run the tests and the whole suite**

Run: `npm test`
Expected: every line `ok`, ending with `ok policy`, exit code 0. (`INSTANCE_OK` already refuses `lfg` and `lfgx`; the new transport assertion passes.)

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat(lfg): dungeon table and lfg/lfgx wire format"
```

---

### Task 2: LFG state, rules and notices

**Files:**
- Create: `LevelMates/LFG.lua`, `tests/lfg.test.lua`, `tests/lfg_life.test.lua`
- Modify: `LevelMates/Core.lua`, `LevelMates/Help.lua`, `LevelMates/Settings.lua`, `LevelMates/Locales/enUS.lua`, `LevelMates/Locales/esES.lua`, `LevelMates/LevelMates.toc`

**Interfaces:**
- Consumes: `ns.Comm.Send/OnMessage/IsReady`, `ns.Roster.mates`, `ns.Dungeons.*`, `ns.db.settings.lfgNotices`, `ns.CutUtf8`.
- Produces: `ns.LFG.ads` (`id -> { name, d, r, n, endsAt }`), `ns.LFG.mine` (`{ id, d, r, n, endsAt }|nil`), `ns.LFG.Post(dungeonId, roles, note) -> boolean`, `ns.LFG.Cancel()`, `ns.LFG.List() -> array of ad ids, newest first`, `ns.LFG.Expire()`, `ns.LFG.NormRoles(roles) -> "TD"|nil`, `ns.LFG.RolesText(roles) -> "tank, damage"`, `ns.LFG.RolesShort(roles) -> "T D"`. Event `LM_LFG_CHANGED`. Also `ns.CutUtf8(s, maxBytes)`.

- [ ] **Step 1: Write the failing tests**

`tests/lfg.test.lua`:

```lua
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local C, G, L = ns.Comm, ns.LFG, ns.L
STUB.player.level = 15
local function mate(name, level) STUB.Receive("LVLM", C.Encode("hb", { l = level or 15, z = 1421 }), "GUILD", name .. "-Testrealm") end
local function ad(from, f) STUB.Receive("LVLM", C.Encode("lfg", f), "GUILD", from .. "-Testrealm") end
local function lastKind() return (C.Decode(STUB.sent[#STUB.sent].msg)) end
mate("Mario", 18); mate("Ana", 12); mate("Luis", 15)
assert(ns.db.settings.lfgNotices == true, "notices on by default")

-- role helpers
assert(G.NormRoles("DT") == "TD" and G.NormRoles("hd") == "HD" and G.NormRoles("X") == nil and G.NormRoles("") == nil, "roles normalised to T,H,D order")
assert(G.RolesShort("THD") == "T H D", "short roles: " .. G.RolesShort("THD"))

-- posting
assert(G.Post(2, "DT", "con agua") == true, "post works")
local k, f = C.Decode(STUB.sent[#STUB.sent].msg)
assert(k == "lfg" and f.d == 2 and f.r == "TD" and f.n == "con agua" and f.m == 20 and f.id == G.mine.id, "ad sent as specified")
assert(G.mine.endsAt == GetTime() + 20 * 60, "own ad lives 20 minutes")
local n = #STUB.sent
assert(G.Post(1, "T") == false and #STUB.sent == n, "second post within 30 s refused")
assert(STUB.printed[#STUB.printed]:find(L.LFG_TOO_SOON, 1, true), "and the user is told why")
STUB.Advance(31)
local oldId = G.mine.id
assert(G.Post(1, "T") == true, "after 30 s a new post is allowed")
assert(select(1, C.Decode(STUB.sent[#STUB.sent - 1].msg)) == "lfgx" and G.mine.id ~= oldId, "the old ad is withdrawn first")
G.Cancel()
assert(lastKind() == "lfgx" and G.mine == nil, "cancel sends lfgx")

-- refusals
STUB.Advance(31)
assert(G.Post(99, "T") == false, "unknown dungeon")
assert(G.Post(2, "X") == false and G.Post(2, "") == false, "no valid role")
STUB.inInstance = true
n = #STUB.sent
assert(G.Post(2, "T") == false and #STUB.sent == n, "not inside an instance")
assert(STUB.printed[#STUB.printed]:find(L.LFG_NO_INSTANCE, 1, true), "and the user is told why")
STUB.inInstance = false
G.Post(2, "T", string.rep("x", 60) .. "|c")
k, f = C.Decode(STUB.sent[#STUB.sent].msg)
assert(k == "lfg" and #f.n == 40, "note cut to 40 bytes: " .. tostring(f.n and #f.n))
G.Cancel()

-- receiving
STUB.Advance(31)
local printedBefore = #STUB.printed
ad("Mario", { d = 2, r = "T", n = "listo", id = "m0000001", m = 15 })
assert(G.ads.m0000001 and G.ads.m0000001.name == "Mario" and G.ads.m0000001.endsAt == GetTime() + 900, "stored with the time left")
assert(#STUB.printed == printedBefore + 1 and STUB.printed[#STUB.printed]:find("Mario", 1, true) and STUB.printed[#STUB.printed]:find(ns.Dungeons.Name(2), 1, true), "notice: dungeon in my range (15 vs 13-18)")
ad("Mario", { d = 2, r = "T", n = "listo", id = "m0000001", m = 14 })
assert(#STUB.printed == printedBefore + 1, "a re-send does not notify again")
STUB.player.level = 40
ad("Ana", { d = 6, r = "D", id = "a0000001", m = 10 })
assert(G.ads.a0000001 and #STUB.printed == printedBefore + 1, "no notice outside my level range, but the ad is listed")
STUB.player.level = 15
ns.db.settings.lfgNotices = false
ad("Luis", { d = 2, r = "H", id = "l0000001", m = 10 })
assert(G.ads.l0000001 and #STUB.printed == printedBefore + 1, "notices off: listed, silent")
ns.db.settings.lfgNotices = true

-- who may announce
ad("Stranger", { d = 2, r = "T", id = "s0000001", m = 10 })
assert(G.ads.s0000001 == nil, "not on the roster: ignored")
ad("Mario", { d = 7, r = "T", id = "m0000009", m = 10 })
assert(G.ads.m0000009 == nil and G.ads.m0000001, "unknown dungeon id ignored, the existing ad untouched")
assert(#STUB.printed == printedBefore + 1, "unknown dungeon id produces no notice")

-- one new ad per player per 30 s; a new ad replaces the old
ad("Mario", { d = 3, r = "H", id = "m0000002", m = 10 })
assert(G.ads.m0000001 and G.ads.m0000002 == nil, "second new ad from the same player within 30 s is ignored")
STUB.Advance(31)
ad("Mario", { d = 3, r = "H", id = "m0000002", m = 10 })
assert(G.ads.m0000002 and G.ads.m0000001 == nil, "after 30 s the new ad replaces the old one")

-- cap of 50, replacing own ad still works at the cap
for i = 1, 60 do
	local name = "Bot" .. i
	mate(name, 20)
	ad(name, { d = 2, r = "D", id = string.format("b%07d", i), m = 20 })
end
local total = 0
for _ in pairs(G.ads) do total = total + 1 end
assert(total == 50, "list capped at 50, got " .. total)
STUB.Advance(31)
ad("Bot1", { d = 3, r = "T", id = "bz000001", m = 20 })
assert(G.ads.bz000001 and G.ads.b0000001 == nil, "replacing your own ad works at the cap")
```

`tests/lfg_life.test.lua`:

```lua
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local C, G = ns.Comm, ns.LFG
STUB.player.level = 15
local function mate(name) STUB.Receive("LVLM", C.Encode("hb", { l = 15, z = 1421 }), "GUILD", name .. "-Testrealm") end
local function ad(from, f) STUB.Receive("LVLM", C.Encode("lfg", f), "GUILD", from .. "-Testrealm") end
mate("Mario"); mate("Ana")

-- the clock comes from the sender's remaining minutes
ad("Mario", { d = 2, r = "T", id = "m0000001", m = 5 })
STUB.Advance(4 * 60); G.Expire()
assert(G.ads.m0000001, "still there after 4 of 5 minutes")
STUB.Advance(2 * 60); G.Expire()
assert(G.ads.m0000001 == nil, "gone after its minutes ran out")
ad("Mario", { d = 2, r = "T", id = "m0000002", m = 1 })
STUB.Advance(120)
assert(G.ads.m0000002 == nil, "expired by the 60 s ticker, nobody called Expire")

-- only the author withdraws
ad("Mario", { d = 2, r = "T", id = "m0000003", m = 20 })
STUB.Receive("LVLM", C.Encode("lfgx", { id = "m0000003" }), "GUILD", "Ana-Testrealm")
assert(G.ads.m0000003, "someone else cannot withdraw Mario's ad")
STUB.Receive("LVLM", C.Encode("lfgx", { id = "m0000003" }), "GUILD", "Mario-Testrealm")
assert(G.ads.m0000003 == nil, "the author can")

-- my own ad: re-sent to newcomers with the minutes that remain, one answer per storm
STUB.Advance(31)
assert(G.Post(2, "T", "hola"))
STUB.Advance(125)
local n = #STUB.sent
STUB.Receive("LVLM", C.Encode("ping", {}), "GUILD", "Ana-Testrealm")
STUB.Advance(6)
local resent
for i = n + 1, #STUB.sent do
	local k, f = C.Decode(STUB.sent[i].msg)
	if k == "lfg" then resent = f end
end
assert(resent and resent.id == G.mine.id and resent.m <= 18 and resent.m >= 17, "re-sent with the minutes left: " .. tostring(resent and resent.m))
n = #STUB.sent
STUB.Receive("LVLM", C.Encode("ping", {}), "GUILD", "Ana-Testrealm")
STUB.Receive("LVLM", C.Encode("ping", {}), "GUILD", "Mario-Testrealm")
STUB.Advance(6)
local count = 0
for i = n + 1, #STUB.sent do if (C.Decode(STUB.sent[i].msg)) == "lfg" then count = count + 1 end end
assert(count == 1, "a login storm gets one answer, got " .. count)
STUB.Advance(20 * 60)
assert(G.mine == nil, "own ad expires after 20 minutes without renewing")

-- group full closes it
STUB.Advance(31)
G.Post(1, "H")
STUB.groupSize = 4; STUB.Fire("GROUP_ROSTER_UPDATE")
assert(G.mine, "four is not full")
STUB.groupSize = 5; STUB.Fire("GROUP_ROSTER_UPDATE")
assert(G.mine == nil and select(1, C.Decode(STUB.sent[#STUB.sent].msg)) == "lfgx", "closed and withdrawn at five")

-- sharing off: you see nobody and have no ad; posting says why
STUB.groupSize = 0
STUB.Advance(31)
ad("Mario", { d = 2, r = "T", id = "m0000004", m = 20 })
assert(G.ads.m0000004)
G.Post(2, "T")
ns.db.settings.share = false; C.Stop()
assert(next(G.ads) == nil and G.mine == nil, "sharing off clears every ad")
assert(G.Post(2, "T") == false and STUB.printed[#STUB.printed]:find(ns.L.HELP_NEEDS_SHARE, 1, true), "and posting tells the user to turn sharing on")
```

- [ ] **Step 2: Run the tests to see them fail**

Run: `node tools/run-lua-test.mjs LevelMates tests/lfg.test.lua`
Expected: LUA ERROR `attempt to index a nil value (field 'LFG')`.
Run: `node tools/run-lua-test.mjs LevelMates tests/lfg_life.test.lua`
Expected: the same error.

- [ ] **Step 3: Implement**

`LevelMates/Core.lua`: add `lfgNotices = true,` to `DEFAULTS` (next to `helpNotices = true,`), and add after `ns.DEFAULTS = DEFAULTS`:

```lua
-- At most max bytes, never cutting a multi-byte UTF-8 character in half (continuation bytes are 0x80-0xBF).
function ns.CutUtf8(s, max)
	if #s <= max then return s end
	local at = max
	while at > 0 do
		local b = s:byte(at + 1)
		if b and b >= 128 and b <= 191 then at = at - 1 else break end
	end
	return s:sub(1, at)
end
```

`LevelMates/Help.lua`: delete the local `cutUtf8` function and its comment (the block from `-- At most max bytes, never cutting…` through its closing `end`), and change `text = cutUtf8(text, 60)` to `text = ns.CutUtf8(text, 60)`.

`LevelMates/Settings.lua`: after the line `Bool(category, "helpNotices", L.OPT_HELP, L.OPT_HELP_TT)` add `Bool(category, "lfgNotices", L.OPT_LFG, L.OPT_LFG_TT)`.

Locale strings. `enUS.lua`:

```lua
L.ROLE_T = "tank"; L.ROLE_H = "healer"; L.ROLE_D = "damage"
L.ROLE_SHORT_T = "T"; L.ROLE_SHORT_H = "H"; L.ROLE_SHORT_D = "D"
L.LFG_NOTICE = "%s looks for a group for %s (%s)."
L.LFG_TOO_SOON = "Wait a moment before posting another group request."
L.LFG_FULL = "Your group is full: group request closed."
L.LFG_NO_INSTANCE = "You cannot post a group request inside an instance."
L.OPT_LFG = "Dungeon group notices"; L.OPT_LFG_TT = "A chat line when a guildmate looks for a group for a dungeon in your level range."
```

`esES.lua`:

```lua
L.ROLE_T = "tanque"; L.ROLE_H = "sanador"; L.ROLE_D = "daño"
L.ROLE_SHORT_T = "T"; L.ROLE_SHORT_H = "S"; L.ROLE_SHORT_D = "D"
L.LFG_NOTICE = "%s busca grupo para %s (%s)."
L.LFG_TOO_SOON = "Espera un momento antes de publicar otro anuncio de grupo."
L.LFG_FULL = "Tu grupo está completo: anuncio de grupo cerrado."
L.LFG_NO_INSTANCE = "No puedes publicar un anuncio de grupo dentro de una instancia."
L.OPT_LFG = "Avisos de grupos de mazmorra"; L.OPT_LFG_TT = "Una línea en el chat cuando un hermano busca grupo para una mazmorra de tu nivel."
```

`LevelMates/LevelMates.toc`: add `LFG.lua` right after `Help.lua`.

Create `LevelMates/LFG.lua`:

```lua
-- LFG.lua: "looking for group" announcements between guildmates. Posting and cancelling run only from a click.
-- Rules (spec 2026-10-09): 20 minute ads, one per player, one new ad per player per 30 s, 50 in the list,
-- only the author withdraws, only people the roster knows may announce.
local _, ns = ...
local G = {}
ns.LFG = G
local L, C, R, D = ns.L, ns.Comm, ns.Roster, ns.Dungeons
G.ads = {}     -- ad id -> { name, d, r, n, endsAt }
G.mine = nil   -- { id, d, r, n, endsAt }
local DURATION, MIN_GAP, MAX_ADS, GROUP_FULL = 20 * 60, 30, 50, 5
local ROLE_ORDER = { "T", "H", "D" }
local lastPost = -math.huge
local lastSeen = {}          -- player name -> { id, at } of the last new ad accepted from them
local resendPending = false

local function newId() return string.format("%04x%04x", math.random(0, 65535), math.random(0, 65535)):sub(1, 8) end

-- "DT" -> "TD": canonical order, no repeats, only T/H/D; nil when nothing valid is left.
function G.NormRoles(roles)
	local want = {}
	for ch in tostring(roles or ""):upper():gmatch(".") do want[ch] = true end
	local out = ""
	for _, ch in ipairs(ROLE_ORDER) do if want[ch] then out = out .. ch end end
	return out ~= "" and out or nil
end

function G.RolesText(roles)
	local names = {}
	for ch in tostring(roles):gmatch(".") do names[#names + 1] = L["ROLE_" .. ch] end
	return table.concat(names, ", ")
end

function G.RolesShort(roles)
	local out = {}
	for ch in tostring(roles):gmatch(".") do out[#out + 1] = L["ROLE_SHORT_" .. ch] end
	return table.concat(out, " ")
end

-- Called from a click (dialog button). Returns true when the ad went out.
function G.Post(dungeonId, roles, note)
	if not D.Get(dungeonId) then return false end
	local r = G.NormRoles(roles)
	if not r then return false end
	if IsInInstance and IsInInstance() then ns.Say(L.LFG_NO_INSTANCE); return false end
	if not C.IsReady() then ns.Say(L.HELP_NEEDS_SHARE); return false end
	local now = GetTime()
	if now - lastPost < MIN_GAP then ns.Say(L.LFG_TOO_SOON); return false end
	note = strtrim(tostring(note or ""))
	note = note:gsub("[%c|]", "")
	note = ns.CutUtf8(note, 40)
	local id = newId()
	local fields = { d = dungeonId, r = r, id = id, m = 20 }
	if note ~= "" then fields.n = note end
	if G.mine then   -- a new ad replaces the old one everywhere
		C.Send("lfgx", { id = G.mine.id }, "now")
		G.mine = nil
	end
	if not C.Send("lfg", fields, "now") then ns.Fire("LM_LFG_CHANGED"); return false end
	lastPost = now
	G.mine = { id = id, d = dungeonId, r = r, n = fields.n, endsAt = now + DURATION }
	ns.Fire("LM_LFG_CHANGED")
	return true
end

function G.Cancel()
	if not G.mine then return end
	C.Send("lfgx", { id = G.mine.id }, "now")
	G.mine = nil
	ns.Fire("LM_LFG_CHANGED")
end

-- Ad ids, newest first (the one that lives longest is the newest).
function G.List()
	local out = {}
	for id in pairs(G.ads) do out[#out + 1] = id end
	table.sort(out, function(a, b)
		local A, B = G.ads[a], G.ads[b]
		if A.endsAt ~= B.endsAt then return A.endsAt > B.endsAt end
		return a < b
	end)
	return out
end

function G.Expire()
	local now, changed = GetTime(), false
	for id, ad in pairs(G.ads) do if ad.endsAt <= now then G.ads[id] = nil; changed = true end end
	if G.mine and G.mine.endsAt <= now then G.mine = nil; changed = true end
	if changed then ns.Fire("LM_LFG_CHANGED") end
end

local function count() local n = 0; for _ in pairs(G.ads) do n = n + 1 end; return n end

C.OnMessage("lfg", function(f, name)
	if not R.mates[name] then return end        -- only people the roster knows: their level and class come from there
	if not D.Get(f.d) then return end           -- a dungeon this version does not know (newer addon): ignore silently
	local now = GetTime()
	local known = G.ads[f.id]
	if not known then
		local seen = lastSeen[name]
		if seen and seen.id ~= f.id and now - seen.at < MIN_GAP then return end   -- one new ad per player every 30 s
		local hasOwn = false
		for _, a in pairs(G.ads) do if a.name == name then hasOwn = true end end
		if count() >= MAX_ADS and not hasOwn then return end                      -- full list; replacing your own still works
		for id, a in pairs(G.ads) do if a.name == name then G.ads[id] = nil end end -- one ad per player
		lastSeen[name] = { id = f.id, at = now }
	end
	G.ads[f.id] = { name = name, d = f.d, r = f.r, n = f.n, endsAt = now + f.m * 60 }
	if not known and ns.db.settings.lfgNotices and D.Fits(f.d, UnitLevel("player")) then
		ns.Say(L.LFG_NOTICE, name, D.Name(f.d), G.RolesText(f.r))
	end
	ns.Fire("LM_LFG_CHANGED")
end)

C.OnMessage("lfgx", function(f, name)
	local ad = G.ads[f.id]
	if ad and ad.name == name then G.ads[f.id] = nil; ns.Fire("LM_LFG_CHANGED") end   -- only the author withdraws it
end)

-- A newcomer's ping: re-send my ad with the minutes that remain, jittered 0-5 s and coalesced into one answer.
C.OnMessage("ping", function()
	if not G.mine or resendPending then return end
	resendPending = true
	C_Timer.After(math.random() * 5, function()
		resendPending = false
		if not G.mine then return end
		local left = math.ceil((G.mine.endsAt - GetTime()) / 60)
		if left < 1 then return end
		local fields = { d = G.mine.d, r = G.mine.r, id = G.mine.id, m = math.min(20, left) }
		if G.mine.n then fields.n = G.mine.n end
		C.Send("lfg", fields)
	end)
end)

local groupFrame = CreateFrame("Frame")
groupFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
groupFrame:SetScript("OnEvent", function()
	if G.mine and GetNumGroupMembers() >= GROUP_FULL then ns.Say(L.LFG_FULL); G.Cancel() end
end)

ns.On("LM_COMM_STOPPED", function()   -- sharing off: you see nobody and have no ad
	G.mine = nil
	wipe(G.ads); wipe(lastSeen)
	ns.Fire("LM_LFG_CHANGED")
end)

local ticker
ns.On("LM_WORLD", function(isInitial, isReloading)
	if not (isInitial or isReloading) or ticker then return end
	ticker = C_Timer.NewTicker(60, G.Expire)
end)
```

- [ ] **Step 4: Run the tests and the whole suite**

Run: `node tools/run-lua-test.mjs LevelMates tests/lfg.test.lua` then `node tools/run-lua-test.mjs LevelMates tests/lfg_life.test.lua`
Expected: `ok` for both.
Run: `npm test`
Expected: all `ok`, exit code 0 (`help.test.lua` still passes: the UTF-8 test now goes through `ns.CutUtf8`).

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat(lfg): group finder state, rules, clock and notices"
```

---

### Task 3: The "Dungeons" tab on the board

**Files:**
- Modify: `LevelMates/Board.lua`, `LevelMates/Locales/enUS.lua`, `LevelMates/Locales/esES.lua`, `tools/wow-stub.lua`
- Create: `tests/board_lfg.test.lua`

**Interfaces:**
- Consumes: `ns.LFG.List/ads/mine/RolesShort`, `ns.Dungeons.Get/Name/Fits`, `ns.Roster.mates`, `ns.CutUtf8`, existing `ClassColor`, `SetClassIcon`, `B.LEVEL_COLORS`, `B.rows`, `B.headText`, `B.search`.
- Produces: `ns.Board.tab` (`"mates"|"lfg"`), `ns.Board.tabs` (`{ mates = Button, lfg = Button }`), `ns.Board.lfgButton`, `ns.Board.SetTab(key)`, `ns.Board.ShowTab(key)`. Event `LM_LFG_BUTTON` (fired by the lfg button's click; Task 4 handles it).

- [ ] **Step 1: Write the failing test**

Stub support first: in `tools/wow-stub.lua`, next to `function Region:SetAllPoints() end` add:

```lua
function Region:SetEnabled(v) self.enabled = v and true or false end
function Region:SetAutoFocus() end
function Region:SetMaxLetters() end
```

`tests/board_lfg.test.lua`:

```lua
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local C, B, G, L = ns.Comm, ns.Board, ns.LFG, ns.L
STUB.player.level = 15
CLASS_ICON_TCOORDS = { MAGE = { 0.25, 0.5, 0, 0.25 } }
local function mate(name, level, class) STUB.Receive("LVLM", C.Encode("hb", { l = level, z = 1421, c = class }), "GUILD", name .. "-Testrealm") end
local function ad(from, f) STUB.Receive("LVLM", C.Encode("lfg", f), "GUILD", from .. "-Testrealm") end
mate("Mario", 18, "MAGE"); mate("Ana", 12)
local note = "con agua y paciencia infinita"
ad("Mario", { d = 2, r = "TD", n = note, id = "m0000001", m = 15 })
STUB.Advance(31)
ad("Ana", { d = 6, r = "H", id = "a0000001", m = 20 })
B.Toggle()

local function shown()
	local out = {}
	for i = 1, #B.rows do local r = B.rows[i]; if r.button:IsShown() then out[#out + 1] = r.name.text end end
	return table.concat(out, ",")
end
local function rowOf(name) for i = 1, #B.rows do if B.rows[i].name.text == name then return B.rows[i] end end end
local function same(a, b) return a and b and a[1] == b[1] and a[2] == b[2] and a[3] == b[3] end

assert(B.tab == "mates" and B.helpButton:IsShown() and not B.lfgButton:IsShown(), "starts on guildmates")
B.tabs.lfg.scripts.OnClick(B.tabs.lfg)
assert(B.tab == "lfg" and ns.char.boardTab == "lfg", "tab switched and remembered")
assert(B.tabs.lfg.enabled == false and B.tabs.mates.enabled ~= false, "the active tab is the disabled one")
assert(B.headText[1].text == L.COL_PLAYER and B.headText[3].text == L.COL_DUNGEON and B.headText[4].text == L.COL_ROLES and B.headText[5].text == L.COL_NOTE, "headers for the list")
assert(shown() == "Ana,Mario", "newest ad first: " .. shown())
local mario = rowOf("Mario")
assert(mario.zone.text == "Ragefire Chasm (13-18)", "dungeon with its range: " .. tostring(mario.zone.text))
assert(mario.group.text == G.RolesShort("TD"), "roles")
assert(mario.level.text == 18, "level comes from the roster")
assert(mario.xph.text:sub(-3) == "..." and #mario.xph.text <= 13, "long note shortened: " .. tostring(mario.xph.text))
assert(same(mario.zone.color, B.LEVEL_COLORS.near) and same(rowOf("Ana").zone.color, B.LEVEL_COLORS.far), "dungeon coloured by whether it fits my level")
assert(mario.icon:IsShown() and not rowOf("Ana").icon:IsShown(), "class icon only when the class is known")
-- full note on hover
mario.button.scripts.OnEnter(mario.button)
assert(GameTooltip.lines[1] == note, "tooltip shows the whole note")
mario.button.scripts.OnLeave(mario.button)
assert(GameTooltip.hidden, "tooltip hides")
-- right click opens the same menu as the guildmates list
rowOf("Ana").button.scripts.OnClick(rowOf("Ana").button, "RightButton")
assert(B.lastMenuFor == "Ana", "context menu for the poster")
-- search matches the player or the dungeon
B.searchBox:SetText("shadow"); B.searchBox.scripts.OnTextChanged(B.searchBox)
assert(shown() == "Ana", "search by dungeon name: " .. shown())
B.searchBox:SetText("mario"); B.searchBox.scripts.OnTextChanged(B.searchBox)
assert(shown() == "Mario", "search by player")
B.searchBox:SetText("zzz"); B.searchBox.scripts.OnTextChanged(B.searchBox)
assert(shown() == "" and B.frame.empty.text == L.EMPTY_FILTERED, "nothing matches")
B.searchBox:SetText(""); B.searchBox.scripts.OnTextChanged(B.searchBox)
-- sort headers do nothing here
B.headers.level.scripts.OnClick(B.headers.level)
assert(shown() == "Ana,Mario", "level header does not sort the ads")
-- buttons follow the tab
assert(B.lfgButton:IsShown() and not B.helpButton:IsShown() and not B.nearCheck:IsShown(), "lfg tab buttons")
assert(B.lfgButton.text == L.BTN_LFG, "button offers to post")
local clicks = 0
ns.On("LM_LFG_BUTTON", function() clicks = clicks + 1 end)
B.lfgButton.scripts.OnClick(B.lfgButton)
assert(clicks == 1, "the button fires LM_LFG_BUTTON")
STUB.Advance(31)
assert(G.Post(2, "T"), "post so the button flips")
assert(B.lfgButton.text == L.BTN_LFG_CANCEL, "button offers to cancel while I have an ad")
-- empty list
G.mine = nil
wipe(G.ads); ns.Fire("LM_LFG_CHANGED")
assert(shown() == "" and B.frame.empty.text == L.LFG_EMPTY, "empty text for the list: " .. tostring(B.frame.empty.text))
-- back to guildmates
B.tabs.mates.scripts.OnClick(B.tabs.mates)
assert(B.tab == "mates" and B.helpButton:IsShown() and not B.lfgButton:IsShown() and B.nearCheck:IsShown(), "guildmates tab buttons")
assert(B.headText[1].text == L.COL_NAME and B.headText[3].text:find(L.COL_ZONE, 1, true), "guildmates headers back")
-- ShowTab opens the window on the tab
B.Toggle()
assert(not B.frame:IsShown(), "closed")
B.ShowTab("lfg")
assert(B.frame:IsShown() and B.tab == "lfg", "ShowTab opens the board on that tab")
```

- [ ] **Step 2: Run the test to see it fail**

Run: `node tools/run-lua-test.mjs LevelMates tests/board_lfg.test.lua`
Expected: LUA ERROR `attempt to index a nil value (field 'tabs')`.

- [ ] **Step 3: Implement**

Locale strings. `enUS.lua`:

```lua
L.COL_PLAYER = "Player"; L.COL_DUNGEON = "Dungeon"; L.COL_ROLES = "Roles"; L.COL_NOTE = "Note"
L.TAB_MATES = "Guildmates"; L.TAB_LFG = "Dungeons"
L.BTN_LFG = "Find a group"; L.BTN_LFG_CANCEL = "Cancel group request"
L.LFG_EMPTY = "Nobody is looking for a group right now."
```
`esES.lua`:

```lua
L.COL_PLAYER = "Jugador"; L.COL_DUNGEON = "Mazmorra"; L.COL_ROLES = "Roles"; L.COL_NOTE = "Nota"
L.TAB_MATES = "Hermanos"; L.TAB_LFG = "Mazmorras"
L.BTN_LFG = "Buscar grupo"; L.BTN_LFG_CANCEL = "Cancelar anuncio"
L.LFG_EMPTY = "Nadie busca grupo ahora mismo."
```

`LevelMates/Board.lua` edits, in order:

(a) Right after the line `B.ROWS, B.ROW_H, B.MIN_ROWS = ROWS, ROW_H, MIN_ROWS` add `B.tab = "mates"`.

(b) At the top of `function B.SetSort(mode)` add as first line: `if B.tab ~= "mates" then return end`.

(c) In `Build`, immediately after the line `B.helpButton = help`, add:

```lua
	-- Dungeons tab: its own action button in the same spot as "Ask for help", and the two tab buttons in the bottom bar.
	local lfg = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
	lfg:SetSize(140, 20); lfg:SetPoint("BOTTOMLEFT", 12, 3); lfg:SetText(L.BTN_LFG)
	lfg:SetScript("OnClick", function() ns.Fire("LM_LFG_BUTTON") end)
	B.lfgButton = lfg
	B.tabs = {}
	local function Tab(key, label, offset)
		local b = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
		b:SetSize(96, 20); b:SetPoint("BOTTOM", offset, 3); b:SetText(label)
		b:SetScript("OnClick", function() B.SetTab(key) end)
		B.tabs[key] = b
	end
	Tab("mates", L.TAB_MATES, -52); Tab("lfg", L.TAB_LFG, 52)
	B.tab = ns.char.boardTab == "lfg" and "lfg" or "mates"
```

(d) In the row-creation loop, immediately before the line `B.rows[i] = r`, add:

```lua
		btn:SetScript("OnEnter", function(self)   -- Dungeons tab: the whole note on hover
			if B.tab ~= "lfg" or not self.adId or not GameTooltip then return end
			local a = ns.LFG.ads[self.adId]
			if a and a.n then GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:AddLine(a.n, 1, 1, 1, true); GameTooltip:Show() end
		end)
		btn:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
```

(e) Replace the whole existing `function B.Refresh() … end` (from the line `function B.Refresh()` through the `RefreshHelp()` line and its closing `end`) with the following, which also adds the new local helpers above it. Use this script to do the replacement exactly:

```js
// run from the repo root: node <script>
const fs = require("fs");
let s = fs.readFileSync("LevelMates/Board.lua", "utf8");
const start = s.indexOf("function B.Refresh()");
const endMarker = "\tRefreshHelp()\nend\n";
const end = s.indexOf(endMarker, start);
if (start < 0 || end < 0) { console.error("anchors missing"); process.exit(1); }
const replacement = fs.readFileSync(process.argv[2], "utf8");
s = s.slice(0, start) + replacement + s.slice(end + endMarker.length);
fs.writeFileSync("LevelMates/Board.lua", s);
console.log("Refresh replaced");
```

with `<replacement file>` containing:

```lua
-- Dungeons tab: ad ids newest first, filtered by the search box (player or dungeon name, plain text).
local function LfgVisible()
	local out = {}
	local q = (B.search or ""):lower()
	for _, id in ipairs(ns.LFG.List()) do
		local a = ns.LFG.ads[id]
		if q == "" or (a.name .. " " .. ns.Dungeons.Name(a.d)):lower():find(q, 1, true) then out[#out + 1] = id end
	end
	return out
end

-- Header texts and colours for the active tab; only the guildmates tab sorts.
local function SetHeaders()
	local lfg = B.tab == "lfg"
	local sort = ns.char.boardSort or { mode = "level", desc = true }
	B.headText[1]:SetText(lfg and L.COL_PLAYER or L.COL_NAME)
	B.headText[5]:SetText(lfg and L.COL_NOTE or L.COL_XPH)
	B.headText[4]:SetText(lfg and L.COL_ROLES or L.COL_GROUP)
	local sorted = not lfg
	for key, fs in pairs({ level = B.headText[2], zone = B.headText[3] }) do
		if sorted and key == sort.mode then fs:SetTextColor(1, 1, 1) else fs:SetTextColor(1, 0.82, 0) end
	end
	-- the sorted header carries its direction: v = high to low / z to a, ^ = low to high / a to z
	B.headText[2]:SetText(L.COL_LEVEL .. (sorted and sort.mode == "level" and (sort.desc and " v" or " ^") or ""))
	B.headText[3]:SetText((lfg and L.COL_DUNGEON or L.COL_ZONE) .. (sorted and sort.mode == "zone" and (sort.desc and " v" or " ^") or ""))
end

local function ClearRow(r) r.icon:Hide(); r.name:SetText(""); r.level:SetText(""); r.zone:SetText(""); r.group:SetText(""); r.xph:SetText(""); r.button:Hide() end

local function FillMates(list)
	local mine = UnitLevel("player")
	for i = 1, ROWS do
		local r, name = B.rows[i], list[i]
		r.button.mate, r.button.adId = name, nil
		if name then
			local m = R.mates[name]
			r.name:SetText(name); r.name:SetTextColor(ClassColor(m.class))
			SetClassIcon(r.icon, m.class)
			r.level:SetText(m.level)
			r.level:SetTextColor(unpack(math.abs((m.level or 0) - mine) <= NEAR_RANGE and B.LEVEL_COLORS.near or B.LEVEL_COLORS.far))
			local info = m.mapId and C_Map.GetMapInfo(m.mapId)
			r.zone:SetText(info and info.name or ""); r.zone:SetTextColor(1, 1, 1)
			local state = m.inGroup and (m.hasSlot and "open" or "full") or "solo"
			r.group:SetText(state == "open" and L.GROUP_FREE or state == "full" and L.GROUP_FULL or L.SOLO)
			r.group:SetTextColor(unpack(B.GROUP_COLORS[state]))
			r.xph:SetText(m.xph and m.xph > 0 and tostring(m.xph) or "")
			r.button:Show()
		else
			r.button.mate = nil
			ClearRow(r)
		end
	end
end

local function FillLfg(list)
	local mine = UnitLevel("player")
	for i = 1, ROWS do
		local r, id = B.rows[i], list[i]
		local a = id and ns.LFG.ads[id]
		r.button.mate, r.button.adId = a and a.name, id
		if a then
			local m = R.mates[a.name]
			r.name:SetText(a.name); r.name:SetTextColor(ClassColor(m and m.class))
			SetClassIcon(r.icon, m and m.class)
			r.level:SetText(m and m.level or ""); r.level:SetTextColor(1, 1, 1)
			local d = ns.Dungeons.Get(a.d)
			r.zone:SetText(string.format("%s (%d-%d)", ns.Dungeons.Name(a.d), d.min, d.max))
			r.zone:SetTextColor(unpack(ns.Dungeons.Fits(a.d, mine) and B.LEVEL_COLORS.near or B.LEVEL_COLORS.far))
			r.group:SetText(ns.LFG.RolesShort(a.r)); r.group:SetTextColor(1, 1, 1)
			local n = a.n or ""
			if #n > 12 then n = ns.CutUtf8(n, 10) .. "..." end   -- the column is narrow; the tooltip has the whole note
			r.xph:SetText(n)
			r.button:Show()
		else
			r.button.mate = nil
			ClearRow(r)
		end
	end
end

-- Which controls belong to which tab.
local function RefreshTabs()
	local lfg = B.tab == "lfg"
	B.tabs.mates:SetEnabled(lfg); B.tabs.lfg:SetEnabled(not lfg)
	B.helpButton:SetShown(not lfg); B.nearCheck:SetShown(not lfg)
	B.lfgButton:SetShown(lfg)
	B.lfgButton:SetText(ns.LFG.mine and L.BTN_LFG_CANCEL or L.BTN_LFG)
end

function B.Refresh()
	if not B.frame or not B.frame:IsShown() then return end
	local lfg = B.tab == "lfg"
	local list = lfg and LfgVisible() or Visible()
	SetHeaders()
	B.frame:SetHeight(B.CHROME + (math.max(MIN_ROWS, math.min(ROWS, #list)) + HELP_ROWS) * ROW_H)
	B.SetTitle(B.TitleString())
	if lfg then FillLfg(list) else FillMates(list) end
	local emptyText = ""
	if #list == 0 then
		if not IsInGuild() then emptyText = L.NOT_IN_GUILD
		elseif lfg then emptyText = #ns.LFG.List() > 0 and L.EMPTY_FILTERED or L.LFG_EMPTY
		elseif #R.List() > 0 then emptyText = L.EMPTY_FILTERED
		else emptyText = L.EMPTY end
	end
	B.frame.empty:SetText(emptyText)
	RefreshTabs()
	RefreshHelp()
end

function B.SetTab(key)
	key = key == "lfg" and "lfg" or "mates"
	ns.char.boardTab, B.tab, B.search = key, key, ""
	if B.searchBox then B.searchBox:SetText("") end
	B.Refresh()
end

-- Open the board on a given tab (slash command, minimap, binding).
function B.ShowTab(key)
	if not B.frame then Build() end
	B.tab = key == "lfg" and "lfg" or "mates"
	ns.char.boardTab = B.tab
	B.frame:Show()
	B.Refresh()
end
```

The `Refresh` replacement keeps `RefreshHelp()` as the last line before `end`, which is why the script's end marker works. Save the replacement to a scratch file and run `node <script> <replacement file>`.

(f) At the end of `Board.lua`, add:

```lua
ns.On("LM_LFG_CHANGED", B.Refresh)
ns.Slash("lfg", function() B.ShowTab("lfg") end)
ns.Slash("grupo", function() B.ShowTab("lfg") end)
```

- [ ] **Step 4: Run the test and the whole suite**

Run: `node tools/run-lua-test.mjs LevelMates tests/board_lfg.test.lua`
Expected: `ok`.
Run: `npm test`
Expected: all `ok`. The existing `board.test.lua`, `board_sort.test.lua`, `board_style.test.lua`, `board_search.test.lua`, `board_template*.test.lua` must still pass; if one asserts a header text for the level column on the guildmates tab it must still read `Niv v` / `Lv v` (the code keeps that behaviour).

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat(board): Dungeons tab with the group list"
```

---

### Task 4: The posting dialog

**Files:**
- Create: `LevelMates/LfgDialog.lua`, `tests/lfg_dialog.test.lua`
- Modify: `LevelMates/LevelMates.toc`, `LevelMates/Locales/enUS.lua`, `LevelMates/Locales/esES.lua`

**Interfaces:**
- Consumes: event `LM_LFG_BUTTON`, `ns.LFG.Post/Cancel/mine`, `ns.Dungeons.list/Name`, `MenuUtil.CreateContextMenu`.
- Produces: `ns.LfgDialog` with `Open()`, `SelectDungeon(id)`, `Publish()`, `Refresh()`, `frame`, `pick`, `roleChecks` (`{ T, H, D }`), `note`, `ok`, `dungeon`.

- [ ] **Step 1: Write the failing test**

`tests/lfg_dialog.test.lua`:

```lua
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local C, G, L = ns.Comm, ns.LFG, ns.L
STUB.player.level = 15
local Dlg = ns.LfgDialog
assert(Dlg, "dialog module loaded")

ns.Fire("LM_LFG_BUTTON")
assert(Dlg.frame:IsShown(), "the button opens the dialog")
assert(Dlg.ok.enabled == false, "cannot post without a dungeon and a role")

local entries = {}
MenuUtil.CreateContextMenu = function(owner, fn)
	local root = { CreateTitle = function() end, CreateButton = function(_, text, cb) entries[#entries + 1] = { text = text, cb = cb } end }
	fn(owner, root)
end
Dlg.pick.scripts.OnClick(Dlg.pick)
assert(#entries == #ns.Dungeons.list, "one menu entry per dungeon")
assert(entries[2].text == "Ragefire Chasm (13-18)", "entry shows the range: " .. entries[2].text)
entries[2].cb()
assert(Dlg.dungeon == 2 and Dlg.pick.text:find("Ragefire Chasm", 1, true), "dungeon chosen")
assert(Dlg.ok.enabled == false, "still needs a role")
Dlg.roleChecks.D:SetChecked(true); Dlg.roleChecks.T:SetChecked(true)
Dlg.roleChecks.T.scripts.OnClick(Dlg.roleChecks.T)
assert(Dlg.ok.enabled == true, "dungeon and a role: can post")

Dlg.note:SetText("hola")
Dlg.ok.scripts.OnClick(Dlg.ok)
local k, f = C.Decode(STUB.sent[#STUB.sent].msg)
assert(k == "lfg" and f.d == 2 and f.r == "TD" and f.n == "hola", "posted from the click")
assert(not Dlg.frame:IsShown() and G.mine, "dialog closes and the ad is mine")

-- the same button now withdraws
ns.Fire("LM_LFG_BUTTON")
assert(G.mine == nil and select(1, C.Decode(STUB.sent[#STUB.sent].msg)) == "lfgx", "second press withdraws the ad")
assert(not Dlg.frame:IsShown(), "and does not reopen the dialog")

-- a refused post keeps the dialog open
STUB.Advance(31)
ns.Fire("LM_LFG_BUTTON")
assert(Dlg.frame:IsShown() and Dlg.dungeon == 2, "dialog remembers the last dungeon")
ns.db.settings.share = false; C.Stop()
Dlg.ok.scripts.OnClick(Dlg.ok)
assert(Dlg.frame:IsShown(), "stays open when the post is refused")
assert(STUB.printed[#STUB.printed]:find(L.HELP_NEEDS_SHARE, 1, true), "and says why")
-- Enter in the note box posts too
ns.db.settings.share = true; C.Start(); STUB.Advance(1)
Dlg.note.scripts.OnEnterPressed(Dlg.note)
assert(not Dlg.frame:IsShown() and G.mine, "Enter in the note box posts")
```

- [ ] **Step 2: Run the test to see it fail**

Run: `node tools/run-lua-test.mjs LevelMates tests/lfg_dialog.test.lua`
Expected: LUA ERROR `dialog module loaded` (assertion) because `ns.LfgDialog` is nil.

- [ ] **Step 3: Implement**

Locale strings. `enUS.lua`:

```lua
L.LFG_DIALOG_TITLE = "Find a dungeon group"; L.LFG_PICK_DUNGEON = "Choose a dungeon..."; L.LFG_ROLES_LABEL = "Your role"
L.LFG_NOTE_HINT = "Note (optional, up to 40 characters)"; L.LFG_PUBLISH = "Post"; L.LFG_CLOSE = "Close"
```
`esES.lua`:

```lua
L.LFG_DIALOG_TITLE = "Buscar grupo de mazmorra"; L.LFG_PICK_DUNGEON = "Elige una mazmorra..."; L.LFG_ROLES_LABEL = "Tu rol"
L.LFG_NOTE_HINT = "Nota (opcional, hasta 40 caracteres)"; L.LFG_PUBLISH = "Publicar"; L.LFG_CLOSE = "Cerrar"
```

`LevelMates/LevelMates.toc`: add `LfgDialog.lua` right after `LFG.lua`.

Create `LevelMates/LfgDialog.lua`:

```lua
-- LfgDialog.lua: the "Find a dungeon group" dialog. G.Post only runs from the Post button or Enter in the note box.
local _, ns = ...
local Dlg = {}
ns.LfgDialog = Dlg
local L, G, D = ns.L, ns.LFG, ns.Dungeons
local ROLES = { "T", "H", "D" }

local function Build()
	local f = CreateFrame("Frame", "LevelMatesLfgDialog", UIParent, "BasicFrameTemplateWithInset")
	Dlg.frame = f
	f:SetSize(320, 230); f:SetPoint("CENTER"); f:SetFrameStrata("DIALOG")
	f:SetMovable(true); f:EnableMouse(true); f:SetClampedToScreen(true); f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", f.StartMoving); f:SetScript("OnDragStop", f.StopMovingOrSizing)
	if f.TitleText then f.TitleText:SetText(L.LFG_DIALOG_TITLE) end
	tinsert(UISpecialFrames, "LevelMatesLfgDialog")
	f:Hide()

	local pick = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
	pick:SetSize(280, 22); pick:SetPoint("TOP", 0, -36); pick:SetText(L.LFG_PICK_DUNGEON)
	pick:SetScript("OnClick", function(self)
		MenuUtil.CreateContextMenu(self, function(_, root)
			for _, d in ipairs(D.list) do
				root:CreateButton(string.format("%s (%d-%d)", D.Name(d.id), d.min, d.max), function() Dlg.SelectDungeon(d.id) end)
			end
		end)
	end)
	Dlg.pick = pick

	local rolesLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	rolesLabel:SetPoint("TOPLEFT", 20, -68); rolesLabel:SetText(L.LFG_ROLES_LABEL)
	Dlg.roleChecks = {}
	for i, ch in ipairs(ROLES) do
		local cb = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
		cb:SetSize(24, 24); cb:SetPoint("TOPLEFT", 20 + (i - 1) * 95, -86)
		local label = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		local text = L["ROLE_" .. ch]
		label:SetPoint("LEFT", cb, "RIGHT", 2, 0); label:SetText(text:sub(1, 1):upper() .. text:sub(2))
		cb:SetScript("OnClick", function() Dlg.Refresh() end)
		Dlg.roleChecks[ch] = cb
	end

	local noteLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	noteLabel:SetPoint("TOPLEFT", 20, -122); noteLabel:SetText(L.LFG_NOTE_HINT)
	local note = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
	note:SetSize(270, 22); note:SetPoint("TOP", 0, -146); note:SetAutoFocus(false); note:SetMaxLetters(40)
	note:SetScript("OnEnterPressed", function() Dlg.Publish() end)
	note:SetScript("OnEscapePressed", function() f:Hide() end)
	Dlg.note = note

	local ok = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
	ok:SetSize(130, 22); ok:SetPoint("BOTTOMLEFT", 20, 14); ok:SetText(L.LFG_PUBLISH)
	ok:SetScript("OnClick", function() Dlg.Publish() end)
	Dlg.ok = ok
	local close = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
	close:SetSize(130, 22); close:SetPoint("BOTTOMRIGHT", -20, 14); close:SetText(L.LFG_CLOSE)
	close:SetScript("OnClick", function() f:Hide() end)
end

local function Roles()
	local out = ""
	for _, ch in ipairs(ROLES) do if Dlg.roleChecks[ch]:GetChecked() then out = out .. ch end end
	return out
end

function Dlg.Refresh()
	if not Dlg.frame then return end
	Dlg.ok:SetEnabled(Dlg.dungeon ~= nil and Roles() ~= "")
end

function Dlg.SelectDungeon(id)
	local d = D.Get(id)
	if not d then return end
	Dlg.dungeon = id
	Dlg.pick:SetText(string.format("%s (%d-%d)", D.Name(id), d.min, d.max))
	Dlg.Refresh()
end

function Dlg.Publish()
	local roles = Roles()
	if not Dlg.dungeon or roles == "" then return end
	if G.Post(Dlg.dungeon, roles, Dlg.note:GetText()) then Dlg.frame:Hide() end   -- a refused post keeps the dialog open
end

-- Opens with the last dungeon and roles remembered, the note empty.
function Dlg.Open()
	if not Dlg.frame then Build() end
	Dlg.note:SetText("")
	Dlg.frame:Show()
	Dlg.Refresh()
end

ns.On("LM_LFG_BUTTON", function()
	if G.mine then G.Cancel() else Dlg.Open() end
end)
```

- [ ] **Step 4: Run the test and the whole suite**

Run: `node tools/run-lua-test.mjs LevelMates tests/lfg_dialog.test.lua`
Expected: `ok`.
Run: `npm test`
Expected: all `ok`, exit code 0.

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat(lfg): click-only posting dialog"
```

---

### Task 5: Simulation, documentation and the final check

**Files:**
- Modify: `LevelMates/Sim.lua`, `README.md`, `CHANGELOG.md`
- Create: `tests/sim_lfg.test.lua`

**Interfaces:**
- Consumes: `ns.Comm.Inject`, `ns.Roster`, `ns.LFG`, `ns.Board.ShowTab`, `ns.Slash("lfg")`.
- Produces: `/lm sim lfg` (two fake ads from Mario and Luis, local only), and `/lm sim off` also removes them.

- [ ] **Step 1: Write the failing test**

`tests/sim_lfg.test.lua`:

```lua
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
STUB.player.realm = "Classic Beta PvP"
STUB.ambiguateKeepsRealm = true
STUB.player.level = 15
local sentBefore = #STUB.sent
SlashCmdList["LEVELMATES"]("sim")
SlashCmdList["LEVELMATES"]("sim lfg")
local list = ns.LFG.List()
assert(#list == 2, "two fake ads: " .. #list)
assert(#STUB.sent == sentBefore, "the simulation sends nothing")
local names = {}
for _, id in ipairs(list) do names[ns.LFG.ads[id].name] = true end
assert(names.Mario and names.Luis, "from Mario and Luis")

SlashCmdList["LEVELMATES"]("lfg")
assert(ns.Board.frame:IsShown() and ns.Board.tab == "lfg", "/lm lfg opens the Dungeons tab")

SlashCmdList["LEVELMATES"]("sim off")
assert(#ns.LFG.List() == 0 and #ns.Roster.List() == 0, "sim off removes the ads and the mates")
```

- [ ] **Step 2: Run the test to see it fail**

Run: `node tools/run-lua-test.mjs LevelMates tests/sim_lfg.test.lua`
Expected: LUA ERROR at `two fake ads: 0`.

- [ ] **Step 3: Implement**

In `LevelMates/Sim.lua`, add after the `simHelp` function:

```lua
local function simLfg()
	if not R.mates.Mario then run() end   -- the ads need their posters in the roster
	inject("lfg", { d = 2, r = "TD", n = "con agua y paciencia", id = "simlfg01", m = 20 }, "Mario")
	inject("lfg", { d = 5, r = "H", id = "simlfg02", m = 20 }, "Luis")
end
```

Replace the `off` function with:

```lua
local function off()
	inject("helpok", { id = "sim00001" }, "Mario")
	inject("lfgx", { id = "simlfg01" }, "Mario"); inject("lfgx", { id = "simlfg02" }, "Luis")
	for _, who in ipairs(FAKES) do inject("bye", {}, who) end
end
```

and replace the slash handler body so `lfg` is recognised:

```lua
ns.Slash("sim", function(rest)
	rest = strlower(strtrim(rest or ""))
	if rest == "off" then off()
	elseif rest == "help" or rest == "ayuda" then simHelp()
	elseif rest == "lfg" or rest == "grupo" then simLfg()
	else run() end
end)
```

Documentation. In `README.md` (English section) add to the "What it does" list:
`- **Dungeon groups** (Dungeons tab, or \`/lm lfg\`): post "Find a group" with a dungeon, your role and a short note; guildmates see it in the list and get a chat line if it fits their level. Ads last 20 minutes.`
and add `/lm lfg` and `/lm sim lfg` to the Commands line. In the Spanish section add `- **Grupos de mazmorra** (pestaña Mazmorras, o \`/lm lfg\`): publica "Buscar grupo" con una mazmorra, tu rol y una nota corta; los hermanos lo ven en la lista y reciben una línea en el chat si encaja con su nivel. Los anuncios duran 20 minutos.` and add `/lm lfg` and `/lm sim lfg` to the Comandos line. In the English and Spanish "Not in v1" lists nothing changes. Append to `CHANGELOG.md`:

```
- Dungeon groups: a "Dungeons" tab on the board and a "Find a group" dialog (dungeon, roles, short note). Ads last 20 minutes, one per player, only the author can withdraw it; a chat line shows when an ad fits your level (option in the settings). Starts with six dungeons. New message kinds `lfg` and `lfgx`; older versions ignore them.
```

- [ ] **Step 4: Run the whole suite**

Run: `npm test`
Expected: every test file `ok`, `ok policy`, exit code 0.

- [ ] **Step 5: In-game acceptance (with the user), then commit**

In the game, with `/reload`: `/lm sim` then `/lm sim lfg` shows two ads in the Dungeons tab; the "Find a group" button opens the dialog; pick a dungeon from the menu, tick a role, Post; the button turns into "Cancel group request". Check the names, level ranges and layout against a screenshot. With a second real player: the ad appears in their list, they can invite and whisper from the row, it disappears after cancel and after 20 minutes. Check `GetNumGroupMembers()` reaches 5 and closes the ad.

```bash
git add -A && git commit -m "feat(lfg): simulation, docs and /lm lfg"
```

---

## Self-Review notes

- Spec §4 (messages) → Task 1; §5 (lifecycle) and all rules → Task 2; §6 (UI) → Tasks 3 and 4 (tab, list, dialog, notice, setting); §7 (dungeon list) → Task 1; §8 (tests) → each task has its test file, simulation in Task 5; §3 policy → Global Constraints, `INSTANCE_OK` assertions in Task 1, click-only post in Task 4.
- Names are consistent across tasks: `ns.LFG.Post/Cancel/List/Expire/NormRoles/RolesText/RolesShort`, `ns.Dungeons.Get/Name/Fits/list`, `ns.CutUtf8`, `B.tab/tabs/lfgButton/SetTab/ShowTab`, `LM_LFG_CHANGED`, `LM_LFG_BUTTON`.
- Open verification, deferred to the in-game acceptance: how Forever counts `GetNumGroupMembers()`, and the Spanish names of dungeons not yet in the table.
