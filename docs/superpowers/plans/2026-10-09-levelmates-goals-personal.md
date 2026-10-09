# LevelMates personal goals (plan B) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Each character can set one personal goal ("me, level 40 by Sunday") that guildmates with the addon see on the Goals tab, with its progress.

**Architecture:** A new module `Personal.lua` keeps my goal per character (`ns.char.goal`) and the guild's per account and guild (`ns.db.personal[guild][name]`), shared with a new message kind `gp` (`l` = target level, 0 withdraws; `e` = deadline day). The Goals tab lists guild goals, then mine, then others'. A small "My goal" dialog sets or removes it.

**Tech Stack:** Lua 5.1 (WoW Forever 1.60.x, interface 16001); tests with node + fengari and `tools/wow-stub.lua`.

**Spec:** `docs/superpowers/specs/2026-10-09-levelmates-goals-design.md` (plan B parts: §2 "Personal" row, §4 `gp`, §6 "Mi meta", §7 personal tests).

## Global Constraints

- New behavior travels only in a new message kind (`gp`); never new `hb` fields.
- Nothing is sent inside instances or with "Appear on the board" off (`C.Send` already refuses); a refused send is retried after the next heartbeat.
- Protected or sending actions run only from clicks (dialog buttons, menu entries).
- One personal goal per character; it expires 2 days after its deadline (`ns.Goals.KEEP_DAYS`).
- Strings in `Locales/enUS.lua` and `Locales/esES.lua`.

## Review Focus

1. A `gp` from someone not in the roster, or with absurd values (level 61, deadline years away, already expired): ignored (Task 1 tests).
2. Withdrawing while sending is refused (instance): the withdraw still reaches the guild after the next heartbeat (Task 1 tests).
3. A newcomer gets my goal; a guildmate's goal survives my /reload and expires on its own (Task 1 tests).
4. Reaching my level target is announced once, not on every later level (Task 1 tests).
5. Only my own row offers "Remove my goal"; guild goals keep their officer-only menu (Task 2 tests).

---

### Task 1: Personal goals core and `gp`

**Files:**
- Create: `LevelMates/Personal.lua`, `tests/personal.test.lua`
- Modify: `LevelMates/Comm.lua` (schema), `LevelMates/Goals.lua` (`G.KnownLevel`), `LevelMates/LevelMates.toc` (after `Goals.lua`), locales

**Interfaces:**
- Produces: `ns.Personal` with `Mine()`, `Set(level, days)`, `Clear()`, `List()` (entries `{ name, l, e, mine?, sim? }`, mine first, then others by deadline), `Text(p)`, `ProgressText(p)`, `IsDone(p)`, `AddSample(name, l, e)`, `RemoveSamples()`; `ns.Goals.KnownLevel(name)`; fires `LM_GOALS_CHANGED`.

- [ ] **Step 1: Write the failing test** — `tests/personal.test.lua`:

```lua
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local C, P, R, L = ns.Comm, ns.Personal, ns.Roster, ns.L
local function mate(name, level) STUB.Receive("LVLM", C.Encode("hb", { l = level or 20, z = 1421 }), "GUILD", name .. "-Testrealm") end
local function last() return C.Decode(STUB.sent[#STUB.sent].msg) end
local today = math.floor(time() / 86400)
STUB.guildMembers = { Tester = true, Mario = true, Ana = true }
R.InvalidateGuildRoster()
STUB.player.level = 30

assert(C.Validate("gp", { l = 40, e = today + 7 }) and C.Validate("gp", { l = 0, e = today }), "gp format")
assert(C.Validate("gp", { l = 61, e = today }) == false and C.Validate("gp", { l = 40 }) == false, "gp ranges and required fields")

-- mine
assert(P.Set(40, 7) and P.Mine().l == 40 and P.Mine().e == today + 7, "set")
local k, f = last()
assert(k == "gp" and f.l == 40 and f.e == today + 7, "told the guild")
local printed = #STUB.printed
assert(not P.Set(25, 7) and not P.Set(40, 40) and not P.Set(61, 3), "invalid refused")
assert(#STUB.printed == printed + 3 and STUB.printed[#STUB.printed]:find(L.MYGOAL_BAD, 1, true), "says why")
assert(P.Mine().l == 40 and P.List()[1].mine and P.List()[1].name == "Tester", "kept, listed first")
assert(P.ProgressText(P.List()[1]) == "30/40" and not P.IsDone(P.List()[1]), "my progress")

-- others
mate("Mario", 22)
STUB.Receive("LVLM", C.Encode("gp", { l = 30, e = today + 3 }), "GUILD", "Mario-Testrealm")
STUB.Receive("LVLM", C.Encode("gp", { l = 30, e = today + 3 }), "GUILD", "Nadie-Testrealm")
local list = P.List()
assert(#list == 2 and list[2].name == "Mario" and P.ProgressText(list[2]) == "22/30" and P.Text(list[2]) == string.format(L.MYGOAL_TEXT, 30), "Mario's goal, not a stranger's")
STUB.Receive("LVLM", C.Encode("gp", { l = 50, e = today - 5 }), "GUILD", "Mario-Testrealm")
STUB.Receive("LVLM", C.Encode("gp", { l = 50, e = today + 400 }), "GUILD", "Mario-Testrealm")
assert(P.List()[2].l == 30, "expired or far-off deadlines are ignored")
STUB.Receive("LVLM", C.Encode("gp", { l = 0, e = today }), "GUILD", "Mario-Testrealm")
assert(#P.List() == 1, "Mario withdrew his")
STUB.Receive("LVLM", C.Encode("gp", { l = 30, e = today + 3 }), "GUILD", "Mario-Testrealm")
ns.db.personal[GetGuildInfo("player")].Mario.e = today - 3
assert(#P.List() == 1, "others' goals expire too")

-- newcomers get mine
local n = #STUB.sent
STUB.Receive("LVLM", C.Encode("ping", {}), "GUILD", "Ana-Testrealm"); STUB.Advance(6)
local got = false
for i = n + 1, #STUB.sent do local kk, ff = C.Decode(STUB.sent[i].msg); if kk == "gp" and ff.l == 40 then got = true end end
assert(got, "a newcomer gets my goal")

-- reached: announced once
local function hits()
	local c = 0
	for i = 1, #STUB.printed do if STUB.printed[i]:find(string.format(L.MYGOAL_REACHED, 40), 1, true) then c = c + 1 end end
	return c
end
STUB.player.level = 40
STUB.Fire("PLAYER_LEVEL_UP", 40); STUB.Advance(1)
assert(hits() == 1 and P.IsDone(P.List()[1]), "reached, announced")
STUB.player.level = 41
STUB.Fire("PLAYER_LEVEL_UP", 41); STUB.Advance(1)
assert(hits() == 1, "only once")

-- a refused withdraw goes out after the next heartbeat
STUB.inInstance = true
n = #STUB.sent
assert(P.Clear() and not P.Mine() and #STUB.sent == n, "removed; nothing sent inside")
STUB.inInstance = false
ns.Fire("LM_HB_SENT")
k, f = last()
assert(k == "gp" and f.l == 0, "the withdraw goes out after the heartbeat")

-- my own expires
assert(P.Set(50, 1))
ns.char.goal.e = today - 3
assert(not P.Mine() and #P.List() == 0, "expired")
```

- [ ] **Step 2: Run it** — `node tools/run-lua-test.mjs LevelMates tests/personal.test.lua` — Expected: LUA ERROR at `gp format`.

- [ ] **Step 3: Implement**

`Comm.lua`: in the schema table after `gc = …` add `gp   = { l = int(0, 60), e = int(0, 100000) },`; in `REQUIRED` add `gp = { "l", "e" }`.

`Goals.lua`, after `G.MyContribution`:

```lua
-- A guildmate's level as I know it: online now, else last seen (up to 30 days).
function G.KnownLevel(name)
	if name == me() then return UnitLevel("player") end
	local m = R.mates[name]
	if m then return m.level end
	local s = seen()[name]
	return s and s.l
end
```

`LevelMates.toc`: `Personal.lua` right after `Goals.lua`.

`LevelMates/Personal.lua`:

```lua
-- Personal.lua: one personal goal per character ("me, level 40 by Sunday"), shown to the guild on the Goals tab.
-- Spec 2026-10-09-levelmates-goals-design (plan B). It travels in its own kind `gp` (l = 0 withdraws it).
local _, ns = ...
local P = {}
ns.Personal = P
local L, C, R, G = ns.L, ns.Comm, ns.Roster, ns.Goals
local DAYS_MAX = 30
local dirty = false   -- a send was refused (instance, sharing off): retry after the next heartbeat

local function today() return math.floor(time() / 86400) end
local function me() return (UnitName("player")) end
local function expired(g) return today() > g.e + G.KEEP_DAYS end
local function theirs()
	ns.db.personal = ns.db.personal or {}
	local k = GetGuildInfo("player") or "?"
	ns.db.personal[k] = ns.db.personal[k] or {}
	return ns.db.personal[k]
end

function P.Mine()
	local g = ns.char.goal
	if g and expired(g) then ns.char.goal = nil; return nil end
	return g
end

local function send(prio)
	local g = P.Mine()
	if C.Send("gp", { l = g and g.l or 0, e = g and g.e or today() }, prio) then dirty = false; return true end
	dirty = true
	return false
end

-- Called from a click (the "My goal" dialog).
function P.Set(level, days)
	if type(level) ~= "number" or level ~= math.floor(level) or level <= UnitLevel("player") or level > 60
		or type(days) ~= "number" or days < 1 or days > DAYS_MAX then
		ns.Say(L.MYGOAL_BAD)
		return false
	end
	ns.char.goal = { l = level, e = today() + days }
	send("now")
	ns.Fire("LM_GOALS_CHANGED")
	return true
end

function P.Clear()
	if not ns.char.goal then return false end
	ns.char.goal = nil
	send("now")
	ns.Fire("LM_GOALS_CHANGED")
	return true
end

-- Mine first, then guildmates' by deadline.
function P.List()
	local out, others, t = {}, {}, theirs()
	local mine = P.Mine()
	if mine then out[1] = { name = me(), l = mine.l, e = mine.e, mine = true } end
	for name, g in pairs(t) do
		if expired(g) then t[name] = nil
		elseif name ~= me() and (g.sim or R.IsGuildmate(name)) then others[#others + 1] = { name = name, l = g.l, e = g.e, sim = g.sim } end
	end
	table.sort(others, function(a, b) if a.e ~= b.e then return a.e < b.e end; return a.name < b.name end)
	for _, o in ipairs(others) do out[#out + 1] = o end
	return out
end

function P.Text(p) return string.format(L.MYGOAL_TEXT, p.l) end
function P.IsDone(p) local lvl = G.KnownLevel(p.name); return lvl ~= nil and lvl >= p.l end
function P.ProgressText(p) local lvl = G.KnownLevel(p.name); return string.format("%s/%d", lvl and tostring(math.min(lvl, p.l)) or "?", p.l) end

C.OnMessage("gp", function(f, name)
	if not R.mates[name] then return end   -- only people the roster knows
	local t = theirs()
	if f.l == 0 then t[name] = nil
	elseif f.l >= 2 and f.e + G.KEEP_DAYS >= today() and f.e <= today() + DAYS_MAX + 1 then t[name] = { l = f.l, e = f.e }
	else return end
	ns.Fire("LM_GOALS_CHANGED")
end)

-- Reached: announced once per goal.
local function check(level)
	local g = P.Mine()
	if g and not g.announced and math.max(UnitLevel("player"), level or 0) >= g.l then
		g.announced = true
		if ns.db.settings.goalNotices then ns.Say(L.MYGOAL_REACHED, g.l) end
		ns.Fire("LM_GOALS_CHANGED")
	end
end
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LEVEL_UP")
ev:SetScript("OnEvent", function(_, _, level) check(level) end)
ns.On("LM_WORLD", function() check() end)

ns.On("LM_PING_ANSWERED", function() if P.Mine() then send() end end)
ns.On("LM_ANNOUNCED", function() if P.Mine() then send() end end)
ns.On("LM_HB_SENT", function() if dirty then send() end end)

-- Simulation support (/lm sim metas): local samples, never sent.
function P.AddSample(name, l, e) theirs()[name] = { l = l, e = e, sim = true }; ns.Fire("LM_GOALS_CHANGED") end
function P.RemoveSamples()
	local t = theirs()
	for name, g in pairs(t) do if g.sim then t[name] = nil end end
	ns.Fire("LM_GOALS_CHANGED")
end
```

Locales — `enUS.lua`:

```lua
L.MYGOAL_TEXT = "Level %d"; L.MYGOAL_BAD = "Choose a level above yours (up to 60) and 1-30 days."; L.MYGOAL_REACHED = "Personal goal reached: level %d!"
```
`esES.lua`:

```lua
L.MYGOAL_TEXT = "Nivel %d"; L.MYGOAL_BAD = "Elige un nivel por encima del tuyo (hasta 60) y de 1 a 30 días."; L.MYGOAL_REACHED = "¡Meta personal cumplida: nivel %d!"
```

- [ ] **Step 4: Run** the test (Expected `ok`) and `npm test` (all `ok`; `comm_format` lists kinds by schema, so check it still passes).

- [ ] **Step 5: Commit** — `git add LevelMates/Personal.lua LevelMates/Comm.lua LevelMates/Goals.lua LevelMates/LevelMates.toc LevelMates/Locales/enUS.lua LevelMates/Locales/esES.lua tests/personal.test.lua` — `feat(goals): personal goals and the gp message`.

---

### Task 2: Personal goals on the Goals tab and the "My goal" dialog

**Files:**
- Modify: `LevelMates/Board.lua`, `LevelMates/GoalDialog.lua`, locales
- Create: `tests/board_personal.test.lua`

**Interfaces:**
- Consumes: `ns.Personal.*` from Task 1.
- Produces: `B.myGoal` (fires `LM_MYGOAL`), `B.OpenMyGoalMenu()`, `ns.MyGoalDialog` with `frame`, `level` (EditBox), `daysButton`, `save`, `remove`, `days`, `Open()`, `Refresh()`.

- [ ] **Step 1: Write the failing test** — `tests/board_personal.test.lua`:

```lua
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local C, B, P, R, L = ns.Comm, ns.Board, ns.Personal, ns.Roster, ns.L
local today = math.floor(time() / 86400)
STUB.guildMembers = { Tester = true, Mario = true, Jefa = true }
STUB.guildRoles = { Jefa = 2 }
R.InvalidateGuildRoster()
STUB.player.level = 30
STUB.Receive("LVLM", C.Encode("hb", { l = 40, z = 1421 }), "GUILD", "Jefa-Testrealm")
STUB.Receive("LVLM", C.Encode("hb", { l = 18, z = 1421 }), "GUILD", "Mario-Testrealm")
STUB.Receive("LVLM", C.Encode("go", { id = "j1", ty = "lvl", a = 30, s = today, e = today + 3 }), "GUILD", "Jefa-Testrealm")
STUB.Receive("LVLM", C.Encode("gp", { l = 20, e = today + 2 }), "GUILD", "Mario-Testrealm")
local entries
MenuUtil.CreateContextMenu = function(owner, fn)
	entries = {}
	local root = { CreateTitle = function() end, CreateButton = function(_, text, cb) entries[#entries + 1] = { text = text, cb = cb } end }
	fn(owner, root)
end
local function pick(button, text) button.scripts.OnClick(button); for _, en in ipairs(entries) do if en.text == text then en.cb() end end end
local function visible()
	local out = {}
	for i = 1, #B.rows do if B.rows[i].button:IsShown() then out[#out + 1] = B.rows[i] end end
	return out
end

B.ShowTab("goals")
local rows = visible()
assert(#rows == 2 and rows[1].button.goalId == "j1", "guild goals first")
assert(rows[2].name.text == "Mario" and rows[2].zone.text == string.format(L.MYGOAL_TEXT, 20) and rows[2].group.text == "18/20" and rows[2].xph.text == ns.Goals.UntilText({ e = today + 2 }), "then personal ones")
assert(B.myGoal:IsShown(), "My goal for everyone")

-- the dialog
B.myGoal.scripts.OnClick(B.myGoal)
local D = ns.MyGoalDialog
assert(D.frame:IsShown() and not D.remove:IsShown() and D.save.enabled == false and D.days == 7, "empty dialog, 7 days by default")
D.level:SetText("35"); D.level.scripts.OnTextChanged(D.level)
pick(D.daysButton, string.format(L.GOAL_DAYS, 3))
assert(D.days == 3 and D.save.enabled == true, "ready")
D.save.scripts.OnClick(D.save)
local k, f = C.Decode(STUB.sent[#STUB.sent].msg)
assert(k == "gp" and f.l == 35 and f.e == today + 3 and not D.frame:IsShown(), "saved and shared")
rows = visible()
assert(#rows == 3 and rows[2].name.text == "Tester" and rows[2].group.text == "30/35", "mine before others'")

-- an invalid level keeps the dialog open
B.myGoal.scripts.OnClick(B.myGoal)
assert(D.level:GetText() == "35" and D.remove:IsShown(), "prefilled, remove available")
D.level:SetText("10"); D.level.scripts.OnTextChanged(D.level)
D.save.scripts.OnClick(D.save)
assert(D.frame:IsShown() and P.Mine().l == 35, "refused: stays open")
D.remove.scripts.OnClick(D.remove)
assert(not P.Mine() and not D.frame:IsShown(), "removed from the dialog")

-- right click: only my own row
P.Set(36, 7)
rows = visible()
entries = nil
rows[3].button.scripts.OnClick(rows[3].button, "RightButton")
assert(entries == nil, "no menu on someone else's goal")
rows[2].button.scripts.OnClick(rows[2].button, "RightButton")
assert(entries and entries[1].text == L.MYGOAL_REMOVE, "remove on my own row")
entries[1].cb()
assert(not P.Mine() and #visible() == 2, "removed")

B.tabs.mates.scripts.OnClick(B.tabs.mates)
assert(not B.myGoal:IsShown(), "only on the Goals tab")
```

- [ ] **Step 2: Run it** — Expected: LUA ERROR at `then personal ones` (only guild goals listed).

- [ ] **Step 3: Implement**

Locales — `enUS.lua`: `L.BTN_MYGOAL = "My goal"; L.MYGOAL_TITLE = "My goal"; L.MYGOAL_LEVEL = "Target level"; L.MYGOAL_SAVE = "Save"; L.MYGOAL_REMOVE = "Remove my goal"`. `esES.lua`: `L.BTN_MYGOAL = "Mi meta"; L.MYGOAL_TITLE = "Mi meta"; L.MYGOAL_LEVEL = "Nivel objetivo"; L.MYGOAL_SAVE = "Guardar"; L.MYGOAL_REMOVE = "Quitar mi meta"`.

`Board.lua`:

(a) After the `B.goalNew = goalNew` line add:

```lua
	local myGoal = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
	myGoal:SetSize(120, 20); myGoal:SetPoint("BOTTOMRIGHT", -12, 3); myGoal:SetText(L.BTN_MYGOAL)
	myGoal:SetScript("OnClick", function() ns.Fire("LM_MYGOAL") end)
	B.myGoal = myGoal
```

(b) Row `OnClick`, goals branch becomes:

```lua
			if B.tab == "goals" then
				if mouse == "RightButton" then
					if self.goalId then B.OpenGoalMenu(self.goalId) elseif self.personalMine then B.OpenMyGoalMenu() end
				end
				return
			end
```

(c) `FillGoals`: replace the row-reset line and the `if g then` body with a branch for personal entries (`g.name` set):

```lua
		r.button.mate, r.button.adId, r.button.entry = nil, nil, nil
		r.button.goalId = g and not g.name and g.id or nil
		r.button.personalMine = g and g.mine or nil
		if g and g.name then   -- personal goal
			local P = ns.Personal
			r.icon:Hide()
			r.name:SetText(g.name); r.name:SetTextColor(1, 1, 1)
			r.level:SetText("")
			r.zone:SetText(P.Text(g)); r.zone:SetTextColor(0.6, 0.8, 1)
			r.group:SetText(P.ProgressText(g)); r.group:SetTextColor(unpack(P.IsDone(g) and B.GROUP_COLORS.open or { 1, 1, 1 }))
			r.xph:SetText(ns.Goals.UntilText(g)); r.xph:SetTextColor(0.7, 0.7, 0.7)
			r.button:Show()
			RowBg(r, i, false)
		elseif g then
```
(the existing guild-goal body follows unchanged).

(d) After `B.OpenGoalMenu` add:

```lua
function B.OpenMyGoalMenu()
	if not ns.Personal.Mine() then return end
	MenuUtil.CreateContextMenu(B.frame, function(_, root)
		root:CreateButton(L.MYGOAL_REMOVE, function() ns.Personal.Clear() end)
	end)
end
```

(e) `RefreshTabs`: after the `B.goalNew:SetShown(...)` line add `B.myGoal:SetShown(goals)`.

(f) `B.Refresh`: the goals list becomes guild goals then personal ones:

```lua
	elseif goals then
		list = ns.Goals.List()
		for _, p in ipairs(ns.Personal.List()) do list[#list + 1] = p end
```

`GoalDialog.lua`, append:

```lua

-- "My goal": any player, one per character. Personal.Set/Clear run only from its buttons.
local My = { days = 7 }
ns.MyGoalDialog = My
local P = ns.Personal

local function BuildMine()
	local f = CreateFrame("Frame", "LevelMatesMyGoalDialog", UIParent, "BasicFrameTemplateWithInset")
	My.frame = f
	f:SetSize(300, 170); f:SetPoint("CENTER"); f:SetFrameStrata("DIALOG")
	f:SetMovable(true); f:EnableMouse(true); f:SetClampedToScreen(true); f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", f.StartMoving); f:SetScript("OnDragStop", f.StopMovingOrSizing)
	if f.TitleText then f.TitleText:SetText(L.MYGOAL_TITLE) end
	tinsert(UISpecialFrames, "LevelMatesMyGoalDialog")
	f:Hide()
	local label = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	label:SetPoint("TOPLEFT", 20, -42); label:SetText(L.MYGOAL_LEVEL)
	local level = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
	level:SetSize(60, 22); level:SetPoint("TOPLEFT", 150, -38); level:SetAutoFocus(false); level:SetMaxLetters(2)
	level:SetScript("OnTextChanged", function() My.Refresh() end)
	My.level = level
	My.daysButton = Button(f, 120, "TOPLEFT", 20, -74, string.format(L.GOAL_DAYS, My.days), function(self)
		local items = {}
		for _, n in ipairs(DAYS) do items[#items + 1] = { string.format(L.GOAL_DAYS, n), function() My.days = n; My.daysButton:SetText(string.format(L.GOAL_DAYS, n)); My.Refresh() end } end
		Menu(self, items)
	end)
	My.remove = Button(f, 130, "TOPLEFT", 150, -74, L.MYGOAL_REMOVE, function() P.Clear(); f:Hide() end)
	My.save = Button(f, 120, "BOTTOMLEFT", 20, 14, L.MYGOAL_SAVE, function()
		if P.Set(tonumber(My.level:GetText() or ""), My.days) then f:Hide() end   -- a refused goal keeps the dialog open
	end)
	Button(f, 120, "BOTTOMRIGHT", -20, 14, L.LFG_CLOSE, function() f:Hide() end)
end

function My.Refresh()
	if not My.frame then return end
	My.save:SetEnabled(tonumber(My.level:GetText() or "") ~= nil)
	My.remove:SetShown(P.Mine() ~= nil)
end

function My.Open()
	if not My.frame then BuildMine() end
	local g = P.Mine()
	My.level:SetText(g and tostring(g.l) or "")
	My.frame:Show()
	My.Refresh()
end

ns.On("LM_MYGOAL", My.Open)
```

`GoalDialog.lua` must load after `Personal.lua` (Task 1 put `Personal.lua` right after `Goals.lua`, before `GoalDialog.lua`).

- [ ] **Step 4: Run** the test (Expected `ok`) and `npm test` (`board_goals` still `ok`: no personal goals there).

- [ ] **Step 5: Commit** — `git add LevelMates/Board.lua LevelMates/GoalDialog.lua LevelMates/Locales/enUS.lua LevelMates/Locales/esES.lua tests/board_personal.test.lua` — `feat(board): personal goals on the Goals tab and the My goal dialog`.

---

### Task 3: Simulation and documentation

**Files:** Modify `LevelMates/Sim.lua`, `tests/sim_goals.test.lua`, `README.md`, `CHANGELOG.md`.

- [ ] **Step 1: Failing test** — in `tests/sim_goals.test.lua`, replace the first block's two asserts with:

```lua
assert(#G.List() == 3, "three sample goals: " .. #G.List())
assert(#ns.Personal.List() == 1 and ns.Personal.List()[1].name == "Mario", "and Mario's personal goal")
assert(#STUB.sent == sentBefore, "the simulation sends nothing")
SlashCmdList["LEVELMATES"]("sim off")
assert(#G.List() == 0 and #ns.Personal.List() == 0, "sim off removes them")
```

- [ ] **Step 2: Run** — Expected: LUA ERROR at `and Mario's personal goal`.

- [ ] **Step 3: Implement** — `Sim.lua`: in `simGoals` add `ns.Personal.AddSample("Mario", 32, day + 4)`; in `off()` add `ns.Personal.RemoveSamples()` after `ns.Goals.RemoveSamples()`. README (English "Guild goals" line): append ` Anyone can also set a personal goal ("My goal": a level by a date) that the guild sees.`; Spanish: append ` Cualquiera puede poner además su meta personal ("Mi meta": un nivel para una fecha) y la hermandad la ve.`. CHANGELOG: `- Personal goals: "My goal" on the Goals tab (a target level and a deadline, one per character), shown to guildmates with their level; announced when reached. New message kind \`gp\`.`

- [ ] **Step 4: Run** `npm test` — all `ok`.

- [ ] **Step 5: Commit** — `git add LevelMates/Sim.lua tests/sim_goals.test.lua README.md CHANGELOG.md` — `feat(goals): personal goals in the simulation and docs`.
