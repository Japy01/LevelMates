# LevelMates wishlist Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Each character keeps a wishlist of up to 10 items that guildmates see, with a notice when you loot something a guildmate wants and a "Wanted by" line on item tooltips.

**Architecture:** `Wishlist.lua` keeps my list per character and the guild's per account and guild, shared with a new message kind `wl` (the whole list as item ids). The journal's loot parser fires `LM_MY_LOOT(link)` for every item I loot; the wishlist listens. A fifth board tab lists the wishes; `WishDialog.lua` adds items through Shift+click (a post-hook on `ChatFrameUtil.InsertLink`). The board's tabs become WoW's classic tabs under the window first, so five fit and the bottom bar is free.

**Tech Stack:** Lua 5.1 (WoW Forever 1.60.x, interface 16001); tests with node + fengari and `tools/wow-stub.lua`.

**Spec:** `docs/superpowers/specs/2026-10-09-levelmates-wishlist-design.md`

## Global Constraints

- New behavior travels only in a new message kind (`wl`); never new `hb` fields.
- Nothing is sent inside instances or with "Appear on the board" off (`C.Send` refuses); a refused send stays pending in `ns.char` and goes out after the next heartbeat.
- Sending actions only from clicks or the roster hooks (`LM_PING_ANSWERED`, `LM_ANNOUNCED`, `LM_HB_SENT`).
- At most 10 wishes per character; others' lists forgotten after 30 days without an update and hidden for people no longer in the guild.
- Strings in `Locales/enUS.lua` and `Locales/esES.lua`. Client APIs not in the stub are guarded (`if X and X.Y then`).

## Review Focus

1. A `wl` from someone not in the roster, with more than 10 ids, empty pieces or ids out of range: ignored (Task 2 tests).
2. Removing a wish inside an instance, then /reload: the new list still reaches the guild (Task 2 tests).
3. Looting an item two people want, or looting it twice: each guildmate named once per session; my own wish removed (Task 2 tests).
4. An item the client has not loaded yet: the row says "Item #id" and fills in when it loads (Task 3 tests).
5. Shift+click while the dialog is closed changes nothing; while open, the link lands in the box (Task 3 tests).

---

### Task 1: Classic tabs under the board

**Files:**
- Modify: `LevelMates/Board.lua`, `tools/wow-stub.lua`, `tests/board_goals.test.lua` (line 21)
- Create: `tests/board_tabs.test.lua`

**Interfaces:**
- Produces: `B.TAB_KEYS` (ordered keys), `B.tabs[key]` (PanelTabButtonTemplate buttons), `B.frame.Tabs`, `B.frame.numTabs`, `B.frame.selectedTab`; Task 3 appends `"wishes"` to `B.TAB_KEYS` and a label to `TAB_LABELS`.

- [ ] **Step 1: Stub support.** Append to `tools/wow-stub.lua`:

```lua

-- Panel tabs (SharedUIPanelTemplates): the selected tab is the disabled one, as PanelTemplates_SelectTab does.
function PanelTemplates_SetNumTabs(frame, n) frame.numTabs = n end
function PanelTemplates_SetTab(frame, id)
	frame.selectedTab = id
	for i, tab in ipairs(frame.Tabs or {}) do tab:SetEnabled(i ~= id) end
end
function PanelTemplates_TabResize() end
```

- [ ] **Step 2: Write the failing test** — `tests/board_tabs.test.lua`:

```lua
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local B = ns.Board
B.Toggle()
assert(B.frame.Tabs and #B.frame.Tabs == #B.TAB_KEYS and B.frame.numTabs == #B.TAB_KEYS, "classic tabs, one per key")
for i, key in ipairs(B.TAB_KEYS) do
	assert(B.tabs[key].template == "PanelTabButtonTemplate" and B.frame.Tabs[i] == B.tabs[key], "classic tab " .. key)
end
local first, second = B.tabs[B.TAB_KEYS[1]], B.tabs[B.TAB_KEYS[2]]
assert(first.point[1] == "TOPLEFT" and first.point[2] == B.frame and first.point[3] == "BOTTOMLEFT", "hanging under the window")
assert(second.point[1] == "LEFT" and second.point[2] == first, "side by side")
B.tabs.journal.scripts.OnClick(B.tabs.journal)
assert(B.frame.selectedTab == 3 and B.tabs.journal.enabled == false and B.tabs.mates.enabled == true, "journal selected")
assert(ns.char.boardTab == "journal", "remembered")
B.ShowTab("nonsense")
assert(B.tab == "mates" and B.frame.selectedTab == 1, "unknown keys fall back to guildmates")
```

- [ ] **Step 3: Run it** — `node tools/run-lua-test.mjs LevelMates tests/board_tabs.test.lua` — Expected: LUA ERROR at `classic tabs, one per key`.

- [ ] **Step 4: Implement** in `LevelMates/Board.lua`:

(a) After `B.GCOLS = …` add:

```lua
-- Tabs, in order; each key's label is L[TAB_LABELS[key]].
B.TAB_KEYS = { "mates", "lfg", "journal", "goals" }
local TAB_LABELS = { mates = "TAB_MATES", lfg = "TAB_LFG", journal = "TAB_JOURNAL", goals = "TAB_GOALS" }
B.TAB_LABELS = TAB_LABELS
local function KnownTab(key) for _, k in ipairs(B.TAB_KEYS) do if k == key then return key end end; return "mates" end
```

(b) Replace from `	B.tabs = {}` through `	B.tab = (saved == "lfg" or saved == "journal" or saved == "goals") and saved or "mates"` with:

```lua
	-- Tabs: WoW's classic tabs hanging under the window (as the Dungeon Journal's), so the bottom bar keeps the buttons.
	B.tabs = {}
	local tabList, prevTab = {}, nil
	for i, key in ipairs(B.TAB_KEYS) do
		local b = CreateFrame("Button", "LevelMatesBoardTab" .. i, f, "PanelTabButtonTemplate")
		b:SetID(i); b:SetText(L[TAB_LABELS[key]])
		if prevTab then b:SetPoint("LEFT", prevTab, "RIGHT", -16, 0) else b:SetPoint("TOPLEFT", f, "BOTTOMLEFT", 11, 2) end
		if PanelTemplates_TabResize then PanelTemplates_TabResize(b, 0) end
		b:SetScript("OnClick", function() B.SetTab(key) end)
		B.tabs[key], tabList[i], prevTab = b, b, b
	end
	f.Tabs = tabList   -- the template's parentArray, set here so the order is ours
	if PanelTemplates_SetNumTabs then PanelTemplates_SetNumTabs(f, #tabList) end
	B.tab = KnownTab(ns.char.boardTab)
```

Also change the comment above the lfg button from `-- Dungeons tab: its own action button in the same spot as "Ask for help", and the two tab buttons in the bottom bar.` to `-- Dungeons tab: its own action button in the same spot as "Ask for help".`

(c) In `RefreshTabs`, replace the line `	B.tabs.mates:SetEnabled(not mates); B.tabs.lfg:SetEnabled(not lfg); B.tabs.journal:SetEnabled(not journal); B.tabs.goals:SetEnabled(not goals)` with:

```lua
	local index = 1
	for i, key in ipairs(B.TAB_KEYS) do if key == B.tab then index = i end end
	if PanelTemplates_SetTab then PanelTemplates_SetTab(B.frame, index)
	else for i, key in ipairs(B.TAB_KEYS) do B.tabs[key]:SetEnabled(i ~= index) end end
```

(d) In `B.SetTab` replace `key = (key == "lfg" or key == "journal" or key == "goals") and key or "mates"` with `key = KnownTab(key)`; in `B.ShowTab` replace `B.tab = (key == "lfg" or key == "journal" or key == "goals") and key or "mates"` with `B.tab = KnownTab(key)`.

`tests/board_goals.test.lua` line 21: replace the tab-width loop with `assert(B.frame.Tabs[4] == B.tabs.goals, "goals is the fourth classic tab")`.

- [ ] **Step 5: Run** the test (Expected `ok`) and `npm test` (all `ok`; `board_lfg`/`board_journal` check the selected tab through `enabled`, which the stub's `PanelTemplates_SetTab` keeps).

- [ ] **Step 6: Commit** — `git add LevelMates/Board.lua tools/wow-stub.lua tests/board_tabs.test.lua tests/board_goals.test.lua` — `feat(board): classic tabs under the window`.

---

### Task 2: Wishlist core, `wl`, loot notices and tooltip line

**Files:**
- Create: `LevelMates/Wishlist.lua`, `tests/wishlist.test.lua`
- Modify: `LevelMates/Comm.lua`, `LevelMates/Journal.lua` (fire `LM_MY_LOOT`), `LevelMates/Core.lua` (default `wishNotices = true`), `LevelMates/Settings.lua`, `LevelMates/LevelMates.toc` (`Wishlist.lua` after `Personal.lua`), `tools/wow-stub.lua`, locales

**Interfaces:**
- Produces: `ns.Wishlist` with `MAX`, `ItemId(text)`, `Has(id)`, `Add(link)`, `Remove(id)`, `List()` (rows `{ name, id, t, mine? }`, mine first in order, then others by name), `WantedBy(id)` (sorted names, mine included), `Link(id)` (item link or nil, asking the client to load it), `AddSample(name, ids)`, `RemoveSamples()`; event `LM_WISHES_CHANGED`; event `LM_MY_LOOT(link)` from the journal.

- [ ] **Step 1: Stub support.** Append to `tools/wow-stub.lua`:

```lua

-- Wishlist support
function hooksecurefunc(a, b, c)
	local tbl, key, fn = a, b, c
	if type(a) == "string" then tbl, key, fn = _G, a, b end
	local old = tbl[key]
	tbl[key] = function(...) local r = { old(...) }; fn(...); return unpack(r) end
end
ChatFrameUtil.InsertLink = function() return false end
STUB.tooltipPost = {}
Enum.TooltipDataType = { Item = 0, Unit = 2 }
TooltipDataProcessor = { AddTooltipPostCall = function(kind, fn) STUB.tooltipPost[#STUB.tooltipPost + 1] = { kind = kind, fn = fn } end }
function STUB.TooltipPost(kind, tooltip, data) for _, p in ipairs(STUB.tooltipPost) do if p.kind == kind then p.fn(tooltip, data) end end end
ItemRefTooltip = {}
STUB.items, STUB.itemLoads = {}, {}
function GetItemInfo(x)
	local id = tonumber(x) or tonumber(tostring(x):match("item:(%d+)") or "")
	local link = id and STUB.items[id]
	if link then return link:match("%[(.-)%]"), link end
end
Item = { CreateFromItemID = function(_, id) return { ContinueOnItemLoad = function(_, fn) STUB.itemLoads[id] = fn end } end }
```

- [ ] **Step 2: Write the failing test** — `tests/wishlist.test.lua`:

```lua
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local C, W, R, L = ns.Comm, ns.Wishlist, ns.Roster, ns.L
local function mate(name) STUB.Receive("LVLM", C.Encode("hb", { l = 20, z = 1421 }), "GUILD", name .. "-Testrealm") end
local function last() return C.Decode(STUB.sent[#STUB.sent].msg) end
local function link(id, name) return "|cff1eff00|Hitem:" .. id .. "::::::::20:::::::|h[" .. (name or ("Item " .. id)) .. "]|h|r" end
local function loot(l) STUB.Fire("CHAT_MSG_LOOT", "You receive loot: " .. l .. ".", "Tester", "", "", "Tester", "", 0, 0, "", 0, 1, "Player-1-TESTER") end
local function said(text) for i = #STUB.printed, 1, -1 do if STUB.printed[i]:find(text, 1, true) then return true end end; return false end
STUB.guildMembers = { Tester = true, Mario = true, Ana = true, Luis = true }
R.InvalidateGuildRoster()
assert(ns.db.settings.wishNotices == true, "notices on by default")

-- wire format
assert(C.Validate("wl", {}) and C.Validate("wl", { ids = "123" }) and C.Validate("wl", { ids = 123 }) and C.Validate("wl", { ids = "1,2,3,4,5,6,7,8,9,10" }), "wl format")
assert(C.Validate("wl", { ids = "1,2,3,4,5,6,7,8,9,10,11" }) == false and C.Validate("wl", { ids = "0" }) == false, "wl count and range")
assert(C.Validate("wl", { ids = "1,,2" }) == false and C.Validate("wl", { ids = "1000000" }) == false and C.Validate("wl", { ids = "1," }) == false, "wl pieces")

-- adding and removing
assert(W.ItemId(link(2589)) == 2589 and W.ItemId("hello") == nil, "item ids from links")
assert(W.Add(link(2589)) and W.Has(2589), "added")
local k, f = last()
assert(k == "wl" and tostring(f.ids) == "2589", "told the guild")
assert(W.Add(link(1001)) and select(2, last()).ids == "2589,1001", "the whole list each time")
assert(not W.Add(link(2589)) and said(L.WISH_DUP), "no duplicates")
assert(not W.Add("hello") and said(L.WISH_NOT_ITEM), "not an item")
for id = 3001, 3008 do assert(W.Add(link(id)), "add " .. id) end
assert(not W.Add(link(3009)) and said(string.format(L.WISH_FULL, W.MAX)), "at most 10")
assert(#W.List() == 10 and W.List()[1].mine and W.List()[1].id == 2589 and W.List()[1].name == "Tester", "mine, in order")
for id = 3001, 3008 do assert(W.Remove(id)) end
assert(W.Remove(1001) and not W.Has(1001) and not W.Remove(1001), "removed once")

-- guildmates' lists
mate("Mario"); mate("Ana")
STUB.Receive("LVLM", C.Encode("wl", { ids = "1001,2589" }), "GUILD", "Mario-Testrealm")
STUB.Receive("LVLM", C.Encode("wl", { ids = "1001" }), "GUILD", "Nadie-Testrealm")
local names = W.WantedBy(1001)
assert(#names == 1 and names[1] == "Mario", "Mario wants it; strangers are ignored")
names = W.WantedBy(2589)
assert(#names == 2 and names[1] == "Mario" and names[2] == "Tester", "mine counts too")
assert(#W.List() == 3 and W.List()[2].name == "Mario" and W.List()[2].id == 1001, "then others' wishes")

-- tooltip line
local line
GameTooltip.AddLine = function(self, t) line = t end
STUB.TooltipPost(Enum.TooltipDataType.Item, GameTooltip, { id = 1001 })
assert(line == string.format(L.WISH_TOOLTIP, "Mario"), "tooltip: who wants it")
line = nil
STUB.TooltipPost(Enum.TooltipDataType.Item, GameTooltip, { id = 4242 })
assert(line == nil, "nobody wants it: no line")

-- looting a guildmate's wish: told once per session
loot(link(1001, "Cool Sword"))
assert(said(string.format(L.WISH_THEY_WANT, "Mario", link(1001, "Cool Sword"))), "Mario wants it")
local count = #STUB.printed
loot(link(1001, "Cool Sword"))
assert(#STUB.printed == count, "told once")

-- looting my own wish: got it, removed, the guild told
loot(link(2589))
assert(not W.Has(2589) and said(string.format(L.WISH_GOT, link(2589))) and (last()) == "wl", "got mine")

-- notices off
ns.db.settings.wishNotices = false
STUB.Receive("LVLM", C.Encode("wl", { ids = "5555" }), "GUILD", "Ana-Testrealm")
count = #STUB.printed
loot(link(5555))
assert(#STUB.printed == count, "notices off: silent")
ns.db.settings.wishNotices = true

-- withdrawn, forgotten, left the guild
STUB.Receive("LVLM", C.Encode("wl", {}), "GUILD", "Mario-Testrealm")
assert(#W.WantedBy(1001) == 0, "Mario withdrew his list")
ns.db.wishes[GetGuildInfo("player")].Ana.t = time() - 31 * 86400
assert(#W.WantedBy(5555) == 0, "forgotten after 30 days")
STUB.Receive("LVLM", C.Encode("wl", { ids = "5555" }), "GUILD", "Ana-Testrealm")
STUB.guildMembers = { Tester = true, Mario = true, Luis = true }; R.InvalidateGuildRoster()
assert(#W.WantedBy(5555) == 0, "someone who left the guild is not shown")
STUB.guildMembers = { Tester = true, Mario = true, Ana = true, Luis = true }; R.InvalidateGuildRoster()

-- item links: known, or asked for
STUB.items[1001] = link(1001, "Cool Sword")
assert(W.Link(1001) == link(1001, "Cool Sword"), "a known item")
assert(W.Link(4242) == nil and STUB.itemLoads[4242], "an unknown one is asked for")
local changed = 0
ns.On("LM_WISHES_CHANGED", function() changed = changed + 1 end)
STUB.itemLoads[4242]()
assert(changed == 1, "refresh when it arrives")

-- newcomers get my list
assert(W.Add(link(7777)))
local n = #STUB.sent
STUB.Receive("LVLM", C.Encode("ping", {}), "GUILD", "Luis-Testrealm"); STUB.Advance(6)
local got = false
for i = n + 1, #STUB.sent do local kk, ff = C.Decode(STUB.sent[i].msg); if kk == "wl" and tostring(ff.ids) == "7777" then got = true end end
assert(got, "a newcomer gets my list")

-- a refused send stays pending in the saved data and goes out after the next heartbeat
STUB.inInstance = true
assert(W.Remove(7777) and LevelMatesDB.chars[ns.PlayerKey()].wishPending == true, "refused inside: pending, saved")
STUB.inInstance = false
ns.Fire("LM_HB_SENT")
k, f = last()
assert(k == "wl" and f.ids == nil and not LevelMatesDB.chars[ns.PlayerKey()].wishPending, "goes out after the heartbeat")
```

- [ ] **Step 3: Run it** — Expected: LUA ERROR at `notices on by default`.

- [ ] **Step 4: Implement**

`Comm.lua`: after the `oneOf` validator add:

```lua
-- Item ids "12,345,…": 1 to max ids, each 1-999999.
local function itemids(max)
	return function(v)
		if type(v) == "number" then v = tostring(v) end
		if type(v) ~= "string" or not v:match("^%d+$") and not v:match("^%d+[%d,]*%d$") or v:find(",,", 1, true) then return false end
		local n = 0
		for id in v:gmatch("%d+") do
			n = n + 1
			local x = tonumber(id)
			if x < 1 or x > 999999 then return false end
		end
		return n >= 1 and n <= max
	end
end
```
In the schema table after `gp = …` add `wl   = { ids = itemids(10) },`; in `REQUIRED` add `wl = {}`.

`Core.lua` DEFAULTS: add `wishNotices = true` after `goalNotices = true`. `Settings.lua`: after the `goalNotices` line add `Bool(category, "wishNotices", L.OPT_WISH, L.OPT_WISH_TT)`.

`Journal.lua`, in the `CHAT_MSG_LOOT` branch, replace

```lua
		local link = text:match("|c%x+|Hitem:.-|h.-|h|r")
		local q = link and quality(link)
```
with
```lua
		local link = text:match("|c%x+|Hitem:.-|h.-|h|r")
		if link then ns.Fire("LM_MY_LOOT", link) end   -- any item I loot (the wishlist listens)
		local q = link and quality(link)
```

`LevelMates.toc`: `Wishlist.lua` right after `Personal.lua`.

`LevelMates/Wishlist.lua`:

```lua
-- Wishlist.lua: items each player wants (up to 10 per character), shared with the guild in its own kind `wl`
-- (the whole list as item ids; no ids withdraws it). Spec 2026-10-09-levelmates-wishlist-design.
local _, ns = ...
local W = {}
ns.Wishlist = W
local L, C, R = ns.L, ns.Comm, ns.Roster
W.MAX, W.FORGET_DAYS = 10, 30

local function me() return (UnitName("player")) end
local function mine() ns.char.wishes = ns.char.wishes or {}; return ns.char.wishes end
local function theirs()
	ns.db.wishes = ns.db.wishes or {}
	local k = GetGuildInfo("player") or "?"
	ns.db.wishes[k] = ns.db.wishes[k] or {}
	return ns.db.wishes[k]
end

function W.ItemId(text)
	local id = type(text) == "string" and tonumber(text:match("item:(%d+)") or "")
	if id and id >= 1 and id <= 999999 then return id end
end

function W.Has(id) for _, w in ipairs(mine()) do if w.id == id then return true end end; return false end

-- A refused send (instance, sharing off) stays pending in the character's saved data and goes out after the next heartbeat.
local sentAt
local function send(prio)
	local ids = {}
	for _, w in ipairs(mine()) do ids[#ids + 1] = w.id end
	local fields = {}
	if #ids > 0 then fields.ids = table.concat(ids, ",") end
	if C.Send("wl", fields, prio) then ns.char.wishPending, sentAt = nil, GetTime(); return true end
	ns.char.wishPending = true
	return false
end
local function resend() if sentAt ~= GetTime() then send() end end   -- the heartbeat may have carried it this instant

-- Called from a click (the "Add a wish" dialog).
function W.Add(link)
	local id = W.ItemId(link)
	if not id then ns.Say(L.WISH_NOT_ITEM); return false end
	if W.Has(id) then ns.Say(L.WISH_DUP); return false end
	local list = mine()
	if #list >= W.MAX then ns.Say(L.WISH_FULL, W.MAX); return false end
	list[#list + 1] = { id = id, t = time() }
	send("now")
	ns.Fire("LM_WISHES_CHANGED")
	return true
end

function W.Remove(id)
	local list = mine()
	for i, w in ipairs(list) do
		if w.id == id then
			table.remove(list, i)
			send("now")
			ns.Fire("LM_WISHES_CHANGED")
			return true
		end
	end
	return false
end

-- Others' lists still worth showing: updated in the last 30 days, by someone still in the guild (or a sample).
local function others()
	local t, out, cutoff = theirs(), {}, time() - W.FORGET_DAYS * 86400
	for name, l in pairs(t) do
		if l.t < cutoff then t[name] = nil
		elseif name ~= me() and (l.sim or R.IsGuildmate(name)) then out[#out + 1] = { name = name, ids = l.ids, t = l.t } end
	end
	table.sort(out, function(a, b) return a.name < b.name end)
	return out
end

function W.List()
	local out = {}
	for _, w in ipairs(mine()) do out[#out + 1] = { name = me(), id = w.id, t = w.t, mine = true } end
	for _, o in ipairs(others()) do
		for _, id in ipairs(o.ids) do out[#out + 1] = { name = o.name, id = id, t = o.t } end
	end
	return out
end

function W.WantedBy(id)
	local names = {}
	if W.Has(id) then names[#names + 1] = me() end
	for _, o in ipairs(others()) do
		for _, x in ipairs(o.ids) do if x == id then names[#names + 1] = o.name; break end end
	end
	table.sort(names)
	return names
end

-- The item's link, or nil while the client has not loaded it (asked once; the board refreshes when it arrives).
local asked = {}
function W.Link(id)
	local info = (C_Item and C_Item.GetItemInfo) or GetItemInfo
	local link = info and select(2, info(id))
	if link then return link end
	if not asked[id] and Item and Item.CreateFromItemID then
		asked[id] = true
		Item:CreateFromItemID(id):ContinueOnItemLoad(function() ns.Fire("LM_WISHES_CHANGED") end)
	end
	return nil
end

C.OnMessage("wl", function(f, name)
	if not R.mates[name] then return end   -- only people the roster knows
	local t = theirs()
	if f.ids == nil then
		t[name] = nil
	else
		local ids = {}
		for id in tostring(f.ids):gmatch("%d+") do ids[#ids + 1] = tonumber(id) end
		t[name] = { ids = ids, t = time() }
	end
	ns.Fire("LM_WISHES_CHANGED")
end)

-- My loot: my own wish is done; a guildmate's wish gets a notice, once per item and person each session.
local told = {}
ns.On("LM_MY_LOOT", function(link)
	local id = W.ItemId(link)
	if not id then return end
	if W.Has(id) then
		W.Remove(id)
		ns.Say(L.WISH_GOT, link)
	end
	if not ns.db.settings.wishNotices then return end
	for _, o in ipairs(others()) do
		for _, x in ipairs(o.ids) do
			if x == id and not told[o.name .. ":" .. id] then
				told[o.name .. ":" .. id] = true
				ns.Say(L.WISH_THEY_WANT, o.name, link)
			end
		end
	end
end)

ns.On("LM_PING_ANSWERED", function() if #mine() > 0 then resend() end end)
ns.On("LM_ANNOUNCED", function() if #mine() > 0 then resend() end end)
ns.On("LM_HB_SENT", function() if ns.char.wishPending then send() end end)

-- Item tooltips anywhere in the game: who wants it.
if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
	TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
		if not ns.db or (tooltip ~= GameTooltip and tooltip ~= ItemRefTooltip) or not data or not data.id then return end
		local names = W.WantedBy(data.id)
		if #names > 0 then tooltip:AddLine(string.format(L.WISH_TOOLTIP, table.concat(names, ", ")), 0.4, 1, 0.4) end
	end)
end

-- Simulation support (/lm sim deseos): local samples, never sent.
function W.AddSample(name, ids) theirs()[name] = { ids = ids, t = time(), sim = true }; ns.Fire("LM_WISHES_CHANGED") end
function W.RemoveSamples()
	local t = theirs()
	for name, l in pairs(t) do if l.sim then t[name] = nil end end
	ns.Fire("LM_WISHES_CHANGED")
end
```

Locales — `enUS.lua`:

```lua
L.WISH_DUP = "That item is already on your wishlist."; L.WISH_NOT_ITEM = "That is not an item link: Shift+click an item."
L.WISH_FULL = "Your wishlist is full (%d items)."; L.WISH_GOT = "You got %s from your wishlist!"
L.WISH_THEY_WANT = "%s wants %s. Pass it on!"; L.WISH_TOOLTIP = "Wanted by: %s"
L.OPT_WISH = "Wishlist notices"; L.OPT_WISH_TT = "A chat line when you loot an item a guildmate wants."
```
`esES.lua`:

```lua
L.WISH_DUP = "Ese objeto ya está en tu lista de deseos."; L.WISH_NOT_ITEM = "Eso no es un enlace de objeto: haz Mayús+clic en un objeto."
L.WISH_FULL = "Tu lista de deseos está llena (%d objetos)."; L.WISH_GOT = "¡Conseguiste %s de tu lista de deseos!"
L.WISH_THEY_WANT = "%s quiere %s. ¡Pásaselo!"; L.WISH_TOOLTIP = "Lo quiere: %s"
L.OPT_WISH = "Avisos de deseos"; L.OPT_WISH_TT = "Una línea en el chat cuando te cae un objeto que quiere un hermano."
```

- [ ] **Step 5: Run** the test (Expected `ok`) and `npm test` (all `ok`; `journal_events` still records items).

- [ ] **Step 6: Commit** — `git add LevelMates/Wishlist.lua LevelMates/Comm.lua LevelMates/Journal.lua LevelMates/Core.lua LevelMates/Settings.lua LevelMates/LevelMates.toc LevelMates/Locales/enUS.lua LevelMates/Locales/esES.lua tools/wow-stub.lua tests/wishlist.test.lua` — `feat(wishlist): wishlist, wl message, loot notices and tooltip line`.

---

### Task 3: The Wishes tab and the "Add a wish" dialog

**Files:**
- Modify: `LevelMates/Board.lua`, `LevelMates/LevelMates.toc` (`WishDialog.lua` after `GoalDialog.lua`), locales
- Create: `LevelMates/WishDialog.lua`, `tests/board_wishes.test.lua`

**Interfaces:**
- Consumes: `ns.Wishlist.*`, `LM_WISHES_CHANGED`, `B.TAB_KEYS`/`B.TAB_LABELS` (Task 1).
- Produces: `B.tabs.wishes`, `B.WCOLS`, `B.wishAdd` (fires `LM_WISH_ADD`), `B.OpenWishMenu(id)`, `ns.WishDialog` with `frame`, `box`, `add`, `Open()`, `Refresh()`, `Capture(text)`; slash `/lm deseos`, `/lm wishlist`.

- [ ] **Step 1: Write the failing test** — `tests/board_wishes.test.lua`:

```lua
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local C, B, W, R, L = ns.Comm, ns.Board, ns.Wishlist, ns.Roster, ns.L
local function link(id, name) return "|cff1eff00|Hitem:" .. id .. "::::::::20:::::::|h[" .. (name or ("Item " .. id)) .. "]|h|r" end
STUB.guildMembers = { Tester = true, Mario = true }
R.InvalidateGuildRoster()
STUB.items[1001] = link(1001, "Cool Sword"); STUB.items[2589] = link(2589, "Linen")
STUB.Receive("LVLM", C.Encode("hb", { l = 20, z = 1421 }), "GUILD", "Mario-Testrealm")
STUB.Receive("LVLM", C.Encode("wl", { ids = "1001,4242" }), "GUILD", "Mario-Testrealm")
assert(W.Add(link(2589)))
local entries
MenuUtil.CreateContextMenu = function(owner, fn)
	entries = {}
	local root = { CreateTitle = function() end, CreateButton = function(_, text, cb) entries[#entries + 1] = { text = text, cb = cb } end }
	fn(owner, root)
end
local function visible()
	local out = {}
	for i = 1, #B.rows do if B.rows[i].button:IsShown() then out[#out + 1] = B.rows[i] end end
	return out
end

B.ShowTab("wishes")
assert(B.tab == "wishes" and B.frame.Tabs[5] == B.tabs.wishes and B.frame.selectedTab == 5, "fifth classic tab")
assert(B.headText[1].text == L.COL_WHO and B.headText[3].text == L.COL_ITEM and B.headText[5].text == L.COL_SINCE, "headers")
assert(B.rows[1].zone:GetWidth() == B.WCOLS[3], "wishes column widths")
local rows = visible()
assert(#rows == 3, "mine and Mario's two: " .. #rows)
assert(rows[1].name.text == "Tester" and rows[1].zone.text == link(2589, "Linen") and rows[1].xph.text ~= "", "mine first")
assert(rows[2].name.text == "Mario" and rows[2].zone.text == link(1001, "Cool Sword"), "Mario's")
assert(rows[3].zone.text == string.format(L.WISH_UNKNOWN, 4242), "not loaded yet")
STUB.items[4242] = link(4242, "Late Item"); STUB.itemLoads[4242]()
assert(visible()[3].zone.text == link(4242, "Late Item"), "filled in when it loads")

-- hover: the item card
rows = visible()
rows[2].button.scripts.OnEnter(rows[2].button)
assert(GameTooltip.link == "item:1001" and not GameTooltip.hidden, "item tooltip")
rows[2].button.scripts.OnLeave(rows[2].button)

-- right click: only on my own wishes
entries = nil
rows[2].button.scripts.OnClick(rows[2].button, "RightButton")
assert(entries == nil, "no menu on someone else's wish")
rows[1].button.scripts.OnClick(rows[1].button, "RightButton")
assert(entries and entries[1].text == L.WISH_REMOVE, "remove on mine")
entries[1].cb()
assert(not W.Has(2589) and #visible() == 2, "removed")

-- "Add wish" and Shift+click
assert(B.wishAdd:IsShown() and not B.myGoal:IsShown() and not B.helpButton:IsShown(), "the tab's own button")
local D = ns.WishDialog
ChatFrameUtil.InsertLink(link(3333, "Early"))
assert(not D.frame or not D.frame:IsShown(), "Shift+click with the dialog closed does nothing")
B.wishAdd.scripts.OnClick(B.wishAdd)
assert(D.frame:IsShown() and D.add.enabled == false and D.box:GetText() == "", "empty dialog")
ChatFrameUtil.InsertLink(link(3333, "Shift"))
assert(D.box:GetText() == link(3333, "Shift") and D.add.enabled == true, "the link lands in the box")
D.add.scripts.OnClick(D.add)
assert(W.Has(3333) and D.box:GetText() == "" and D.frame:IsShown(), "added; ready for the next one")
D.frame:Hide()
ChatFrameUtil.InsertLink(link(4444, "After"))
assert(D.box:GetText() == "", "closed again: nothing captured")

-- empty, other tabs, slash
for _, w in ipairs(W.List()) do if w.mine then W.Remove(w.id) end end
STUB.Receive("LVLM", C.Encode("wl", {}), "GUILD", "Mario-Testrealm")
assert(#visible() == 0 and B.frame.empty.text == L.WISH_EMPTY, "empty text")
B.tabs.mates.scripts.OnClick(B.tabs.mates)
assert(not B.wishAdd:IsShown(), "only on the Wishes tab")
B.Toggle()
SlashCmdList["LEVELMATES"]("deseos")
assert(B.frame:IsShown() and B.tab == "wishes", "/lm deseos")
```

- [ ] **Step 2: Run it** — Expected: LUA ERROR at `fifth classic tab`.

- [ ] **Step 3: Implement**

Locales — `enUS.lua`:

```lua
L.TAB_WISHES = "Wishes"; L.COL_WHO = "Who"; L.COL_ITEM = "Item"; L.COL_SINCE = "Since"
L.WISH_EMPTY = "Nobody has wishes yet. Add yours with \"Add wish\"."; L.WISH_UNKNOWN = "Item #%d"; L.WISH_REMOVE = "Remove from my list"
L.BTN_WISH_ADD = "Add wish"; L.WISH_DIALOG_TITLE = "Add a wish"; L.WISH_HINT = "Shift+click an item (bags, chat, loot...)"; L.WISH_ADD = "Add"
```
`esES.lua`:

```lua
L.TAB_WISHES = "Deseos"; L.COL_WHO = "Quién"; L.COL_ITEM = "Objeto"; L.COL_SINCE = "Desde"
L.WISH_EMPTY = "Nadie tiene deseos todavía. Añade los tuyos con \"Añadir deseo\"."; L.WISH_UNKNOWN = "Objeto #%d"; L.WISH_REMOVE = "Quitar de la lista"
L.BTN_WISH_ADD = "Añadir deseo"; L.WISH_DIALOG_TITLE = "Añadir deseo"; L.WISH_HINT = "Mayús+clic en un objeto (bolsas, chat, botín...)"; L.WISH_ADD = "Añadir"
```

`Board.lua`:

(a) After `B.GCOLS = …` add `B.WCOLS = { 100, 1, 344, 1, 74 }   -- wishes: who, -, item, -, since (same total as B.COLS)`; change `B.TAB_KEYS = { "mates", "lfg", "journal", "goals" }` to `B.TAB_KEYS = { "mates", "lfg", "journal", "goals", "wishes" }` and add `wishes = "TAB_WISHES"` to `TAB_LABELS`.

(b) Row `OnClick`: before `			if B.tab == "goals" then` insert:

```lua
			if B.tab == "wishes" then
				if mouse == "RightButton" and self.wishMine then B.OpenWishMenu(self.wishId) end
				return
			end
```

(c) Row `OnEnter`: before `			elseif B.tab == "journal" and self.entry and self.entry.link then` insert:

```lua
			elseif B.tab == "wishes" and self.wishId then   -- wishes: the item card
				GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:SetHyperlink("item:" .. self.wishId); GameTooltip:Show()
```

(d) After the `B.myGoal = myGoal` line add:

```lua

	-- Wishes tab: "Add wish" (bottom left).
	local wishAdd = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
	wishAdd:SetSize(120, 20); wishAdd:SetPoint("BOTTOMLEFT", 12, 3); wishAdd:SetText(L.BTN_WISH_ADD)
	wishAdd:SetScript("OnClick", function() ns.Fire("LM_WISH_ADD") end)
	B.wishAdd = wishAdd
```

(e) `SetHeaders`: before `	if B.tab == "goals" then` insert:

```lua
	if B.tab == "wishes" then
		B.headText[1]:SetText(L.COL_WHO); B.headText[2]:SetText(""); B.headText[3]:SetText(L.COL_ITEM)
		B.headText[4]:SetText(""); B.headText[5]:SetText(L.COL_SINCE)
		for i = 1, 5 do B.headText[i]:SetTextColor(1, 0.82, 0) end
		return
	end
```

(f) Before `function B.OpenMyGoalMenu()` add:

```lua
local function FillWishes(list)
	for i = 1, ROWS do
		local r, w = B.rows[i], list[i]
		r.button.mate, r.button.adId, r.button.entry, r.button.goalId, r.button.personalMine = nil, nil, nil, nil, nil
		r.button.wishId, r.button.wishMine = w and w.id or nil, w and w.mine or nil
		if w then
			r.icon:Hide()
			r.name:SetText(w.name); r.name:SetTextColor(unpack(w.mine and { 1, 1, 1 } or { 0.7, 0.7, 0.7 }))
			r.level:SetText("")
			r.zone:SetText(ns.Wishlist.Link(w.id) or string.format(L.WISH_UNKNOWN, w.id)); r.zone:SetTextColor(1, 1, 1)
			r.group:SetText("")
			r.xph:SetText(date("%d/%m", w.t)); r.xph:SetTextColor(0.7, 0.7, 0.7)
			r.button:Show()
			RowBg(r, i, false)
		else
			ClearRow(r)
		end
	end
end

function B.OpenWishMenu(id)
	if not ns.Wishlist.Has(id) then return end
	MenuUtil.CreateContextMenu(B.frame, function(_, root)
		root:CreateButton(L.WISH_REMOVE, function() ns.Wishlist.Remove(id) end)
	end)
end

```

(g) `RefreshTabs`: replace `	local lfg, journal, goals = B.tab == "lfg", B.tab == "journal", B.tab == "goals"\n	local mates = not lfg and not journal and not goals` with `	local lfg, journal, goals, wishes = B.tab == "lfg", B.tab == "journal", B.tab == "goals", B.tab == "wishes"\n	local mates = B.tab == "mates"`, and after `	B.myGoal:SetShown(goals)` add `	B.wishAdd:SetShown(wishes)`.

(h) `B.Refresh`:
- replace `	local lfg, journal, goals = B.tab == "lfg", B.tab == "journal", B.tab == "goals"\n	local list` with `	local lfg, journal, goals, wishes = B.tab == "lfg", B.tab == "journal", B.tab == "goals", B.tab == "wishes"\n	local list`;
- before `	elseif goals then\n		list = ns.Goals.List()` insert `	elseif wishes then\n		list = ns.Wishlist.List()`;
- replace `SetColumns(journal and B.JCOLS or goals and B.GCOLS or B.COLS)` with `SetColumns(journal and B.JCOLS or goals and B.GCOLS or wishes and B.WCOLS or B.COLS)`;
- replace `if journal then FillJournal(list) elseif goals then FillGoals(list)` with `if journal then FillJournal(list) elseif wishes then FillWishes(list) elseif goals then FillGoals(list)`;
- after `		elseif goals then emptyText = L.GOAL_EMPTY` add `		elseif wishes then emptyText = L.WISH_EMPTY`;
- replace `	if journal or goals then\n		for _, hr in ipairs(B.helpRows)` with `	if journal or goals or wishes then\n		for _, hr in ipairs(B.helpRows)`.

(i) At the end of the file:

```lua

ns.On("LM_WISHES_CHANGED", B.Refresh)
ns.Slash("deseos", function() B.ShowTab("wishes") end)
ns.Slash("wishlist", function() B.ShowTab("wishes") end)
```

`LevelMates/WishDialog.lua`:

```lua
-- WishDialog.lua: "Add a wish". While it is open, a Shift+click on any item puts its link in the box
-- (a post-hook on the client's link insertion); Wishlist.Add runs only from its Add button.
local _, ns = ...
local Dlg = {}
ns.WishDialog = Dlg
local L, W = ns.L, ns.Wishlist

local function Build()
	local f = CreateFrame("Frame", "LevelMatesWishDialog", UIParent, "BasicFrameTemplateWithInset")
	Dlg.frame = f
	f:SetSize(340, 140); f:SetPoint("CENTER"); f:SetFrameStrata("DIALOG")
	f:SetMovable(true); f:EnableMouse(true); f:SetClampedToScreen(true); f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", f.StartMoving); f:SetScript("OnDragStop", f.StopMovingOrSizing)
	if f.TitleText then f.TitleText:SetText(L.WISH_DIALOG_TITLE) end
	tinsert(UISpecialFrames, "LevelMatesWishDialog")
	f:Hide()
	local hint = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	hint:SetPoint("TOP", 0, -34); hint:SetText(L.WISH_HINT)
	local box = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
	box:SetSize(290, 22); box:SetPoint("TOP", 0, -56); box:SetAutoFocus(false); box:SetMaxLetters(255)
	box:SetScript("OnTextChanged", function() Dlg.Refresh() end)
	Dlg.box = box
	local add = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
	add:SetSize(120, 22); add:SetPoint("BOTTOMLEFT", 20, 14); add:SetText(L.WISH_ADD)
	add:SetScript("OnClick", function()
		if W.Add(box:GetText()) then box:SetText(""); Dlg.Refresh() end   -- stays open for the next one
	end)
	Dlg.add = add
	local close = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
	close:SetSize(120, 22); close:SetPoint("BOTTOMRIGHT", -20, 14); close:SetText(L.LFG_CLOSE)
	close:SetScript("OnClick", function() f:Hide() end)
end

function Dlg.Refresh()
	if Dlg.frame then Dlg.add:SetEnabled(W.ItemId(Dlg.box:GetText() or "") ~= nil) end
end

function Dlg.Open()
	if not Dlg.frame then Build() end
	Dlg.box:SetText("")
	Dlg.frame:Show()
	Dlg.Refresh()
end

-- Shift+click on an item anywhere: the client inserts its link; take it while the dialog is open.
function Dlg.Capture(text)
	if Dlg.frame and Dlg.frame:IsShown() and W.ItemId(text) then Dlg.box:SetText(text); Dlg.Refresh() end
end
if hooksecurefunc then
	if ChatFrameUtil and ChatFrameUtil.InsertLink then hooksecurefunc(ChatFrameUtil, "InsertLink", Dlg.Capture) end
	if ChatEdit_InsertLink then hooksecurefunc("ChatEdit_InsertLink", Dlg.Capture) end
end

ns.On("LM_WISH_ADD", Dlg.Open)
```

- [ ] **Step 4: Run** the test (Expected `ok`) and `npm test` (all `ok`; `board_tabs` loops over `B.TAB_KEYS`, now five).

- [ ] **Step 5: Commit** — `git add LevelMates/Board.lua LevelMates/WishDialog.lua LevelMates/LevelMates.toc LevelMates/Locales/enUS.lua LevelMates/Locales/esES.lua tests/board_wishes.test.lua` — `feat(board): Wishes tab and the Add a wish dialog with Shift+click`.

---

### Task 4: Simulation and documentation

**Files:** Modify `LevelMates/Sim.lua`, `README.md`, `CHANGELOG.md`; create `tests/sim_wishes.test.lua`.

- [ ] **Step 1: Failing test** — `tests/sim_wishes.test.lua`:

```lua
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local W = ns.Wishlist
local sentBefore = #STUB.sent
SlashCmdList["LEVELMATES"]("sim deseos")
assert(#W.List() == 4 and #W.WantedBy(2589) == 1, "two wishes each for Mario and Ana: " .. #W.List())
assert(#STUB.sent == sentBefore, "the simulation sends nothing")
SlashCmdList["LEVELMATES"]("sim off")
assert(#W.List() == 0, "sim off removes them")
```

- [ ] **Step 2: Run** — Expected: LUA ERROR at `two wishes each`.

- [ ] **Step 3: Implement** — `Sim.lua`: after `simGoals` add

```lua
local function simWishes()
	ns.Wishlist.AddSample("Mario", { 2589, 2318 })
	ns.Wishlist.AddSample("Ana", { 765, 2447 })
end
```
in `off()` add `ns.Wishlist.RemoveSamples()` on the line with the other `RemoveSamples` calls, and in the slash handler after the `metas` branch `	elseif rest == "deseos" or rest == "wishes" then simWishes()`.

README English "What it does", after the guild goals line: `- **Wishlist** (Wishes tab, or \`/lm deseos\`): up to 10 items you want, added with Shift+click; guildmates see them, item tooltips say who wants an item, and looting something a guildmate wants tells you who to pass it to.`; Spanish: `- **Lista de deseos** (pestaña Deseos, o \`/lm deseos\`): hasta 10 objetos que quieres, añadidos con Mayús+clic; la hermandad los ve, el tooltip de un objeto dice quién lo quiere y, si te cae algo que quiere un hermano, te avisa para que se lo pases.` Add `/lm deseos` and `/lm sim deseos` to both command lines. CHANGELOG: `- Wishlist: a fifth board tab (the tabs are now classic tabs under the window); up to 10 items per character added with Shift+click; shared with the guild; "Wanted by" on item tooltips; a notice when you loot a guildmate's wish. New message kind \`wl\`.`

- [ ] **Step 4: Run** `npm test` — all `ok`.

- [ ] **Step 5: Commit** — `git add LevelMates/Sim.lua tests/sim_wishes.test.lua README.md CHANGELOG.md` — `feat(wishlist): simulation and docs`.
