# LevelMates: Journal Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. Every task also REQUIRES the `wow-forever-addons` skill (API facts, tools, policy).

**Goal:** A local, per-character journal of the leveling journey — level-ups (with time per level), quests turned in, dungeons (with the guildmates in the group), groups with guildmates, uncommon-or-better items, profession milestones and deaths — shown in a third "Journal" tab of the board.

**Architecture:** `Journal.lua` owns the entries in `ns.char.journal` (oldest first, capped at 1000), the seven recorders (game events), text/colour/duration formatting and the list/filter/search; it never sends anything. `Board.lua` gains a third tab that reuses the row frames with its own column widths, a type filter (game context menu), a pager in the help-rows area, a "Clear journal" button with a confirmation popup, and the item tooltip on hover. The board grows from 560 to 600 wide so three tab buttons fit in the bottom bar.

**Tech Stack:** Lua 5.1 (WoW Forever client, interface 16001), the repo's fengari harness (`node tools/run-lua-test.mjs LevelMates tests/<name>.test.lua`), `npm test`.

**Spec:** `docs/superpowers/specs/2026-10-09-levelmates-journal-design.md`

## Global Constraints

- The journal is local: no addon message, no chat. Entries live in `ns.char.journal` (per character).
- Every entry has `k` (kind), `t` (`time()`), `zone` (`GetRealZoneText()`) and its kind's fields. Kinds: `level`, `quest`, `dungeon`, `group`, `item`, `skill`, `death`.
- At most 1000 entries per character; adding the 1001st drops the oldest.
- Items: only mine (`guid` of `CHAT_MSG_LOOT` = `UnitGUID("player")`; if the guid is empty, the short sender name = my name), only quality ≥ 2 (uncommon). Quality from `C_Item.GetItemQualityByID(link)` when available, otherwise from the link colour.
- Dungeon: an instance of type `party`; once per entry into it (a loading screen or `/reload` inside does not add another; the current instance key is kept in `ns.char.journalInstance`).
- Group: once per guildmate (roster name) per session.
- Professions: only the twelve profession skill IDs (171, 164, 333, 202, 182, 165, 186, 393, 197, 129, 185, 356); the first time skills are readable for a character only a snapshot is taken (`ns.char.skills`), no entries; then "learned" and every new multiple of 25.
- Board width 600; three tabs of 80 at the bottom centre; journal controls: "Clear journal" bottom-left, type filter bottom-right, pager in the help-rows area.
- Every visible string through `L` (enUS, esES). `npm test` green after every task.

## Review Focus

1. Someone else's loot, or a grey item, must never enter the journal; a green item with an unloaded item cache still must (Task 2 tests: other guid, grey, colour fallback).
2. Skills not yet loaded at login must not turn every existing profession into a "learned" entry later (Task 2 test: no snapshot while `GetNumSkillLines()` is 0; first readable sight is a snapshot only).
3. Dungeons: loading screens and `/reload` inside the same instance add nothing; leaving and entering again adds one (Task 2 test).
4. The cap: 1000 entries, oldest dropped, newest kept (Task 1 test).
5. Nothing leaves the client (Task 1 test inspects every message sent during the journal tests).

---

## File Structure

| File | Responsibility |
|---|---|
| `LevelMates/Journal.lua` (new) | Storage, recorders, formatting, list/filter/search, clear popup. No network. |
| `LevelMates/Board.lua` (modify) | Width 600, third tab, per-tab columns, journal rows, pager, filter, clear button, item tooltip, `/lm diario`. |
| `LevelMates/Locales/*.lua`, `LevelMates.toc` (modify) | Strings; `Journal.lua` after `Rested.lua`. |
| `LevelMates/Sim.lua`, `README.md`, `CHANGELOG.md` (modify) | `/lm sim diario`; docs. |
| `tools/wow-stub.lua` (modify) | `time()`, `UnitGUID`, `GetInstanceInfo`, `C_SkillInfo`, `GameTooltip:SetHyperlink`. |

---

### Task 1: Journal core, level, quest and death

**Files:**
- Create: `LevelMates/Journal.lua`, `tests/journal.test.lua`
- Modify: `LevelMates/Locales/enUS.lua`, `LevelMates/Locales/esES.lua`, `LevelMates/LevelMates.toc`, `tools/wow-stub.lua`

**Interfaces:**
- Produces: `ns.Journal.KINDS`, `ns.Journal.FILTERS` (`"all"` + kinds), `Add(kind, data) -> entry`, `Count()`, `List(filter, search) -> entries newest first`, `Text(entry)`, `Color(entry) -> {r,g,b}`, `When(entry)`, `Duration(seconds)`, `FilterName(kind)`, `Clear()`, `RemoveWhere(fn)`; event `LM_JOURNAL_CHANGED`.

- [ ] **Step 1: Write the failing test**

In `tools/wow-stub.lua` append:

```lua
-- Journal support
function time() return 1760000000 + math.floor(STUB.now) end
function UnitGUID(u) return "Player-1-TESTER" end
function GetInstanceInfo() return STUB.instanceName or "Mulgore", STUB.inInstance and "party" or "none", 0, "", 5, 0, false, STUB.instanceId or 0 end
C_SkillInfo = {
	GetNumSkillLines = function() return STUB.skills and #STUB.skills or 0 end,
	GetSkillLineInfo = function(i) return STUB.skills and STUB.skills[i] end,
}
```

`tests/journal.test.lua`:

```lua
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local J, L = ns.Journal, ns.L
local sent0 = #STUB.sent
assert(type(ns.char.journal) == "table" and J.Count() == 0, "empty journal per character")

-- level-ups with the time since the previous one
STUB.player.level = 21; STUB.Fire("PLAYER_LEVEL_UP", 21)
local e = J.List("all", "")[1]
assert(e.k == "level" and e.level == 21 and e.took == nil and e.zone == STUB.player.zone, "first level entry")
STUB.Advance(2 * 3600 + 600)
STUB.player.level = 22; STUB.Fire("PLAYER_LEVEL_UP", 22)
e = J.List("all", "")[1]
assert(e.level == 22 and e.took == 2 * 3600 + 600, "time since the previous level: " .. tostring(e.took))
assert(J.Text(e) == string.format(L.J_LEVEL, 22) .. string.format(L.J_TOOK, string.format(L.J_DUR_HM, 2, 10), 21), "text: " .. J.Text(e))

-- quest and death
STUB.Fire("QUEST_TURNED_IN", 1098, 450, 0)
e = J.List("all", "")[1]
assert(e.k == "quest" and e.name == "Quest 1098" and J.Text(e) == string.format(L.J_QUEST, "Quest 1098"), "quest entry")
STUB.Fire("PLAYER_DEAD")
e = J.List("all", "")[1]
assert(e.k == "death" and e.level == 22 and J.Text(e) == string.format(L.J_DEATH, 22), "death entry")

-- filter and search; formatting helpers
assert(#J.List("level", "") == 2 and #J.List("quest", "") == 1 and #J.List("death", "") == 1, "filter by kind")
assert(#J.List("all", "1098") == 1 and #J.List("all", "zzz") == 0, "search the text")
assert(J.Duration(30) == L.J_DUR_LT and J.Duration(35 * 60) == string.format(L.J_DUR_M, 35), "durations")
assert(J.FilterName("all") == L.J_FILTER_ALL and J.FilterName("quest") == L.J_FILTER_QUEST, "filter names")
assert(type(J.Color(e)) == "table" and J.When(e) == date("%d/%m %H:%M", e.t), "colour and date")

-- cap of 1000, oldest dropped
for i = 1, 1005 do J.Add("quest", { id = i, name = "Q" .. i }) end
assert(J.Count() == 1000, "capped at 1000: " .. J.Count())
local all = J.List("all", "")
assert(all[1].name == "Q1005" and all[1000].name == "Q6", "oldest dropped: " .. tostring(all[1000].name))

-- remove some, then clear
J.RemoveWhere(function(x) return x.id and x.id <= 10 end)
assert(J.Count() == 995, "RemoveWhere: " .. J.Count())
J.Clear()
assert(J.Count() == 0, "cleared")

-- the journal never sends anything
for i = sent0 + 1, #STUB.sent do
	local k = ns.Comm.Decode(STUB.sent[i].msg)
	assert(k == "hb" or k == "q" or k == "ping", "only the roster's own messages went out, got " .. tostring(k))
end
```

- [ ] **Step 2: Run the test to see it fail**

Run: `node tools/run-lua-test.mjs LevelMates tests/journal.test.lua` — Expected: LUA ERROR (`ns.Journal` / `J` is nil).

- [ ] **Step 3: Implement**

`LevelMates/Locales/enUS.lua` append:

```lua
L.J_LEVEL = "Level %d reached"; L.J_TOOK = " (%s since level %d)"
L.J_DUR_HM = "%d h %d min"; L.J_DUR_M = "%d min"; L.J_DUR_LT = "<1 min"
L.J_QUEST = "Quest completed: %s"; L.J_DUNGEON = "Dungeon: %s"; L.J_WITH = " with %s"; L.J_GROUP = "Grouped with %s"
L.J_ITEM = "Got %s"; L.J_SKILL_NEW = "Learned %s"; L.J_SKILL_UP = "%s reached %d"; L.J_DEATH = "Died at level %d"
L.J_FILTER_ALL = "All"; L.J_FILTER_LEVEL = "Levels"; L.J_FILTER_QUEST = "Quests"; L.J_FILTER_DUNGEON = "Dungeons"
L.J_FILTER_GROUP = "Groups"; L.J_FILTER_ITEM = "Items"; L.J_FILTER_SKILL = "Professions"; L.J_FILTER_DEATH = "Deaths"
```

`LevelMates/Locales/esES.lua` append:

```lua
L.J_LEVEL = "Nivel %d alcanzado"; L.J_TOOK = " (%s desde el nivel %d)"
L.J_DUR_HM = "%d h %d min"; L.J_DUR_M = "%d min"; L.J_DUR_LT = "<1 min"
L.J_QUEST = "Misión completada: %s"; L.J_DUNGEON = "Mazmorra: %s"; L.J_WITH = " con %s"; L.J_GROUP = "En grupo con %s"
L.J_ITEM = "Conseguido: %s"; L.J_SKILL_NEW = "Aprendida: %s"; L.J_SKILL_UP = "%s llega a %d"; L.J_DEATH = "Muerte a nivel %d"
L.J_FILTER_ALL = "Todo"; L.J_FILTER_LEVEL = "Niveles"; L.J_FILTER_QUEST = "Misiones"; L.J_FILTER_DUNGEON = "Mazmorras"
L.J_FILTER_GROUP = "Grupos"; L.J_FILTER_ITEM = "Objetos"; L.J_FILTER_SKILL = "Profesiones"; L.J_FILTER_DEATH = "Muertes"
```

`LevelMates/LevelMates.toc`: add `Journal.lua` right after `Rested.lua`.

Create `LevelMates/Journal.lua`:

```lua
-- Journal.lua: a local, per-character record of the leveling journey. Never sends anything.
-- Spec 2026-10-09-levelmates-journal-design.
local _, ns = ...
local J = {}
ns.Journal = J
local L, R = ns.L, ns.Roster
J.KINDS = { "level", "quest", "dungeon", "group", "item", "skill", "death" }
J.FILTERS = { "all", "level", "quest", "dungeon", "group", "item", "skill", "death" }
J.MAX = 1000
local COLORS = {
	level = { 1, 0.82, 0 }, quest = { 1, 1, 1 }, dungeon = { 0.6, 0.8, 1 }, group = { 0.4, 1, 0.4 },
	item = { 1, 1, 1 }, skill = { 1, 0.7, 0.3 }, death = { 1, 0.4, 0.4 },
}

local function entries()
	ns.char.journal = ns.char.journal or {}
	return ns.char.journal
end

function J.Add(kind, data)
	local e = { k = kind, t = time(), zone = GetRealZoneText() }
	for key, value in pairs(data or {}) do e[key] = value end
	local list = entries()
	list[#list + 1] = e
	while #list > J.MAX do table.remove(list, 1) end   -- oldest first: drop from the front
	ns.Fire("LM_JOURNAL_CHANGED")
	return e
end

function J.Count() return #entries() end

function J.Clear() wipe(entries()); ns.Fire("LM_JOURNAL_CHANGED") end

function J.RemoveWhere(fn)
	local list = entries()
	for i = #list, 1, -1 do if fn(list[i]) then table.remove(list, i) end end
	ns.Fire("LM_JOURNAL_CHANGED")
end

function J.Duration(sec)
	if sec < 60 then return L.J_DUR_LT end
	local h, m = math.floor(sec / 3600), math.floor(sec % 3600 / 60)
	if h > 0 then return string.format(L.J_DUR_HM, h, m) end
	return string.format(L.J_DUR_M, m)
end

function J.Text(e)
	if e.k == "level" then
		return string.format(L.J_LEVEL, e.level) .. (e.took and string.format(L.J_TOOK, J.Duration(e.took), e.level - 1) or "")
	elseif e.k == "quest" then return string.format(L.J_QUEST, e.name)
	elseif e.k == "dungeon" then
		return string.format(L.J_DUNGEON, e.name) .. ((e.mates and #e.mates > 0) and string.format(L.J_WITH, table.concat(e.mates, ", ")) or "")
	elseif e.k == "group" then return string.format(L.J_GROUP, e.name)
	elseif e.k == "item" then return string.format(L.J_ITEM, e.link)
	elseif e.k == "skill" then
		if e.learned then return string.format(L.J_SKILL_NEW, e.name) end
		return string.format(L.J_SKILL_UP, e.name, e.rank)
	elseif e.k == "death" then return string.format(L.J_DEATH, e.level)
	end
	return ""
end

function J.Color(e) return COLORS[e.k] or { 1, 1, 1 } end
function J.When(e) return date("%d/%m %H:%M", e.t) end
function J.FilterName(kind) return L["J_FILTER_" .. string.upper(kind)] end

-- Newest first; filter by kind ("all" for every kind) and by plain text in the entry or its zone.
function J.List(filter, search)
	local out, q = {}, (search or ""):lower()
	local list = entries()
	for i = #list, 1, -1 do
		local e = list[i]
		if (filter == nil or filter == "all" or e.k == filter)
			and (q == "" or (J.Text(e) .. " " .. (e.zone or "")):lower():find(q, 1, true)) then
			out[#out + 1] = e
		end
	end
	return out
end

-- Recorders: level, quest, death.
local function lastLevelEntry()
	local list = entries()
	for i = #list, 1, -1 do if list[i].k == "level" then return list[i] end end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LEVEL_UP"); ev:RegisterEvent("QUEST_TURNED_IN"); ev:RegisterEvent("PLAYER_DEAD")
ev:SetScript("OnEvent", function(_, event, a1)
	if event == "PLAYER_LEVEL_UP" then
		local prev = lastLevelEntry()
		J.Add("level", { level = a1, took = prev and (time() - prev.t) or nil })
	elseif event == "QUEST_TURNED_IN" then
		J.Add("quest", { id = a1, name = C_QuestLog.GetTitleForQuestID(a1) or ("#" .. tostring(a1)) })
	elseif event == "PLAYER_DEAD" then
		J.Add("death", { level = UnitLevel("player") })
	end
end)

ns.On("LM_LOADED", function() entries() end)
```

- [ ] **Step 4: Run the test and the whole suite**

Run: `node tools/run-lua-test.mjs LevelMates tests/journal.test.lua` — Expected: `ok`. Run: `npm test` — Expected: all `ok`.

- [ ] **Step 5: Commit**

```bash
git add LevelMates/Journal.lua LevelMates/Locales/enUS.lua LevelMates/Locales/esES.lua LevelMates/LevelMates.toc tools/wow-stub.lua tests/journal.test.lua
git commit -m "feat(journal): storage, cap, list/filter/search, level, quest and death"
```

---

### Task 2: Dungeon, group, item and profession recorders

**Files:**
- Modify: `LevelMates/Journal.lua`
- Create: `tests/journal_events.test.lua`

**Interfaces:**
- Consumes: `ns.Roster.mates`, `ns.ShortName`, `IsInInstance`, `GetInstanceInfo`, `UnitInParty/UnitInRaid`, `UnitGUID`, `C_Item.GetItemQualityByID` (optional), `C_SkillInfo.GetNumSkillLines/GetSkillLineInfo`, event `LM_WORLD`.
- Produces: entries of kinds `dungeon` (`name`, `mates`), `group` (`name`), `item` (`link`, `q`), `skill` (`name`, `rank` or `learned`); `ns.char.journalInstance`, `ns.char.skills`.

- [ ] **Step 1: Write the failing test**

`tests/journal_events.test.lua`:

```lua
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local C, J = ns.Comm, ns.Journal
local function mate(name) STUB.Receive("LVLM", C.Encode("hb", { l = 20, z = 1421 }), "GUILD", name .. "-Testrealm") end
local function first() return J.List("all", "")[1] end
mate("Mario"); mate("Ana")

-- group: once per guildmate per session; strangers are not guildmates
STUB.partyMembers = { Mario = true }
STUB.Fire("GROUP_ROSTER_UPDATE")
assert(first() and first().k == "group" and first().name == "Mario", "grouped with Mario")
local n = J.Count()
STUB.Fire("GROUP_ROSTER_UPDATE")
assert(J.Count() == n, "not twice")
STUB.partyMembers = { Mario = true, Ana = true, Stranger = true }
STUB.Fire("GROUP_ROSTER_UPDATE")
assert(J.Count() == n + 1 and first().name == "Ana", "Ana added; the stranger is not a guildmate")

-- dungeon: once per entry, with the guildmates in the group
STUB.inInstance = true; STUB.instanceName = "Ragefire Chasm"; STUB.instanceId = 389
STUB.Fire("PLAYER_ENTERING_WORLD", false, false); STUB.Advance(1)
local d = first()
assert(d.k == "dungeon" and d.name == "Ragefire Chasm" and table.concat(d.mates, ",") == "Ana,Mario", "dungeon with guildmates: " .. tostring(d.name))
n = J.Count()
STUB.Fire("PLAYER_ENTERING_WORLD", false, false); STUB.Fire("ZONE_CHANGED_NEW_AREA"); STUB.Advance(1)
assert(J.Count() == n, "another loading screen inside is not a new entry")
STUB.Fire("PLAYER_ENTERING_WORLD", false, true); STUB.Advance(1)
assert(J.Count() == n, "nor a /reload inside")
STUB.inInstance = false; STUB.Fire("ZONE_CHANGED_NEW_AREA"); STUB.Advance(1)
STUB.inInstance = true; STUB.Fire("ZONE_CHANGED_NEW_AREA"); STUB.Advance(1)
assert(J.Count() == n + 1, "going in again is a new entry")
STUB.inInstance = false; STUB.Fire("ZONE_CHANGED_NEW_AREA"); STUB.Advance(1)
STUB.partyMembers = {}

-- loot: mine only, uncommon or better
local me = UnitGUID("player")
local green = "|cff1eff00|Hitem:2589::::::::20:::::::|h[Linen Cloth]|h|r"
local grey = "|cff9d9d9d|Hitem:117::::::::20:::::::|h[Tough Jerky]|h|r"
local function loot(text, guid, who) STUB.Fire("CHAT_MSG_LOOT", text, who or "Tester", "", "", who or "Tester", "", 0, 0, "", 0, 1, guid) end
n = J.Count()
loot("You receive loot: " .. green .. ".", me)
assert(J.Count() == n + 1 and first().k == "item" and first().link == green and first().q == 2, "green item recorded (quality from the colour)")
loot("You receive loot: " .. grey .. ".", me)
assert(J.Count() == n + 1, "grey ignored")
loot("Mario receives loot: " .. green .. ".", "Player-1-OTHER", "Mario")
assert(J.Count() == n + 1, "someone else's loot ignored")
loot("You receive loot: " .. green .. ".", "", "Tester")
assert(J.Count() == n + 2, "empty guid: the sender name decides")
C_Item = { GetItemQualityByID = function() return 4 end }
loot("You receive loot: " .. grey .. ".", me)
assert(J.Count() == n + 3 and first().q == 4, "quality from the item info when the client has it")
C_Item = nil
loot("You receive loot: nothing to link here.", me)
assert(J.Count() == n + 3, "no item link, no entry")

-- professions: no snapshot while skills are not loaded; the first readable sight is a snapshot only
STUB.skills = nil
STUB.Fire("SKILL_LINES_CHANGED")
assert(ns.char.skills == nil, "no snapshot while nothing is readable")
n = J.Count()
STUB.skills = {
	{ skillID = 182, name = "Herbalism", rank = 40, isHeader = false },
	{ skillID = 98, name = "Language: Orcish", rank = 300, isHeader = false },
}
STUB.Fire("SKILL_LINES_CHANGED")
assert(ns.char.skills and ns.char.skills[182] and ns.char.skills[182].rank == 40 and J.Count() == n, "first sight: snapshot only")
STUB.skills[1].rank = 49; STUB.Fire("SKILL_LINES_CHANGED")
assert(J.Count() == n, "40 to 49: no new multiple of 25")
STUB.skills[1].rank = 50; STUB.Fire("SKILL_LINES_CHANGED")
assert(J.Count() == n + 1 and first().k == "skill" and first().rank == 50 and first().name == "Herbalism", "reached 50")
STUB.skills[2].rank = 301; STUB.Fire("SKILL_LINES_CHANGED")
assert(J.Count() == n + 1, "languages are not professions")
table.insert(STUB.skills, { skillID = 186, name = "Mining", rank = 1, isHeader = false })
STUB.Fire("SKILL_LINES_CHANGED")
assert(J.Count() == n + 2 and first().learned and first().name == "Mining", "learned Mining")
```

- [ ] **Step 2: Run the test to see it fail**

Run: `node tools/run-lua-test.mjs LevelMates tests/journal_events.test.lua` — Expected: LUA ERROR at `grouped with Mario`.

- [ ] **Step 3: Implement** — append to `LevelMates/Journal.lua`:

```lua

-- Recorders: groups with guildmates (once per person per session).
local grouped = {}
local function inMyGroup(name) return UnitInParty(name) or UnitInRaid(name) end
local function guildmatesInGroup()
	local out = {}
	for name in pairs(R.mates) do if inMyGroup(name) then out[#out + 1] = name end end
	table.sort(out)
	return out
end

-- Dungeons: once per entry into a party instance; the key survives loading screens and /reload.
local function checkInstance()
	local inside, itype = IsInInstance()
	if inside and itype == "party" then
		local name, _, _, _, _, _, _, id = GetInstanceInfo()
		local key = tostring(id and id ~= 0 and id or name)
		if ns.char.journalInstance ~= key then
			ns.char.journalInstance = key
			J.Add("dungeon", { name = name, mates = guildmatesInGroup() })
		end
	elseif not inside then
		ns.char.journalInstance = nil
	end
end

-- Items: mine only (guid, or the sender name when the guid is empty), uncommon or better.
local COLOR_QUALITY = { ["9d9d9d"] = 0, ["ffffff"] = 1, ["1eff00"] = 2, ["0070dd"] = 3, ["a335ee"] = 4, ["ff8000"] = 5, ["e6cc80"] = 6 }
local function quality(link)
	local q = C_Item and C_Item.GetItemQualityByID and C_Item.GetItemQualityByID(link)
	if q then return q end
	local hex = link:match("^|c%x%x(%x%x%x%x%x%x)")
	return hex and COLOR_QUALITY[hex:lower()]
end
local function isMine(guid, sender)
	if guid and guid ~= "" then return guid == UnitGUID("player") end
	return sender ~= nil and sender ~= "" and ns.ShortName(sender) == UnitName("player")
end

-- Professions: the twelve profession skill IDs (locale-independent).
local PROFESSIONS = { [171] = true, [164] = true, [333] = true, [202] = true, [182] = true, [165] = true,
	[186] = true, [393] = true, [197] = true, [129] = true, [185] = true, [356] = true }
local function readProfessions()
	local n = C_SkillInfo and C_SkillInfo.GetNumSkillLines() or 0
	if n == 0 then return nil end   -- not loaded yet
	local out = {}
	for i = 1, n do
		local s = C_SkillInfo.GetSkillLineInfo(i)
		if s and not s.isHeader and PROFESSIONS[s.skillID] then out[s.skillID] = { name = s.name, rank = s.rank } end
	end
	return out
end
local function checkSkills()
	local now = readProfessions()
	if not now then return end
	local before = ns.char.skills
	ns.char.skills = now
	if not before then return end   -- first readable sight: snapshot only
	for id, s in pairs(now) do
		local old = before[id]
		if not old then
			J.Add("skill", { name = s.name, learned = true, rank = s.rank })
		elseif math.floor(s.rank / 25) > math.floor(old.rank / 25) then
			J.Add("skill", { name = s.name, rank = math.floor(s.rank / 25) * 25 })
		end
	end
end

local ev2 = CreateFrame("Frame")
ev2:RegisterEvent("GROUP_ROSTER_UPDATE"); ev2:RegisterEvent("ZONE_CHANGED_NEW_AREA")
ev2:RegisterEvent("CHAT_MSG_LOOT"); ev2:RegisterEvent("SKILL_LINES_CHANGED")
ev2:SetScript("OnEvent", function(_, event, ...)
	if event == "GROUP_ROSTER_UPDATE" then
		for _, name in ipairs(guildmatesInGroup()) do
			if not grouped[name] then grouped[name] = true; J.Add("group", { name = name }) end
		end
	elseif event == "ZONE_CHANGED_NEW_AREA" then
		checkInstance()
	elseif event == "CHAT_MSG_LOOT" then
		local text, sender = ...
		local guid = select(12, ...)
		if type(text) ~= "string" or not isMine(guid, sender) then return end
		local link = text:match("|c%x+|Hitem:.-|h.-|h|r")
		local q = link and quality(link)
		if q and q >= 2 then J.Add("item", { link = link, q = q }) end
	elseif event == "SKILL_LINES_CHANGED" then
		checkSkills()
	end
end)
ns.On("LM_WORLD", function() checkInstance(); checkSkills() end)
```

- [ ] **Step 4: Run the test and the whole suite**

Run: `node tools/run-lua-test.mjs LevelMates tests/journal_events.test.lua` — Expected: `ok`. Run: `npm test` — Expected: all `ok`.

- [ ] **Step 5: Commit**

```bash
git add LevelMates/Journal.lua tests/journal_events.test.lua
git commit -m "feat(journal): dungeon, group, item and profession entries"
```

---

### Task 3: The Journal tab

**Files:**
- Modify: `LevelMates/Board.lua`, `LevelMates/Journal.lua`, `LevelMates/Locales/enUS.lua`, `LevelMates/Locales/esES.lua`, `tools/wow-stub.lua`
- Create: `tests/board_journal.test.lua`

**Interfaces:**
- Consumes: `ns.Journal.List/Count/Text/Color/When/FilterName/FILTERS/Clear`, event `LM_JOURNAL_CHANGED`.
- Produces: `B.tabs.journal`, `B.JCOLS`, `B.journalClear`, `B.journalFilterButton`, `B.journalPrev`, `B.journalNext`, `B.journalPageText`, `B.journalFilter`, `B.journalPage`; event `LM_JOURNAL_CLEAR` (handled in Journal.lua with a confirmation popup); slash `/lm diario` and `/lm journal`.

- [ ] **Step 1: Write the failing test**

In `tools/wow-stub.lua`, inside the `GameTooltip = {` table, add an entry `SetHyperlink = function(self, link) self.link = link end,`.

`tests/board_journal.test.lua`:

```lua
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local B, J, L = ns.Board, ns.Journal, ns.L
local green = "|cff1eff00|Hitem:2589::::::::20:::::::|h[Linen Cloth]|h|r"
for i = 1, 25 do J.Add("quest", { id = i, name = "Q" .. i }) end
J.Add("item", { link = green, q = 2 })
B.Toggle()
local function visible()
	local out = {}
	for i = 1, #B.rows do if B.rows[i].button:IsShown() then out[#out + 1] = B.rows[i] end end
	return out
end

assert(B.WIDTH == 600, "the board is 600 wide")
assert(B.tabs.journal, "third tab")
B.tabs.journal.scripts.OnClick(B.tabs.journal)
assert(B.tab == "journal" and ns.char.boardTab == "journal", "journal tab, remembered")
assert(B.tabs.journal.enabled == false and B.tabs.mates.enabled ~= false and B.tabs.lfg.enabled ~= false, "active tab")
assert(B.headText[1].text == L.COL_WHEN and B.headText[3].text == L.COL_ENTRY and B.headText[5].text == L.COL_ZONE, "headers")
assert(B.rows[1].zone:GetWidth() == B.JCOLS[3], "journal column widths")

local rows = visible()
assert(#rows == 20 and rows[1].zone.text == J.Text(J.List("all", "")[1]), "newest first, one page of 20")
assert(B.journalPageText.text == string.format(L.J_PAGE, 1, 2), "page 1 of 2: " .. tostring(B.journalPageText.text))
assert(B.journalPrev.enabled == false and B.journalNext.enabled == true, "pager buttons")
B.journalNext.scripts.OnClick(B.journalNext)
assert(#visible() == 6 and B.journalPageText.text == string.format(L.J_PAGE, 2, 2), "page 2 has the 6 oldest")
B.journalPrev.scripts.OnClick(B.journalPrev)

-- item tooltip on hover
rows = visible()
rows[1].button.scripts.OnEnter(rows[1].button)
assert(GameTooltip.link == green and not GameTooltip.hidden, "item card on hover")
rows[1].button.scripts.OnLeave(rows[1].button)

-- type filter from the game's menu
local entries = {}
MenuUtil.CreateContextMenu = function(owner, fn)
	local root = { CreateTitle = function() end, CreateButton = function(_, text, cb) entries[#entries + 1] = { text = text, cb = cb } end }
	fn(owner, root)
end
B.journalFilterButton.scripts.OnClick(B.journalFilterButton)
assert(#entries == #J.FILTERS and entries[1].text == L.J_FILTER_ALL, "one entry per filter")
for _, en in ipairs(entries) do if en.text == L.J_FILTER_ITEM then en.cb() end end
assert(B.journalFilter == "item" and #visible() == 1 and B.journalFilterButton.text == L.J_FILTER_ITEM, "items only")
for _, en in ipairs(entries) do if en.text == L.J_FILTER_ALL then en.cb() end end

-- search
B.searchBox:SetText("Q25"); B.searchBox.scripts.OnTextChanged(B.searchBox)
assert(#visible() == 1, "search the journal")
B.searchBox:SetText(""); B.searchBox.scripts.OnTextChanged(B.searchBox)

-- controls follow the tab; help rows give way to the pager
assert(B.journalClear:IsShown() and B.journalFilterButton:IsShown() and B.journalPrev:IsShown() and B.journalPageText:IsShown(), "journal controls shown")
assert(not B.helpButton:IsShown() and not B.lfgButton:IsShown() and not B.nearCheck:IsShown() and not B.palCheck:IsShown(), "others hidden")
for _, hr in ipairs(B.helpRows) do assert(not hr.text:IsShown() and not hr.button:IsShown(), "help rows hidden") end
B.tabs.mates.scripts.OnClick(B.tabs.mates)
assert(not B.journalClear:IsShown() and not B.journalFilterButton:IsShown() and not B.journalPrev:IsShown() and not B.journalPageText:IsShown(), "journal controls hidden elsewhere")
assert(B.rows[1].zone:GetWidth() == B.COLS[3], "guildmates column widths back")

-- clear, with confirmation
B.ShowTab("journal")
B.journalClear.scripts.OnClick(B.journalClear)
assert(STUB.lastPopup == "LEVELMATES_JOURNAL_CLEAR", "asks first")
assert(J.Count() == 26, "nothing deleted before accepting")
StaticPopupDialogs.LEVELMATES_JOURNAL_CLEAR.OnAccept(STUB.lastDialog)
assert(J.Count() == 0 and #visible() == 0 and B.frame.empty.text == L.J_EMPTY, "cleared; empty text")

-- /lm diario opens it
B.Toggle()
SlashCmdList["LEVELMATES"]("diario")
assert(B.frame:IsShown() and B.tab == "journal", "/lm diario")
```

- [ ] **Step 2: Run the test to see it fail**

Run: `node tools/run-lua-test.mjs LevelMates tests/board_journal.test.lua` — Expected: LUA ERROR at `the board is 600 wide`.

- [ ] **Step 3: Implement**

Locales. `enUS.lua` append:

```lua
L.TAB_JOURNAL = "Journal"; L.COL_WHEN = "When"; L.COL_ENTRY = "Entry"
L.J_PAGE = "Page %d of %d"; L.BTN_J_PREV = "< Previous"; L.BTN_J_NEXT = "Next >"; L.BTN_J_CLEAR = "Clear journal"
L.J_CLEAR_CONFIRM = "Delete every journal entry of this character?"; L.J_EMPTY = "Nothing in the journal yet."
```
`esES.lua` append:

```lua
L.TAB_JOURNAL = "Diario"; L.COL_WHEN = "Cuándo"; L.COL_ENTRY = "Entrada"
L.J_PAGE = "Página %d de %d"; L.BTN_J_PREV = "< Anterior"; L.BTN_J_NEXT = "Siguiente >"; L.BTN_J_CLEAR = "Borrar diario"
L.J_CLEAR_CONFIRM = "¿Borrar todas las entradas del diario de este personaje?"; L.J_EMPTY = "El diario está vacío por ahora."
```

`LevelMates/Journal.lua` append (the confirmation lives with the data it deletes):

```lua

-- "Clear journal" (board button): confirm first.
ns.On("LM_JOURNAL_CLEAR", function()
	StaticPopupDialogs["LEVELMATES_JOURNAL_CLEAR"] = StaticPopupDialogs["LEVELMATES_JOURNAL_CLEAR"] or {
		text = L.J_CLEAR_CONFIRM, button1 = YES or OKAY, button2 = NO or CANCEL,
		timeout = 0, whileDead = true, hideOnEscape = true,
		OnAccept = function() J.Clear() end,
	}
	StaticPopup_Show("LEVELMATES_JOURNAL_CLEAR")
end)
```

`LevelMates/Board.lua`, in order:

(a) `B.GAP, B.MARGIN, B.WIDTH = 4, 12, 560` → `B.GAP, B.MARGIN, B.WIDTH = 4, 12, 600`, and after the `B.COLS = …` line add:

```lua
B.JCOLS = { 100, 1, 315, 1, 103 }   -- journal: when, -, entry, -, zone (same total as B.COLS)
```

(b) In `Build`, in `local function Tab(key, label, offset)` change `b:SetSize(96, 20)` to `b:SetSize(80, 20)`, and replace `Tab("mates", L.TAB_MATES, -52); Tab("lfg", L.TAB_LFG, 52)` with `Tab("mates", L.TAB_MATES, -84); Tab("lfg", L.TAB_LFG, 0); Tab("journal", L.TAB_JOURNAL, 84)`. Replace `B.tab = ns.char.boardTab == "lfg" and "lfg" or "mates"` with:

```lua
	B.tab = (ns.char.boardTab == "lfg" or ns.char.boardTab == "journal") and ns.char.boardTab or "mates"

	-- Journal tab: clear (bottom left), type filter (bottom right), pager in the help-rows area.
	local clear = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
	clear:SetSize(120, 20); clear:SetPoint("BOTTOMLEFT", 12, 3); clear:SetText(L.BTN_J_CLEAR)
	clear:SetScript("OnClick", function() ns.Fire("LM_JOURNAL_CLEAR") end)
	B.journalClear = clear
	local filter = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
	filter:SetSize(140, 20); filter:SetPoint("BOTTOMRIGHT", -12, 3)
	filter:SetScript("OnClick", function(self)
		MenuUtil.CreateContextMenu(self, function(_, root)
			for _, kind in ipairs(ns.Journal.FILTERS) do
				root:CreateButton(ns.Journal.FilterName(kind), function() B.journalFilter = kind; B.journalPage = 1; B.Refresh() end)
			end
		end)
	end)
	B.journalFilterButton = filter
	local prev = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
	prev:SetSize(110, 20); prev:SetPoint("BOTTOM", -160, B.BOTTOM + 8); prev:SetText(L.BTN_J_PREV)
	prev:SetScript("OnClick", function() B.journalPage = (B.journalPage or 1) - 1; B.Refresh() end)
	local nextb = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
	nextb:SetSize(110, 20); nextb:SetPoint("BOTTOM", 160, B.BOTTOM + 8); nextb:SetText(L.BTN_J_NEXT)
	nextb:SetScript("OnClick", function() B.journalPage = (B.journalPage or 1) + 1; B.Refresh() end)
	local pageText = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	pageText:SetPoint("BOTTOM", 0, B.BOTTOM + 12)
	B.journalPrev, B.journalNext, B.journalPageText = prev, nextb, pageText
```

(c) In the row `OnEnter` handler, replace the line `elseif B.tab == "mates" and self.mate then   -- partner match and shared rested XP` with:

```lua
			elseif B.tab == "journal" and self.entry and self.entry.link then   -- journal: the item card
				GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:SetHyperlink(self.entry.link); GameTooltip:Show()
			elseif B.tab == "mates" and self.mate then   -- partner match and shared rested XP
```

(d) In `local function SetHeaders()`, right after its first line `local lfg = B.tab == "lfg"`, add:

```lua
	if B.tab == "journal" then
		B.headText[1]:SetText(L.COL_WHEN); B.headText[2]:SetText(""); B.headText[3]:SetText(L.COL_ENTRY)
		B.headText[4]:SetText(""); B.headText[5]:SetText(L.COL_ZONE)
		for i = 1, 5 do B.headText[i]:SetTextColor(1, 0.82, 0) end
		return
	end
```

(e) Before `local function RefreshTabs()` add:

```lua
-- Column widths for the active tab (the row and header font strings are chained left to right).
local function SetColumns(widths)
	for i, w in ipairs(widths) do B.headText[i]:SetWidth(w) end
	for _, r in ipairs(B.rows) do
		r.name:SetWidth(widths[1] - (ROW_H - 4) - 4); r.level:SetWidth(widths[2]); r.zone:SetWidth(widths[3])
		r.group:SetWidth(widths[4]); r.xph:SetWidth(widths[5])
	end
end

local function FillJournal(list)
	for i = 1, ROWS do
		local r, e = B.rows[i], list[i]
		r.button.mate, r.button.adId, r.button.entry = nil, nil, e
		if e then
			r.icon:Hide()
			r.name:SetText(ns.Journal.When(e)); r.name:SetTextColor(0.7, 0.7, 0.7)
			r.level:SetText("")
			r.zone:SetText(ns.Journal.Text(e)); r.zone:SetTextColor(unpack(ns.Journal.Color(e)))
			r.group:SetText("")
			r.xph:SetText(e.zone or ""); r.xph:SetTextColor(0.7, 0.7, 0.7)
			r.button:Show()
			RowBg(r, i, false)
		else
			ClearRow(r)
		end
	end
end
```

(f) Replace the whole `local function RefreshTabs() … end` with:

```lua
local function RefreshTabs()
	local lfg, journal = B.tab == "lfg", B.tab == "journal"
	local mates = not lfg and not journal
	B.tabs.mates:SetEnabled(not mates); B.tabs.lfg:SetEnabled(not lfg); B.tabs.journal:SetEnabled(not journal)
	B.helpButton:SetShown(mates); B.nearCheck:SetShown(mates); B.nearLabel:SetShown(mates)
	B.palCheck:SetShown(mates); B.palLabel:SetShown(mates)
	B.palCheck:SetChecked(ns.Partner and ns.Partner.IsOn() or false)
	B.lfgButton:SetShown(lfg)
	B.lfgButton:SetText(ns.LFG.mine and L.BTN_LFG_CANCEL or L.BTN_LFG)
	B.journalClear:SetShown(journal); B.journalFilterButton:SetShown(journal)
	B.journalPrev:SetShown(journal); B.journalNext:SetShown(journal); B.journalPageText:SetShown(journal)
end
```

(g) Replace the whole `function B.Refresh() … end` with:

```lua
function B.Refresh()
	if not B.frame or not B.frame:IsShown() then return end
	local lfg, journal = B.tab == "lfg", B.tab == "journal"
	local list
	if journal then
		local all = ns.Journal.List(B.journalFilter or "all", B.search)
		local pages = math.max(1, math.ceil(#all / ROWS))
		B.journalPage = math.min(math.max(1, B.journalPage or 1), pages)
		list = {}
		for i = (B.journalPage - 1) * ROWS + 1, math.min(#all, B.journalPage * ROWS) do list[#list + 1] = all[i] end
		B.journalPageText:SetText(string.format(L.J_PAGE, B.journalPage, pages))
		B.journalPrev:SetEnabled(B.journalPage > 1); B.journalNext:SetEnabled(B.journalPage < pages)
		B.journalFilterButton:SetText(ns.Journal.FilterName(B.journalFilter or "all"))
	else
		list = lfg and LfgVisible() or Visible()
	end
	SetColumns(journal and B.JCOLS or B.COLS)
	SetHeaders()
	B.frame:SetHeight(B.CHROME + (math.max(MIN_ROWS, math.min(ROWS, #list)) + HELP_ROWS) * ROW_H)
	B.SetTitle(B.TitleString())
	local rested = ns.Rested and ns.Rested.Mine()
	B.restedText:SetText(rested and string.format(L.RESTED_MINE, rested) or "")
	if journal then FillJournal(list) elseif lfg then FillLfg(list) else FillMates(list) end
	local emptyText = ""
	if #list == 0 then
		if journal then emptyText = ns.Journal.Count() == 0 and L.J_EMPTY or L.EMPTY_FILTERED
		elseif not IsInGuild() then emptyText = L.NOT_IN_GUILD
		elseif lfg then emptyText = #ns.LFG.List() > 0 and L.EMPTY_FILTERED or L.LFG_EMPTY
		elseif #R.List() > 0 then emptyText = L.EMPTY_FILTERED
		else emptyText = L.EMPTY end
	end
	B.frame.empty:SetText(emptyText)
	RefreshTabs()
	if journal then
		for _, hr in ipairs(B.helpRows) do hr.text:Hide(); hr.button:Hide() end   -- the pager uses this area
	else
		RefreshHelp()
	end
end
```

(h) In `function B.SetTab(key)` and `function B.ShowTab(key)`, replace `key == "lfg" and "lfg" or "mates"` with `(key == "lfg" or key == "journal") and key or "mates"` (in `SetTab` it is the first line `key = …`; in `ShowTab` it is `B.tab = …`).

(i) At the end of the file add:

```lua
ns.On("LM_JOURNAL_CHANGED", B.Refresh)
ns.Slash("diario", function() B.ShowTab("journal") end)
ns.Slash("journal", function() B.ShowTab("journal") end)
```

- [ ] **Step 4: Run the test and the whole suite**

Run: `node tools/run-lua-test.mjs LevelMates tests/board_journal.test.lua` — Expected: `ok`. Run: `npm test` — Expected: all `ok` (board_style's column-fit test still holds: `B.JCOLS` sums like `B.COLS`, and 600 is wider).

- [ ] **Step 5: Commit**

```bash
git add LevelMates/Board.lua LevelMates/Journal.lua LevelMates/Locales/enUS.lua LevelMates/Locales/esES.lua tools/wow-stub.lua tests/board_journal.test.lua
git commit -m "feat(board): Journal tab with filter, search, pages, item card and clear"
```

---

### Task 4: Simulation and documentation

**Files:**
- Modify: `LevelMates/Sim.lua`, `README.md`, `CHANGELOG.md`
- Create: `tests/sim_journal.test.lua`

**Interfaces:**
- Consumes: `ns.Journal.Add/Count/RemoveWhere`.
- Produces: `/lm sim diario` (seven sample entries flagged `sim = true`); `/lm sim off` removes them.

- [ ] **Step 1: Write the failing test**

`tests/sim_journal.test.lua`:

```lua
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local J = ns.Journal
J.Add("quest", { id = 1, name = "Real quest" })
local sentBefore = #STUB.sent
SlashCmdList["LEVELMATES"]("sim diario")
assert(J.Count() == 8, "seven sample entries, one per kind: " .. J.Count())
local kinds = {}
for _, e in ipairs(J.List("all", "")) do kinds[e.k] = true end
for _, k in ipairs(J.KINDS) do assert(kinds[k], "sample of kind " .. k) end
assert(#STUB.sent == sentBefore, "the simulation sends nothing")
SlashCmdList["LEVELMATES"]("sim off")
assert(J.Count() == 1 and J.List("all", "")[1].name == "Real quest", "sim off removes only the samples")
```

- [ ] **Step 2: Run the test to see it fail**

Run: `node tools/run-lua-test.mjs LevelMates tests/sim_journal.test.lua` — Expected: LUA ERROR at `seven sample entries`.

- [ ] **Step 3: Implement**

In `LevelMates/Sim.lua`, after the `simRested` function add:

```lua
local function simJournal()
	local J = ns.Journal
	local green = "|cff1eff00|Hitem:2589::::::::20:::::::|h[Linen Cloth]|h|r"
	J.Add("level", { level = 21, took = 4800, sim = true })
	J.Add("quest", { id = 1098, name = "Fuerte Colmillo", sim = true })
	J.Add("dungeon", { name = "Ragefire Chasm", mates = { "Mario" }, sim = true })
	J.Add("group", { name = "Mario", sim = true })
	J.Add("item", { link = green, q = 2, sim = true })
	J.Add("skill", { name = "Herbalism", rank = 50, sim = true })
	J.Add("death", { level = 21, sim = true })
end
```

In `off()`, add as its first line:

```lua
	ns.Journal.RemoveWhere(function(e) return e.sim end)
```

and in the slash handler, after the `simRested` branch, add:

```lua
	elseif rest == "diario" or rest == "journal" then simJournal()
```

`README.md`, English "What it does", add:
`- **Journal** (Journal tab, or \`/lm diario\`): a private record of your leveling — level-ups with the time each took, quests, dungeons with the guildmates who came, groups with guildmates, green-or-better items, profession milestones and deaths. Filter by type, search, pages, and a clear button. Nothing is sent to anyone.`
and add `/lm diario` and `/lm sim diario` to the Commands line (after `/lm lfg` and after `/lm sim rested`). Spanish "Qué hace", add:
`- **Diario** (pestaña Diario, o \`/lm diario\`): un registro privado de tu subida — niveles con lo que tardaste en cada uno, misiones, mazmorras con los hermanos que fueron, grupos con hermanos, objetos verdes o mejores, hitos de profesiones y muertes. Filtro por tipo, búsqueda, páginas y botón para borrarlo. No se envía nada a nadie.`
and the same two commands in the Comandos line. `CHANGELOG.md` append:

```
- Journal: a third board tab with a private, per-character record (levels with time per level, quests, dungeons with guildmates, groups, green-or-better items, profession milestones, deaths); filter, search, pages, clear with confirmation; at most 1000 entries. The board is now 600 wide.
```

- [ ] **Step 4: Run the whole suite**

Run: `npm test` — Expected: all `ok`, exit code 0.

- [ ] **Step 5: In-game check (with the user), then commit**

In game: `/reload`, `/lm sim diario`, open the Journal tab: rows, colours, item card on hover, filter menu, pages, clear popup; bottom bar with three tabs and the filter button not overlapping. Kill something that drops a green item, level up, turn in a quest, enter a dungeon with a guildmate: each appears. Check that profession lines appear only on real changes.

```bash
git add LevelMates/Sim.lua README.md CHANGELOG.md tests/sim_journal.test.lua
git commit -m "feat(journal): simulation and docs"
```

---

## Self-Review notes

- Spec §4 kinds → Task 1 (level, quest, death) and Task 2 (dungeon, group, item, skill); §5 UI → Task 3; §6 storage and cap → Task 1; §3 privacy → Task 1 network check; §7 tests → each task; simulation → Task 4.
- Commits use explicit paths (not `git add -A`), after the editor temp-file incident in the rested XP plan.
- The board width change to 600 is a design consequence (three tabs + journal controls in the bottom bar), recorded here; the spec only asked for the third tab.
