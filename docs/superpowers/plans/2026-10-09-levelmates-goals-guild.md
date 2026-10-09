# LevelMates: Guild Goals (plan A) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. Every task also REQUIRES the `wow-forever-addons` skill (API facts, tools, policy).

**Goal:** Officers and the guild master create guild goals — everyone to level X, a dungeon together, or a counter (levels, quests or dungeons between everyone) — that every guildmate with the addon sees in a fourth "Goals" tab with live progress, kept across sessions and re-shared to newcomers.

**Architecture:** `Goals.lua` owns the goals per guild in `ns.db.goals[guild]`, the levels last seen per guildmate in `ns.db.seen[guild]`, the progress maths (counters from the journal), officer checks, and four new message kinds (`go`, `gx`, `gd`, `gc`). The roster learns each member's community role (Owner/Leader = officer). The journal announces each new entry (`LM_JOURNAL_ADDED`) so dungeon goals and counters react. `Board.lua` adds the tab; `GoalDialog.lua` is the officers' creation dialog. Personal goals are plan B.

**Tech Stack:** Lua 5.1 (WoW Forever client, interface 16001), the repo's fengari harness (`node tools/run-lua-test.mjs LevelMates tests/<name>.test.lua`), `npm test`.

**Spec:** `docs/superpowers/specs/2026-10-09-levelmates-goals-design.md`

## Global Constraints

- Create/delete guild goals: only Owner (1) or Leader (2) community role. Me: `IsGuildLeader()` or `C_GuildInfo.IsGuildOfficer()`. A sender: role from the cached guild member list (`C_Club.GetMemberInfo(...).role`). Messages `go`/`gx` from anyone else are ignored; `gx` is also accepted from the goal's creator.
- At most 5 active guild goals; a goal disappears 2 days after its deadline (`today > e + 2`, days = `floor(time() / 86400)`).
- Messages: `go` {`id` word ≤ 8, `ty` ∈ lvl|dun|cnt, `a` int 1..100000, `w` ∈ lvl|qst|dun (counters), `s`, `e` int 0..100000}, required `id ty a s e`; `gx` {`id`}; `gd` {`id`}; `gc` {`id`, `n` int 0..10000}. Older versions ignore new kinds.
- Valid goals: lvl `a` 2..60; dun `a` a known dungeon id; cnt `a` 1..10000 with `w`; duration 1..30 days.
- Re-share to a newcomer (after my heartbeat, on `LM_PING_ANSWERED`): every goal I hold if I am an officer, otherwise only the goals I created; my counter contributions (> 0); `gd` for dungeon goals I completed.
- My counter contribution = journal entries of the counted kind (`level`/`quest`/`dungeon`) dated from the start of the goal's first day; sent after a heartbeat when it changed, at most once a minute per goal.
- Dungeon together is done when my journal records that dungeon (`e.name == ns.Dungeons.Name(a)`) with at least one guildmate in `e.mates`; I send `gd` once.
- "Everyone to level X" counts: me, online mates (roster level), and guildmates whose heartbeat I saw in the last 30 days (`ns.db.seen`).
- Notices (option `goalNotices`, default on): a new guild goal from someone else; a goal reached (once per goal).
- Nothing inside instances / without "Appear on the board" (existing `Comm` gates). Strings through `L`. `npm test` green after every task. Commits with explicit paths.

## Review Focus

1. Forgery: a non-officer sends `go` or `gx`, or someone deletes a goal they did not create and are not an officer of (Task 1 tests).
2. Flood: more than 5 goals, or a goal with absurd values (level 99, unknown dungeon, unknown counter kind) (Task 1 tests).
3. Persistence and re-sharing: a newcomer gets the goals from an officer even if the creator is offline; a plain member does not re-broadcast others' goals (Task 1 tests).
4. Progress truth: offline guildmates count with their last seen level but are forgotten after 30 days; counters never double-count my own part (Task 1 and Task 2 tests).
5. Completion: a dungeon done alone or a different dungeon does not count; a goal is announced as reached once (Task 2 tests).

---

## File Structure

| File | Responsibility |
|---|---|
| `LevelMates/Goals.lua` (new) | Storage, seen levels, validation, create/delete, officer checks, messages, progress, notices, re-sharing. |
| `LevelMates/GoalDialog.lua` (new) | Officers' "New goal" dialog. |
| `LevelMates/Roster.lua` (modify) | Cache each member's community role; `R.IsOfficer(name)`, `R.IAmOfficer()`. |
| `LevelMates/Journal.lua` (modify) | Fire `LM_JOURNAL_ADDED(entry)`. |
| `LevelMates/Comm.lua` (modify) | Schemas `go`, `gx`, `gd`, `gc`. |
| `LevelMates/Board.lua` (modify) | Fourth tab, columns, rows, tooltip, right-click delete, "New goal" button. |
| `LevelMates/Core.lua`, `Settings.lua`, `Locales/*.lua`, `LevelMates.toc` (modify) | Option, strings, load order (`Goals.lua` and `GoalDialog.lua` after `Journal.lua`). |
| `LevelMates/Sim.lua`, `README.md`, `CHANGELOG.md` | `/lm sim metas`, docs. |
| `tools/wow-stub.lua` | Member roles, `IsGuildLeader`, `C_GuildInfo.IsGuildOfficer`. |

---

### Task 1: Goals core, roles and messages

**Files:**
- Create: `LevelMates/Goals.lua`, `tests/goals.test.lua`
- Modify: `LevelMates/Roster.lua`, `LevelMates/Comm.lua`, `LevelMates/Core.lua`, `LevelMates/Settings.lua`, `LevelMates/Locales/enUS.lua`, `LevelMates/Locales/esES.lua`, `LevelMates/LevelMates.toc`, `tools/wow-stub.lua`, `tests/comm_format.test.lua`

**Interfaces:**
- Produces: `ns.Roster.IsOfficer(name)`, `ns.Roster.IAmOfficer()`; `ns.Goals.MAX`, `Get(id)`, `List()`, `Create(ty, a, w, days) -> boolean`, `CanDelete(id)`, `Delete(id)`, `Text(g)`, `UntilText(g)`, `Progress(g)`, `ProgressText(g)`, `IsDone(g)`, `MyContribution(g)`; event `LM_GOALS_CHANGED`.

- [ ] **Step 1: Write the failing tests**

`tools/wow-stub.lua`: replace `GetMemberInfo = function(_, id) return { name = id, level = 1, presence = 1 } end,` with:

```lua
	GetMemberInfo = function(_, id) return { name = id, level = 1, presence = 1, role = STUB.guildRoles and STUB.guildRoles[id] or 4 } end,
```

and append:

```lua
-- Guild ranks (community roles: 1 Owner, 2 Leader, 3 Moderator, 4 Member)
function IsGuildLeader() return STUB.iAmLeader == true end
C_GuildInfo = { IsGuildOfficer = function() return STUB.iAmOfficer == true end }
```

Append to `tests/comm_format.test.lua` before `print("ok")`:

```lua
-- guild goals
local kg2, fg2 = C.Decode(C.Encode("go", { id = "g1", ty = "cnt", a = 100, w = "qst", s = 20370, e = 20377 }))
assert(kg2 == "go" and fg2.ty == "cnt" and fg2.a == 100 and fg2.w == "qst" and fg2.e == 20377, "go roundtrip")
assert(C.Validate("go", { id = "g1", ty = "xyz", a = 1, s = 1, e = 1 }) == false and C.Validate("go", { id = "g1", ty = "cnt", a = 1, w = "xp", s = 1, e = 1 }) == false, "types are a closed set")
assert(C.Validate("go", { id = "g1", ty = "lvl", a = 30, s = 1 }) == false, "deadline required")
assert(C.Validate("gx", { id = "g1" }) and C.Validate("gd", { id = "g1" }) and C.Validate("gc", { id = "g1", n = 5 }), "gx gd gc")
assert(C.Validate("gc", { id = "g1", n = 10001 }) == false, "contribution range")
```

`tests/goals.test.lua`:

```lua
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local C, G, R, L = ns.Comm, ns.Goals, ns.Roster, ns.L
local function mate(name, level) STUB.Receive("LVLM", C.Encode("hb", { l = level or 20, z = 1421 }), "GUILD", name .. "-Testrealm") end
local function lastKind() return (C.Decode(STUB.sent[#STUB.sent].msg)) end
local function find(pred) for _, g in ipairs(G.List()) do if pred(g) then return g end end end
local today = math.floor(time() / 86400)
STUB.guildMembers = { Tester = true, Mario = true, Ana = true, Luis = true, Jefa = true }
STUB.guildRoles = { Jefa = 2 }
R.InvalidateGuildRoster()
assert(ns.db.settings.goalNotices == true, "notices on by default")
assert(R.IsOfficer("Jefa") and not R.IsOfficer("Mario") and not R.IsOfficer("Nadie"), "officer by community role")

-- creating needs an officer
assert(G.Create("lvl", 30, nil, 7) == false and STUB.printed[#STUB.printed]:find(L.GOAL_NOT_OFFICER, 1, true), "not an officer: refused")
STUB.iAmOfficer = true
assert(R.IAmOfficer(), "me as officer")
assert(G.Create("lvl", 30, nil, 7) == true, "officer creates")
local k, f = C.Decode(STUB.sent[#STUB.sent].msg)
assert(k == "go" and f.ty == "lvl" and f.a == 30 and f.s == today and f.e == today + 7, "go sent")
local mineId = f.id
assert(#G.List() == 1 and G.Get(mineId).by == "Tester", "stored with its creator")
assert(G.Create("lvl", 99, nil, 7) == false and G.Create("dun", 99, nil, 7) == false and G.Create("cnt", 50, "xxx", 7) == false and G.Create("lvl", 30, nil, 40) == false, "invalid goals refused")

-- receiving: only from officers
mate("Mario"); mate("Jefa", 40)
local printed = #STUB.printed
STUB.Receive("LVLM", C.Encode("go", { id = "m1", ty = "cnt", a = 100, w = "lvl", s = today, e = today + 7 }), "GUILD", "Mario-Testrealm")
assert(#G.List() == 1, "a non-officer's goal is ignored")
STUB.Receive("LVLM", C.Encode("go", { id = "j1", ty = "dun", a = 5, s = today, e = today + 3 }), "GUILD", "Jefa-Testrealm")
assert(#G.List() == 2 and #STUB.printed == printed + 1 and STUB.printed[#STUB.printed]:find("Jefa", 1, true), "an officer's goal is stored and announced")
STUB.Receive("LVLM", C.Encode("go", { id = "j9", ty = "dun", a = 99, s = today, e = today + 3 }), "GUILD", "Jefa-Testrealm")
assert(not G.Get("j9"), "an unknown dungeon is refused even from an officer")

-- at most 5 active
for i = 2, 6 do STUB.Receive("LVLM", C.Encode("go", { id = "j" .. i, ty = "cnt", a = 10, w = "qst", s = today, e = today + 3 }), "GUILD", "Jefa-Testrealm") end
assert(#G.List() == 5, "at most 5 active: " .. #G.List())
assert(G.Create("lvl", 20, nil, 3) == false and STUB.printed[#STUB.printed]:find(L.GOAL_FULL, 1, true), "full: refused")

-- deleting: the creator or an officer
STUB.Receive("LVLM", C.Encode("gx", { id = "j1" }), "GUILD", "Mario-Testrealm")
assert(G.Get("j1"), "Mario cannot delete Jefa's goal")
STUB.Receive("LVLM", C.Encode("gx", { id = "j1" }), "GUILD", "Jefa-Testrealm")
assert(not G.Get("j1"), "Jefa can")
assert(G.CanDelete(mineId) and G.Delete(mineId) and not G.Get(mineId) and lastKind() == "gx", "I delete mine and tell the guild")

-- a newcomer gets the goals from officers, not from plain members
local function gosAfterPing(who)
	local n = #STUB.sent
	STUB.Receive("LVLM", C.Encode("ping", {}), "GUILD", who .. "-Testrealm")
	STUB.Advance(6)
	local c = 0
	for i = n + 1, #STUB.sent do if (C.Decode(STUB.sent[i].msg)) == "go" then c = c + 1 end end
	return c
end
assert(gosAfterPing("Nuevo") == #G.List(), "an officer re-sends every goal it holds")
STUB.iAmOfficer = false
assert(gosAfterPing("Otro") == 0, "a plain member does not re-send others' goals")
STUB.iAmOfficer = true

-- everyone to level X: me, online mates, and those seen in the last 30 days; who is missing
for _, g in ipairs(G.List()) do G.Delete(g.id) end
STUB.player.level = 20
assert(G.Create("lvl", 25, nil, 7))
local lvl = find(function(g) return g.ty == "lvl" end)
mate("Mario", 26); mate("Ana", 22)
local reached, total, missing = G.Progress(lvl)
assert(reached == 2 and total == 4 and table.concat(missing, ",") == "Ana,Tester", "Mario and Jefa reached, Ana and I missing: " .. reached .. "/" .. total .. " " .. table.concat(missing, ","))
assert(G.ProgressText(lvl) == "2/4" and not G.IsDone(lvl), "progress text")
STUB.Receive("LVLM", C.Encode("bye", {}), "GUILD", "Ana-Testrealm")
reached, total = G.Progress(lvl)
assert(total == 4, "offline guildmates still count with their last level")
ns.db.seen[GetGuildInfo("player")].Ana.t = time() - 31 * 86400
reached, total, missing = G.Progress(lvl)
assert(total == 3 and table.concat(missing, ",") == "Tester", "forgotten after 30 days")

-- texts
assert(G.Text(lvl) == string.format(L.GOAL_LVL, 25) and G.UntilText(lvl) == date("%d/%m", lvl.e * 86400), "texts")

-- expiry: 2 days after the deadline
lvl.e = today - 3
assert(#G.List() == 0, "expired goals are dropped")
```

- [ ] **Step 2: Run the tests to see them fail**

Run: `node tools/run-lua-test.mjs LevelMates tests/comm_format.test.lua` — Expected: LUA ERROR at `go roundtrip`.
Run: `node tools/run-lua-test.mjs LevelMates tests/goals.test.lua` — Expected: LUA ERROR at `notices on by default`.

- [ ] **Step 3: Implement**

`LevelMates/Roster.lua`:
- replace `if info and info.name then set[ns.ShortName(info.name)] = true end` with `if info and info.name then set[ns.ShortName(info.name)] = info.role or 4 end`;
- replace `if full then set[ns.ShortName(full)] = true end` with `if full then set[ns.ShortName(full)] = 4 end`;
- replace `return guildSet[name] == true   -- no roster available: nobody is trusted` with `return guildSet[name] ~= nil   -- no roster available: nobody is trusted`;
- after the whole `function R.IsGuildmate(name) … end` add:

```lua
-- Officers: community role Owner (1, guild master) or Leader (2, officer), the rule Blizzard's own UI uses.
function R.IsOfficer(name)
	if not R.IsGuildmate(name) then return false end
	local role = guildSet[name]
	return role == 1 or role == 2
end
function R.IAmOfficer()
	return (IsGuildLeader and IsGuildLeader()) or (C_GuildInfo and C_GuildInfo.IsGuildOfficer and C_GuildInfo.IsGuildOfficer()) or false
end
```

`LevelMates/Comm.lua`: after the `roles` validator add:

```lua
-- one of a closed set of words
local function oneOf(...)
	local set = {}
	for _, w in ipairs({ ... }) do set[w] = true end
	return function(v) return type(v) == "string" and set[v] == true end
end
```

add to `C.SCHEMA` (next to `rx`):

```lua
	go   = { id = word(8), ty = oneOf("lvl", "dun", "cnt"), a = int(1, 100000), w = oneOf("lvl", "qst", "dun"), s = int(0, 100000), e = int(0, 100000) },
	gx   = { id = word(8) },
	gd   = { id = word(8) },
	gc   = { id = word(8), n = int(0, 10000) },
```

and to `REQUIRED`: `go = { "id", "ty", "a", "s", "e" }, gx = { "id" }, gd = { "id" }, gc = { "id", "n" },`.

`LevelMates/Core.lua`: `restedNotices = true,` → `restedNotices = true, goalNotices = true,`. `LevelMates/Settings.lua`: after `Bool(category, "restedNotices", L.OPT_RESTED_NOTICE, L.OPT_RESTED_NOTICE_TT)` add `Bool(category, "goalNotices", L.OPT_GOAL, L.OPT_GOAL_TT)`.

`enUS.lua` append:

```lua
L.GOAL_LVL = "Everyone to level %d"; L.GOAL_DUN = "Dungeon together: %s"
L.GOAL_CNT_LVL = "%d levels between us"; L.GOAL_CNT_QST = "%d quests between us"; L.GOAL_CNT_DUN = "%d dungeons between us"
L.GOAL_DONE_BY = "Done: %s"; L.GOAL_PENDING = "Pending"
L.GOAL_NEW = "%s created a guild goal: %s."; L.GOAL_REACHED = "Guild goal reached: %s!"
L.GOAL_NOT_OFFICER = "Only officers and the guild master can create guild goals."; L.GOAL_FULL = "There are already 5 active guild goals."
L.OPT_GOAL = "Guild goal notices"; L.OPT_GOAL_TT = "A chat line when a guild goal is created or reached."
```

`esES.lua` append:

```lua
L.GOAL_LVL = "Todos a nivel %d"; L.GOAL_DUN = "Mazmorra juntos: %s"
L.GOAL_CNT_LVL = "%d niveles entre todos"; L.GOAL_CNT_QST = "%d misiones entre todos"; L.GOAL_CNT_DUN = "%d mazmorras entre todos"
L.GOAL_DONE_BY = "Hecha: %s"; L.GOAL_PENDING = "Pendiente"
L.GOAL_NEW = "%s ha creado una meta de hermandad: %s."; L.GOAL_REACHED = "¡Meta de hermandad cumplida: %s!"
L.GOAL_NOT_OFFICER = "Solo los oficiales y el maestro pueden crear metas de hermandad."; L.GOAL_FULL = "Ya hay 5 metas de hermandad activas."
L.OPT_GOAL = "Avisos de metas de hermandad"; L.OPT_GOAL_TT = "Una línea en el chat cuando se crea o se cumple una meta de hermandad."
```

`LevelMates/LevelMates.toc`: add `Goals.lua` right after `Journal.lua`.

Create `LevelMates/Goals.lua`:

```lua
-- Goals.lua: guild goals (plan A): everyone to level X, dungeon together, counters. Officers create and delete;
-- every addon keeps them per guild and re-shares them from officers and creators.
-- Spec 2026-10-09-levelmates-goals-design.
local _, ns = ...
local G = {}
ns.Goals = G
local L, C, R, D, J = ns.L, ns.Comm, ns.Roster, ns.Dungeons, ns.Journal
G.MAX, G.KEEP_DAYS, G.SEEN_DAYS = 5, 2, 30
local COUNT_KIND = { lvl = "level", qst = "quest", dun = "dungeon" }

local function today() return math.floor(time() / 86400) end
local function me() return (UnitName("player")) end
local function guildKey() return GetGuildInfo("player") or "?" end
local function store()
	ns.db.goals = ns.db.goals or {}
	local k = guildKey()
	ns.db.goals[k] = ns.db.goals[k] or {}
	return ns.db.goals[k]
end
local function seen()
	ns.db.seen = ns.db.seen or {}
	local k = guildKey()
	ns.db.seen[k] = ns.db.seen[k] or {}
	return ns.db.seen[k]
end
local function newId() return string.format("%04x%04x", math.random(0, 65535), math.random(0, 65535)):sub(1, 8) end

function G.Get(id) return store()[id] end

-- Active goals, soonest deadline first; goals 2 days past their deadline are dropped here.
function G.List()
	local s, out = store(), {}
	for id, g in pairs(s) do
		if today() > g.e + G.KEEP_DAYS then s[id] = nil else out[#out + 1] = g end
	end
	table.sort(out, function(a, b) if a.e ~= b.e then return a.e < b.e end; return a.id < b.id end)
	return out
end

local function valid(ty, a, w)
	if ty == "lvl" then return type(a) == "number" and a >= 2 and a <= 60
	elseif ty == "dun" then return D.Get(a) ~= nil
	elseif ty == "cnt" then return type(a) == "number" and a >= 1 and a <= 10000 and COUNT_KIND[w] ~= nil end
	return false
end

local function fields(g)
	local f = { id = g.id, ty = g.ty, a = g.a, s = g.s, e = g.e }
	if g.ty == "cnt" then f.w = g.w end
	return f
end
G.Fields = fields

function G.Text(g)
	if g.ty == "lvl" then return string.format(L.GOAL_LVL, g.a)
	elseif g.ty == "dun" then return string.format(L.GOAL_DUN, D.Name(g.a)) end
	return string.format(L["GOAL_CNT_" .. string.upper(g.w)], g.a)
end
function G.UntilText(g) return date("%d/%m", g.e * 86400) end

-- My part of a counter: journal entries of the counted kind from the start of the goal's first day.
function G.MyContribution(g)
	if g.ty ~= "cnt" then return 0 end
	local from, n = g.s * 86400, 0
	for _, e in ipairs(J.List(COUNT_KIND[g.w], "")) do if e.t >= from then n = n + 1 end end
	return n
end

-- lvl: reached, total, missing names; dun: 1|0, 1, by; cnt: sum, target.
function G.Progress(g)
	if g.ty == "lvl" then
		local levels, cutoff = {}, time() - G.SEEN_DAYS * 86400
		for name, s in pairs(seen()) do if s.t >= cutoff then levels[name] = s.l end end
		for name, m in pairs(R.mates) do levels[name] = m.level end
		levels[me()] = UnitLevel("player")
		local reached, total, missing = 0, 0, {}
		for name, l in pairs(levels) do
			total = total + 1
			if l >= g.a then reached = reached + 1 else missing[#missing + 1] = name end
		end
		table.sort(missing)
		return reached, total, missing
	elseif g.ty == "dun" then
		return g.doneBy and 1 or 0, 1, g.doneBy
	end
	local sum = G.MyContribution(g)
	for name, n in pairs(g.contrib or {}) do if name ~= me() then sum = sum + n end end   -- never count my part twice
	return sum, g.a
end

function G.IsDone(g)
	local a, b = G.Progress(g)
	if g.ty == "lvl" then return b > 0 and a == b end
	return a >= b
end

function G.ProgressText(g)
	if g.ty == "dun" then return g.doneBy and string.format(L.GOAL_DONE_BY, g.doneBy) or L.GOAL_PENDING end
	local a, b = G.Progress(g)
	return string.format("%d/%d", math.min(a, b), b)
end

-- Reached: announced once per goal.
function G.CheckDone(g)
	if not g.announced and G.IsDone(g) then
		g.announced = true
		if ns.db.settings.goalNotices then ns.Say(L.GOAL_REACHED, G.Text(g)) end
	end
end

-- Called from a click (the officers' dialog).
function G.Create(ty, a, w, days)
	if not R.IAmOfficer() then ns.Say(L.GOAL_NOT_OFFICER); return false end
	if not C.IsReady() then ns.Say(L.HELP_NEEDS_SHARE); return false end
	if not valid(ty, a, w) or type(days) ~= "number" or days < 1 or days > 30 then return false end
	if #G.List() >= G.MAX then ns.Say(L.GOAL_FULL); return false end
	local g = { id = newId(), ty = ty, a = a, w = ty == "cnt" and w or nil, s = today(), e = today() + days, by = me(), contrib = {} }
	if not C.Send("go", fields(g), "now") then return false end
	store()[g.id] = g
	ns.Fire("LM_GOALS_CHANGED")
	return true
end

function G.CanDelete(id) local g = G.Get(id); return g ~= nil and (g.by == me() or R.IAmOfficer()) end

function G.Delete(id)
	if not G.CanDelete(id) then return false end
	C.Send("gx", { id = id }, "now")
	store()[id] = nil
	ns.Fire("LM_GOALS_CHANGED")
	return true
end

C.OnMessage("go", function(f, name)
	if not R.IsOfficer(name) or not valid(f.ty, f.a, f.w) then return end
	local s = store()
	local g = s[f.id]
	if not g then
		if #G.List() >= G.MAX then return end
		g = { id = f.id, contrib = {}, by = name }
		s[f.id] = g
		if ns.db.settings.goalNotices then ns.Say(L.GOAL_NEW, name, G.Text({ ty = f.ty, a = f.a, w = f.w })) end
	end
	g.ty, g.a, g.w, g.s, g.e = f.ty, f.a, f.w, f.s, f.e
	ns.Fire("LM_GOALS_CHANGED")
end)

C.OnMessage("gx", function(f, name)
	local g = G.Get(f.id)
	if g and (g.by == name or R.IsOfficer(name)) then store()[f.id] = nil; ns.Fire("LM_GOALS_CHANGED") end
end)

-- Levels last seen per guildmate, for "everyone to level X".
C.OnMessage("hb", function(f, name) seen()[name] = { l = f.l, t = time() } end)

-- A newcomer: officers re-send every goal they hold, others only the goals they created.
ns.On("LM_PING_ANSWERED", function()
	local officer = R.IAmOfficer()
	for _, g in ipairs(G.List()) do
		if officer or g.by == me() then C.Send("go", fields(g)) end
	end
end)
```

- [ ] **Step 4: Run the tests and the whole suite**

Run: `node tools/run-lua-test.mjs LevelMates tests/goals.test.lua` and `tests/comm_format.test.lua` — Expected: `ok`. Run: `npm test` — Expected: all `ok` (existing roster/transport tests still pass: `IsGuildmate` now checks `~= nil`).

- [ ] **Step 5: Commit**

```bash
git add LevelMates/Goals.lua LevelMates/Roster.lua LevelMates/Comm.lua LevelMates/Core.lua LevelMates/Settings.lua LevelMates/Locales/enUS.lua LevelMates/Locales/esES.lua LevelMates/LevelMates.toc tools/wow-stub.lua tests/goals.test.lua tests/comm_format.test.lua
git commit -m "feat(goals): guild goals core, officer roles, go/gx messages, level progress"
```

---

### Task 2: Dungeon-together and counters

**Files:**
- Modify: `LevelMates/Goals.lua`, `LevelMates/Journal.lua`
- Create: `tests/goals_progress.test.lua`

**Interfaces:**
- Consumes: `LM_JOURNAL_ADDED(entry)` (new, fired by `J.Add`), `LM_HB_SENT`, `LM_PING_ANSWERED`.
- Produces: `gd` and `gc` handling and sending; completion notices.

- [ ] **Step 1: Write the failing test**

`tests/goals_progress.test.lua`:

```lua
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local C, G, R, J, L = ns.Comm, ns.Goals, ns.Roster, ns.Journal, ns.L
local function mate(name) STUB.Receive("LVLM", C.Encode("hb", { l = 20, z = 1421 }), "GUILD", name .. "-Testrealm") end
local function lastKind() return (C.Decode(STUB.sent[#STUB.sent].msg)) end
local function find(pred) for _, g in ipairs(G.List()) do if pred(g) then return g end end end
STUB.guildMembers = { Tester = true, Mario = true }
R.InvalidateGuildRoster()
STUB.iAmOfficer = true
mate("Mario")

-- dungeon together: done when my journal records it with a guildmate
assert(G.Create("dun", 2, nil, 7))
local dun = find(function(g) return g.ty == "dun" end)
J.Add("dungeon", { name = ns.Dungeons.Name(2), mates = {} })
assert(not G.IsDone(dun), "alone does not count")
J.Add("dungeon", { name = ns.Dungeons.Name(3), mates = { "Mario" } })
assert(not G.IsDone(dun), "another dungeon does not count")
local printed = #STUB.printed
J.Add("dungeon", { name = ns.Dungeons.Name(2), mates = { "Mario" } })
assert(G.IsDone(dun) and dun.doneBy == "Tester" and lastKind() == "gd", "done with a guildmate; the guild is told")
assert(#STUB.printed == printed + 1 and STUB.printed[#STUB.printed]:find(G.Text(dun), 1, true), "reached, announced once")
J.Add("dungeon", { name = ns.Dungeons.Name(2), mates = { "Mario" } })
assert(#STUB.printed == printed + 1, "not announced twice")

-- done by someone else
assert(G.Create("dun", 4, nil, 7))
local dun2 = find(function(g) return g.ty == "dun" and g.a == 4 end)
STUB.Receive("LVLM", C.Encode("gd", { id = dun2.id }), "GUILD", "Stranger-Testrealm")
assert(not dun2.doneBy, "a stranger cannot complete it")
STUB.Receive("LVLM", C.Encode("gd", { id = dun2.id }), "GUILD", "Mario-Testrealm")
assert(G.IsDone(dun2) and dun2.doneBy == "Mario" and G.ProgressText(dun2) == string.format(L.GOAL_DONE_BY, "Mario"), "done by Mario")

-- counter: my part from the journal plus everyone else's
assert(G.Create("cnt", 5, "qst", 7))
local cnt = find(function(g) return g.ty == "cnt" end)
J.Add("quest", { id = 1, name = "a" }); J.Add("quest", { id = 2, name = "b" })
assert(G.MyContribution(cnt) == 2, "my part from the journal")
STUB.Receive("LVLM", C.Encode("gc", { id = cnt.id, n = 2 }), "GUILD", "Mario-Testrealm")
assert(select(1, G.Progress(cnt)) == 4 and G.ProgressText(cnt) == "4/5", "sum of everyone")
STUB.Receive("LVLM", C.Encode("gc", { id = cnt.id, n = 2 }), "GUILD", "Tester-Testrealm")
assert(select(1, G.Progress(cnt)) == 4, "my own echo never counts twice")

-- my part goes out after a heartbeat, at most once a minute
local function gcs(from) local out = {}; for i = from, #STUB.sent do local k, f = C.Decode(STUB.sent[i].msg); if k == "gc" then out[#out + 1] = f.n end end; return table.concat(out, ",") end
local n = #STUB.sent + 1
STUB.Advance(100)
assert(gcs(n) == "2", "sent with a heartbeat: " .. gcs(n))
printed = #STUB.printed
J.Add("quest", { id = 3, name = "c" })
assert(G.IsDone(cnt) and #STUB.printed == printed + 1, "reached at 5, announced")
n = #STUB.sent + 1
STUB.Advance(100)
assert(gcs(n) == "3", "the new part goes out: " .. gcs(n))
STUB.Receive("LVLM", C.Encode("gc", { id = cnt.id, n = 3 }), "GUILD", "Mario-Testrealm")
assert(#STUB.printed == printed + 1, "a reached goal is not announced again")

-- a newcomer gets my contributions and my completed dungeon
n = #STUB.sent
STUB.iAmOfficer = false
STUB.Receive("LVLM", C.Encode("ping", {}), "GUILD", "Nuevo-Testrealm")
STUB.Advance(6)
local kinds = {}
for i = n + 1, #STUB.sent do kinds[#kinds + 1] = (C.Decode(STUB.sent[i].msg)) end
local s = table.concat(kinds, ",")
assert(s:find("gc", 1, true) and s:find("gd", 1, true), "contributions and my completion re-sent: " .. s)
```

- [ ] **Step 2: Run the test to see it fail**

Run: `node tools/run-lua-test.mjs LevelMates tests/goals_progress.test.lua` — Expected: LUA ERROR at `done with a guildmate; the guild is told`.

- [ ] **Step 3: Implement**

`LevelMates/Journal.lua`: in `function J.Add`, replace the line `ns.Fire("LM_JOURNAL_CHANGED")` (the one right after the `while #list > J.MAX` line) with:

```lua
	ns.Fire("LM_JOURNAL_ADDED", e)
	ns.Fire("LM_JOURNAL_CHANGED")
```

Append to `LevelMates/Goals.lua`:

```lua

-- Dungeon together, done by someone else (any guildmate).
C.OnMessage("gd", function(f, name)
	local g = G.Get(f.id)
	if not g or g.ty ~= "dun" or g.doneBy or not R.mates[name] then return end
	g.doneBy = name
	G.CheckDone(g)
	ns.Fire("LM_GOALS_CHANGED")
end)

-- A guildmate's part of a counter (my own echo is ignored by Progress).
C.OnMessage("gc", function(f, name)
	local g = G.Get(f.id)
	if not g or g.ty ~= "cnt" or not R.mates[name] then return end
	g.contrib = g.contrib or {}
	g.contrib[name] = f.n
	G.CheckDone(g)
	ns.Fire("LM_GOALS_CHANGED")
end)

-- My journal: a dungeon with a guildmate completes a dungeon goal; any entry may move a counter.
ns.On("LM_JOURNAL_ADDED", function(e)
	for _, g in ipairs(G.List()) do
		if g.ty == "dun" and not g.doneBy and e.k == "dungeon" and e.name == D.Name(g.a) and e.mates and #e.mates > 0 then
			g.doneBy = me()
			C.Send("gd", { id = g.id }, "now")
		end
		G.CheckDone(g)
	end
	ns.Fire("LM_GOALS_CHANGED")
end)

-- My counter parts go out after a heartbeat when they changed, at most once a minute per goal.
local sentN, sentAt = {}, {}
ns.On("LM_HB_SENT", function()
	local now = GetTime()
	for _, g in ipairs(G.List()) do
		if g.ty == "cnt" then
			local n = math.min(10000, G.MyContribution(g))
			if n ~= (sentN[g.id] or 0) and now - (sentAt[g.id] or -math.huge) >= 60 then
				if C.Send("gc", { id = g.id, n = n }) then sentN[g.id], sentAt[g.id] = n, now end
			end
		end
	end
end)

-- A newcomer also gets my counter parts and the dungeons I completed.
ns.On("LM_PING_ANSWERED", function()
	for _, g in ipairs(G.List()) do
		if g.ty == "cnt" then
			local n = G.MyContribution(g)
			if n > 0 then C.Send("gc", { id = g.id, n = math.min(10000, n) }) end
		elseif g.ty == "dun" and g.doneBy == me() then
			C.Send("gd", { id = g.id })
		end
	end
end)
```

- [ ] **Step 4: Run the test and the whole suite**

Run: `node tools/run-lua-test.mjs LevelMates tests/goals_progress.test.lua` — Expected: `ok`. Run: `npm test` — Expected: all `ok`.

- [ ] **Step 5: Commit**

```bash
git add LevelMates/Goals.lua LevelMates/Journal.lua tests/goals_progress.test.lua
git commit -m "feat(goals): dungeon-together completion and counters from the journal"
```

---

### Task 3: The Goals tab

**Files:**
- Modify: `LevelMates/Board.lua`, `LevelMates/Locales/enUS.lua`, `LevelMates/Locales/esES.lua`
- Create: `tests/board_goals.test.lua`

**Interfaces:**
- Consumes: `ns.Goals.List/Text/ProgressText/UntilText/IsDone/Progress/CanDelete/Delete`, `ns.Roster.IAmOfficer`, event `LM_GOALS_CHANGED`.
- Produces: `B.tabs.goals`, `B.GCOLS`, `B.goalNew` (fires `LM_GOAL_NEW`), `B.OpenGoalMenu(id)`, `B.lastGoalMenu`, slash `/lm metas` and `/lm goals`.

- [ ] **Step 1: Write the failing test**

`tests/board_goals.test.lua`:

```lua
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local C, B, G, R, L = ns.Comm, ns.Board, ns.Goals, ns.Roster, ns.L
local today = math.floor(time() / 86400)
STUB.guildMembers = { Tester = true, Mario = true, Jefa = true }
STUB.guildRoles = { Jefa = 2 }
R.InvalidateGuildRoster()
STUB.Receive("LVLM", C.Encode("hb", { l = 40, z = 1421 }), "GUILD", "Jefa-Testrealm")
STUB.Receive("LVLM", C.Encode("hb", { l = 18, z = 1421 }), "GUILD", "Mario-Testrealm")
STUB.Receive("LVLM", C.Encode("go", { id = "j1", ty = "lvl", a = 30, s = today, e = today + 3 }), "GUILD", "Jefa-Testrealm")
STUB.Receive("LVLM", C.Encode("go", { id = "j2", ty = "cnt", a = 50, w = "qst", s = today, e = today + 7 }), "GUILD", "Jefa-Testrealm")
B.Toggle()
local function visible()
	local out = {}
	for i = 1, #B.rows do if B.rows[i].button:IsShown() then out[#out + 1] = B.rows[i] end end
	return out
end

assert(B.tabs.goals, "fourth tab")
for _, key in ipairs({ "mates", "lfg", "journal", "goals" }) do assert(B.tabs[key]:GetWidth() == 70, "tab width 70: " .. key) end
B.tabs.goals.scripts.OnClick(B.tabs.goals)
assert(B.tab == "goals" and ns.char.boardTab == "goals", "goals tab, remembered")
assert(B.headText[1].text == L.COL_BY and B.headText[3].text == L.COL_GOAL and B.headText[4].text == L.COL_PROGRESS and B.headText[5].text == L.COL_UNTIL, "headers")
assert(B.rows[1].zone:GetWidth() == B.GCOLS[3], "goals column widths")
local rows = visible()
assert(#rows == 2 and rows[1].zone.text == G.Text(G.Get("j1")) and rows[2].zone.text == G.Text(G.Get("j2")), "soonest deadline first")
assert(rows[1].name.text == "Jefa" and rows[1].group.text == G.ProgressText(G.Get("j1")) and rows[1].xph.text == G.UntilText(G.Get("j1")), "creator, progress, deadline")

-- who is missing, on hover
rows[1].button.scripts.OnEnter(rows[1].button)
local _, _, missing = G.Progress(G.Get("j1"))
assert(GameTooltip.lines[1] == string.format(L.GOAL_MISSING, table.concat(missing, ", ")) and not GameTooltip.hidden, "missing on hover: " .. tostring(GameTooltip.lines[1]))
rows[1].button.scripts.OnLeave(rows[1].button)

-- right click: delete only for the creator or an officer
B.lastGoalMenu = nil
rows[1].button.scripts.OnClick(rows[1].button, "RightButton")
assert(B.lastGoalMenu == nil, "a plain member gets no delete menu")
STUB.iAmOfficer = true
local entries = {}
MenuUtil.CreateContextMenu = function(owner, fn)
	local root = { CreateTitle = function() end, CreateButton = function(_, text, cb) entries[#entries + 1] = { text = text, cb = cb } end }
	fn(owner, root)
end
rows[1].button.scripts.OnClick(rows[1].button, "RightButton")
assert(B.lastGoalMenu == "j1" and entries[1].text == L.GOAL_DELETE, "officer: delete in the menu")
entries[1].cb()
assert(not G.Get("j1") and (C.Decode(STUB.sent[#STUB.sent].msg)) == "gx" and #visible() == 1, "deleted, guild told, list refreshed")

-- "New goal": officers only
B.Refresh()
assert(B.goalNew:IsShown(), "officer sees New goal")
local opened = 0
ns.On("LM_GOAL_NEW", function() opened = opened + 1 end)
B.goalNew.scripts.OnClick(B.goalNew)
assert(opened == 1, "fires LM_GOAL_NEW")
STUB.iAmOfficer = false
B.Refresh()
assert(not B.goalNew:IsShown(), "members do not")

-- controls and help rows follow the tab
assert(not B.helpButton:IsShown() and not B.lfgButton:IsShown() and not B.journalClear:IsShown() and not B.nearCheck:IsShown(), "other controls hidden")
for _, hr in ipairs(B.helpRows) do assert(not hr.text:IsShown(), "help rows hidden") end

-- empty
G.Delete("j2")
STUB.iAmOfficer = true; G.Delete("j2"); STUB.iAmOfficer = false
assert(#visible() == 0 and B.frame.empty.text == L.GOAL_EMPTY, "empty text")

-- back to guildmates; /lm metas
B.tabs.mates.scripts.OnClick(B.tabs.mates)
assert(not B.goalNew:IsShown() and B.rows[1].zone:GetWidth() == B.COLS[3], "guildmates again")
B.Toggle()
SlashCmdList["LEVELMATES"]("metas")
assert(B.frame:IsShown() and B.tab == "goals", "/lm metas")
```

- [ ] **Step 2: Run the test to see it fail**

Run: `node tools/run-lua-test.mjs LevelMates tests/board_goals.test.lua` — Expected: LUA ERROR at `fourth tab`.

- [ ] **Step 3: Implement**

Locales. `enUS.lua` append:

```lua
L.TAB_GOALS = "Goals"; L.COL_BY = "By"; L.COL_GOAL = "Goal"; L.COL_PROGRESS = "Progress"; L.COL_UNTIL = "Until"
L.GOAL_EMPTY = "No guild goals right now."; L.GOAL_MISSING = "Missing: %s"; L.GOAL_DELETE = "Delete goal"; L.BTN_GOAL_NEW = "New goal"
```
`esES.lua` append:

```lua
L.TAB_GOALS = "Metas"; L.COL_BY = "Creada por"; L.COL_GOAL = "Meta"; L.COL_PROGRESS = "Progreso"; L.COL_UNTIL = "Hasta"
L.GOAL_EMPTY = "No hay metas de hermandad ahora mismo."; L.GOAL_MISSING = "Falta: %s"; L.GOAL_DELETE = "Borrar meta"; L.BTN_GOAL_NEW = "Nueva meta"
```

`LevelMates/Board.lua`:

(a) After the `B.JCOLS = …` line add:

```lua
B.GCOLS = { 100, 1, 284, 70, 65 }   -- goals: by, -, goal, progress, until (same total as B.COLS)
```

(b) Replace `b:SetSize(80, 20)` with `b:SetSize(70, 20)`, and `Tab("mates", L.TAB_MATES, -84); Tab("lfg", L.TAB_LFG, 0); Tab("journal", L.TAB_JOURNAL, 84)` with `Tab("mates", L.TAB_MATES, -111); Tab("lfg", L.TAB_LFG, -37); Tab("journal", L.TAB_JOURNAL, 37); Tab("goals", L.TAB_GOALS, 111)`. Replace `B.tab = (ns.char.boardTab == "lfg" or ns.char.boardTab == "journal") and ns.char.boardTab or "mates"` with:

```lua
	local saved = ns.char.boardTab
	B.tab = (saved == "lfg" or saved == "journal" or saved == "goals") and saved or "mates"
```

(c) After the line `B.journalPrev, B.journalNext, B.journalPageText = prev, nextb, pageText` add:

```lua
	-- Goals tab: "New goal" for officers (bottom left).
	local goalNew = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
	goalNew:SetSize(120, 20); goalNew:SetPoint("BOTTOMLEFT", 12, 3); goalNew:SetText(L.BTN_GOAL_NEW)
	goalNew:SetScript("OnClick", function() ns.Fire("LM_GOAL_NEW") end)
	B.goalNew = goalNew
```

(d) Replace the row `OnClick` handler body's first two lines

```lua
			local name = self.mate
			if not name then return end
```

with:

```lua
			if B.tab == "goals" then
				if mouse == "RightButton" and self.goalId then B.OpenGoalMenu(self.goalId) end
				return
			end
			local name = self.mate
			if not name then return end
```

(e) In the row `OnEnter`, replace the line `elseif B.tab == "journal" and self.entry and self.entry.link then   -- journal: the item card` with:

```lua
			elseif B.tab == "goals" and self.goalId then   -- goals: who is missing a level goal
				local g = ns.Goals.Get(self.goalId)
				if g and g.ty == "lvl" then
					local _, _, missing = ns.Goals.Progress(g)
					if #missing > 0 then
						GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
						GameTooltip:AddLine(string.format(L.GOAL_MISSING, table.concat(missing, ", ")), 1, 1, 1, true)
						GameTooltip:Show()
					end
				end
			elseif B.tab == "journal" and self.entry and self.entry.link then   -- journal: the item card
```

(f) In `SetHeaders`, replace the line `	if B.tab == "journal" then` with:

```lua
	if B.tab == "goals" then
		B.headText[1]:SetText(L.COL_BY); B.headText[2]:SetText(""); B.headText[3]:SetText(L.COL_GOAL)
		B.headText[4]:SetText(L.COL_PROGRESS); B.headText[5]:SetText(L.COL_UNTIL)
		for i = 1, 5 do B.headText[i]:SetTextColor(1, 0.82, 0) end
		return
	end
	if B.tab == "journal" then
```

(g) Before `local function RefreshTabs()` add:

```lua
local function FillGoals(list)
	for i = 1, ROWS do
		local r, g = B.rows[i], list[i]
		r.button.mate, r.button.adId, r.button.entry, r.button.goalId = nil, nil, nil, g and g.id
		if g then
			r.icon:Hide()
			r.name:SetText(g.by or ""); r.name:SetTextColor(0.7, 0.7, 0.7)
			r.level:SetText("")
			r.zone:SetText(ns.Goals.Text(g)); r.zone:SetTextColor(1, 0.82, 0)
			r.group:SetText(ns.Goals.ProgressText(g)); r.group:SetTextColor(unpack(ns.Goals.IsDone(g) and B.GROUP_COLORS.open or { 1, 1, 1 }))
			r.xph:SetText(ns.Goals.UntilText(g)); r.xph:SetTextColor(0.7, 0.7, 0.7)
			r.button:Show()
			RowBg(r, i, false)
		else
			ClearRow(r)
		end
	end
end

function B.OpenGoalMenu(id)
	if not ns.Goals.CanDelete(id) then return end
	B.lastGoalMenu = id
	local g = ns.Goals.Get(id)
	MenuUtil.CreateContextMenu(B.frame, function(_, root)
		root:CreateTitle(ns.Goals.Text(g))
		root:CreateButton(L.GOAL_DELETE, function() ns.Goals.Delete(id) end)
	end)
end
```

(h) Replace the whole `local function RefreshTabs() … end` with:

```lua
local function RefreshTabs()
	local lfg, journal, goals = B.tab == "lfg", B.tab == "journal", B.tab == "goals"
	local mates = not lfg and not journal and not goals
	B.tabs.mates:SetEnabled(not mates); B.tabs.lfg:SetEnabled(not lfg); B.tabs.journal:SetEnabled(not journal); B.tabs.goals:SetEnabled(not goals)
	B.helpButton:SetShown(mates); B.nearCheck:SetShown(mates); B.nearLabel:SetShown(mates)
	B.palCheck:SetShown(mates); B.palLabel:SetShown(mates)
	B.palCheck:SetChecked(ns.Partner and ns.Partner.IsOn() or false)
	B.lfgButton:SetShown(lfg)
	B.lfgButton:SetText(ns.LFG.mine and L.BTN_LFG_CANCEL or L.BTN_LFG)
	B.journalClear:SetShown(journal); B.journalFilterButton:SetShown(journal)
	B.journalPrev:SetShown(journal); B.journalNext:SetShown(journal); B.journalPageText:SetShown(journal)
	B.goalNew:SetShown(goals and R.IAmOfficer())
end
```

(i) In `function B.Refresh()`:
- replace `local lfg, journal = B.tab == "lfg", B.tab == "journal"` with `local lfg, journal, goals = B.tab == "lfg", B.tab == "journal", B.tab == "goals"`;
- replace the `else` branch that sets the list, `	else\n		list = lfg and LfgVisible() or Visible()\n	end`, with `	elseif goals then\n		list = ns.Goals.List()\n	else\n		list = lfg and LfgVisible() or Visible()\n	end`;
- replace `SetColumns(journal and B.JCOLS or B.COLS)` with `SetColumns(journal and B.JCOLS or goals and B.GCOLS or B.COLS)`;
- replace `if journal then FillJournal(list) elseif lfg then FillLfg(list) else FillMates(list) end` with `if journal then FillJournal(list) elseif goals then FillGoals(list) elseif lfg then FillLfg(list) else FillMates(list) end`;
- replace `if journal then emptyText = ns.Journal.Count() == 0 and L.J_EMPTY or L.EMPTY_FILTERED` with `if journal then emptyText = ns.Journal.Count() == 0 and L.J_EMPTY or L.EMPTY_FILTERED\n		elseif goals then emptyText = L.GOAL_EMPTY`;
- replace `	if journal then\n		for _, hr in ipairs(B.helpRows)` with `	if journal or goals then\n		for _, hr in ipairs(B.helpRows)`.

(j) Replace every `(key == "lfg" or key == "journal") and key or "mates"` (in `SetTab` and `ShowTab`) with `(key == "lfg" or key == "journal" or key == "goals") and key or "mates"`.

(k) At the end of the file add:

```lua
ns.On("LM_GOALS_CHANGED", B.Refresh)
ns.Slash("metas", function() B.ShowTab("goals") end)
ns.Slash("goals", function() B.ShowTab("goals") end)
```

- [ ] **Step 4: Run the test and the whole suite**

Run: `node tools/run-lua-test.mjs LevelMates tests/board_goals.test.lua` — Expected: `ok`. Run: `npm test` — Expected: all `ok` (`board_lfg`/`board_journal` assert tab states, not widths; `board_journal` checks `B.WIDTH == 600`, unchanged).

- [ ] **Step 5: Commit**

```bash
git add LevelMates/Board.lua LevelMates/Locales/enUS.lua LevelMates/Locales/esES.lua tests/board_goals.test.lua
git commit -m "feat(board): Goals tab with progress, who is missing, delete and New goal"
```

---

### Task 4: The officers' "New goal" dialog

**Files:**
- Create: `LevelMates/GoalDialog.lua`, `tests/goal_dialog.test.lua`
- Modify: `LevelMates/LevelMates.toc`, `LevelMates/Locales/enUS.lua`, `LevelMates/Locales/esES.lua`

**Interfaces:**
- Consumes: event `LM_GOAL_NEW`, `ns.Goals.Create`, `ns.Dungeons.list/Name`, `MenuUtil.CreateContextMenu`.
- Produces: `ns.GoalDialog` with `Open()`, `SetType(ty)`, `Refresh()`, `Create()`, `frame`, `typeButton`, `target` (EditBox), `dungeonButton`, `whatButton`, `daysButton`, `ok`, fields `type`, `dungeon`, `what`, `days` (default 7).

- [ ] **Step 1: Write the failing test**

`tests/goal_dialog.test.lua`:

```lua
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local C, G, L = ns.Comm, ns.Goals, ns.L
local today = math.floor(time() / 86400)
local Dlg = ns.GoalDialog
assert(Dlg, "dialog module loaded")
local entries
MenuUtil.CreateContextMenu = function(owner, fn)
	entries = {}
	local root = { CreateTitle = function() end, CreateButton = function(_, text, cb) entries[#entries + 1] = { text = text, cb = cb } end }
	fn(owner, root)
end
local function pick(button, text) button.scripts.OnClick(button); for _, en in ipairs(entries) do if en.text == text then en.cb() end end end
STUB.iAmOfficer = true

ns.Fire("LM_GOAL_NEW")
assert(Dlg.frame:IsShown() and Dlg.ok.enabled == false and Dlg.days == 7, "opens; nothing to create yet; 7 days by default")

-- everyone to level 30, in 3 days
pick(Dlg.typeButton, L.GOAL_TYPE_LVL)
assert(Dlg.type == "lvl" and Dlg.target:IsShown() and not Dlg.dungeonButton:IsShown() and not Dlg.whatButton:IsShown(), "level: a number")
Dlg.target:SetText("30"); Dlg.target.scripts.OnTextChanged(Dlg.target)
pick(Dlg.daysButton, string.format(L.GOAL_DAYS, 3))
assert(Dlg.days == 3 and Dlg.ok.enabled == true, "ready")
Dlg.ok.scripts.OnClick(Dlg.ok)
local k, f = C.Decode(STUB.sent[#STUB.sent].msg)
assert(k == "go" and f.ty == "lvl" and f.a == 30 and f.e == today + 3, "created from the click")
assert(not Dlg.frame:IsShown(), "dialog closes")

-- dungeon together
ns.Fire("LM_GOAL_NEW")
pick(Dlg.typeButton, L.GOAL_TYPE_DUN)
assert(Dlg.dungeonButton:IsShown() and not Dlg.target:IsShown() and Dlg.ok.enabled == false, "dungeon: pick one")
pick(Dlg.dungeonButton, string.format("%s (%d-%d)", ns.Dungeons.Name(5), 17, 26))
assert(Dlg.dungeon == 5 and Dlg.ok.enabled == true, "picked")
Dlg.ok.scripts.OnClick(Dlg.ok)
k, f = C.Decode(STUB.sent[#STUB.sent].msg)
assert(k == "go" and f.ty == "dun" and f.a == 5, "dungeon goal created")

-- counter: 50 quests
ns.Fire("LM_GOAL_NEW")
pick(Dlg.typeButton, L.GOAL_TYPE_CNT)
assert(Dlg.whatButton:IsShown() and Dlg.target:IsShown(), "counter: number and what")
Dlg.target:SetText("50"); Dlg.target.scripts.OnTextChanged(Dlg.target)
assert(Dlg.ok.enabled == false, "still needs what it counts")
pick(Dlg.whatButton, L.GOAL_WHAT_QST)
assert(Dlg.what == "qst" and Dlg.ok.enabled == true, "ready")
Dlg.ok.scripts.OnClick(Dlg.ok)
k, f = C.Decode(STUB.sent[#STUB.sent].msg)
assert(k == "go" and f.ty == "cnt" and f.a == 50 and f.w == "qst", "counter created")

-- a refused create keeps the dialog open
STUB.iAmOfficer = false
ns.Fire("LM_GOAL_NEW")
Dlg.ok.scripts.OnClick(Dlg.ok)
assert(Dlg.frame:IsShown() and STUB.printed[#STUB.printed]:find(L.GOAL_NOT_OFFICER, 1, true), "refused: stays open, says why")
```

- [ ] **Step 2: Run the test to see it fail**

Run: `node tools/run-lua-test.mjs LevelMates tests/goal_dialog.test.lua` — Expected: LUA ERROR at `dialog module loaded`.

- [ ] **Step 3: Implement**

Locales. `enUS.lua` append:

```lua
L.GOAL_DIALOG_TITLE = "New guild goal"; L.GOAL_PICK_TYPE = "Type..."
L.GOAL_TYPE_LVL = "Everyone to a level"; L.GOAL_TYPE_DUN = "Dungeon together"; L.GOAL_TYPE_CNT = "Counter"
L.GOAL_TARGET = "Target"; L.GOAL_COUNT_WHAT = "Counts..."
L.GOAL_WHAT_LVL = "Levels"; L.GOAL_WHAT_QST = "Quests"; L.GOAL_WHAT_DUN = "Dungeons"
L.GOAL_DAYS = "%d days"; L.GOAL_CREATE = "Create"
```
`esES.lua` append:

```lua
L.GOAL_DIALOG_TITLE = "Nueva meta de hermandad"; L.GOAL_PICK_TYPE = "Tipo..."
L.GOAL_TYPE_LVL = "Todos a un nivel"; L.GOAL_TYPE_DUN = "Mazmorra juntos"; L.GOAL_TYPE_CNT = "Contador"
L.GOAL_TARGET = "Objetivo"; L.GOAL_COUNT_WHAT = "Cuenta..."
L.GOAL_WHAT_LVL = "Niveles"; L.GOAL_WHAT_QST = "Misiones"; L.GOAL_WHAT_DUN = "Mazmorras"
L.GOAL_DAYS = "%d días"; L.GOAL_CREATE = "Crear"
```

`LevelMates/LevelMates.toc`: add `GoalDialog.lua` right after `Goals.lua`.

Create `LevelMates/GoalDialog.lua`:

```lua
-- GoalDialog.lua: the officers' "New guild goal" dialog. Goals.Create runs only from its Create button.
local _, ns = ...
local Dlg = {}
ns.GoalDialog = Dlg
local L, G, D = ns.L, ns.Goals, ns.Dungeons
local TYPES = { { "lvl", "GOAL_TYPE_LVL" }, { "dun", "GOAL_TYPE_DUN" }, { "cnt", "GOAL_TYPE_CNT" } }
local WHATS = { { "lvl", "GOAL_WHAT_LVL" }, { "qst", "GOAL_WHAT_QST" }, { "dun", "GOAL_WHAT_DUN" } }
local DAYS = { 1, 3, 7, 14 }
Dlg.days = 7

local function Menu(owner, items)
	MenuUtil.CreateContextMenu(owner, function(_, root)
		for _, it in ipairs(items) do root:CreateButton(it[1], it[2]) end
	end)
end

local function Button(f, w, point, x, y, text, onClick)
	local b = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
	b:SetSize(w, 22); b:SetPoint(point, x, y); b:SetText(text)
	b:SetScript("OnClick", onClick)
	return b
end

local function Build()
	local f = CreateFrame("Frame", "LevelMatesGoalDialog", UIParent, "BasicFrameTemplateWithInset")
	Dlg.frame = f
	f:SetSize(320, 220); f:SetPoint("CENTER"); f:SetFrameStrata("DIALOG")
	f:SetMovable(true); f:EnableMouse(true); f:SetClampedToScreen(true); f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", f.StartMoving); f:SetScript("OnDragStop", f.StopMovingOrSizing)
	if f.TitleText then f.TitleText:SetText(L.GOAL_DIALOG_TITLE) end
	tinsert(UISpecialFrames, "LevelMatesGoalDialog")
	f:Hide()

	Dlg.typeButton = Button(f, 280, "TOP", 0, -36, L.GOAL_PICK_TYPE, function(self)
		local items = {}
		for _, t in ipairs(TYPES) do items[#items + 1] = { L[t[2]], function() Dlg.SetType(t[1]) end } end
		Menu(self, items)
	end)
	local target = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
	target:SetSize(80, 22); target:SetPoint("TOPLEFT", 28, -76); target:SetAutoFocus(false); target:SetMaxLetters(5)
	target:SetScript("OnTextChanged", function() Dlg.Refresh() end)
	Dlg.target = target
	Dlg.dungeonButton = Button(f, 280, "TOP", 0, -74, L.LFG_PICK_DUNGEON, function(self)
		local items = {}
		for _, d in ipairs(D.list) do
			items[#items + 1] = { string.format("%s (%d-%d)", D.Name(d.id), d.min, d.max), function()
				Dlg.dungeon = d.id; Dlg.dungeonButton:SetText(string.format("%s (%d-%d)", D.Name(d.id), d.min, d.max)); Dlg.Refresh()
			end }
		end
		Menu(self, items)
	end)
	Dlg.whatButton = Button(f, 160, "TOPLEFT", 130, -74, L.GOAL_COUNT_WHAT, function(self)
		local items = {}
		for _, w in ipairs(WHATS) do items[#items + 1] = { L[w[2]], function() Dlg.what = w[1]; Dlg.whatButton:SetText(L[w[2]]); Dlg.Refresh() end } end
		Menu(self, items)
	end)
	Dlg.daysButton = Button(f, 120, "TOPLEFT", 20, -118, string.format(L.GOAL_DAYS, Dlg.days), function(self)
		local items = {}
		for _, n in ipairs(DAYS) do items[#items + 1] = { string.format(L.GOAL_DAYS, n), function() Dlg.days = n; Dlg.daysButton:SetText(string.format(L.GOAL_DAYS, n)); Dlg.Refresh() end } end
		Menu(self, items)
	end)
	Dlg.ok = Button(f, 130, "BOTTOMLEFT", 20, 14, L.GOAL_CREATE, function() Dlg.Create() end)
	Button(f, 130, "BOTTOMRIGHT", -20, 14, L.LFG_CLOSE, function() f:Hide() end)
end

function Dlg.SetType(ty)
	Dlg.type = ty
	for _, t in ipairs(TYPES) do if t[1] == ty then Dlg.typeButton:SetText(L[t[2]]) end end
	Dlg.Refresh()
end

local function Target()
	if Dlg.type == "dun" then return Dlg.dungeon end
	return tonumber(Dlg.target:GetText() or "")
end

function Dlg.Refresh()
	if not Dlg.frame then return end
	local ty = Dlg.type
	Dlg.target:SetShown(ty == "lvl" or ty == "cnt")
	Dlg.dungeonButton:SetShown(ty == "dun")
	Dlg.whatButton:SetShown(ty == "cnt")
	local ready = ty ~= nil and Target() ~= nil and (ty ~= "cnt" or Dlg.what ~= nil)
	Dlg.ok:SetEnabled(ready)
end

function Dlg.Create()
	if G.Create(Dlg.type, Target(), Dlg.what, Dlg.days) then Dlg.frame:Hide() end   -- a refused create keeps the dialog open
end

function Dlg.Open()
	if not Dlg.frame then Build() end
	Dlg.frame:Show()
	Dlg.Refresh()
end

ns.On("LM_GOAL_NEW", Dlg.Open)
```

- [ ] **Step 4: Run the test and the whole suite**

Run: `node tools/run-lua-test.mjs LevelMates tests/goal_dialog.test.lua` — Expected: `ok`. Run: `npm test` — Expected: all `ok`.

- [ ] **Step 5: Commit**

```bash
git add LevelMates/GoalDialog.lua LevelMates/LevelMates.toc LevelMates/Locales/enUS.lua LevelMates/Locales/esES.lua tests/goal_dialog.test.lua
git commit -m "feat(goals): officers' New goal dialog"
```

---

### Task 5: Simulation and documentation

**Files:**
- Modify: `LevelMates/Sim.lua`, `README.md`, `CHANGELOG.md`
- Create: `tests/sim_goals.test.lua`

**Interfaces:**
- Produces: `/lm sim metas` — a fake officer ("Jefa", in the roster, role Leader in a local override) posts three goals locally; `/lm sim off` deletes them.

- [ ] **Step 1: Write the failing test**

`tests/sim_goals.test.lua`:

```lua
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
STUB.player.realm = "Classic Beta PvP"
STUB.ambiguateKeepsRealm = true
local G = ns.Goals
local sentBefore = #STUB.sent
SlashCmdList["LEVELMATES"]("sim metas")
assert(#G.List() == 3, "three sample goals: " .. #G.List())
assert(#STUB.sent == sentBefore, "the simulation sends nothing")
SlashCmdList["LEVELMATES"]("sim off")
assert(#G.List() == 0, "sim off removes them")
```

- [ ] **Step 2: Run the test to see it fail**

Run: `node tools/run-lua-test.mjs LevelMates tests/sim_goals.test.lua` — Expected: LUA ERROR at `three sample goals`.

- [ ] **Step 3: Implement**

The simulation cannot make a fake sender an officer through the real guild list, so it stores sample goals directly, flagged `sim = true`. In `LevelMates/Goals.lua` append:

```lua

-- Simulation support (/lm sim metas): local sample goals, never sent.
function G.AddSample(g) g.sim = true; g.contrib = g.contrib or {}; store()[g.id] = g; ns.Fire("LM_GOALS_CHANGED") end
function G.RemoveSamples()
	local s = store()
	for id, g in pairs(s) do if g.sim then s[id] = nil end end
	ns.Fire("LM_GOALS_CHANGED")
end
```

In `LevelMates/Sim.lua`, after the `simJournal` function add:

```lua
local function simGoals()
	local G, day = ns.Goals, math.floor(time() / 86400)
	G.AddSample({ id = "simgo01", ty = "lvl", a = 25, s = day, e = day + 3, by = "Jefa" })
	G.AddSample({ id = "simgo02", ty = "dun", a = 5, s = day, e = day + 5, by = "Jefa" })
	G.AddSample({ id = "simgo03", ty = "cnt", a = 50, w = "qst", s = day, e = day + 7, by = "Jefa", contrib = { Mario = 12, Luis = 7 } })
end
```

In `off()` add as first line `ns.Goals.RemoveSamples()`, and in the slash handler, after the `simJournal` branch, add:

```lua
	elseif rest == "metas" or rest == "goals" then simGoals()
```

`README.md`, English "What it does", add:
`- **Guild goals** (Goals tab, or \`/lm metas\`): officers set goals for the guild — everyone to a level, a dungeon together, or a counter of levels, quests or dungeons between everyone — with live progress and who is missing. Kept across sessions; up to 5 at a time.`
and `/lm metas`, `/lm sim metas` in the Commands line. Spanish "Qué hace":
`- **Metas de hermandad** (pestaña Metas, o \`/lm metas\`): los oficiales marcan objetivos para la hermandad — todos a un nivel, una mazmorra juntos, o un contador de niveles, misiones o mazmorras entre todos — con el progreso en directo y quién falta. Se guardan entre sesiones; hasta 5 a la vez.`
and the two commands in the Comandos line. `CHANGELOG.md` append:

```
- Guild goals: a fourth board tab; officers and the guild master create goals (everyone to a level, a dungeon together, a counter of levels, quests or dungeons); progress with who is missing; kept per guild and re-shared by officers; at most 5, they expire two days after their deadline. New message kinds `go`, `gx`, `gd`, `gc`.
```

- [ ] **Step 4: Run the whole suite**

Run: `npm test` — Expected: all `ok`.

- [ ] **Step 5: In-game check (with the user), then commit**

In game: an officer creates each type from "Nueva meta"; a member sees them, the bars move, "who is missing" on hover; a non-officer has no "Nueva meta"; `/reload` keeps them; log another character in and confirm it receives the goals from an online officer. Check that `C_Club` roles really say Owner/Leader for the guild master and officers on Forever.

```bash
git add LevelMates/Sim.lua LevelMates/Goals.lua README.md CHANGELOG.md tests/sim_goals.test.lua
git commit -m "feat(goals): simulation and docs"
```

---

## Self-Review notes

- Spec §2 types → Tasks 1-2 (lvl, dun, cnt); personal goals are plan B. §3 officers → Task 1 (`IsOfficer`, `IAmOfficer`, gates). §4 messages and re-sharing → Tasks 1-2. §5 storage, seen levels, forgetting → Task 1; counters from the journal → Task 2. §6 UI → Tasks 3-4 (tab, tooltip, delete, dialog, notices). §7 tests → each task. Simulation → Task 5.
- Known limit recorded for the reviewer: a goal re-shared by an officer who did not create it is stored with that officer as "by" on a newcomer's side (the message carries no creator field).
