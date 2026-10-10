# LevelMates social block (wall, giveaways, meetups) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A guild wall tab, a giveaway market matched with wishes, and dungeon meetups on the dungeon cards.

**Architecture:** Three modules in the existing pattern (per-guild store in `ns.db`, roster-only senders, new message kinds, sends from clicks or roster hooks): `Feed.lua` (`fe`), `Gifts.lua` (`gv`, `gr`), `Meetups.lua` (`qd`, `qdx`, `qj`, `qjx`) with `MeetDialog.lua`. `Board.lua` gets a seventh tab (wall), a "gives/wants" column on Wishes and a meetup badge, tooltip lines and menu entries on dungeon cards.

**Tech Stack:** Lua 5.1 (WoW Forever 1.60.x); node + fengari tests with `tools/wow-stub.lua`.

**Spec:** `docs/superpowers/specs/2026-10-10-levelmates-social-leveling-design.md` (part A)

## Global Constraints

- Only new message kinds; only roster guildmates are believed; nothing in instances or with sharing off (`C.Send` refuses).
- Click-only actions (whisper, invite) stay in `B.Whisper/B.Invite` called from menus (policy test).
- Stored data per account and guild; others forgotten after their window (wall 7 days, gifts 30 days, meetups 3 h after the hour).
- Strings in both locale files.

## Review Focus

1. The same event arriving twice (heartbeat level-up and `fe`, re-sends to newcomers) is listed once (Task 1 tests).
2. A reservation is first-come: a second `gr` for the same gift does not steal it (Task 2 tests).
3. A meetup cannot be created in the past or more than 7 days ahead, nor more than 2 per person (Task 3 tests).
4. The reminder fires once, 15 minutes before, only for the creator and those joined (Task 3 tests).
5. Wishes tab still lists and removes wishes exactly as before (Task 2 tests).

---

### Task 1: The guild wall

**Files:** Create `LevelMates/Feed.lua`, `tests/feed.test.lua`. Modify `Comm.lua`, `Core.lua`, `Settings.lua`, `Goals.lua`, `Personal.lua`, `Board.lua`, `DiscordCopy.lua`, `LevelMates.toc` (`Feed.lua` after `Professions.lua`), locales.

**Interfaces:** Produces `ns.Feed` with `Now()`, `Add(e)`, `List(search)`, `Text(e)`, `Who(e)`, `Ago(e)`, `AddSample(who, k, a, b, minutesAgo)`, `RemoveSamples()`; events `LM_FEED_CHANGED`, `LM_GOAL_REACHED(g)` (Goals), `LM_MYGOAL_REACHED(level)` (Personal); board tab `feed`.

- [ ] **Step 1: Failing test** — `tests/feed.test.lua`:

```lua
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local C, F, J, B, R, L = ns.Comm, ns.Feed, ns.Journal, ns.Board, ns.Roster, ns.L
local function last(kind) for i = #STUB.sent, 1, -1 do local k, f = C.Decode(STUB.sent[i].msg); if k == kind then return f, i end end end
local function count(kind, from) local n = 0; for i = (from or 0) + 1, #STUB.sent do if (C.Decode(STUB.sent[i].msg)) == kind then n = n + 1 end end; return n end
local function link(id, name) return "|cff0070dd|Hitem:" .. id .. "::::::::20:::::::|h[" .. name .. "]|h|r" end
STUB.guildMembers = { Tester = true, Mario = true, Ana = true, Luis = true }
R.InvalidateGuildRoster()
assert(ns.db.settings.shareFeed == true and ns.db.settings.feedLoot == true, "defaults on")
local now = F.Now()
assert(C.Validate("fe", { k = "lvl", a = 30, t = now }) and C.Validate("fe", { k = "dun", a = 0, b = "Minas · Ana", t = now }), "fe format")
assert(C.Validate("fe", { k = "gol", a = 1, t = now }) == false and C.Validate("fe", { k = "lvl", a = 30 }) == false, "fe kinds and fields")

-- what I live goes out
J.Add("level", { level = 21 })
local f = last("fe")
assert(f and f.k == "lvl" and f.a == 21, "my level-up")
assert(F.List()[1].who == "Tester" and F.Text(F.List()[1]) == string.format(L.FEED_LVL, 21), "on my wall too")
local n = #STUB.sent
J.Add("dungeon", { name = "Ragefire Chasm", mates = {} })
assert(count("fe", n) == 0, "a dungeon alone: nothing")
J.Add("dungeon", { name = "Ragefire Chasm", mates = { "Mario" } })
assert(last("fe").k == "dun" and last("fe").b == "Ragefire Chasm · Mario", "a dungeon with guildmates")
J.Add("item", { link = link(9001, "Blue Sword"), q = 3 })
assert(last("fe").k == "itm" and last("fe").a == 9001, "rare loot")
n = #STUB.sent
J.Add("item", { link = link(9002, "Green Boots"), q = 2 })
ns.db.settings.feedLoot = false
J.Add("item", { link = link(9003, "Blue Hat"), q = 3 })
ns.db.settings.feedLoot = true
assert(count("fe", n) == 0, "green loot, or loot sharing off: nothing")
ns.Fire("LM_MYGOAL_REACHED", 25)
assert(last("fe").k == "pgl" and last("fe").a == 25, "personal goal reached")

-- guildmates'
STUB.Receive("LVLM", C.Encode("hb", { l = 29, z = 1421 }), "GUILD", "Mario-Testrealm")
STUB.Receive("LVLM", C.Encode("fe", { k = "lvl", a = 29, t = now - 5 }), "GUILD", "Mario-Testrealm")
STUB.Receive("LVLM", C.Encode("fe", { k = "lvl", a = 29, t = now - 5 }), "GUILD", "Mario-Testrealm")
STUB.Receive("LVLM", C.Encode("fe", { k = "lvl", a = 50, t = now }), "GUILD", "Nadie-Testrealm")
STUB.Receive("LVLM", C.Encode("fe", { k = "lvl", a = 31, t = now + 60 }), "GUILD", "Mario-Testrealm")
local mario = 0
for _, e in ipairs(F.List()) do if e.who == "Mario" then mario = mario + 1 end end
assert(mario == 1, "once, from the roster, not from the future")
STUB.Receive("LVLM", C.Encode("hb", { l = 30, z = 1421 }), "GUILD", "Mario-Testrealm")
STUB.Receive("LVLM", C.Encode("fe", { k = "lvl", a = 30, t = now }), "GUILD", "Mario-Testrealm")
mario = 0
for _, e in ipairs(F.List()) do if e.who == "Mario" and e.a == 30 then mario = mario + 1 end end
assert(mario == 1, "a level-up seen by heartbeat and by message: once")
ns.Fire("LM_GOAL_REACHED", { ty = "lvl", a = 20 })
local gol
for _, e in ipairs(F.List()) do if e.k == "gol" then gol = e end end
assert(gol and F.Who(gol) == L.FEED_GUILD and F.Text(gol) == string.format(L.FEED_GOL, ns.Goals.Text({ ty = "lvl", a = 20 })), "guild goal reached")
assert(#F.List("mario") >= 1 and #F.List("zzz") == 0, "search")

-- a newcomer gets my last 24 hours, at most five
n = #STUB.sent
STUB.Receive("LVLM", C.Encode("ping", {}), "GUILD", "Luis-Testrealm"); STUB.Advance(6)
local mine = count("fe", n)
assert(mine >= 1 and mine <= F.RESEND, "re-sent to a newcomer: " .. mine)

-- sharing off: on my wall, not sent
ns.db.settings.shareFeed = false
n = #STUB.sent
J.Add("level", { level = 22 })
assert(count("fe", n) == 0 and F.List()[1].a == 22, "kept locally only")
ns.db.settings.shareFeed = true

-- older than 7 days: gone
F.Add({ who = "Ana", k = "lvl", a = 10, t = now - 8 * 1440 })
for _, e in ipairs(F.List()) do assert(not (e.who == "Ana" and e.a == 10), "pruned") end

-- the tab
B.ShowTab("feed")
assert(B.frame.Tabs[7] == B.tabs.feed and B.heading.text == L.HEAD_FEED, "seventh tab")
local rows = {}
for i = 1, #B.rows do if B.rows[i].button:IsShown() then rows[#rows + 1] = B.rows[i] end end
assert(#rows == #F.List() and rows[1].zone.text == F.Text(F.List()[1]) and rows[1].xph.text == F.Ago(F.List()[1]), "rows: who, what, when")
for _, r in ipairs(rows) do
	if r.button.feedItem == 9001 then r.button.scripts.OnEnter(r.button); assert(GameTooltip.link == "item:9001", "item card on hover") end
end
assert(ns.DiscordCopy.Text("feed"):find(L.TAB_FEED, 1, true), "Copy for Discord")
```

- [ ] **Step 2: Run** — Expected: LUA ERROR at `defaults on`.

- [ ] **Step 3: Implement**

`Comm.lua` schema `fe   = { k = oneOf("lvl", "dun", "itm", "pgl"), a = int(0, 999999), b = text(60), t = int(0, 100000000) },`; REQUIRED `fe = { "k", "a", "t" }`.

`Core.lua` DEFAULTS: add `shareFeed = true, feedLoot = true,` after `shareProfessions = true,`. `Settings.lua`: after the `shareProfessions` line add `Bool(category, "shareFeed", L.OPT_FEED, L.OPT_FEED_TT)` and `Bool(category, "feedLoot", L.OPT_FEED_LOOT, L.OPT_FEED_LOOT_TT)`.

`Goals.lua` `G.CheckDone`: after `		g.announced = true` add `		ns.Fire("LM_GOAL_REACHED", g)`. `Personal.lua` `check`: after `		g.announced = true` add `		ns.Fire("LM_MYGOAL_REACHED", g.l)`.

`LevelMates/Feed.lua`:

```lua
-- Feed.lua: the guild wall. What I live (a level, a dungeon with guildmates, rare-or-better loot, my personal goal)
-- goes out in its own kind `fe`; guildmates' arrive the same way; guild goals reached and level-ups seen by
-- heartbeat are added locally. Spec 2026-10-10-levelmates-social-leveling-design (A1).
local _, ns = ...
local F = {}
ns.Feed = F
local L, C, R = ns.L, ns.Comm, ns.Roster
F.MAX, F.DAYS, F.RESEND = 200, 7, 5

local function me() return (UnitName("player")) end
function F.Now() return math.floor(time() / 60) end   -- minutes since 1970
local function store()
	ns.db.feed = ns.db.feed or {}
	local k = GetGuildInfo("player") or "?"
	ns.db.feed[k] = ns.db.feed[k] or {}
	return ns.db.feed[k]
end
-- The same event twice (a re-send, a level-up seen by heartbeat and by message) is kept once.
local function key(e)
	if e.k == "lvl" or e.k == "pgl" then return e.who .. ":" .. e.k .. ":" .. e.a end
	if e.k == "gol" then return "gol:" .. tostring(e.b) end
	return e.who .. ":" .. e.k .. ":" .. e.a .. ":" .. tostring(e.b) .. ":" .. e.t
end

function F.Add(e)
	local s, k = store(), key(e)
	for _, x in ipairs(s) do if key(x) == k then return false end end
	s[#s + 1] = e
	table.sort(s, function(a, b) return a.t > b.t end)   -- newest first
	while #s > F.MAX do table.remove(s) end
	ns.Fire("LM_FEED_CHANGED")
	return true
end

function F.Who(e) return e.k == "gol" and L.FEED_GUILD or e.who end
function F.Text(e)
	if e.k == "lvl" then return string.format(L.FEED_LVL, e.a)
	elseif e.k == "dun" then return string.format(L.FEED_DUN, e.b or "")
	elseif e.k == "itm" then return string.format(L.FEED_ITM, ns.Wishlist.Link(e.a) or string.format(L.WISH_UNKNOWN, e.a))
	elseif e.k == "pgl" then return string.format(L.FEED_PGL, e.a)
	elseif e.k == "gol" then return string.format(L.FEED_GOL, e.b or "") end
	return ""
end
function F.Ago(e) return string.format(L.FEED_AGO, ns.Journal.Duration(math.max(0, F.Now() - e.t) * 60)) end

-- Newest first, the last 7 days, of people still in the guild; filtered by name or text.
function F.List(search)
	local s, out, cutoff, q = store(), {}, F.Now() - F.DAYS * 1440, (search or ""):lower()
	for i = #s, 1, -1 do if s[i].t < cutoff then table.remove(s, i) end end
	for _, e in ipairs(s) do
		if (e.k == "gol" or e.sim or e.who == me() or R.IsGuildmate(e.who))
			and (q == "" or (F.Who(e) .. " " .. F.Text(e)):lower():find(q, 1, true)) then out[#out + 1] = e end
	end
	return out
end

local function share(k, a, b)
	local e = { who = me(), k = k, a = a or 0, b = b, t = F.Now() }
	F.Add(e)
	if ns.db.settings.shareFeed then C.Send("fe", { k = k, a = e.a, b = b, t = e.t }) end
end

ns.On("LM_JOURNAL_ADDED", function(e)
	if e.sim then return end
	if e.k == "level" then share("lvl", e.level)
	elseif e.k == "dungeon" and e.mates and #e.mates > 0 then
		share("dun", 0, ns.CutUtf8(e.name .. " · " .. table.concat(e.mates, ", "), 60))
	elseif e.k == "item" and (e.q or 0) >= 3 and ns.db.settings.feedLoot then
		local id = ns.Wishlist.ItemId(e.link)
		if id then share("itm", id) end
	end
end)
ns.On("LM_MYGOAL_REACHED", function(level) share("pgl", level) end)
ns.On("LM_GOAL_REACHED", function(g) F.Add({ who = "", k = "gol", a = 0, b = ns.Goals.Text(g), t = F.Now() }) end)
ns.On("LM_MATE_LEVELUP", function(name, level) F.Add({ who = name, k = "lvl", a = level, t = F.Now() }) end)

C.OnMessage("fe", function(f, name)
	if not R.mates[name] then return end   -- only people the roster knows
	local now = F.Now()
	if f.t > now + 10 or f.t < now - F.DAYS * 1440 then return end
	F.Add({ who = name, k = f.k, a = f.a, b = f.b, t = f.t })
end)

-- A newcomer gets what I lived in the last 24 hours (the newest five).
ns.On("LM_PING_ANSWERED", function()
	if not ns.db.settings.shareFeed then return end
	local n, cutoff = 0, F.Now() - 1440
	for _, e in ipairs(store()) do
		if n >= F.RESEND or e.t < cutoff then break end
		if e.who == me() and e.k ~= "gol" and not e.sim then
			C.Send("fe", { k = e.k, a = e.a, b = e.b, t = e.t })
			n = n + 1
		end
	end
end)

-- Simulation support (/lm sim muro): local samples, never sent.
function F.AddSample(who, k, a, b, minutesAgo) F.Add({ who = who, k = k, a = a or 0, b = b, t = F.Now() - (minutesAgo or 0), sim = true }) end
function F.RemoveSamples()
	local s = store()
	for i = #s, 1, -1 do if s[i].sim then table.remove(s, i) end end
	ns.Fire("LM_FEED_CHANGED")
end
```

`Board.lua`:
- after `B.CCOLS = …`: `B.FCOLS = { 110, 1, 313, 1, 95 }   -- wall: who, -, what, -, when (same total as B.COLS)`;
- `B.TAB_KEYS` gains `"feed"`; `TAB_LABELS` gains `feed = "TAB_FEED"`; `HEAD_KEY` gains `feed = "FEED"`; `PAGE_KEY` gains `feed = "feedPage"`;
- row `OnClick`: before `			if B.tab == "crafts" then` insert `			if B.tab == "feed" then return end`;
- row `OnEnter`: before `			elseif B.tab == "journal" and self.entry and self.entry.link then` insert:

```lua
			elseif B.tab == "feed" and self.feedItem then   -- wall: the item card
				GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:SetHyperlink("item:" .. self.feedItem); GameTooltip:Show()
```
- `SetHeaders`: before `	if B.tab == "crafts" then` (the headers one) insert:

```lua
	if B.tab == "feed" then
		B.headText[1]:SetText(L.COL_WHO); B.headText[2]:SetText(""); B.headText[3]:SetText(L.COL_WHAT)
		B.headText[4]:SetText(""); B.headText[5]:SetText(L.COL_WHEN)
		for i = 1, 5 do B.headText[i]:SetTextColor(1, 0.82, 0) end
		return
	end
```
- before `local function FillCrafts(list)` add:

```lua
local function FillFeed(list)
	for i = 1, ROWS do
		local r, e = B.rows[i], list[i]
		r.button.mate, r.button.adId, r.button.entry, r.button.goalId, r.button.personalMine = nil, nil, nil, nil, nil
		r.button.feedItem = e and e.k == "itm" and e.a or nil
		if e then
			local m = R.mates[e.who]
			r.icon:Hide()
			r.name:SetText(ns.Feed.Who(e))
			if e.k == "gol" then r.name:SetTextColor(1, 0.82, 0)
			elseif e.who == UnitName("player") then r.name:SetTextColor(ClassColor(MyClass()))
			else r.name:SetTextColor(ClassColor(m and m.class)) end
			r.level:SetText("")
			r.zone:SetText(ns.Feed.Text(e)); r.zone:SetTextColor(1, 1, 1)
			r.group:SetText("")
			r.xph:SetText(ns.Feed.Ago(e)); r.xph:SetTextColor(0.7, 0.7, 0.7)
			r.button:Show()
			RowBg(r, i, false)
		else
			ClearRow(r)
		end
	end
end

```
- `B.Refresh`/`RefreshTabs` flags: add `feed = B.tab == "feed"` (extend both `local lfg, journal, goals, wishes, crafts = …` lines with `, feed` / `, B.tab == "feed"`); list branch before `	elseif crafts then`: `	elseif feed then\n		list, pages = Page(ns.Feed.List(B.search))`; columns `… or crafts and B.CCOLS or feed and B.FCOLS or B.COLS`; fill `elseif feed then FillFeed(list)` before `elseif crafts then FillCrafts(list)`; empty `		elseif feed then emptyText = L.FEED_EMPTY` before the crafts empty line; pager `(goals or wishes or crafts or feed) and pages > 1`; help rows `journal or goals or wishes or crafts or feed`;
- at the end: `ns.On("LM_FEED_CHANGED", B.Refresh)`, `ns.Slash("muro", function() B.ShowTab("feed") end)`, `ns.Slash("wall", function() B.ShowTab("feed") end)`.

`DiscordCopy.lua`: `TAB_TITLE` gains `feed = "TAB_FEED"`; before `-- The text for a tab` add:

```lua
function builders.feed()
	local F, lines = ns.Feed, {}
	for _, e in ipairs(F.List()) do lines[#lines + 1] = string.format("• **%s** %s (%s)", F.Who(e), plain(F.Text(e):match("|H") and F.Text(e):gsub("|c%x+(|H.-|h.-|h)|r", "%1") or F.Text(e)), F.Ago(e)) end
	return lines
end
```
(the `plain()` helper turns a link into `[name]`; text without a link is passed through `plain` only when it holds one — simpler: use `F.Text(e):gsub("|c%x+|H.-|h%[(.-)%]|h|r", "[%1]")`.) Final form:

```lua
function builders.feed()
	local F, lines = ns.Feed, {}
	for _, e in ipairs(F.List()) do
		local what = F.Text(e):gsub("|c[^|]-|H.-|h%[(.-)%]|h|r", "[%1]")
		lines[#lines + 1] = string.format("• **%s** %s (%s)", F.Who(e), what, F.Ago(e))
	end
	return lines
end
```

Locales — enUS:

```lua
L.TAB_FEED = "Wall"; L.HEAD_FEED = "Guild wall"; L.SUB_FEED = "What has been happening in the guild (last 7 days)."; L.SEARCH_FEED = "Name or text..."
L.COL_WHAT = "What"; L.COL_WHEN = "When"; L.FEED_EMPTY = "Nothing on the wall yet."; L.FEED_GUILD = "Guild"; L.FEED_AGO = "%s ago"
L.FEED_LVL = "reached level %d"; L.FEED_DUN = "went to %s"; L.FEED_ITM = "got %s"; L.FEED_PGL = "reached their goal: level %d"; L.FEED_GOL = "goal reached: %s"
L.OPT_FEED = "Share on the wall"; L.OPT_FEED_TT = "Your level-ups, dungeons with guildmates and goals appear on guildmates' wall."
L.OPT_FEED_LOOT = "Loot on the wall"; L.OPT_FEED_LOOT_TT = "Rare (blue) or better items you loot appear on the wall."
```
esES:

```lua
L.TAB_FEED = "Muro"; L.HEAD_FEED = "Muro de la hermandad"; L.SUB_FEED = "Lo que ha pasado en la hermandad (últimos 7 días)."; L.SEARCH_FEED = "Nombre o texto..."
L.COL_WHAT = "Qué"; L.COL_WHEN = "Cuándo"; L.FEED_EMPTY = "Todavía no hay nada en el muro."; L.FEED_GUILD = "Hermandad"; L.FEED_AGO = "hace %s"
L.FEED_LVL = "subió a nivel %d"; L.FEED_DUN = "fue a %s"; L.FEED_ITM = "consiguió %s"; L.FEED_PGL = "cumplió su meta: nivel %d"; L.FEED_GOL = "meta cumplida: %s"
L.OPT_FEED = "Compartir en el muro"; L.OPT_FEED_TT = "Tus subidas de nivel, mazmorras con hermanos y metas salen en el muro de los hermanos."
L.OPT_FEED_LOOT = "Botín en el muro"; L.OPT_FEED_LOOT_TT = "Los objetos raros (azules) o mejores que consigues salen en el muro."
```

- [ ] **Step 4: Run** test and `npm test` (`board_tabs` loops over 7 keys). **Step 5: Commit** — `feat(feed): the guild wall`.

---

### Task 2: Giveaways matched with wishes

**Files:** Create `LevelMates/Gifts.lua`, `tests/gifts.test.lua`. Modify `Comm.lua`, `Wishlist.lua` (fire `LM_WISH_ADDED`), `WishDialog.lua` (mode), `Board.lua`, `DiscordCopy.lua`, `LevelMates.toc` (`Gifts.lua` after `Wishlist.lua`), locales.

**Interfaces:** Produces `ns.Gifts` with `MAX`, `Has(id)`, `Add(text)`, `Remove(id)`, `Reserve(giver, id)`, `List()` (rows `{ name, id, t, mine?, reservedBy? }`), `GivenBy(id)`, `AddSample(name, ids)`, `RemoveSamples()`; `ns.WishDialog.Open(mode)` with mode `"wish"`/`"gift"`; event `LM_GIFT_ADD`; `B.giftAdd`.

- [ ] **Step 1: Failing test** — `tests/gifts.test.lua`:

```lua
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local C, B, W, GF, R, L = ns.Comm, ns.Board, ns.Wishlist, ns.Gifts, ns.Roster, ns.L
local function link(id, name) return "|cff1eff00|Hitem:" .. id .. "::::::::20:::::::|h[" .. (name or ("Item " .. id)) .. "]|h|r" end
local function last(kind) for i = #STUB.sent, 1, -1 do local k, f = C.Decode(STUB.sent[i].msg); if k == kind then return f end end end
local function said(text) for _, p in ipairs(STUB.printed) do if p:find(text, 1, true) then return true end end; return false end
STUB.guildMembers = { Tester = true, Mario = true, Ana = true, Luis = true }
R.InvalidateGuildRoster()
for _, n in ipairs({ "Mario", "Ana", "Luis" }) do STUB.Receive("LVLM", C.Encode("hb", { l = 20, z = 1421 }), "GUILD", n .. "-Testrealm") end
for id = 1, 12 do STUB.items[1000 + id] = link(1000 + id, "Thing " .. id) end

assert(C.Validate("gv", {}) and C.Validate("gv", { ids = "1001,1002" }) and C.Validate("gr", { i = 1001, to = "Ana" }) and C.Validate("gr", { i = 1001 }) == false, "formats")

-- my giveaways
assert(GF.Add(link(1001)) and GF.Has(1001) and last("gv").ids == 1001, "added and shared")
assert(not GF.Add(link(1001)) and said(L.GIFT_DUP), "no duplicates")
for id = 1002, 1010 do assert(GF.Add(link(id))) end
assert(not GF.Add(link(1011)) and said(string.format(L.GIFT_FULL, GF.MAX)), "at most 10")
for id = 1003, 1010 do GF.Remove(id) end

-- matching both ways
assert(W.Add(link(1011)))
STUB.Receive("LVLM", C.Encode("gv", { ids = "1011,1012" }), "GUILD", "Ana-Testrealm")
assert(said(string.format(L.GIFT_FOR_YOU, "Ana", link(1011, "Thing 11"))), "Ana gives what I want")
STUB.Receive("LVLM", C.Encode("wl", { ids = "1002" }), "GUILD", "Mario-Testrealm")
assert(said(string.format(L.GIFT_WANTED, "Mario", link(1002, "Thing 2"))), "Mario wants what I give")
STUB.Receive("LVLM", C.Encode("gv", { ids = "1006" }), "GUILD", "Luis-Testrealm")
assert(W.Add(link(1006)) and said(string.format(L.GIFT_FOR_YOU, "Luis", link(1006, "Thing 6"))), "a new wish finds a giveaway")
assert(#GF.GivenBy(1011) == 1 and GF.GivenBy(1011)[1] == "Ana", "who gives it")

-- reserving: first come
assert(GF.Reserve("Ana", 1011) and last("gr").i == 1011 and last("gr").to == "Ana", "I reserve Ana's")
STUB.Receive("LVLM", C.Encode("gr", { i = 1002, to = "Tester" }), "GUILD", "Mario-Testrealm")
assert(GF.Has(1002).reservedBy == "Mario" and said(string.format(L.GIFT_RESERVED, "Mario", link(1002, "Thing 2"))), "Mario reserves mine")
STUB.Receive("LVLM", C.Encode("gr", { i = 1002, to = "Tester" }), "GUILD", "Luis-Testrealm")
assert(GF.Has(1002).reservedBy == "Mario", "first come")

-- tooltip
local lines = {}
GameTooltip.AddLine = function(self, t) lines[#lines + 1] = t end
STUB.TooltipPost(Enum.TooltipDataType.Item, GameTooltip, { id = 1011 })
local found = false
for _, l in ipairs(lines) do if l == string.format(L.GIFT_TOOLTIP, "Ana") then found = true end end
assert(found, "tooltip: who gives it")

-- the Wishes tab: wants and gives
local entries
MenuUtil.CreateContextMenu = function(owner, fn)
	entries = {}
	local root = { CreateTitle = function() end, CreateButton = function(_, text, cb) entries[#entries + 1] = { text = text, cb = cb } end }
	fn(owner, root)
end
B.ShowTab("wishes")
assert(B.giftAdd:IsShown() and B.wishAdd:IsShown(), "both buttons")
assert(B.headText[4].text == L.COL_KIND, "the gives/wants column")
local function rowFor(name, id, kind) for i = 1, #B.rows do local r = B.rows[i]; if r.button:IsShown() and r.name.text == name and r.button.wishId == id and r.group.text == kind then return r end end end
local mineGift, anaGift, myWish = rowFor("Tester", 1002, L.GIVES), rowFor("Ana", 1012, L.GIVES), rowFor("Tester", 1011, L.WANTS)
assert(mineGift and anaGift and myWish, "rows for both kinds")
assert(mineGift.zone.text:find(string.format(L.GIFT_RESERVED_BY, "Mario"), 1, true), "reserved shown")
anaGift.button.scripts.OnClick(anaGift.button, "RightButton")
assert(entries[1].text == L.GIFT_RESERVE, "reserve a guildmate's gift")
entries[1].cb()
assert(last("gr").i == 1012, "reserved from the menu")
mineGift.button.scripts.OnClick(mineGift.button, "RightButton")
assert(entries[#entries].text == L.GIFT_REMOVE, "remove my gift")
entries[#entries].cb()
assert(not GF.Has(1002), "removed")
myWish.button.scripts.OnClick(myWish.button, "RightButton")
assert(entries[1].text == L.WISH_REMOVE, "my wish: as before")

-- the dialog in gift mode
B.giftAdd.scripts.OnClick(B.giftAdd)
local D = ns.WishDialog
assert(D.frame:IsShown() and D.mode == "gift", "gift mode")
ChatFrameUtil.InsertLink(link(1005))
D.add.scripts.OnClick(D.add)
assert(GF.Has(1005) and not W.Has(1005), "added as a gift")
D.frame:Hide()
B.wishAdd.scripts.OnClick(B.wishAdd)
assert(D.mode == "wish", "back to wish mode")
```

- [ ] **Step 2: Run** — Expected: LUA ERROR at `formats`.

- [ ] **Step 3: Implement**

`Comm.lua`: schemas `gv   = { ids = itemids(10) },` and `gr   = { i = int(1, 999999), to = text(24) },`; REQUIRED `gv = {}, gr = { "i", "to" }`; `LATEST_ONLY` gains `gv = true`.

`Wishlist.lua` `W.Add`: after `	list[#list + 1] = { id = id, t = time() }` add `	ns.Fire("LM_WISH_ADDED", id)`.

`LevelMates/Gifts.lua`:

```lua
-- Gifts.lua: the giveaway market. Items I give away (up to 10) go out in `gv` (as wishes do in `wl`); a guildmate
-- reserves one with `gr`, first come. Giveaways and wishes are matched both ways with a notice.
-- Spec 2026-10-10-levelmates-social-leveling-design (A2).
local _, ns = ...
local GF = {}
ns.Gifts = GF
local L, C, R, W = ns.L, ns.Comm, ns.Roster, ns.Wishlist
GF.MAX, GF.FORGET_DAYS = 10, 30

local function me() return (UnitName("player")) end
local function mine() ns.char.gifts = ns.char.gifts or {}; return ns.char.gifts end
local function theirs()
	ns.db.gifts = ns.db.gifts or {}
	local k = GetGuildInfo("player") or "?"
	ns.db.gifts[k] = ns.db.gifts[k] or {}
	return ns.db.gifts[k]
end
local function link(id) return W.Link(id) or string.format(L.WISH_UNKNOWN, id) end

function GF.Has(id) for _, g in ipairs(mine()) do if g.id == id then return g end end end

-- A refused send stays pending in the character's saved data and goes out after the next heartbeat.
local sentAt
local function send(prio)
	local ids = {}
	for _, g in ipairs(mine()) do ids[#ids + 1] = g.id end
	local fields = {}
	if #ids > 0 then fields.ids = table.concat(ids, ",") end
	if C.Send("gv", fields, prio) then ns.char.giftPending, sentAt = nil, GetTime(); return true end
	ns.char.giftPending = true
	return false
end
local function resend() if sentAt ~= GetTime() then send() end end

-- Others' giveaways: updated in the last 30 days, by someone still in the guild (or a sample).
local function others()
	local t, out, cutoff = theirs(), {}, time() - GF.FORGET_DAYS * 86400
	for name, l in pairs(t) do
		if l.t < cutoff then t[name] = nil
		elseif name ~= me() and (l.sim or R.IsGuildmate(name)) then out[#out + 1] = { name = name, ids = l.ids, t = l.t, reserved = l.reserved or {} } end
	end
	table.sort(out, function(a, b) return a.name < b.name end)
	return out
end

-- Matches, told once per person and item each session.
local told = {}
local function tell(key, fmt, ...) if told[key] then return end; told[key] = true; ns.Notice(fmt, ...) end

-- Called from a click (the dialog in gift mode).
function GF.Add(text)
	local id = W.ItemId(text)
	if not id then ns.Say(L.WISH_NOT_ITEM); return false end
	if GF.Has(id) then ns.Say(L.GIFT_DUP); return false end
	local list = mine()
	if #list >= GF.MAX then ns.Say(L.GIFT_FULL, GF.MAX); return false end
	list[#list + 1] = { id = id, t = time() }
	send("now")
	for _, name in ipairs(W.WantedBy(id)) do if name ~= me() then tell(name .. ":w:" .. id, L.GIFT_WANTED, name, link(id)) end end
	ns.Fire("LM_WISHES_CHANGED")
	return true
end

function GF.Remove(id)
	local list = mine()
	for i, g in ipairs(list) do
		if g.id == id then table.remove(list, i); send("now"); ns.Fire("LM_WISHES_CHANGED"); return true end
	end
	return false
end

-- Called from a click (a row's menu): reserve a guildmate's giveaway.
function GF.Reserve(giver, id)
	local e = theirs()[giver]
	if not e then return false end
	if not C.Send("gr", { i = id, to = giver }, "now") then ns.Say(L.HELP_NEEDS_SHARE); return false end
	e.reserved = e.reserved or {}
	e.reserved[id] = e.reserved[id] or me()
	ns.Fire("LM_WISHES_CHANGED")
	return true
end

function GF.List()
	local out = {}
	for _, g in ipairs(mine()) do out[#out + 1] = { name = me(), id = g.id, t = g.t, mine = true, reservedBy = g.reservedBy } end
	for _, o in ipairs(others()) do
		for _, id in ipairs(o.ids) do out[#out + 1] = { name = o.name, id = id, t = o.t, reservedBy = o.reserved[id] } end
	end
	return out
end

function GF.GivenBy(id)
	local names = {}
	if GF.Has(id) then names[#names + 1] = me() end
	for _, o in ipairs(others()) do for _, x in ipairs(o.ids) do if x == id then names[#names + 1] = o.name; break end end end
	table.sort(names)
	return names
end

C.OnMessage("gv", function(f, name)
	if not R.mates[name] then return end
	local t = theirs()
	if f.ids == nil then
		t[name] = nil
	else
		local old = t[name] and t[name].reserved or {}
		local ids, reserved = {}, {}
		for id in tostring(f.ids):gmatch("%d+") do id = tonumber(id); ids[#ids + 1] = id; reserved[id] = old[id] end
		t[name] = { ids = ids, t = time(), reserved = reserved }
		for _, id in ipairs(ids) do if W.Has(id) then tell(name .. ":g:" .. id, L.GIFT_FOR_YOU, name, link(id)) end end
	end
	ns.Fire("LM_WISHES_CHANGED")
end)

-- A guildmate's wishes against my giveaways (the wishlist module stores them).
C.OnMessage("wl", function(f, name)
	if not R.mates[name] or f.ids == nil then return end
	for id in tostring(f.ids):gmatch("%d+") do
		id = tonumber(id)
		if GF.Has(id) then tell(name .. ":w:" .. id, L.GIFT_WANTED, name, link(id)) end
	end
end)

-- My new wish against guildmates' giveaways.
ns.On("LM_WISH_ADDED", function(id)
	for _, o in ipairs(others()) do
		for _, x in ipairs(o.ids) do if x == id then tell(o.name .. ":g:" .. id, L.GIFT_FOR_YOU, o.name, link(id)) end end
	end
end)

C.OnMessage("gr", function(f, name)
	if not R.mates[name] then return end
	if f.to == me() then
		local g = GF.Has(f.i)
		if not g or (g.reservedBy and g.reservedBy ~= name) then return end   -- first come
		local first = g.reservedBy == nil
		g.reservedBy = name
		if first then ns.Notice(L.GIFT_RESERVED, name, link(f.i)) end
	else
		local e = theirs()[f.to]
		if not e then return end
		e.reserved = e.reserved or {}
		e.reserved[f.i] = e.reserved[f.i] or name
	end
	ns.Fire("LM_WISHES_CHANGED")
end)

ns.On("LM_PING_ANSWERED", function() if #mine() > 0 then resend() end end)
ns.On("LM_ANNOUNCED", function() if #mine() > 0 then resend() end end)
ns.On("LM_HB_SENT", function() if ns.char.giftPending then send() end end)
ns.On("LM_COMM_DROPPED", function(kind) if kind == "gv" then ns.char.giftPending = true end end)

if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
	TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
		if not ns.db or (tooltip ~= GameTooltip and tooltip ~= ItemRefTooltip) or not data or not data.id then return end
		local names = GF.GivenBy(data.id)
		if #names > 0 then tooltip:AddLine(string.format(L.GIFT_TOOLTIP, table.concat(names, ", ")), 1, 0.82, 0) end
	end)
end

-- Simulation support (/lm sim mercadillo): local samples, never sent.
function GF.AddSample(name, ids) theirs()[name] = { ids = ids, t = time(), sim = true, reserved = {} }; ns.Fire("LM_WISHES_CHANGED") end
function GF.RemoveSamples()
	local t = theirs()
	for name, l in pairs(t) do if l.sim then t[name] = nil end end
	ns.Fire("LM_WISHES_CHANGED")
end
```

`WishDialog.lua`:
- replace `function Dlg.Open()\n	if not Dlg.frame then Build() end\n	Dlg.box:SetText("")` with `function Dlg.Open(mode)\n	if not Dlg.frame then Build() end\n	Dlg.mode = mode == "gift" and "gift" or "wish"\n	if Dlg.frame.TitleText then Dlg.frame.TitleText:SetText(Dlg.mode == "gift" and L.GIFT_DIALOG_TITLE or L.WISH_DIALOG_TITLE) end\n	Dlg.box:SetText("")`;
- in the Add button's `OnClick`, replace `if W.Add(box:GetText()) then` with `if (Dlg.mode == "gift" and ns.Gifts.Add or W.Add)(box:GetText()) then`;
- replace `ns.On("LM_WISH_ADD", Dlg.Open)` with `ns.On("LM_WISH_ADD", function() Dlg.Open("wish") end)\nns.On("LM_GIFT_ADD", function() Dlg.Open("gift") end)`.

`Board.lua`:
- `B.WCOLS = { 100, 1, 344, 1, 74 }` → `B.WCOLS = { 100, 1, 280, 65, 74 }   -- wishes and gifts: who, -, item, wants/gives, since (same total as B.COLS)`;
- after `	B.wishAdd = wishAdd` add:

```lua
	local giftAdd = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
	giftAdd:SetSize(120, 20); giftAdd:SetPoint("BOTTOMRIGHT", -12, 3); giftAdd:SetText(L.BTN_GIFT_ADD)
	giftAdd:SetScript("OnClick", function() ns.Fire("LM_GIFT_ADD") end)
	B.giftAdd = giftAdd
```
- `RefreshTabs`: after `	B.wishAdd:SetShown(wishes)` add `	B.giftAdd:SetShown(wishes)`;
- wishes headers: replace `		B.headText[4]:SetText(""); B.headText[5]:SetText(L.COL_SINCE)` with `		B.headText[4]:SetText(L.COL_KIND); B.headText[5]:SetText(L.COL_SINCE)`;
- row `OnClick` wishes branch: replace `				if mouse == "RightButton" and self.wishMine then B.OpenWishMenu(self.wishId) end` with `				if mouse == "RightButton" and self.wishId then B.OpenWishMenu(self.wishId, self.wishKind, self.wishMine, self.wishName) end`;
- `FillWishes`: replace the line `		r.button.wishId, r.button.wishMine = w and w.id or nil, w and w.mine or nil` with `		r.button.wishId, r.button.wishMine, r.button.wishKind, r.button.wishName = w and w.id or nil, w and w.mine or nil, w and w.kind or nil, w and w.name or nil`; replace `			r.zone:SetText(ns.Wishlist.Link(w.id) or string.format(L.WISH_UNKNOWN, w.id)); r.zone:SetTextColor(1, 1, 1)\n			r.group:SetText("")` with:

```lua
			local item = ns.Wishlist.Link(w.id) or string.format(L.WISH_UNKNOWN, w.id)
			if w.reservedBy then item = item .. "  " .. string.format(L.GIFT_RESERVED_BY, w.reservedBy) end
			r.zone:SetText(item); r.zone:SetTextColor(1, 1, 1)
			r.group:SetText(w.kind == "give" and L.GIVES or L.WANTS)
			r.group:SetTextColor(unpack(w.kind == "give" and { 1, 0.82, 0 } or { 0.4, 1, 0.4 }))
```
- replace the whole `function B.OpenWishMenu(id) … end` with:

```lua
function B.OpenWishMenu(id, kind, mine, name)
	if kind == "give" then
		if mine then
			MenuUtil.CreateContextMenu(B.frame, function(_, root) root:CreateButton(L.GIFT_REMOVE, function() ns.Gifts.Remove(id) end) end)
		else
			local row
			for _, g in ipairs(ns.Gifts.List()) do if g.name == name and g.id == id then row = g end end
			if row and not row.reservedBy then
				MenuUtil.CreateContextMenu(B.frame, function(_, root) root:CreateButton(L.GIFT_RESERVE, function() ns.Gifts.Reserve(name, id) end) end)
			end
		end
		return
	end
	if not mine or not ns.Wishlist.Has(id) then return end
	MenuUtil.CreateContextMenu(B.frame, function(_, root)
		root:CreateButton(L.WISH_REMOVE, function() ns.Wishlist.Remove(id) end)
	end)
end
```
- `B.Refresh` wishes list: replace `		list, pages = Page(ns.Wishlist.List())` with:

```lua
		local all = {}
		for _, w in ipairs(ns.Wishlist.List()) do w.kind = "want"; all[#all + 1] = w end
		for _, g in ipairs(ns.Gifts.List()) do g.kind = "give"; all[#all + 1] = g end
		list, pages = Page(all)
```
- wishes empty text: `		elseif wishes then emptyText = L.WISH_EMPTY` stays.

`DiscordCopy.lua` `builders.wishes`: before `	return lines` add:

```lua
	local gives, gorder = {}, {}
	for _, g in ipairs(ns.Gifts.List()) do
		if not gives[g.name] then gives[g.name] = {}; gorder[#gorder + 1] = g.name end
		local l = W.Link(g.id)
		table.insert(gives[g.name], (l and plain(l) or string.format(L.WISH_UNKNOWN, g.id)) .. (g.reservedBy and (" (" .. string.format(L.GIFT_RESERVED_BY, g.reservedBy) .. ")") or ""))
	end
	for _, name in ipairs(gorder) do lines[#lines + 1] = string.format("• **%s** %s: %s", name, L.GIVES, table.concat(gives[name], ", ")) end
```

Locales — enUS:

```lua
L.BTN_GIFT_ADD = "Give away"; L.GIFT_DIALOG_TITLE = "Give an item away"; L.COL_KIND = "Kind"; L.WANTS = "wants"; L.GIVES = "gives"
L.GIFT_DUP = "That item is already in your giveaways."; L.GIFT_FULL = "You give away at most %d items."
L.GIFT_FOR_YOU = "%s gives away %s, which is on your list. Right-click their row to reserve it."; L.GIFT_WANTED = "%s wants %s, which you give away."
L.GIFT_RESERVED = "%s reserves your %s."; L.GIFT_RESERVED_BY = "reserved by %s"; L.GIFT_RESERVE = "Reserve"; L.GIFT_REMOVE = "Remove from my giveaways"; L.GIFT_TOOLTIP = "Given away by: %s"
```
esES:

```lua
L.BTN_GIFT_ADD = "Regalar"; L.GIFT_DIALOG_TITLE = "Regalar un objeto"; L.COL_KIND = "Tipo"; L.WANTS = "quiere"; L.GIVES = "regala"
L.GIFT_DUP = "Ese objeto ya está en tus regalos."; L.GIFT_FULL = "Puedes regalar como mucho %d objetos."
L.GIFT_FOR_YOU = "%s regala %s, que está en tu lista. Clic derecho en su fila para reservarlo."; L.GIFT_WANTED = "%s quiere %s, que tú regalas."
L.GIFT_RESERVED = "%s reserva tu %s."; L.GIFT_RESERVED_BY = "reservado por %s"; L.GIFT_RESERVE = "Reservar"; L.GIFT_REMOVE = "Quitar de mis regalos"; L.GIFT_TOOLTIP = "Lo regala: %s"
```

- [ ] **Step 4: Run** test and `npm test` (`board_wishes` still `ok`: wishes rows, menu and dialog unchanged for wishes). **Step 5: Commit** — `feat(gifts): giveaways matched with wishes`.

---

### Task 3: Dungeon meetups

**Files:** Create `LevelMates/Meetups.lua`, `LevelMates/MeetDialog.lua`, `tests/meetups.test.lua`. Modify `Comm.lua`, `Board.lua`, `LevelMates.toc` (`Meetups.lua` after `LFG.lua`; `MeetDialog.lua` after `LfgDialog.lua`), `tools/wow-stub.lua`, locales.

**Interfaces:** Produces `ns.Meetups` with `MAX`, `PER_PERSON`, `REMIND`, `Now()`, `List(dungeonId?)`, `When(m)`, `Create(d, at, note)`, `Cancel(id)`, `Join(id, role)`, `Leave(id)`, `MyRole(id)`, `Tick()`, `AddSample(by, d, minutesFromNow, joined)`, `RemoveSamples()`; event `LM_MEETUPS_CHANGED`, `LM_MEET_HERE(d)`; `ns.MeetDialog` with `Open(d)`, `At()`, `dayOffset`, `hour`, `minute`, `dayButton`, `hourButton`, `minuteButton`, `note`, `ok`; card field `badge`.

- [ ] **Step 1: Stub** — in `tools/wow-stub.lua` replace `function date(fmt) return "00:00:00" end` with:

```lua
function date(fmt, t)
	if fmt == "*t" then   -- UTC is this stub's "local time"; 1970-01-01 was a Thursday (wday 5)
		t = t or time()
		local s = t % 86400
		return { year = 2025, month = 10, day = 9, hour = math.floor(s / 3600), min = math.floor(s % 3600 / 60), sec = s % 60, wday = (math.floor(t / 86400) + 4) % 7 + 1 }
	end
	return "00:00:00"
end
```

- [ ] **Step 2: Failing test** — `tests/meetups.test.lua`:

```lua
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local C, B, M, D, R, L = ns.Comm, ns.Board, ns.Meetups, ns.Dungeons, ns.Roster, ns.L
local function last(kind) for i = #STUB.sent, 1, -1 do local k, f = C.Decode(STUB.sent[i].msg); if k == kind then return f end end end
local function said(text) local n = 0; for _, p in ipairs(STUB.printed) do if p:find(text, 1, true) then n = n + 1 end end; return n end
STUB.guildMembers = { Tester = true, Mario = true, Ana = true, Luis = true }
R.InvalidateGuildRoster()
for _, n in ipairs({ "Mario", "Ana", "Luis" }) do STUB.Receive("LVLM", C.Encode("hb", { l = 20, z = 1421 }), "GUILD", n .. "-Testrealm") end
local now = M.Now()
local entries
MenuUtil.CreateContextMenu = function(owner, fn)
	entries = {}
	local root = { CreateTitle = function() end, CreateButton = function(_, text, cb) entries[#entries + 1] = { text = text, cb = cb } end }
	fn(owner, root)
end
local function pick(text) for _, e in ipairs(entries) do if e.text == text then e.cb(); return true end end; return false end

assert(C.Validate("qd", { id = "m1", d = 5, at = now + 60 }) and C.Validate("qdx", { id = "m1" }) and C.Validate("qj", { id = "m1", r = "H" }) and C.Validate("qjx", { id = "m1" }), "formats")
assert(C.Validate("qj", { id = "m1", r = "X" }) == false and C.Validate("qd", { id = "m1", d = 5 }) == false, "limits")

-- creating
assert(not M.Create(5, now + 2, "") and not M.Create(5, now + 8 * 1440, ""), "not now, not past 7 days")
assert(M.Create(5, now + 60, "traed agua"), "created")
local f = last("qd")
assert(f.d == 5 and f.at == now + 60 and f.n == "traed agua", "shared")
assert(M.Create(2, now + 120, "") and not M.Create(4, now + 180, "") and said(L.MEET_FULL) == 1, "two per person")
local mine = M.List(5)[1]
assert(M.When(mine) == string.format("%s %02d:%02d", L["DAY_" .. date("*t", mine.at * 60).wday], date("*t", mine.at * 60).hour, date("*t", mine.at * 60).min), "day and time")

-- guildmates join mine; I am told
STUB.Receive("LVLM", C.Encode("qj", { id = mine.id, r = "H" }), "GUILD", "Ana-Testrealm")
assert(mine.joined.Ana == "H" and said(string.format(L.MEET_JOINED, "Ana", D.Name(5), M.When(mine), L.ROLE_H)) == 1, "Ana joins")
STUB.Receive("LVLM", C.Encode("qj", { id = mine.id, r = "D" }), "GUILD", "Nadie-Testrealm")
assert(not mine.joined.Nadie, "strangers cannot")
STUB.Receive("LVLM", C.Encode("qjx", { id = mine.id }), "GUILD", "Ana-Testrealm")
assert(not mine.joined.Ana, "Ana leaves")

-- a guildmate's meetup; I join it from the card
STUB.Receive("LVLM", C.Encode("qd", { id = "mario01", d = 4, at = now + 30, n = "vamos" }), "GUILD", "Mario-Testrealm")
assert(said(string.format(L.MEET_NEW, "Mario", D.Name(4), M.When({ at = now + 30 }))) == 1, "new meetup notice")
STUB.Receive("LVLM", C.Encode("qd", { id = "mario01", d = 4, at = now + 30 }), "GUILD", "Ana-Testrealm")
assert(M.List(4)[1].by == "Mario", "only its creator re-sends it")
B.ShowTab("lfg")
local card
for _, c in ipairs(B.cards) do if c:IsShown() and c.dungeonId == 4 then card = c end end
assert(card.badge:IsShown() and card.badge.text == M.When(M.List(4)[1]) .. " · 1", "the card shows the next meetup")
card.scripts.OnClick(card, "LeftButton")
assert(pick(string.format(L.MEET_JOIN, M.When(M.List(4)[1]), L.ROLE_T)), "join as tank")
assert(last("qj").id == "mario01" and last("qj").r == "T" and M.MyRole("mario01") == "T", "qj sent, remembered")
card.scripts.OnEnter(card)
assert(table.concat(GameTooltip.lines, "\n"):find("Tester", 1, true), "the tooltip lists who joined")
card.scripts.OnClick(card, "LeftButton")
assert(pick(string.format(L.MEET_LEAVE, M.When(M.List(4)[1]))) and last("qjx").id == "mario01", "leave")
assert(M.Join("mario01", "T"), "join again")

-- reminder: 15 minutes before, once, only if mine or joined
STUB.Receive("LVLM", C.Encode("qd", { id = "ana00001", d = 6, at = now + 20 }), "GUILD", "Ana-Testrealm")
STUB.Advance(16 * 60)
M.Tick(); M.Tick()
assert(said(string.format(L.MEET_SOON, D.Name(4), M.When(M.List(4)[1]))) == 1, "reminded once for the joined one")
assert(said(string.format(L.MEET_SOON, D.Name(6), M.When(M.List(6)[1]))) == 0, "not for one I did not join")

-- cancel mine; the creator's cancel removes it everywhere
card = nil
for _, c in ipairs(B.cards) do if c:IsShown() and c.dungeonId == 5 then card = c end end
card.scripts.OnClick(card, "LeftButton")
assert(pick(string.format(L.MEET_CANCEL, M.When(M.List(5)[1]))) and last("qdx") and #M.List(5) == 0, "cancelled")
STUB.Receive("LVLM", C.Encode("qdx", { id = "mario01" }), "GUILD", "Ana-Testrealm")
assert(#M.List(4) == 1, "nobody else can cancel it")
STUB.Receive("LVLM", C.Encode("qdx", { id = "mario01" }), "GUILD", "Mario-Testrealm")
assert(#M.List(4) == 0 and not M.MyRole("mario01"), "Mario cancels it")

-- newcomers get my meetups and joins
STUB.Receive("LVLM", C.Encode("qd", { id = "luis0001", d = 3, at = now + 300 }), "GUILD", "Luis-Testrealm")
assert(M.Join("luis0001", "D"))
local n = #STUB.sent
STUB.Receive("LVLM", C.Encode("ping", {}), "GUILD", "Ana-Testrealm"); STUB.Advance(6)
local qd, qj = 0, 0
for i = n + 1, #STUB.sent do local k, ff = C.Decode(STUB.sent[i].msg); if k == "qd" then qd = qd + 1 elseif k == "qj" and ff.id == "luis0001" then qj = qj + 1 end end
assert(qd == 1 and qj == 1, "re-sent: my meetup and my join")

-- gone 3 hours after the hour
STUB.Advance(8 * 3600)
assert(#M.List() == 0, "expired")

-- the dialog
ns.Fire("LM_MEET_HERE", 5)
local Dlg = ns.MeetDialog
assert(Dlg.frame:IsShown() and Dlg.dungeon == 5, "opens on the card's dungeon")
Dlg.dayOffset, Dlg.hour, Dlg.minute = 1, 21, 30
local t = date("*t")
local expect = math.floor((time() - (t.hour * 3600 + t.min * 60 + t.sec) + 86400 + 21 * 3600 + 30 * 60) / 60)
assert(Dlg.At() == expect, "tomorrow 21:30")
Dlg.ok.scripts.OnClick(Dlg.ok)
assert(last("qd").at == expect and not Dlg.frame:IsShown(), "created from the dialog")
```

- [ ] **Step 3: Run** — Expected: LUA ERROR at `formats`.

- [ ] **Step 4: Implement**

`Comm.lua`: schemas
```lua
	qd   = { id = word(8), d = int(1, 99), at = int(0, 100000000), n = text(40) },
	qdx  = { id = word(8) },
	qj   = { id = word(8), r = oneOf("T", "H", "D") },
	qjx  = { id = word(8) },
```
REQUIRED `qd = { "id", "d", "at" }, qdx = { "id" }, qj = { "id", "r" }, qjx = { "id" }`.

`LevelMates/Meetups.lua`:

```lua
-- Meetups.lua: dungeon meetups ("Deadmines, Saturday 21:00"), made from a dungeon card, joined with a role and
-- reminded 15 minutes before. Kinds qd/qdx (meetup, cancel) and qj/qjx (join, leave).
-- Spec 2026-10-10-levelmates-social-leveling-design (A3).
local _, ns = ...
local M = {}
ns.Meetups = M
local L, C, R, D = ns.L, ns.Comm, ns.Roster, ns.Dungeons
M.MAX, M.PER_PERSON, M.KEEP, M.REMIND = 10, 2, 180, 15   -- at once, per creator, minutes kept after the hour, reminder
local ROLES = { T = true, H = true, D = true }

local function me() return (UnitName("player")) end
function M.Now() return math.floor(time() / 60) end   -- minutes since 1970
local function store()
	ns.db.meetups = ns.db.meetups or {}
	local k = GetGuildInfo("player") or "?"
	ns.db.meetups[k] = ns.db.meetups[k] or {}
	return ns.db.meetups[k]
end
local function myJoins() ns.char.meetJoins = ns.char.meetJoins or {}; return ns.char.meetJoins end
local function newId() return string.format("%04x%04x", math.random(0, 65535), math.random(0, 65535)):sub(1, 8) end
local function prune()
	local s = store()
	for id, m in pairs(s) do if M.Now() > m.at + M.KEEP then s[id] = nil; myJoins()[id] = nil end end
end
local function count(by)
	local n = 0
	for _, m in pairs(store()) do if not by or m.by == by then n = n + 1 end end
	return n
end
local function changed() ns.Fire("LM_MEETUPS_CHANGED") end

-- Soonest first; of one dungeon when given.
function M.List(dungeonId)
	prune()
	local out = {}
	for _, m in pairs(store()) do
		if (not dungeonId or m.d == dungeonId) and (m.sim or m.by == me() or R.IsGuildmate(m.by)) then out[#out + 1] = m end
	end
	table.sort(out, function(a, b) if a.at ~= b.at then return a.at < b.at end; return a.id < b.id end)
	return out
end

function M.When(m)
	local t = date("*t", m.at * 60)
	return string.format("%s %02d:%02d", L["DAY_" .. t.wday], t.hour, t.min)
end
function M.MyRole(id) return myJoins()[id] end

-- Called from a click (the meetup dialog). at: minutes since 1970.
function M.Create(d, at, note)
	if not D.Get(d) then return false end
	if not C.IsReady() then ns.Say(L.HELP_NEEDS_SHARE); return false end
	if type(at) ~= "number" or at < M.Now() + 5 or at > M.Now() + 7 * 1440 then ns.Say(L.MEET_BAD_TIME); return false end
	prune()
	if count(me()) >= M.PER_PERSON or count() >= M.MAX then ns.Say(L.MEET_FULL); return false end
	local clean = strtrim(tostring(note or "")):gsub("[%c|]", "")
	clean = ns.CutUtf8(clean, 40)
	local m = { id = newId(), d = d, at = at, n = clean ~= "" and clean or nil, by = me(), joined = {} }
	if not C.Send("qd", { id = m.id, d = d, at = at, n = m.n }, "now") then return false end
	store()[m.id] = m
	changed()
	return true
end

function M.Cancel(id)
	local m = store()[id]
	if not m or m.by ~= me() then return false end
	C.Send("qdx", { id = id }, "now")
	store()[id] = nil
	changed()
	return true
end

function M.Join(id, role)
	local m = store()[id]
	if not m or m.by == me() or not ROLES[role] then return false end
	if not C.Send("qj", { id = id, r = role }, "now") then ns.Say(L.HELP_NEEDS_SHARE); return false end
	myJoins()[id] = role
	m.joined = m.joined or {}
	m.joined[me()] = role
	changed()
	return true
end

function M.Leave(id)
	if not myJoins()[id] then return false end
	if not C.Send("qjx", { id = id }, "now") then ns.Say(L.HELP_NEEDS_SHARE); return false end
	myJoins()[id] = nil
	local m = store()[id]
	if m and m.joined then m.joined[me()] = nil end
	changed()
	return true
end

C.OnMessage("qd", function(f, name)
	if not R.mates[name] or not D.Get(f.d) then return end
	if f.at < M.Now() - M.KEEP or f.at > M.Now() + 8 * 1440 then return end
	local s = store()
	local m = s[f.id]
	if m and m.by ~= name then return end   -- an id belongs to whoever made it
	if not m then
		prune()
		if count(name) >= M.PER_PERSON or count() >= M.MAX then return end
		m = { id = f.id, by = name, joined = {} }
		s[f.id] = m
		if ns.db.settings.lfgNotices then ns.Notice(L.MEET_NEW, name, D.Name(f.d), M.When({ at = f.at })) end
	end
	m.d, m.at, m.n = f.d, f.at, f.n
	changed()
end)

C.OnMessage("qdx", function(f, name)
	local m = store()[f.id]
	if m and m.by == name then store()[f.id] = nil; myJoins()[f.id] = nil; changed() end
end)

C.OnMessage("qj", function(f, name)
	if not R.mates[name] then return end
	local m = store()[f.id]
	if not m or m.by == name then return end
	m.joined = m.joined or {}
	local new = m.joined[name] == nil
	m.joined[name] = f.r
	if new and m.by == me() then ns.Notice(L.MEET_JOINED, name, D.Name(m.d), M.When(m), L["ROLE_" .. f.r]) end
	changed()
end)

C.OnMessage("qjx", function(f, name)
	local m = store()[f.id]
	if m and m.joined and m.joined[name] then m.joined[name] = nil; changed() end
end)

-- A newcomer gets my meetups and my joins.
ns.On("LM_PING_ANSWERED", function()
	for _, m in ipairs(M.List()) do
		if m.by == me() and not m.sim then C.Send("qd", { id = m.id, d = m.d, at = m.at, n = m.n }) end
	end
	for id, role in pairs(myJoins()) do if store()[id] then C.Send("qj", { id = id, r = role }) end end
end)

-- The reminder: 15 minutes before, once, for mine and the ones I joined.
local reminded = {}
function M.Tick()
	for _, m in ipairs(M.List()) do
		local left = m.at - M.Now()
		if not reminded[m.id] and left >= 0 and left <= M.REMIND and (m.by == me() or myJoins()[m.id]) then
			reminded[m.id] = true
			ns.Notice(L.MEET_SOON, D.Name(m.d), M.When(m))
		end
	end
end
ns.On("LM_WORLD", function() if not M.ticker then M.ticker = C_Timer.NewTicker(30, M.Tick) end end)

-- Simulation support (/lm sim quedada): local samples, never sent.
function M.AddSample(by, d, minutesFromNow, joined)
	local id = "sim" .. by:sub(1, 3):lower() .. d
	store()[id] = { id = id, by = by, d = d, at = M.Now() + minutesFromNow, joined = joined or {}, sim = true }
	changed()
end
function M.RemoveSamples()
	local s = store()
	for id, m in pairs(s) do if m.sim then s[id] = nil end end
	changed()
end
```

`LevelMates/MeetDialog.lua`:

```lua
-- MeetDialog.lua: "Meet here..." from a dungeon card: day, hour, minutes and a note. Meetups.Create runs only
-- from its Create button.
local _, ns = ...
local Dlg = { dayOffset = 0, hour = 21, minute = 0 }
ns.MeetDialog = Dlg
local L, D, M = ns.L, ns.Dungeons, ns.Meetups
local MINUTES = { 0, 15, 30, 45 }

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

function Dlg.DayName(offset)
	if offset == 0 then return L.MEET_TODAY elseif offset == 1 then return L.MEET_TOMORROW end
	return L["DAY_" .. date("*t", time() + offset * 86400).wday]
end

-- Minutes since 1970 for the chosen day (0 = today), hour and minute, in this PC's local time.
function Dlg.At()
	local now, t = time(), date("*t")
	local midnight = now - (t.hour * 3600 + t.min * 60 + t.sec)
	return math.floor((midnight + Dlg.dayOffset * 86400 + Dlg.hour * 3600 + Dlg.minute * 60) / 60)
end

local function Labels()
	Dlg.dayButton:SetText(Dlg.DayName(Dlg.dayOffset))
	Dlg.hourButton:SetText(string.format("%02d h", Dlg.hour))
	Dlg.minuteButton:SetText(string.format(":%02d", Dlg.minute))
end

local function Build()
	local f = CreateFrame("Frame", "LevelMatesMeetDialog", UIParent, "BasicFrameTemplateWithInset")
	Dlg.frame = f
	f:SetSize(330, 190); f:SetPoint("CENTER"); f:SetFrameStrata("DIALOG")
	f:SetMovable(true); f:EnableMouse(true); f:SetClampedToScreen(true); f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", f.StartMoving); f:SetScript("OnDragStop", f.StopMovingOrSizing)
	tinsert(UISpecialFrames, "LevelMatesMeetDialog")
	f:Hide()
	Dlg.dayButton = Button(f, 130, "TOPLEFT", 16, -36, "", function(self)
		local items = {}
		for o = 0, 6 do items[#items + 1] = { Dlg.DayName(o), function() Dlg.dayOffset = o; Labels() end } end
		Menu(self, items)
	end)
	Dlg.hourButton = Button(f, 80, "TOPLEFT", 152, -36, "", function(self)
		local items = {}
		for h = 0, 23 do items[#items + 1] = { string.format("%02d h", h), function() Dlg.hour = h; Labels() end } end
		Menu(self, items)
	end)
	Dlg.minuteButton = Button(f, 70, "TOPLEFT", 238, -36, "", function(self)
		local items = {}
		for _, mm in ipairs(MINUTES) do items[#items + 1] = { string.format(":%02d", mm), function() Dlg.minute = mm; Labels() end } end
		Menu(self, items)
	end)
	local hint = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	hint:SetPoint("TOPLEFT", 20, -70); hint:SetText(L.MEET_NOTE_HINT)
	local note = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
	note:SetSize(286, 22); note:SetPoint("TOPLEFT", 22, -86); note:SetAutoFocus(false); note:SetMaxLetters(40)
	Dlg.note = note
	Dlg.ok = Button(f, 130, "BOTTOMLEFT", 16, 14, L.MEET_CREATE, function()
		if M.Create(Dlg.dungeon, Dlg.At(), Dlg.note:GetText()) then f:Hide() end   -- a refused meetup keeps the dialog open
	end)
	Button(f, 130, "BOTTOMRIGHT", -16, 14, L.LFG_CLOSE, function() f:Hide() end)
end

function Dlg.Open(d)
	if not D.Get(d) then return end
	if not Dlg.frame then Build() end
	Dlg.dungeon = d
	if Dlg.frame.TitleText then Dlg.frame.TitleText:SetText(string.format(L.MEET_TITLE, D.Name(d))) end
	Dlg.note:SetText("")
	Labels()
	Dlg.frame:Show()
end

ns.On("LM_MEET_HERE", Dlg.Open)
```

`Board.lua`:
- in the card build loop, after the `c.count = …` line add `		c.badge = c:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); c.badge:SetPoint("TOPLEFT", c.art, "TOPLEFT", 3, -3)`;
- in `FillGrid`, after `			c.count:SetText(…)` add:

```lua
			local meet = ns.Meetups.List(id)[1]
			if meet then
				local n = 1
				for _ in pairs(meet.joined or {}) do n = n + 1 end
				c.badge:SetText(ns.Meetups.When(meet) .. " · " .. n); c.badge:Show()
			else
				c.badge:SetText(""); c.badge:Hide()
			end
```
- in `B.DungeonTooltip`, before `	GameTooltip:Show()` add:

```lua
	for _, m in ipairs(ns.Meetups.List(d.id)) do
		local who = {}
		for name, role in pairs(m.joined or {}) do who[#who + 1] = name .. " (" .. L["ROLE_" .. role] .. ")" end
		table.sort(who)
		GameTooltip:AddLine(string.format(L.MEET_LINE, ns.Meetups.When(m), m.by) .. (m.n and (": " .. m.n) or ""), 0.6, 0.8, 1, true)
		if #who > 0 then GameTooltip:AddLine("   " .. string.format(L.LFJ_JOINED, table.concat(who, ", ")), 0.4, 1, 0.4, true) end
	end
```
- in `B.OpenDungeonMenu`, replace `		root:CreateButton(L.LFG_HERE, function() ns.Fire("LM_LFG_HERE", id) end)` with:

```lua
		for _, m in ipairs(ns.Meetups.List(id)) do
			local when = ns.Meetups.When(m)
			if m.by == UnitName("player") then
				root:CreateButton(string.format(L.MEET_CANCEL, when), function() ns.Meetups.Cancel(m.id) end)
			elseif ns.Meetups.MyRole(m.id) then
				root:CreateButton(string.format(L.MEET_LEAVE, when), function() ns.Meetups.Leave(m.id) end)
			else
				for _, role in ipairs({ "T", "H", "D" }) do
					root:CreateButton(string.format(L.MEET_JOIN, when, L["ROLE_" .. role]), function() ns.Meetups.Join(m.id, role) end)
				end
			end
		end
		root:CreateButton(L.MEET_HERE, function() ns.Fire("LM_MEET_HERE", id) end)
		root:CreateButton(L.LFG_HERE, function() ns.Fire("LM_LFG_HERE", id) end)
```
- at the end: `ns.On("LM_MEETUPS_CHANGED", B.Refresh)`.

Locales — enUS:

```lua
L.DAY_1 = "Sun"; L.DAY_2 = "Mon"; L.DAY_3 = "Tue"; L.DAY_4 = "Wed"; L.DAY_5 = "Thu"; L.DAY_6 = "Fri"; L.DAY_7 = "Sat"
L.MEET_TODAY = "Today"; L.MEET_TOMORROW = "Tomorrow"; L.MEET_TITLE = "Meet at %s"; L.MEET_NOTE_HINT = "Note (optional, up to 40 characters)"; L.MEET_CREATE = "Create"
L.MEET_HERE = "Meet here..."; L.MEET_JOIN = "Join the %s meetup as %s"; L.MEET_LEAVE = "Leave the %s meetup"; L.MEET_CANCEL = "Cancel the %s meetup"
L.MEET_LINE = "Meetup %s (%s)"; L.MEET_NEW = "%s set a %s meetup for %s."; L.MEET_JOINED = "%s joins your %s meetup (%s) as %s."
L.MEET_SOON = "Your %s meetup (%s) starts in 15 minutes!"; L.MEET_BAD_TIME = "Pick a time from now to 7 days ahead."; L.MEET_FULL = "Too many meetups: at most 2 yours and 10 in the guild."
```
esES:

```lua
L.DAY_1 = "dom"; L.DAY_2 = "lun"; L.DAY_3 = "mar"; L.DAY_4 = "mié"; L.DAY_5 = "jue"; L.DAY_6 = "vie"; L.DAY_7 = "sáb"
L.MEET_TODAY = "Hoy"; L.MEET_TOMORROW = "Mañana"; L.MEET_TITLE = "Quedar en %s"; L.MEET_NOTE_HINT = "Nota (opcional, hasta 40 caracteres)"; L.MEET_CREATE = "Crear"
L.MEET_HERE = "Quedar aquí..."; L.MEET_JOIN = "Me apunto a la quedada del %s como %s"; L.MEET_LEAVE = "Me borro de la quedada del %s"; L.MEET_CANCEL = "Cancelar la quedada del %s"
L.MEET_LINE = "Quedada %s (%s)"; L.MEET_NEW = "%s ha quedado para %s el %s."; L.MEET_JOINED = "%s se apunta a tu quedada de %s (%s) como %s."
L.MEET_SOON = "¡Tu quedada de %s (%s) empieza en 15 minutos!"; L.MEET_BAD_TIME = "Elige una hora de ahora a 7 días vista."; L.MEET_FULL = "Demasiadas quedadas: como mucho 2 tuyas y 10 en la hermandad."
```

- [ ] **Step 5: Run** test and `npm test` (`board_lfg` and `lfg_join` still `ok`: their menu entries remain). **Step 6: Commit** — `feat(meetups): dungeon meetups on the cards`.

---

### Task 4: Simulation and documentation

**Files:** Modify `Sim.lua`, `README.md`, `CHANGELOG.md`; create `tests/sim_social.test.lua`.

- [ ] **Step 1: Failing test** — `tests/sim_social.test.lua`:

```lua
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local sent = #STUB.sent
SlashCmdList["LEVELMATES"]("sim muro")
SlashCmdList["LEVELMATES"]("sim mercadillo")
SlashCmdList["LEVELMATES"]("sim quedada")
assert(#ns.Feed.List() >= 4, "wall samples")
assert(#ns.Gifts.List() == 3, "giveaway samples")
assert(#ns.Meetups.List() == 2, "meetup samples")
assert(#STUB.sent == sent, "nothing sent")
SlashCmdList["LEVELMATES"]("sim off")
assert(#ns.Feed.List() == 0 and #ns.Gifts.List() == 0 and #ns.Meetups.List() == 0, "sim off removes them")
```

- [ ] **Step 2: Run** — Expected: LUA ERROR at `wall samples`.

- [ ] **Step 3: Implement** — `Sim.lua`, after `simLevel`:

```lua
local function simWall()
	local F = ns.Feed
	F.AddSample("Mario", "lvl", 31, nil, 20)
	F.AddSample("Ana", "dun", 0, "Minas de la Muerte · Mario, Luis", 95)
	F.AddSample("Luis", "itm", 2318, nil, 180)
	F.AddSample("Ana", "pgl", 25, nil, 400)
end
local function simGifts()
	ns.Gifts.AddSample("Ana", { 2589, 765 })
	ns.Gifts.AddSample("Luis", { 2318 })
end
local function simMeetups()
	ns.Meetups.AddSample("Mario", 5, 90, { Ana = "H" })
	ns.Meetups.AddSample("Ana", 4, 24 * 60, {})
end
```
`off()`: add `ns.Feed.RemoveSamples(); ns.Gifts.RemoveSamples(); ns.Meetups.RemoveSamples()`; slash: `	elseif rest == "muro" or rest == "wall" then simWall()`, `	elseif rest == "mercadillo" or rest == "gifts" then simGifts()`, `	elseif rest == "quedada" or rest == "meetup" then simMeetups()` after the `nivel` branch.

README (both languages): the wall (`/lm muro`), giveaways on the Wishes tab, meetups on dungeon cards; add `/lm muro` and the three sim commands to the command lines. CHANGELOG: one line per feature with the new kinds (`fe`; `gv`, `gr`; `qd`, `qdx`, `qj`, `qjx`).

- [ ] **Step 4: Run** `npm test`. **Step 5: Commit** — `feat: social block simulation and docs`.
