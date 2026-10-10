# LevelMates leveling block (rares, group quest progress, guild map, panic button) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rare sightings with a waypoint link, guildmates' progress on shared quests while grouped, guildmates on the world map, and a key that asks for help at once.

**Architecture:** `Rares.lua` (`rr`), `QuestProgress.lua` (`qo`) and `GuildMap.lua` (pins on the world map canvas, a busiest-zone line) follow the module pattern; the panic key is a binding calling `ns.Help.Ask`.

**Tech Stack:** Lua 5.1 (WoW Forever 1.60.x); node + fengari tests with `tools/wow-stub.lua`.

**Spec:** `docs/superpowers/specs/2026-10-10-levelmates-social-leveling-design.md` (part B)

## Global Constraints

- New kinds only (`rr`, `qo`); roster guildmates only; nothing in instances (`C.Send` refuses).
- Protected values (`issecretvalue`) are never sent or compared.
- Strings in both locale files; options default on.

## Review Focus

1. The same rare is announced at most once per 15 minutes by me, and a guildmate's sighting reaches me only in the same map (Task 1 tests).
2. Quest progress goes out only for quests shared with a grouped guildmate, only when it changes (Task 2 tests).
3. Map pins only for guildmates sharing their position and on the map being shown (Task 3 tests).
4. The panic key cannot be spammed (Task 4 tests).
5. A completed objective set is announced once per quest and guildmate (Task 2 tests).

---

### Task 1: Rare sightings

**Files:** Create `LevelMates/Rares.lua`, `tests/rares.test.lua`. Modify `Comm.lua`, `Core.lua` (`rareNotices = true`), `Settings.lua`, `LevelMates.toc` (`Rares.lua` after `Help.lua`), `tools/wow-stub.lua`, locales.

**Interfaces:** Produces `ns.Rares` with `THROTTLE`, `Seen(unit)`, `Link(map, x, y)`, `OnLink(link)`, `AddSample(name, who)`.

- [ ] **Step 1: Stub** — append to `tools/wow-stub.lua`:

```lua

-- Units (rares)
STUB.units = {}
function UnitExists(u) return STUB.units[u] ~= nil end
function UnitClassification(u) return STUB.units[u] and STUB.units[u].class or "normal" end
function UnitIsDead(u) return STUB.units[u] and STUB.units[u].dead or false end
function UnitIsPlayer(u) return STUB.units[u] and STUB.units[u].player or false end
local realUnitName = UnitName
function UnitName(u) if STUB.units[u] then return STUB.units[u].name end; return realUnitName(u) end
C_Map.GetPlayerMapPosition = function() return { GetXY = function() return STUB.pos and STUB.pos[1] or 0.5, STUB.pos and STUB.pos[2] or 0.5 end } end
```

- [ ] **Step 2: Failing test** — `tests/rares.test.lua`:

```lua
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local C, RA, R, L = ns.Comm, ns.Rares, ns.Roster, ns.L
local function last(kind) for i = #STUB.sent, 1, -1 do local k, f = C.Decode(STUB.sent[i].msg); if k == kind then return f end end end
local function count(kind, from) local n = 0; for i = (from or 0) + 1, #STUB.sent do if (C.Decode(STUB.sent[i].msg)) == kind then n = n + 1 end end; return n end
STUB.guildMembers = { Tester = true, Mario = true }
R.InvalidateGuildRoster()
STUB.Receive("LVLM", C.Encode("hb", { l = 20, z = 1412 }), "GUILD", "Mario-Testrealm")
assert(ns.db.settings.rareNotices == true, "on by default")
assert(C.Validate("rr", { n = "Mangaleta", z = 1412, x = 42.5, y = 61 }) and C.Validate("rr", { n = "Mangaleta", z = 1412 }) == false, "rr format")

-- I target a live rare: the guild hears it once in 15 minutes
STUB.player.mapId = 1412; STUB.pos = { 0.425, 0.61 }
STUB.units.target = { name = "Mangaleta", class = "rare" }
STUB.Fire("PLAYER_TARGET_CHANGED")
local f = last("rr")
assert(f and f.n == "Mangaleta" and f.z == 1412 and f.x == 42.5 and f.y == 61, "sighting sent")
local n = #STUB.sent
STUB.Fire("PLAYER_TARGET_CHANGED"); STUB.units.mouseover = STUB.units.target; STUB.Fire("UPDATE_MOUSEOVER_UNIT")
assert(count("rr", n) == 0, "not again soon")
STUB.Advance(RA.THROTTLE + 1)
STUB.Fire("PLAYER_TARGET_CHANGED")
assert(count("rr", n) == 1, "again after 15 minutes")
-- not rares, dead rares, players: nothing
n = #STUB.sent
STUB.units.target = { name = "Lobo", class = "normal" }; STUB.Fire("PLAYER_TARGET_CHANGED")
STUB.units.target = { name = "Muerto", class = "rareelite", dead = true }; STUB.Fire("PLAYER_TARGET_CHANGED")
STUB.units.target = { name = "Pepe", class = "rare", player = true }; STUB.Fire("PLAYER_TARGET_CHANGED")
assert(count("rr", n) == 0, "only live, non-player rares")
-- protected values: nothing
issecretvalue = function(v) return v == "Secreto" end
STUB.units.target = { name = "Secreto", class = "rare" }; STUB.Fire("PLAYER_TARGET_CHANGED")
assert(count("rr", n) == 0, "protected names are not sent")
issecretvalue = nil

-- a guildmate's sighting: told in the same map, with a [Waypoint] link
STUB.Receive("LVLM", C.Encode("rr", { n = "Rey Mosh", z = 1412, x = 30, y = 40 }), "GUILD", "Mario-Testrealm")
local line = STUB.printed[#STUB.printed]
assert(line:find(string.format(L.RARE_SEEN, "Mario", "Rey Mosh", "Map 1412"), 1, true) and line:find("|Haddon:LevelMates:way:1412:30.0:40.0|h", 1, true), "notice with the link")
assert(UIErrorsFrame.messages[#UIErrorsFrame.messages] == string.format(L.RARE_SEEN, "Mario", "Rey Mosh", "Map 1412"), "on screen")
local printed = #STUB.printed
STUB.Receive("LVLM", C.Encode("rr", { n = "Rey Mosh", z = 1412, x = 30, y = 40 }), "GUILD", "Mario-Testrealm")
STUB.Receive("LVLM", C.Encode("rr", { n = "Otro", z = 1421, x = 30, y = 40 }), "GUILD", "Mario-Testrealm")
STUB.Receive("LVLM", C.Encode("rr", { n = "Extraño", z = 1412, x = 30, y = 40 }), "GUILD", "Nadie-Testrealm")
assert(#STUB.printed == printed, "no repeats, other maps or strangers")
-- the link sets the waypoint
local wp
C_Map.CanSetUserWaypointOnMap = function() return true end
C_Map.SetUserWaypoint = function(p) wp = p end
UiMapPoint = { CreateFromCoordinates = function(m, x, y) return { m = m, x = x, y = y } end }
STUB.ClickLink("addon:LevelMates:way:1412:30.0:40.0")
assert(wp and wp.m == 1412 and math.abs(wp.x - 0.30) < 1e-9 and math.abs(wp.y - 0.40) < 1e-9, "waypoint set")
-- option off
ns.db.settings.rareNotices = false
STUB.Advance(400)
STUB.Receive("LVLM", C.Encode("rr", { n = "Rey Mosh", z = 1412, x = 30, y = 40 }), "GUILD", "Mario-Testrealm")
assert(#STUB.printed == printed, "option off")
```

- [ ] **Step 3: Run** — Expected: LUA ERROR at `on by default`.

- [ ] **Step 4: Implement**

`Comm.lua`: schema `rr   = { n = text(40), z = int(1, 100000), x = num(0, 100), y = num(0, 100) },`; REQUIRED `rr = { "n", "z", "x", "y" }`. `Core.lua` DEFAULTS: `rareNotices = true,` after `feedLoot = true,`. `Settings.lua`: after the `feedLoot` line `Bool(category, "rareNotices", L.OPT_RARE, L.OPT_RARE_TT)`.

`LevelMates/Rares.lua`:

```lua
-- Rares.lua: a live rare (or rare elite) I target or mouse over is announced to the guild (`rr`, my position), at
-- most once every 15 minutes per rare; guildmates in the same map get a notice with a [Waypoint] link.
-- Spec 2026-10-10-levelmates-social-leveling-design (B1).
local _, ns = ...
local RA = {}
ns.Rares = RA
local L, C, R = ns.L, ns.Comm, ns.Roster
RA.THROTTLE, RA.REPEAT = 15 * 60, 5 * 60
local RARE = { rare = true, rareelite = true }
local secret = function(v) return issecretvalue and issecretvalue(v) end
local sentAt, heardAt = {}, {}

local function myPosition()
	local mapId = C_Map.GetBestMapForUnit("player")
	if not mapId then return nil end
	local pos = C_Map.GetPlayerMapPosition(mapId, "player")
	if not pos then return nil end
	local x, y = pos:GetXY()
	return mapId, math.floor(x * 1000 + 0.5) / 10, math.floor(y * 1000 + 0.5) / 10
end

function RA.Seen(unit)
	if not UnitExists(unit) then return false end
	local class, name = UnitClassification(unit), UnitName(unit)
	if secret(class) or secret(name) or not RARE[class] or not name or UnitIsDead(unit) or UnitIsPlayer(unit) then return false end
	local now = GetTime()
	if sentAt[name] and now - sentAt[name] < RA.THROTTLE then return false end
	local mapId, x, y = myPosition()
	if not mapId or not x then return false end
	if C.Send("rr", { n = ns.CutUtf8(name, 40), z = mapId, x = x, y = y }) then sentAt[name] = now; return true end
	return false
end

function RA.Link(mapId, x, y) return string.format("|Haddon:LevelMates:way:%d:%.1f:%.1f|h|cff7ec8ff[%s]|r|h", mapId, x, y, L.WAYPOINT) end

-- The link's click: the waypoint.
function RA.OnLink(link)
	local mapId, x, y = tostring(link):match("^addon:LevelMates:way:(%d+):([%d%.]+):([%d%.]+)")
	if not mapId then return false end
	return ns.Help.WaypointTo(tonumber(mapId), tonumber(x), tonumber(y))
end
if EventRegistry and EventRegistry.RegisterCallback then
	EventRegistry:RegisterCallback("SetItemRef", function(_, link) RA.OnLink(link) end, RA)
end

local function mapName(id) local info = C_Map.GetMapInfo(id); return info and info.name or tostring(id) end

C.OnMessage("rr", function(f, name)
	if not R.mates[name] or not ns.db.settings.rareNotices then return end
	if C_Map.GetBestMapForUnit("player") ~= f.z then return end   -- only where I am
	local key, now = name .. ":" .. f.n, GetTime()
	if heardAt[key] and now - heardAt[key] < RA.REPEAT then return end
	heardAt[key] = now
	local text = string.format(L.RARE_SEEN, name, f.n, mapName(f.z))
	ns.Say("%s %s", text, RA.Link(f.z, f.x, f.y))
	ns.Screen(text)
end)

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_TARGET_CHANGED"); ev:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
ev:SetScript("OnEvent", function(_, event) RA.Seen(event == "PLAYER_TARGET_CHANGED" and "target" or "mouseover") end)
```

Locales — enUS: `L.RARE_SEEN = "%s spotted %s in %s"; L.WAYPOINT = "Waypoint"; L.OPT_RARE = "Rare sightings"; L.OPT_RARE_TT = "Tell the guild when you see a rare, and hear about the ones guildmates see where you are."`. esES: `L.RARE_SEEN = "%s ha visto a %s en %s"; L.WAYPOINT = "Ruta"; L.OPT_RARE = "Avistamiento de raros"; L.OPT_RARE_TT = "Avisa a la hermandad cuando ves un raro, y te avisa de los que ven tus hermanos donde estás."`.

- [ ] **Step 5: Run** test and `npm test`. **Step 6: Commit** — `feat(rares): rare sightings with a waypoint link`.

---

### Task 2: Group quest progress

**Files:** Create `LevelMates/QuestProgress.lua`, `tests/quest_progress.test.lua`. Modify `Comm.lua`, `Board.lua` (mates tooltip), `LevelMates.toc` (`QuestProgress.lua` after `Match.lua`), `tools/wow-stub.lua`, locales.

**Interfaces:** Produces `ns.QuestProgress` with `Objectives(id)`, `SendChanged()`, `Shared(name)` (rows `{ id, title, o }` for quests I share with that guildmate and have their progress of).

- [ ] **Step 1: Stub** — append:

```lua

-- Quest objectives
STUB.objectives = {}
C_QuestLog.GetQuestObjectives = function(id) return STUB.objectives[id] end
```

- [ ] **Step 2: Failing test** — `tests/quest_progress.test.lua`:

```lua
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local C, Q, B, R, L = ns.Comm, ns.QuestProgress, ns.Board, ns.Roster, ns.L
local function sentQo(from) local out = {}; for i = (from or 0) + 1, #STUB.sent do local k, f = C.Decode(STUB.sent[i].msg); if k == "qo" then out[#out + 1] = f end end; return out end
STUB.guildMembers = { Tester = true, Mario = true }
R.InvalidateGuildRoster()
assert(C.Validate("qo", { i = 101, o = "6/10,1/1" }) and C.Validate("qo", { i = 101, o = "6 de 10" }) == false, "qo format")

STUB.quests = { 101, 102 }
STUB.objectives[101] = { { numFulfilled = 6, numRequired = 10, finished = false }, { numFulfilled = 0, numRequired = 0, finished = true } }
STUB.objectives[102] = { { numFulfilled = 1, numRequired = 3, finished = false } }
assert(Q.Objectives(101) == "6/10,1/1", "objectives as text")
STUB.Receive("LVLM", C.Encode("hb", { l = 20, z = 1421 }), "GUILD", "Mario-Testrealm")
STUB.Receive("LVLM", C.Encode("q", { i = "1/1", ids = "101,555" }), "GUILD", "Mario-Testrealm")

-- not grouped: nothing
local n = #STUB.sent
Q.SendChanged()
assert(#sentQo(n) == 0, "only while grouped")
-- grouped with Mario: the shared quest only, once per change
STUB.partyMembers.Mario = true
Q.SendChanged()
local qo = sentQo(n)
assert(#qo == 1 and qo[1].i == 101 and qo[1].o == "6/10,1/1", "shared quest progress")
n = #STUB.sent
Q.SendChanged()
assert(#sentQo(n) == 0, "unchanged: nothing")
STUB.objectives[101][1].numFulfilled = 7
STUB.Fire("QUEST_LOG_UPDATE"); STUB.Advance(3)
assert(#sentQo(n) == 1 and sentQo(n)[1].o == "7/10,1/1", "changed: sent after the log settles")

-- Mario's progress: in his tooltip; completion told once
STUB.Receive("LVLM", C.Encode("qo", { i = 101, o = "9/10,1/1" }), "GUILD", "Mario-Testrealm")
local shared = Q.Shared("Mario")
assert(#shared == 1 and shared[1].o == "9/10,1/1" and shared[1].title == "Quest 101", "stored")
STUB.Receive("LVLM", C.Encode("qo", { i = 101, o = "10/10,1/1" }), "GUILD", "Mario-Testrealm")
STUB.Receive("LVLM", C.Encode("qo", { i = 101, o = "10/10,1/1" }), "GUILD", "Mario-Testrealm")
local told = 0
for _, p in ipairs(STUB.printed) do if p:find(string.format(L.QUEST_DONE, "Mario", "Quest 101"), 1, true) then told = told + 1 end end
assert(told == 1, "completed: told once")
STUB.Receive("LVLM", C.Encode("qo", { i = 555, o = "1/1" }), "GUILD", "Mario-Testrealm")
assert(#Q.Shared("Mario") == 1, "a quest I do not have is not shown")
STUB.Receive("LVLM", C.Encode("qo", { i = 102, o = "1/3" }), "GUILD", "Nadie-Testrealm")
B.Toggle()
local row
for i = 1, #B.rows do if B.rows[i].name.text == "Mario" then row = B.rows[i] end end
row.button.scripts.OnEnter(row.button)
local tip = table.concat(GameTooltip.lines, "\n")
assert(tip:find(L.QUEST_SHARED, 1, true) and tip:find("Quest 101: 10/10, 1/1", 1, true), "in Mario's tooltip: " .. tip)
```

- [ ] **Step 3: Run** — Expected: LUA ERROR at `qo format`.

- [ ] **Step 4: Implement**

`Comm.lua`: validator after `profs`:

```lua
-- Quest objectives "6/10,1/1": up to 60 characters of have/need pairs.
local function objectives(v) return type(v) == "string" and #v <= 60 and v:match("^%d+/%d+[%d/,]*$") ~= nil and not v:find(",,", 1, true) and v:sub(-1) ~= "," end
```
schema `qo   = { i = int(1, 999999), o = objectives },`; REQUIRED `qo = { "i", "o" }`.

`LevelMates/QuestProgress.lua`:

```lua
-- QuestProgress.lua: while grouped with guildmates, my progress on the quests we share goes out (`qo`) when it
-- changes; theirs shows in their tooltip, and a guildmate completing a shared quest is told once.
-- Spec 2026-10-10-levelmates-social-leveling-design (B2).
local _, ns = ...
local Q = {}
ns.QuestProgress = Q
local L, C, R = ns.L, ns.Comm, ns.Roster
local sent, told = {}, {}

-- "6/10,1/1": each objective as have/need (an objective without a count is 0/1 or 1/1).
function Q.Objectives(id)
	local objs = C_QuestLog.GetQuestObjectives and C_QuestLog.GetQuestObjectives(id)
	if not objs or #objs == 0 then return nil end
	local parts = {}
	for _, o in ipairs(objs) do
		local need = (o.numRequired or 0) > 0 and o.numRequired or 1
		local have = o.finished and need or math.min(need, o.numFulfilled or 0)
		parts[#parts + 1] = have .. "/" .. need
	end
	return table.concat(parts, ",")
end

-- My quests, complete ones included (the last "10/10" matters too).
local function myQuests()
	local set = {}
	for i = 1, C_QuestLog.GetNumQuestLogEntries() do
		local info = C_QuestLog.GetInfo(i)
		if info and not info.isHeader and info.questID then set[info.questID] = true end
	end
	return set
end
local function grouped(name) return UnitInParty(name) or UnitInRaid(name) end

function Q.SendChanged()
	local mine, shared = myQuests(), {}
	for name, m in pairs(R.mates) do
		if grouped(name) then for id in pairs(m.quests or {}) do if mine[id] then shared[id] = true end end end
	end
	for id in pairs(shared) do
		local o = Q.Objectives(id)
		if o and #o <= 60 and o ~= sent[id] and C.Send("qo", { i = id, o = o }) then sent[id] = o end
	end
end

local pending = false
local function soon()
	if pending then return end
	pending = true
	C_Timer.After(2, function() pending = false; Q.SendChanged() end)
end

local function complete(o)
	if not o then return false end
	for have, need in o:gmatch("(%d+)/(%d+)") do if tonumber(have) < tonumber(need) then return false end end
	return true
end

C.OnMessage("qo", function(f, name)
	local m = R.mates[name]
	if not m then return end
	m.progress = m.progress or {}
	local before = m.progress[f.i]
	m.progress[f.i] = f.o
	if complete(f.o) and not complete(before) and myQuests()[f.i] and not told[name .. ":" .. f.i] and ns.db.settings.matchNotices then
		told[name .. ":" .. f.i] = true
		ns.Notice(L.QUEST_DONE, name, C_QuestLog.GetTitleForQuestID(f.i) or ("#" .. f.i))
	end
end)

-- Rows for a guildmate's tooltip: the shared quests with their progress.
function Q.Shared(name)
	local m, out, mine = R.mates[name], {}, myQuests()
	for id, o in pairs(m and m.progress or {}) do
		if mine[id] then out[#out + 1] = { id = id, o = o, title = C_QuestLog.GetTitleForQuestID(id) or ("#" .. id) } end
	end
	table.sort(out, function(a, b) return a.title < b.title end)
	return out
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("QUEST_LOG_UPDATE"); ev:RegisterEvent("GROUP_ROSTER_UPDATE")
ev:SetScript("OnEvent", function(_, event)
	if event == "GROUP_ROSTER_UPDATE" and not IsInGroup() then wipe(sent) end   -- a new group hears everything again
	soon()
end)
ns.On("LM_MATE_QUESTS", soon)
```

`Board.lua`, row `OnEnter`, mates branch: after `if rx then lines[#lines + 1] = { string.format(L.RESTED_THEIRS, rx), 0.6, 0.8, 1 } end` add:

```lua
				local shared = ns.QuestProgress and ns.QuestProgress.Shared(self.mate) or {}
				if #shared > 0 then
					lines[#lines + 1] = { L.QUEST_SHARED, 1, 0.82, 0 }
					for _, q in ipairs(shared) do lines[#lines + 1] = { q.title .. ": " .. q.o:gsub(",", ", "), 1, 1, 1 } end
				end
```
(`q.o:gsub` returns two values; wrap it: `(q.o:gsub(",", ", "))`.)

Locales — enUS: `L.QUEST_SHARED = "Quests in common:"; L.QUEST_DONE = "%s has completed: %s"`. esES: `L.QUEST_SHARED = "Misiones en común:"; L.QUEST_DONE = "%s ya tiene completa: %s"`.

- [ ] **Step 5: Run** test and `npm test`. **Step 6: Commit** — `feat(quests): group quest progress`.

---

### Task 3: The guild on the world map

**Files:** Create `LevelMates/GuildMap.lua`, `tests/guild_map.test.lua`. Modify `Board.lua` (busiest zone next to the rested text on Guildmates), `Core.lua` (`mapPins = true`), `Settings.lua`, `LevelMates.toc` (`GuildMap.lua` after `Board.lua`), `tools/wow-stub.lua`, locales.

**Interfaces:** Produces `ns.GuildMap` with `Refresh()`, `pins`, `Busiest()` (count, mapId or nil).

- [ ] **Step 1: Stub** — append:

```lua

-- World map
STUB.worldMapId = 1412
WorldMapFrame = CreateFrame("Frame", "WorldMapFrame")
local canvas = CreateFrame("Frame"); canvas:SetSize(1000, 700)
function WorldMapFrame:GetCanvas() return canvas end
function WorldMapFrame:GetMapID() return STUB.worldMapId end
function WorldMapFrame:OnMapChanged() end
```

- [ ] **Step 2: Failing test** — `tests/guild_map.test.lua`:

```lua
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local C, GM, B, R, L = ns.Comm, ns.GuildMap, ns.Board, ns.Roster, ns.L
STUB.guildMembers = { Tester = true, Mario = true, Ana = true, Luis = true }
R.InvalidateGuildRoster()
STUB.Receive("LVLM", C.Encode("hb", { l = 30, z = 1412, c = "MAGE", x = 40, y = 50 }), "GUILD", "Mario-Testrealm")
STUB.Receive("LVLM", C.Encode("hb", { l = 20, z = 1412 }), "GUILD", "Ana-Testrealm")             -- no position shared
STUB.Receive("LVLM", C.Encode("hb", { l = 25, z = 1421, x = 10, y = 10 }), "GUILD", "Luis-Testrealm")
assert(ns.db.settings.mapPins == true, "on by default")

-- pins: guildmates sharing their position, on the map shown
WorldMapFrame:Show(); WorldMapFrame:OnMapChanged()
local shown = {}
for _, p in ipairs(GM.pins) do if p:IsShown() then shown[#shown + 1] = p end end
assert(#shown == 1 and shown[1].mate == "Mario", "Mario only")
local pt = shown[1].point
assert(pt[1] == "CENTER" and pt[3] == "TOPLEFT" and pt[4] == 400 and pt[5] == -350, "at his position")
shown[1].scripts.OnEnter(shown[1])
assert(GameTooltip.lines[1]:find("Mario", 1, true) and GameTooltip.lines[1]:find("30", 1, true), "name and level on hover")
STUB.worldMapId = 1421; WorldMapFrame:OnMapChanged()
shown = {}
for _, p in ipairs(GM.pins) do if p:IsShown() then shown[#shown + 1] = p end end
assert(#shown == 1 and shown[1].mate == "Luis", "another map, another guildmate")
ns.db.settings.mapPins = false; GM.Refresh()
for _, p in ipairs(GM.pins) do assert(not p:IsShown(), "option off: no pins") end
ns.db.settings.mapPins = true

-- the busiest zone on the Guildmates tab
local n, mapId = GM.Busiest()
assert(n == 3 and mapId == 1412, "Mario, Ana and me in 1412: " .. tostring(n))
B.ShowTab("mates")
assert(B.restedText.text:find(string.format(L.ZONE_BUSY, 3, "Map 1412"), 1, true), "shown by the heading: " .. tostring(B.restedText.text))
B.ShowTab("goals")
assert(not B.restedText.text:find(string.format(L.ZONE_BUSY, 3, "Map 1412"), 1, true), "only on Guildmates")
```

- [ ] **Step 3: Run** — Expected: LUA ERROR at `on by default`.

- [ ] **Step 4: Implement**

`Core.lua` DEFAULTS: `mapPins = true,` after `rareNotices = true,`. `Settings.lua`: after the `rareNotices` line `Bool(category, "mapPins", L.OPT_MAP, L.OPT_MAP_TT, function() ns.GuildMap.Refresh() end)`.

`LevelMates/GuildMap.lua`:

```lua
-- GuildMap.lua: guildmates who share their position, as class-icon pins on the world map being shown, and the
-- busiest zone for the Guildmates tab. Spec 2026-10-10-levelmates-social-leveling-design (B3).
local _, ns = ...
local GM = {}
ns.GuildMap = GM
local L, R = ns.L, ns.Roster
GM.pins = {}
local SIZE = 16

local function pin(i)
	local p = GM.pins[i]
	if p then return p end
	p = CreateFrame("Button", nil, WorldMapFrame:GetCanvas())
	p:SetSize(SIZE, SIZE); p:SetFrameStrata("HIGH")
	p.icon = p:CreateTexture(nil, "OVERLAY"); p.icon:SetAllPoints()
	p:SetScript("OnEnter", function(self)
		local m = R.mates[self.mate]
		if not (GameTooltip and m) then return end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:AddLine(string.format("%s (%d)", self.mate, m.level or 0), 1, 1, 1)
		GameTooltip:Show()
	end)
	p:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
	GM.pins[i] = p
	return p
end

local function classIcon(tex, class)
	local atlas = class and ("classicon-" .. class:lower())
	if atlas and C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(atlas) then tex:SetAtlas(atlas) return end
	tex:SetTexture("Interface\\Minimap\\PartyRaidBlips"); tex:SetTexCoord(0.875, 1, 0.25, 0.5)   -- a plain dot
end

function GM.Refresh()
	if not WorldMapFrame or not WorldMapFrame.GetCanvas then return end
	local canvas, mapId, i = WorldMapFrame:GetCanvas(), WorldMapFrame:GetMapID(), 0
	if ns.db.settings.mapPins and WorldMapFrame:IsShown() then
		for name, m in pairs(R.mates) do
			if m.mapId == mapId and m.x and m.y then
				i = i + 1
				local p = pin(i)
				p.mate = name
				classIcon(p.icon, m.class)
				p:ClearAllPoints()
				p:SetPoint("CENTER", canvas, "TOPLEFT", canvas:GetWidth() * m.x / 100, -canvas:GetHeight() * m.y / 100)
				p:Show()
			end
		end
	end
	for j = i + 1, #GM.pins do GM.pins[j]:Hide() end
end

-- The zone with most guildmates online (me included), when two or more share it.
function GM.Busiest()
	local counts = {}
	local mine = C_Map.GetBestMapForUnit("player")
	if mine then counts[mine] = 1 end
	for _, m in pairs(R.mates) do if m.mapId and m.mapId > 0 then counts[m.mapId] = (counts[m.mapId] or 0) + 1 end end
	local best, bestN = nil, 1
	for id, n in pairs(counts) do if n > bestN or (n == bestN and best and id < best) then best, bestN = id, n end end
	return best and bestN or 0, best
end

local hooked = false
local function hook()
	if hooked or not WorldMapFrame or not WorldMapFrame.OnMapChanged then return end
	hooked = true
	hooksecurefunc(WorldMapFrame, "OnMapChanged", GM.Refresh)
	WorldMapFrame:HookScript("OnShow", GM.Refresh)
end
ns.On("LM_WORLD", hook)
ns.On("LM_ROSTER_CHANGED", function() if WorldMapFrame and WorldMapFrame:IsShown() then GM.Refresh() end end)
local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:SetScript("OnEvent", function(_, _, name) if name == "Blizzard_WorldMap" then hook() end end)
```

`Board.lua`, in `B.Refresh`, replace `	B.restedText:SetText(rested and string.format(L.RESTED_MINE, rested) or "")` with:

```lua
	local top = rested and string.format(L.RESTED_MINE, rested) or ""
	if B.tab == "mates" and ns.GuildMap then
		local n, mapId = ns.GuildMap.Busiest()
		if mapId then
			local info = C_Map.GetMapInfo(mapId)
			top = top .. (top ~= "" and "  ·  " or "") .. string.format(L.ZONE_BUSY, n, info and info.name or tostring(mapId))
		end
	end
	B.restedText:SetText(top)
```

Locales — enUS: `L.ZONE_BUSY = "%d guildmates in %s"; L.OPT_MAP = "Guildmates on the map"; L.OPT_MAP_TT = "Guildmates who share their position appear on the world map."`. esES: `L.ZONE_BUSY = "%d hermanos en %s"; L.OPT_MAP = "Hermanos en el mapa"; L.OPT_MAP_TT = "Los hermanos que comparten su posición salen en el mapa del mundo."`.

- [ ] **Step 5: Run** test and `npm test`. **Step 6: Commit** — `feat(map): guildmates on the world map and the busiest zone`.

---

### Task 4: Panic key, simulation and documentation

**Files:** Modify `Bindings.xml`, `Help.lua`, `Sim.lua`, `README.md`, `CHANGELOG.md`, locales; create `tests/panic.test.lua`.

**Interfaces:** Produces global `LevelMates_Panic()`, `ns.Help.Panic()`, `ns.Help.PANIC_GAP`; slash `/lm panico`; `/lm sim raro`.

- [ ] **Step 1: Failing test** — `tests/panic.test.lua`:

```lua
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local C, H, L = ns.Comm, ns.Help, ns.L
local function count(from) local n = 0; for i = from + 1, #STUB.sent do if (C.Decode(STUB.sent[i].msg)) == "help" then n = n + 1 end end; return n end
local n = #STUB.sent
LevelMates_Panic()
local _, f = C.Decode(STUB.sent[#STUB.sent].msg)
assert(count(n) == 1 and f.t == L.PANIC_TEXT, "help asked at once")
LevelMates_Panic()
assert(count(n) == 1 and STUB.printed[#STUB.printed]:find(L.PANIC_WAIT, 1, true), "not twice in 30 s")
STUB.Advance(H.PANIC_GAP + 1)
SlashCmdList["LEVELMATES"]("panico")
assert(count(n) == 2, "again later, also by slash")
assert(BINDING_NAME_LEVELMATES_PANIC == L.BINDING_PANIC, "the key binding has a name")
-- simulation
local before = #STUB.printed
SlashCmdList["LEVELMATES"]("sim raro")
assert(#STUB.printed > before and STUB.printed[#STUB.printed]:find("|Haddon:LevelMates:way:", 1, true), "sim raro: a sighting notice with its link")
```

- [ ] **Step 2: Run** — Expected: LUA ERROR (`LevelMates_Panic` is nil).

- [ ] **Step 3: Implement**

`Bindings.xml`: add before `</Bindings>`:

```xml
	<Binding name="LEVELMATES_PANIC" category="LevelMates">
		LevelMates_Panic()
	</Binding>
```

`Help.lua`, at the end:

```lua

-- The panic key: a help request at once with a fixed text, at most every 30 seconds.
H.PANIC_GAP = 30
local lastPanic = -math.huge
function H.Panic()
	if GetTime() - lastPanic < H.PANIC_GAP then ns.Say(L.PANIC_WAIT); return false end
	if H.Ask(L.PANIC_TEXT) then lastPanic = GetTime(); return true end
	return false
end
function LevelMates_Panic() H.Panic() end
BINDING_NAME_LEVELMATES_PANIC = L.BINDING_PANIC
ns.Slash("panico", H.Panic); ns.Slash("panic", H.Panic)
```

`Sim.lua`: after `simMeetups`:

```lua
local function simRare()
	if not R.mates.Mario then run() end
	local map = C_Map.GetBestMapForUnit("player") or 1
	inject("rr", { n = "Mangaleta", z = map, x = 42.5, y = 61.0 }, "Mario")
end
```
slash: `	elseif rest == "raro" or rest == "rare" then simRare()` after the `quedada` branch.

Locales — enUS: `L.PANIC_TEXT = "Help! I'm being killed"; L.PANIC_WAIT = "Help already asked; wait a few seconds."; L.BINDING_PANIC = "Ask for help now"`. esES: `L.PANIC_TEXT = "¡Ayuda! Me están matando"; L.PANIC_WAIT = "Ya has pedido ayuda; espera unos segundos."; L.BINDING_PANIC = "Pedir ayuda ya"`.

README (both languages) and CHANGELOG: rare sightings with [Waypoint], group quest progress in tooltips, guildmates on the world map and the busiest zone, the panic key (Key Bindings → LevelMates, or `/lm panico`), `/lm sim raro`; new kinds `rr`, `qo`.

- [ ] **Step 4: Run** test and `npm test`. **Step 5: Commit** — `feat: panic key, leveling block simulation and docs`.
