# LevelMates extras Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Per-tab headings, screen notices with a version notice, congratulating level-ups, your leveling pace, a shared professions directory (sixth tab) and "join" on dungeon cards.

**Architecture:** `Core.lua` gains `ns.Screen`/`ns.Notice`; `Version.lua` and `Cheers.lua` listen to heartbeats and roster events; `Journal.lua` computes the pace; `Professions.lua` shares ranks in a new kind `pf` and feeds a sixth tab; `LFG.lua` gains `lfj`/`lfjx` joins shown in the card tooltip and menu.

**Tech Stack:** Lua 5.1 (WoW Forever 1.60.x); node + fengari tests with `tools/wow-stub.lua`.

**Spec:** `docs/superpowers/specs/2026-10-10-levelmates-extras-design.md`

## Global Constraints

- New wire data only in new kinds (`pf`, `lfj`, `lfjx`); never new `hb` fields.
- Sending only from clicks or the roster hooks; refused whole-state sends stay pending in `ns.char` (pattern of `Wishlist.lua`).
- Only roster guildmates are believed; stored data of others is per account and guild, forgotten after 30 days.
- Strings in both locale files.

## Review Focus

1. A guildmate seen for the first time (or after expiring) is not "levelled up" (Task 3 tests).
2. Joins survive an ad re-send (keepalive/newcomer) and vanish with the ad (Task 6 tests).
3. Turning "share professions" off withdraws them at once (Task 4 tests).
4. Screen notices never show raw link codes (Task 1 tests).
5. A development checkout (version "dev") never claims a newer version exists (Task 1 tests).

---

### Task 1: Screen notices and the version notice

**Files:** Modify `Core.lua`, `Settings.lua`, `LFG.lua`, `Help.lua`, `Partner.lua`, `Goals.lua`, `Personal.lua`, `Wishlist.lua`, `LevelMates.toc` (`Version.lua` after `Roster.lua`), locales, `tools/wow-stub.lua`; create `Version.lua`, `tests/notices.test.lua`.

**Interfaces:** Produces `ns.Screen(text)`, `ns.Notice(fmt, ...)`, `ns.Version.Newer(a, b)`; settings `screenNotices`, `levelNotices`, `shareProfessions` (defaults true; the last two used by Tasks 3-4).

- [ ] **Step 1: Stub** — append to `tools/wow-stub.lua`:

```lua

-- Screen notices
UIErrorsFrame = { messages = {}, AddMessage = function(self, text) self.messages[#self.messages + 1] = text end }
```

- [ ] **Step 2: Failing test** — `tests/notices.test.lua`:

```lua
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local C, L, V = ns.Comm, ns.L, ns.Version
assert(ns.db.settings.screenNotices == true and ns.db.settings.levelNotices == true and ns.db.settings.shareProfessions == true, "defaults on")
ns.Notice("Hola %s", "Ana")
assert(STUB.printed[#STUB.printed]:find("Hola Ana", 1, true) and UIErrorsFrame.messages[#UIErrorsFrame.messages] == "Hola Ana", "chat and screen")
ns.Notice("%s", "|cff1eff00|Hitem:1::::|h[Boots]|h|r")
assert(UIErrorsFrame.messages[#UIErrorsFrame.messages] == "[Boots]", "no link codes on screen: " .. UIErrorsFrame.messages[#UIErrorsFrame.messages])
ns.db.settings.screenNotices = false
local n = #UIErrorsFrame.messages
ns.Notice("Adios")
assert(#UIErrorsFrame.messages == n and STUB.printed[#STUB.printed]:find("Adios", 1, true), "option off: chat only")
ns.db.settings.screenNotices = true

-- an ad for my level reaches the screen
STUB.player.level = 15
STUB.Receive("LVLM", C.Encode("hb", { l = 16, z = 1421 }), "GUILD", "Mario-Testrealm")
STUB.Receive("LVLM", C.Encode("lfg", { d = 2, r = "T", id = "ad000001", m = 20 }), "GUILD", "Mario-Testrealm")
assert(UIErrorsFrame.messages[#UIErrorsFrame.messages]:find("Mario", 1, true), "LFG notice on screen")

-- versions
assert(V.Newer("0.2.0", "0.1.9") and V.Newer("1.0", "0.9.9") and V.Newer("v0.1.1", "0.1.0"), "newer")
assert(not V.Newer("0.1.0", "0.1.0") and not V.Newer("0.1.0", "0.2") and not V.Newer("dev", "0.1.0") and not V.Newer("0.2.0", "dev"), "not newer")
ns.VERSION = "0.1.0"
STUB.Receive("LVLM", C.Encode("hb", { l = 16, z = 1421, v = "0.1.0" }), "GUILD", "Mario-Testrealm")
local said = 0
local function count() said = 0; for _, p in ipairs(STUB.printed) do if p:find(string.format(L.VERSION_NEW, "0.2.0"), 1, true) then said = said + 1 end end; return said end
assert(count() == 0, "same version: nothing")
STUB.Receive("LVLM", C.Encode("hb", { l = 16, z = 1421, v = "0.2.0" }), "GUILD", "Mario-Testrealm")
STUB.Receive("LVLM", C.Encode("hb", { l = 16, z = 1421, v = "0.2.0" }), "GUILD", "Mario-Testrealm")
assert(count() == 1, "newer: told once")
```

- [ ] **Step 3: Run** — Expected: LUA ERROR at `defaults on`.

- [ ] **Step 4: Implement**

`Core.lua` DEFAULTS: add `screenNotices = true, levelNotices = true, shareProfessions = true,` after `wishNotices = true,`. After `function ns.Say(...)` add:

```lua
-- Important notices: the chat line, and the same text in the middle of the screen when the option is on
-- (links shown as their plain "[name]").
function ns.Screen(text)
	if not (ns.db and ns.db.settings.screenNotices and UIErrorsFrame) then return end
	local plain = text:gsub("|H.-|h(.-)|h", "%1"):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
	UIErrorsFrame:AddMessage(plain, 1, 0.82, 0)
end
function ns.Notice(fmt, ...)
	local text = string.format(fmt, ...)
	ns.Say("%s", text)
	ns.Screen(text)
end
```

`Settings.lua`: after the `wishNotices` line add `Bool(category, "screenNotices", L.OPT_SCREEN, L.OPT_SCREEN_TT)` and `Bool(category, "levelNotices", L.OPT_LEVELUP, L.OPT_LEVELUP_TT)`.

Switch to `ns.Notice` (same arguments): `LFG.lua` `ns.Say(L.LFG_NOTICE, …)`; `Help.lua` `ns.Say(L.HELP_NOTICE, …)`; `Partner.lua` `ns.Say(L.PAL_NOTICE, …)`; `Goals.lua` both `ns.Say(L.GOAL_REACHED, …)` and `ns.Say(L.GOAL_NEW, …)`; `Personal.lua` `ns.Say(L.MYGOAL_REACHED, …)`; `Wishlist.lua` `ns.Say(L.WISH_GOT, …)` and `ns.Say(L.WISH_THEY_WANT, …)`.

`LevelMates/Version.lua`:

```lua
-- Version.lua: a guildmate on a newer LevelMates (the heartbeat's v) gets me a notice, once a session.
local _, ns = ...
local V = {}
ns.Version = V
local L, C = ns.L, ns.Comm

local function parts(v)
	local a, b, c = tostring(v or ""):match("^v?(%d+)%.(%d+)%.?(%d*)$")
	if not a then return nil end
	return { tonumber(a), tonumber(b), tonumber(c) or 0 }
end

-- Whether version a is newer than b; false when either is not "x.y" or "x.y.z" (a development checkout).
function V.Newer(a, b)
	local x, y = parts(a), parts(b)
	if not x or not y then return false end
	for i = 1, 3 do if x[i] ~= y[i] then return x[i] > y[i] end end
	return false
end

local told = false
C.OnMessage("hb", function(f)
	if told or not f.v or not V.Newer(f.v, ns.VERSION) then return end
	told = true
	ns.Notice(L.VERSION_NEW, f.v)
end)
```

Locales — enUS: `L.OPT_SCREEN = "Screen notices"; L.OPT_SCREEN_TT = "Important notices also in the middle of the screen."; L.OPT_LEVELUP = "Guildmates' level-ups"; L.OPT_LEVELUP_TT = "A chat line with a [Congratulate] link when a guildmate levels up."; L.VERSION_NEW = "There is a newer LevelMates (%s). Update when you can."`. esES: `L.OPT_SCREEN = "Avisos en pantalla"; L.OPT_SCREEN_TT = "Los avisos importantes también en el centro de la pantalla."; L.OPT_LEVELUP = "Subidas de nivel de hermanos"; L.OPT_LEVELUP_TT = "Una línea en el chat con un enlace [Felicitar] cuando un hermano sube de nivel."; L.VERSION_NEW = "Hay una versión nueva de LevelMates (%s). Actualiza cuando puedas."`.

- [ ] **Step 5: Run** test and `npm test`. **Step 6: Commit** — `feat: screen notices and the newer-version notice`.

---

### Task 2: Per-tab headings and your pace

**Files:** Modify `Board.lua`, `Journal.lua`, locales; create `tests/board_heads.test.lua`.

**Interfaces:** Produces `J.Pace()` (`{ avg, fastest, fastestTook, toMax? }` or nil), `J.PaceText()`; locale keys `HEAD_<TAB>`, `SUB_<TAB>`, `SEARCH_<TAB>` for MATES, LFG, JOURNAL, GOALS, WISHES, CRAFTS.

- [ ] **Step 1: Failing test** — `tests/board_heads.test.lua`:

```lua
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local B, J, L = ns.Board, ns.Journal, ns.L
STUB.player.level = 20
for _, tab in ipairs({ "mates", "lfg", "goals", "wishes" }) do
	B.ShowTab(tab)
	local k = string.upper(tab)
	assert(B.heading.text == L["HEAD_" .. k] and B.subtitle.text == L["SUB_" .. k], "heading and help for " .. tab)
	assert(not B.searchBox.Instructions or B.searchBox.Instructions.text == L["SEARCH_" .. k], "search hint for " .. tab)
end
B.ShowTab("journal")
assert(B.heading.text == L.HEAD_JOURNAL and B.subtitle.text == L.SUB_JOURNAL and J.Pace() == nil, "no pace yet")
J.Add("level", { level = 10, from = 9, took = 3600 })
J.Add("level", { level = 11, from = 10, took = 1800 })
J.Add("level", { level = 12, from = 11, took = 2400 })
J.Add("level", { level = 13, sim = true, from = 12, took = 10 })
local p = J.Pace()
assert(p and p.avg == 2600 and p.fastest == 11 and p.fastestTook == 1800 and p.toMax == 2600 * 40, "average, fastest, to 60")
B.Refresh()
assert(B.subtitle.text == J.PaceText() and J.PaceText():find(J.Duration(2600), 1, true), "pace as the journal's help line")
STUB.player.level = 60
assert(J.Pace().toMax == nil and not J.PaceText():find(L.PACE_TO_MAX:gsub("%%s", ""), 1, true), "no projection at 60")
```

- [ ] **Step 2: Run** — Expected: LUA ERROR at `heading and help for mates`.

- [ ] **Step 3: Implement**

`Journal.lua`, after `J.Duration`:

```lua
-- Pace from the levels with a recorded time: the average of the last five, the fastest, and a rough time to 60.
function J.Pace()
	local times = {}
	for _, e in ipairs(J.List("level", "")) do if e.took and not e.sim then times[#times + 1] = e end end   -- newest first
	if #times < 2 then return nil end
	local n, sum = math.min(5, #times), 0
	for i = 1, n do sum = sum + times[i].took end
	local fastest = times[1]
	for _, e in ipairs(times) do if e.took < fastest.took then fastest = e end end
	local avg, left = sum / n, math.max(0, 60 - UnitLevel("player"))
	return { avg = avg, fastest = fastest.level, fastestTook = fastest.took, toMax = left > 0 and avg * left or nil }
end
function J.PaceText()
	local p = J.Pace()
	if not p then return nil end
	local text = string.format(L.PACE, J.Duration(p.avg), p.fastest, J.Duration(p.fastestTook))
	if p.toMax then text = text .. string.format(L.PACE_TO_MAX, J.Duration(p.toMax)) end
	return text
end
```

`Board.lua`: after `B.TAB_LABELS = TAB_LABELS` add `local HEAD_KEY = { mates = "MATES", lfg = "LFG", journal = "JOURNAL", goals = "GOALS", wishes = "WISHES", crafts = "CRAFTS" }`. In `B.Refresh`, after `SetHeaders()` add:

```lua
	local hk = HEAD_KEY[B.tab] or "MATES"
	B.heading:SetText(L["HEAD_" .. hk])
	B.subtitle:SetText(journal and ns.Journal.PaceText() or L["SUB_" .. hk])
	if B.searchBox and B.searchBox.Instructions then B.searchBox.Instructions:SetText(L["SEARCH_" .. hk]) end
```
(the search box must be stored as `B.searchBox`; it already is.)

Locales — enUS:

```lua
L.HEAD_MATES = "Guildmates online"; L.SUB_MATES = "Right-click a name: invite, whisper or waypoint."; L.SEARCH_MATES = "Search name..."
L.HEAD_LFG = "Dungeons"; L.SUB_LFG = "Click a card: join, whisper, invite or look for a group there."; L.SEARCH_LFG = "Dungeon or player..."
L.HEAD_JOURNAL = "My journal"; L.SUB_JOURNAL = "Your journey: levels, quests, dungeons, loot..."; L.SEARCH_JOURNAL = "Search text..."
L.HEAD_GOALS = "Goals"; L.SUB_GOALS = "Guild goals and personal goals."; L.SEARCH_GOALS = "Search..."
L.HEAD_WISHES = "Wishes"; L.SUB_WISHES = "Shift+click an item to add it; right-click yours to remove it."; L.SEARCH_WISHES = "Item or name..."
L.HEAD_CRAFTS = "Professions"; L.SUB_CRAFTS = "Who has each profession and at what rank. Right-click: whisper."; L.SEARCH_CRAFTS = "Profession or name..."
L.PACE = "Pace: %s per level · fastest: level %d in %s"; L.PACE_TO_MAX = " · level 60 in ~%s"
```
esES:

```lua
L.HEAD_MATES = "Hermanos conectados"; L.SUB_MATES = "Clic derecho: invitar, susurrar o punto de ruta."; L.SEARCH_MATES = "Buscar nombre..."
L.HEAD_LFG = "Mazmorras"; L.SUB_LFG = "Clic en una tarjeta: apuntarte, susurrar, invitar o buscar grupo ahí."; L.SEARCH_LFG = "Mazmorra o jugador..."
L.HEAD_JOURNAL = "Mi diario"; L.SUB_JOURNAL = "Tu viaje: niveles, misiones, mazmorras, botín..."; L.SEARCH_JOURNAL = "Buscar texto..."
L.HEAD_GOALS = "Metas"; L.SUB_GOALS = "Metas de la hermandad y metas personales."; L.SEARCH_GOALS = "Buscar..."
L.HEAD_WISHES = "Deseos"; L.SUB_WISHES = "Mayús+clic en un objeto para añadirlo; clic derecho en el tuyo para quitarlo."; L.SEARCH_WISHES = "Objeto o nombre..."
L.HEAD_CRAFTS = "Oficios"; L.SUB_CRAFTS = "Quién tiene cada profesión y a qué nivel. Clic derecho: susurrar."; L.SEARCH_CRAFTS = "Profesión o nombre..."
L.PACE = "Ritmo: %s por nivel · el más rápido: nivel %d en %s"; L.PACE_TO_MAX = " · nivel 60 en ~%s"
```

- [ ] **Step 4: Run** test and `npm test`. **Step 5: Commit** — `feat(board): per-tab headings and your leveling pace`.

---

### Task 3: Congratulate level-ups

**Files:** Modify `Roster.lua`, `LevelMates.toc` (`Cheers.lua` after `Version.lua`), locales, `tools/wow-stub.lua`; create `Cheers.lua`, `tests/cheers.test.lua`.

**Interfaces:** Produces event `LM_MATE_LEVELUP(name, level)`, `ns.Cheers.Link(name, level)`, `ns.Cheers.OnLink(link)`.

- [ ] **Step 1: Stub** — append:

```lua

-- EventRegistry callbacks (addon chat links arrive as "SetItemRef")
EventRegistry = { callbacks = {} }
function EventRegistry:RegisterCallback(event, fn, owner) self.callbacks[event] = self.callbacks[event] or {}; table.insert(self.callbacks[event], { fn = fn, owner = owner }) end
function STUB.ClickLink(link) for _, c in ipairs(EventRegistry.callbacks.SetItemRef or {}) do c.fn(c.owner, link, link, "LeftButton") end end
```

- [ ] **Step 2: Failing test** — `tests/cheers.test.lua`:

```lua
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local C, L = ns.Comm, ns.L
local function hb(name, level) STUB.Receive("LVLM", C.Encode("hb", { l = level, z = 1421 }), "GUILD", name .. "-Testrealm") end
local function lines(text) local n = 0; for _, p in ipairs(STUB.printed) do if p:find(text, 1, true) then n = n + 1 end end; return n end
hb("Mario", 20); hb("Ana", 30)
assert(lines(string.format(L.LEVELUP_NOTICE, "Mario", 20)) == 0 and lines(string.format(L.LEVELUP_NOTICE, "Ana", 30)) == 0, "first sight is not a level-up")
hb("Mario", 20)
assert(lines("Mario") == 0, "same level: nothing")
hb("Mario", 21)
assert(lines(string.format(L.LEVELUP_NOTICE, "Mario", 21)) == 1, "level-up line")
assert(STUB.printed[#STUB.printed]:find("|Haddon:LevelMates:cheer:Mario:21|h", 1, true), "with the [Congratulate] link")
assert(UIErrorsFrame.messages[#UIErrorsFrame.messages] == string.format(L.LEVELUP_NOTICE, "Mario", 21), "and on screen")
STUB.ClickLink("addon:LevelMates:cheer:Mario:21")
assert(STUB.lastChat and STUB.lastChat.chatType == "WHISPER" and STUB.lastChat.target == "Mario" and STUB.lastChat.msg == string.format(L.CHEER_TEXT, 21), "the click whispers")
STUB.lastChat = nil
STUB.ClickLink("addon:OtherAddon:x:y")
assert(STUB.lastChat == nil, "other links are not ours")
ns.db.settings.levelNotices = false
hb("Mario", 22)
assert(lines(string.format(L.LEVELUP_NOTICE, "Mario", 22)) == 0, "option off")
```

- [ ] **Step 3: Run** — Expected: LUA ERROR at `level-up line`.

- [ ] **Step 4: Implement**

`Roster.lua`, in the `hb` handler: replace `	local m = R.mates[name] or { quests = {} }` with `	local m = R.mates[name] or { quests = {} }\n	local before = m.level`, and replace `	R.mates[name] = m\n	ns.Fire("LM_ROSTER_CHANGED")\nend)` (the hb handler's end) with `	R.mates[name] = m\n	if before and f.l > before then ns.Fire("LM_MATE_LEVELUP", name, f.l) end   -- a mate I already knew\n	ns.Fire("LM_ROSTER_CHANGED")\nend)`.

`LevelMates/Cheers.lua`:

```lua
-- Cheers.lua: a guildmate's level-up gets a chat line with a [Congratulate] link; its click whispers them.
-- The link is an addon link ("addon:LevelMates:cheer:<name>:<level>"), which the client hands to EventRegistry.
local _, ns = ...
local K = {}
ns.Cheers = K
local L = ns.L

function K.Link(name, level) return string.format("|Haddon:LevelMates:cheer:%s:%d|h|cff7ec8ff[%s]|r|h", name, level, L.CHEER) end

ns.On("LM_MATE_LEVELUP", function(name, level)
	if not ns.db.settings.levelNotices then return end
	local text = string.format(L.LEVELUP_NOTICE, name, level)
	ns.Say("%s %s", text, K.Link(name, level))
	ns.Screen(text)
end)

-- The link's click (a hardware event, so the whisper is allowed).
function K.OnLink(link)
	local name, level = tostring(link):match("^addon:LevelMates:cheer:([^:]+):(%d+)")
	if not name then return false end
	SendChatMessage(string.format(L.CHEER_TEXT, tonumber(level)), "WHISPER", nil, name)
	return true
end
if EventRegistry and EventRegistry.RegisterCallback then
	EventRegistry:RegisterCallback("SetItemRef", function(_, link) K.OnLink(link) end, K)
end
```

Locales — enUS: `L.LEVELUP_NOTICE = "%s reached level %d!"; L.CHEER = "Congratulate"; L.CHEER_TEXT = "Congratulations on level %d!"`. esES: `L.LEVELUP_NOTICE = "¡%s ha llegado a nivel %d!"; L.CHEER = "Felicitar"; L.CHEER_TEXT = "¡Felicidades por el nivel %d!"`.

- [ ] **Step 5: Run** test and `npm test`. **Step 6: Commit** — `feat: congratulate guildmates' level-ups`.

---

### Task 4: Professions shared with `pf`

**Files:** Modify `Comm.lua`, `Journal.lua`, `Settings.lua`, `LevelMates.toc` (`Professions.lua` after `Wishlist.lua`), locales; create `Professions.lua`, `tests/professions.test.lua`.

**Interfaces:** Produces `ns.Professions` with `IDS`, `Name(id)`, `Mine()`, `List()` (rows `{ name, id, rank, t, mine? }` by profession name, rank desc, name), `SetSharing(on)`, `AddSample(name, list)`, `RemoveSamples()`; events `LM_SKILLS_CHANGED` (journal), `LM_PROFESSIONS_CHANGED`.

- [ ] **Step 1: Failing test** — `tests/professions.test.lua`:

```lua
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local C, P, R, L = ns.Comm, ns.Professions, ns.Roster, ns.L
local function last(kind) for i = #STUB.sent, 1, -1 do local k, f = C.Decode(STUB.sent[i].msg); if k == kind then return f end end end
STUB.guildMembers = { Tester = true, Mario = true, Ana = true, Luis = true }
R.InvalidateGuildRoster()

assert(C.Validate("pf", {}) and C.Validate("pf", { p = "171:120" }) and C.Validate("pf", { p = "171:120,182:95,129:1,185:450,356:300,164:5" }), "pf format")
assert(C.Validate("pf", { p = "171:120,182:95,129:1,185:450,356:300,164:5,165:1" }) == false and C.Validate("pf", { p = "171:451" }) == false, "count and rank limits")
assert(C.Validate("pf", { p = "171:" }) == false and C.Validate("pf", { p = "171:1,,2:3" }) == false and C.Validate("pf", { p = "abc" }) == false, "shape")

-- mine, from the journal's skill snapshot, sent when it changes
ns.char.skills = { [171] = { name = "Alchemy", rank = 120 }, [182] = { name = "Herbalism", rank = 95 } }
ns.Fire("LM_SKILLS_CHANGED")
assert(last("pf") and last("pf").p == "171:120,182:95", "mine shared: " .. tostring(last("pf") and last("pf").p))

-- guildmates'
STUB.Receive("LVLM", C.Encode("hb", { l = 20, z = 1421 }), "GUILD", "Mario-Testrealm")
STUB.Receive("LVLM", C.Encode("hb", { l = 20, z = 1421 }), "GUILD", "Ana-Testrealm")
STUB.Receive("LVLM", C.Encode("pf", { p = "164:80,171:200,999:5" }), "GUILD", "Mario-Testrealm")
STUB.Receive("LVLM", C.Encode("pf", { p = "171:50" }), "GUILD", "Nadie-Testrealm")
local rows = P.List()
local seen = {}
for _, r in ipairs(rows) do seen[#seen + 1] = r.name .. ":" .. r.id .. ":" .. r.rank end
assert(table.concat(seen, ",") == "Mario:171:200,Tester:171:120,Mario:164:80,Tester:182:95", "by profession, rank: " .. table.concat(seen, ","))
assert(P.Name(171) == L.PROF_171, "localized names")
STUB.Receive("LVLM", C.Encode("pf", {}), "GUILD", "Mario-Testrealm")
assert(#P.List() == 2, "Mario withdrew")
STUB.Receive("LVLM", C.Encode("pf", { p = "197:90" }), "GUILD", "Ana-Testrealm")
ns.db.professions[GetGuildInfo("player")].Ana.t = time() - 31 * 86400
assert(#P.List() == 2, "forgotten after 30 days")
STUB.Receive("LVLM", C.Encode("pf", { p = "197:90" }), "GUILD", "Ana-Testrealm")
STUB.guildMembers = { Tester = true, Mario = true, Luis = true }; R.InvalidateGuildRoster()
assert(#P.List() == 2, "not shown once out of the guild")
STUB.guildMembers = { Tester = true, Mario = true, Ana = true, Luis = true }; R.InvalidateGuildRoster()

-- newcomers get mine
local n = #STUB.sent
STUB.Receive("LVLM", C.Encode("ping", {}), "GUILD", "Luis-Testrealm"); STUB.Advance(6)
local got = false
for i = n + 1, #STUB.sent do local k, f = C.Decode(STUB.sent[i].msg); if k == "pf" and f.p == "171:120,182:95" then got = true end end
assert(got, "a newcomer gets mine")

-- sharing off withdraws at once; refused sends stay pending
ns.db.settings.shareProfessions = false
P.SetSharing(false)
assert(last("pf") and last("pf").p == nil, "withdrawn")
ns.db.settings.shareProfessions = true
STUB.inInstance = true
ns.char.skills[182].rank = 100; ns.Fire("LM_SKILLS_CHANGED")
assert(LevelMatesDB.chars[ns.PlayerKey()].profPending == true, "refused inside: pending")
STUB.inInstance = false
ns.Fire("LM_HB_SENT")
assert(last("pf").p == "171:120,182:100" and not LevelMatesDB.chars[ns.PlayerKey()].profPending, "sent after the heartbeat")
```

- [ ] **Step 2: Run** — Expected: LUA ERROR at `pf format`.

- [ ] **Step 3: Implement**

`Comm.lua`: after `itemids` add:

```lua
-- Professions "171:120,182:95": 1-6 pairs of skill id (1-999) and rank (1-450).
local function profs(v)
	if type(v) ~= "string" or v == "" or v:find(",,", 1, true) or v:sub(-1) == "," then return false end
	local n = 0
	for pair in v:gmatch("[^,]+") do
		local id, rank = pair:match("^(%d+):(%d+)$")
		if not id then return false end
		id, rank = tonumber(id), tonumber(rank)
		if id < 1 or id > 999 or rank < 1 or rank > 450 then return false end
		n = n + 1
	end
	return n <= 6
end
```
Schema `pf   = { p = profs },`; REQUIRED `pf = {}`; `LATEST_ONLY` gains `pf = true`.

`Journal.lua`: after `	ns.char.skills = now` add `	ns.Fire("LM_SKILLS_CHANGED")`.

`Settings.lua`: after the `shareRested` line add `Bool(category, "shareProfessions", L.OPT_PROFS, L.OPT_PROFS_TT, function(v) ns.Professions.SetSharing(v) end)`.

`LevelMates/Professions.lua`:

```lua
-- Professions.lua: who has which profession and at what rank, shared with the guild in its own kind `pf`
-- ("id:rank,..."; no p = not sharing). Mine come from the journal's skill snapshot. Spec 2026-10-10-levelmates-extras-design.
local _, ns = ...
local P = {}
ns.Professions = P
local L, C, R = ns.L, ns.Comm, ns.Roster
P.FORGET_DAYS = 30
P.IDS = { 171, 164, 333, 202, 182, 165, 186, 393, 197, 129, 185, 356 }
local KNOWN = {}
for _, id in ipairs(P.IDS) do KNOWN[id] = true end

local function me() return (UnitName("player")) end
local function theirs()
	ns.db.professions = ns.db.professions or {}
	local k = GetGuildInfo("player") or "?"
	ns.db.professions[k] = ns.db.professions[k] or {}
	return ns.db.professions[k]
end

function P.Name(id) return L["PROF_" .. id] or ("#" .. tostring(id)) end

function P.Mine()
	local out = {}
	for id, s in pairs(ns.char.skills or {}) do
		if KNOWN[id] and (s.rank or 0) > 0 then out[#out + 1] = { id = id, rank = math.min(450, s.rank) } end
	end
	table.sort(out, function(a, b) return a.id < b.id end)
	while #out > 6 do table.remove(out) end
	return out
end

local function encode()
	if not ns.db.settings.shareProfessions then return "" end
	local parts = {}
	for _, p in ipairs(P.Mine()) do parts[#parts + 1] = p.id .. ":" .. p.rank end
	return table.concat(parts, ",")
end

-- A refused send (instance, sharing off) stays pending in the character's saved data until the next heartbeat.
local sentAt, lastSent
local function send(prio)
	local p = encode()
	local fields = {}
	if p ~= "" then fields.p = p end
	if C.Send("pf", fields, prio) then ns.char.profPending, sentAt, lastSent = nil, GetTime(), p; return true end
	ns.char.profPending = true
	return false
end
local function resend() if sentAt ~= GetTime() then send() end end

-- The settings check box: on shares mine, off withdraws them.
function P.SetSharing() send("now") end

ns.On("LM_SKILLS_CHANGED", function() if encode() ~= lastSent then send() end end)
ns.On("LM_ANNOUNCED", function() if encode() ~= "" then resend() end end)
ns.On("LM_PING_ANSWERED", function() if encode() ~= "" then resend() end end)
ns.On("LM_HB_SENT", function() if ns.char.profPending then send() end end)
ns.On("LM_COMM_DROPPED", function(kind) if kind == "pf" then ns.char.profPending = true end end)

C.OnMessage("pf", function(f, name)
	if not R.mates[name] then return end   -- only people the roster knows
	local t = theirs()
	if f.p == nil then
		t[name] = nil
	else
		local list = {}
		for id, rank in tostring(f.p):gmatch("(%d+):(%d+)") do
			id = tonumber(id)
			if KNOWN[id] then list[#list + 1] = { id = id, rank = tonumber(rank) } end
		end
		t[name] = { list = list, t = time() }
	end
	ns.Fire("LM_PROFESSIONS_CHANGED")
end)

-- Rows for the Professions tab: me and guildmates (seen in the last 30 days, still in the guild), by profession,
-- then rank (highest first), then name.
function P.List()
	local out, t, cutoff = {}, theirs(), time() - P.FORGET_DAYS * 86400
	for _, p in ipairs(P.Mine()) do out[#out + 1] = { name = me(), id = p.id, rank = p.rank, t = time(), mine = true } end
	for name, e in pairs(t) do
		if e.t < cutoff then t[name] = nil
		elseif name ~= me() and (e.sim or R.IsGuildmate(name)) then
			for _, p in ipairs(e.list) do out[#out + 1] = { name = name, id = p.id, rank = p.rank, t = e.t } end
		end
	end
	table.sort(out, function(a, b)
		local na, nb = P.Name(a.id), P.Name(b.id)
		if na ~= nb then return na < nb end
		if a.rank ~= b.rank then return a.rank > b.rank end
		return a.name < b.name
	end)
	return out
end

-- Simulation support (/lm sim oficios): local samples, never sent.
function P.AddSample(name, list) theirs()[name] = { list = list, t = time(), sim = true }; ns.Fire("LM_PROFESSIONS_CHANGED") end
function P.RemoveSamples()
	local t = theirs()
	for name, e in pairs(t) do if e.sim then t[name] = nil end end
	ns.Fire("LM_PROFESSIONS_CHANGED")
end
```

Locales — enUS:

```lua
L.OPT_PROFS = "Share my professions"; L.OPT_PROFS_TT = "Guildmates see your professions and ranks on the Professions tab."
L.PROF_171 = "Alchemy"; L.PROF_164 = "Blacksmithing"; L.PROF_333 = "Enchanting"; L.PROF_202 = "Engineering"; L.PROF_182 = "Herbalism"; L.PROF_165 = "Leatherworking"
L.PROF_186 = "Mining"; L.PROF_393 = "Skinning"; L.PROF_197 = "Tailoring"; L.PROF_129 = "First Aid"; L.PROF_185 = "Cooking"; L.PROF_356 = "Fishing"
```
esES:

```lua
L.OPT_PROFS = "Compartir mis profesiones"; L.OPT_PROFS_TT = "Los hermanos ven tus profesiones y su nivel en la pestaña Oficios."
L.PROF_171 = "Alquimia"; L.PROF_164 = "Herrería"; L.PROF_333 = "Encantamiento"; L.PROF_202 = "Ingeniería"; L.PROF_182 = "Herboristería"; L.PROF_165 = "Peletería"
L.PROF_186 = "Minería"; L.PROF_393 = "Desuello"; L.PROF_197 = "Sastrería"; L.PROF_129 = "Primeros auxilios"; L.PROF_185 = "Cocina"; L.PROF_356 = "Pesca"
```

- [ ] **Step 4: Run** test and `npm test`. **Step 5: Commit** — `feat(professions): share professions with pf`.

---

### Task 5: The Professions tab

**Files:** Modify `Board.lua`, `DiscordCopy.lua`, locales; create `tests/board_crafts.test.lua`.

**Interfaces:** Consumes `ns.Professions.List/Name`. Produces `B.tabs.crafts`, `B.CCOLS`, `B.OpenCraftMenu(name)`, Discord builder `crafts`, slash `/lm oficios`, `/lm professions`.

- [ ] **Step 1: Failing test** — `tests/board_crafts.test.lua`:

```lua
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local C, B, P, R, L = ns.Comm, ns.Board, ns.Professions, ns.Roster, ns.L
STUB.guildMembers = { Tester = true, Mario = true, Ana = true }
R.InvalidateGuildRoster()
ns.char.skills = { [171] = { name = "Alchemy", rank = 120 } }
STUB.Receive("LVLM", C.Encode("hb", { l = 20, z = 1421, c = "MAGE" }), "GUILD", "Mario-Testrealm")
STUB.Receive("LVLM", C.Encode("pf", { p = "171:200,164:80" }), "GUILD", "Mario-Testrealm")
local entries
MenuUtil.CreateContextMenu = function(owner, fn)
	entries = {}
	local root = { CreateTitle = function() end, CreateButton = function(_, text, cb) entries[#entries + 1] = { text = text, cb = cb } end }
	fn(owner, root)
end
local function visible() local out = {}; for i = 1, #B.rows do if B.rows[i].button:IsShown() then out[#out + 1] = B.rows[i] end end; return out end

B.ShowTab("crafts")
assert(B.frame.Tabs[6] == B.tabs.crafts and B.frame.selectedTab == 6, "sixth classic tab")
assert(B.headText[1].text == L.COL_WHO and B.headText[3].text == L.COL_PROFESSION and B.headText[4].text == L.COL_RANK and B.headText[5].text == L.COL_SEEN, "headers")
assert(B.rows[1].zone:GetWidth() == B.CCOLS[3], "column widths")
local rows = visible()
assert(#rows == 3 and rows[1].name.text == "Mario" and rows[1].zone.text == P.Name(171) and rows[1].group.text == "200" and rows[1].xph.text == L.ONLINE, "Mario's alchemy first, online")
assert(rows[2].name.text == "Tester" and rows[3].zone.text == P.Name(164), "then mine, then blacksmithing")
-- search by profession or name
B.searchBox:SetText(P.Name(164):lower()); B.searchBox.scripts.OnTextChanged(B.searchBox)
assert(#visible() == 1 and visible()[1].zone.text == P.Name(164), "by profession")
B.searchBox:SetText("tester"); B.searchBox.scripts.OnTextChanged(B.searchBox)
assert(#visible() == 1 and visible()[1].name.text == "Tester", "by name")
B.searchBox:SetText(""); B.searchBox.scripts.OnTextChanged(B.searchBox)
-- right click: whisper and invite a guildmate, nothing on mine
rows = visible()
rows[2].button.scripts.OnClick(rows[2].button, "RightButton")
assert(entries == nil, "no menu on my own row")
rows[1].button.scripts.OnClick(rows[1].button, "RightButton")
assert(entries[1].text == L.MENU_WHISPER and entries[2].text == L.MENU_INVITE, "whisper and invite")
entries[1].cb()
assert(STUB.lastTell == "Mario", "whispers")
-- offline: last seen, whisper only
R.mates.Mario = nil; B.Refresh()
rows = visible()
assert(rows[1].xph.text ~= L.ONLINE and rows[1].xph.text ~= "", "last seen date when offline")
rows[1].button.scripts.OnClick(rows[1].button, "RightButton")
assert(#entries == 1 and entries[1].text == L.MENU_WHISPER, "offline: whisper only")
-- Discord: grouped by profession
local t = ns.DiscordCopy.Text("crafts")
assert(t:find(L.TAB_CRAFTS, 1, true) and t:find("**" .. P.Name(171) .. "**: Mario 200, Tester 120", 1, true), "Discord text: " .. t)
-- empty, slash
SlashCmdList["LEVELMATES"]("oficios")
assert(B.tab == "crafts", "/lm oficios")
```

- [ ] **Step 2: Run** — Expected: LUA ERROR at `sixth classic tab`.

- [ ] **Step 3: Implement**

`Board.lua`:
- after `B.WCOLS = …`: `B.CCOLS = { 150, 1, 239, 60, 70 }   -- professions: who, -, profession, rank, online or last seen (same total as B.COLS)`;
- `B.TAB_KEYS` gains `"crafts"`; `TAB_LABELS` gains `crafts = "TAB_CRAFTS"`;
- row `OnClick`: before `			if B.tab == "wishes" then` insert:

```lua
			if B.tab == "crafts" then
				if mouse == "RightButton" and self.craftName and not self.craftMine then B.OpenCraftMenu(self.craftName) end
				return
			end
```
- `SetHeaders`: before `	if B.tab == "wishes" then` insert:

```lua
	if B.tab == "crafts" then
		B.headText[1]:SetText(L.COL_WHO); B.headText[2]:SetText(""); B.headText[3]:SetText(L.COL_PROFESSION)
		B.headText[4]:SetText(L.COL_RANK); B.headText[5]:SetText(L.COL_SEEN)
		for i = 1, 5 do B.headText[i]:SetTextColor(1, 0.82, 0) end
		return
	end
```
- before `local function FillWishes(list)` add:

```lua
local function FillCrafts(list)
	for i = 1, ROWS do
		local r, c = B.rows[i], list[i]
		r.button.mate, r.button.adId, r.button.entry, r.button.goalId, r.button.personalMine = nil, nil, nil, nil, nil
		r.button.craftName, r.button.craftMine = c and c.name or nil, c and c.mine or nil
		if c then
			local m = R.mates[c.name]
			r.icon:Hide()
			r.name:SetText(c.name); r.name:SetTextColor(ClassColor(m and m.class))
			r.level:SetText("")
			r.zone:SetText(ns.Professions.Name(c.id)); r.zone:SetTextColor(1, 0.82, 0)
			r.group:SetText(tostring(c.rank)); r.group:SetTextColor(1, 1, 1)
			local online = c.mine or m ~= nil
			r.xph:SetText(online and L.ONLINE or date("%d/%m", c.t)); r.xph:SetTextColor(unpack(online and B.GROUP_COLORS.open or { 0.7, 0.7, 0.7 }))
			r.button:Show()
			RowBg(r, i, false)
		else
			ClearRow(r)
		end
	end
end

function B.OpenCraftMenu(name)
	MenuUtil.CreateContextMenu(B.frame, function(_, root)
		root:CreateTitle(name)
		root:CreateButton(L.MENU_WHISPER, function() B.Whisper(name) end)
		if R.mates[name] then root:CreateButton(L.MENU_INVITE, function() B.Invite(name) end) end
	end)
end

local function CraftsVisible()
	local out, q = {}, (B.search or ""):lower()
	for _, c in ipairs(ns.Professions.List()) do
		if q == "" or c.name:lower():find(q, 1, true) or ns.Professions.Name(c.id):lower():find(q, 1, true) then out[#out + 1] = c end
	end
	return out
end

```
- `PAGE_KEY` gains `crafts = "craftPage"`;
- `RefreshTabs` and `B.Refresh`: add `crafts = B.tab == "crafts"` to the local tab flags (`local lfg, journal, goals, wishes, crafts = …, B.tab == "crafts"`); in `B.Refresh` insert before `	elseif wishes then` the branch `	elseif crafts then\n		list, pages = Page(CraftsVisible())`; `SetColumns(… or wishes and B.WCOLS or crafts and B.CCOLS or B.COLS)`; fill `elseif crafts then FillCrafts(list)` before `elseif wishes then FillWishes(list)`; empty text `		elseif crafts then emptyText = #ns.Professions.List() > 0 and L.EMPTY_FILTERED or L.CRAFTS_EMPTY` before the wishes empty line; the pager condition `(goals or wishes or crafts) and pages > 1`; the help rows condition `journal or goals or wishes or crafts`;
- at the end: `ns.On("LM_PROFESSIONS_CHANGED", B.Refresh)`, `ns.Slash("oficios", function() B.ShowTab("crafts") end)`, `ns.Slash("professions", function() B.ShowTab("crafts") end)`.

`DiscordCopy.lua`: `TAB_TITLE` gains `crafts = "TAB_CRAFTS"`; add before `-- The text for a tab`:

```lua
function builders.crafts()
	local P, lines, byProf, order = ns.Professions, {}, {}, {}
	for _, c in ipairs(P.List()) do
		if not byProf[c.id] then byProf[c.id] = {}; order[#order + 1] = c.id end
		table.insert(byProf[c.id], c.name .. " " .. c.rank)
	end
	for _, id in ipairs(order) do lines[#lines + 1] = string.format("• **%s**: %s", P.Name(id), table.concat(byProf[id], ", ")) end
	return lines
end
```

Locales — enUS: `L.TAB_CRAFTS = "Professions"; L.COL_PROFESSION = "Profession"; L.COL_RANK = "Rank"; L.COL_SEEN = "Seen"; L.ONLINE = "online"; L.CRAFTS_EMPTY = "Nobody has shared professions yet."`. esES: `L.TAB_CRAFTS = "Oficios"; L.COL_PROFESSION = "Profesión"; L.COL_RANK = "Nivel"; L.COL_SEEN = "Visto"; L.ONLINE = "conectado"; L.CRAFTS_EMPTY = "Nadie ha compartido profesiones todavía."`.

- [ ] **Step 4: Run** test and `npm test` (`board_tabs` loops over six keys now). **Step 5: Commit** — `feat(board): Professions tab`.

---

### Task 6: "Join" on dungeon cards

**Files:** Modify `Comm.lua`, `LFG.lua`, `Board.lua`, locales; create `tests/lfg_join.test.lua`.

**Interfaces:** Produces `G.Join(id, role)`, `G.Leave(id)`, `G.myJoins`, ad field `joined = { [name] = role }` and `id`; kinds `lfj`, `lfjx`.

- [ ] **Step 1: Failing test** — `tests/lfg_join.test.lua`:

```lua
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local C, B, G, D, L = ns.Comm, ns.Board, ns.LFG, ns.Dungeons, ns.L
local function last(kind) for i = #STUB.sent, 1, -1 do local k, f = C.Decode(STUB.sent[i].msg); if k == kind then return f end end end
local function said(text) for _, p in ipairs(STUB.printed) do if p:find(text, 1, true) then return true end end; return false end
local entries
MenuUtil.CreateContextMenu = function(owner, fn)
	entries = {}
	local root = { CreateTitle = function() end, CreateButton = function(_, text, cb) entries[#entries + 1] = { text = text, cb = cb } end }
	fn(owner, root)
end
local function pick(text) for _, e in ipairs(entries) do if e.text == text then e.cb(); return true end end; return false end
local function has(text) for _, e in ipairs(entries) do if e.text == text then return true end end; return false end
STUB.player.level = 15
for _, n in ipairs({ "Mario", "Ana", "Luis", "Eva", "Pepe" }) do STUB.Receive("LVLM", C.Encode("hb", { l = 16, z = 1421 }), "GUILD", n .. "-Testrealm") end

assert(C.Validate("lfj", { id = "ad1", r = "T" }) and C.Validate("lfj", { id = "ad1", r = "X" }) == false and C.Validate("lfjx", { id = "ad1" }), "formats")

-- I join Mario's ad from its card
STUB.Receive("LVLM", C.Encode("lfg", { d = 2, r = "T", id = "mario001", m = 20 }), "GUILD", "Mario-Testrealm")
B.ShowTab("lfg")
B.OpenDungeonMenu(2)
assert(has(string.format(L.LFJ_JOIN, "Mario", L.ROLE_H)), "join entries per role")
assert(pick(string.format(L.LFJ_JOIN, "Mario", L.ROLE_H)), "join as healer")
assert(last("lfj").id == "mario001" and last("lfj").r == "H" and G.myJoins.mario001 == "H", "lfj sent")
B.OpenDungeonMenu(2)
assert(not has(string.format(L.LFJ_JOIN, "Mario", L.ROLE_H)) and pick(string.format(L.LFJ_LEAVE, "Mario")), "then: leave")
assert(last("lfjx").id == "mario001" and not G.myJoins.mario001, "lfjx sent")

-- my own ad: others join, I get notices, the group fills, I can invite them
STUB.Advance(31)
assert(G.Post(5, "T"), "I post")
local id = G.mine.id
STUB.Receive("LVLM", C.Encode("lfj", { id = id, r = "H" }), "GUILD", "Ana-Testrealm")
assert(said(string.format(L.LFJ_NOTICE, "Ana", D.Name(5), L.ROLE_H)) and UIErrorsFrame.messages[#UIErrorsFrame.messages]:find("Ana", 1, true), "Ana joins: notice")
STUB.Receive("LVLM", C.Encode("lfj", { id = id, r = "D" }), "GUILD", "Nadie-Testrealm")
assert(not G.mine.joined.Nadie, "strangers cannot join")
for _, n in ipairs({ "Luis", "Eva" }) do STUB.Receive("LVLM", C.Encode("lfj", { id = id, r = "D" }), "GUILD", n .. "-Testrealm") end
assert(not said(string.format(L.LFJ_FULL, D.Name(5))), "4 of 5: not full yet")
STUB.Receive("LVLM", C.Encode("lfj", { id = id, r = "D" }), "GUILD", "Pepe-Testrealm")
STUB.Receive("LVLM", C.Encode("lfj", { id = id, r = "D" }), "GUILD", "Pepe-Testrealm")
local full = 0
for _, p in ipairs(STUB.printed) do if p:find(string.format(L.LFJ_FULL, D.Name(5)), 1, true) then full = full + 1 end end
assert(full == 1, "full: told once")
B.OpenDungeonMenu(5)
assert(has(string.format(L.LFJ_INVITE, "Ana", L.ROLE_H)) and has(L.LFG_CANCEL_MINE), "invite each, withdraw")
STUB.Receive("LVLM", C.Encode("lfjx", { id = id }), "GUILD", "Ana-Testrealm")
assert(not G.mine.joined.Ana, "Ana left")

-- joins show in the card tooltip, survive a re-send of the ad and vanish with it
STUB.Receive("LVLM", C.Encode("lfj", { id = "mario001", r = "D" }), "GUILD", "Luis-Testrealm")
local card
for _, c in ipairs(B.cards) do if c:IsShown() and c.dungeonId == 2 then card = c end end
card.scripts.OnEnter(card)
assert(table.concat(GameTooltip.lines, "\n"):find("Luis", 1, true), "tooltip shows who joined")
STUB.Receive("LVLM", C.Encode("lfg", { d = 2, r = "T", id = "mario001", m = 19 }), "GUILD", "Mario-Testrealm")
assert(G.ads.mario001.joined.Luis == "D", "a re-sent ad keeps its joins")
STUB.Receive("LVLM", C.Encode("lfgx", { id = "mario001" }), "GUILD", "Mario-Testrealm")
assert(not G.ads.mario001, "gone with the ad")

-- my joins go again to newcomers while the ad lives
STUB.Receive("LVLM", C.Encode("lfg", { d = 4, r = "T", id = "ana00001", m = 20 }), "GUILD", "Ana-Testrealm")
assert(G.Join("ana00001", "D"))
local n = #STUB.sent
STUB.Receive("LVLM", C.Encode("ping", {}), "GUILD", "Eva-Testrealm"); STUB.Advance(6)
local again = false
for i = n + 1, #STUB.sent do local k, f = C.Decode(STUB.sent[i].msg); if k == "lfj" and f.id == "ana00001" then again = true end end
assert(again, "re-sent to a newcomer")
```

- [ ] **Step 2: Run** — Expected: LUA ERROR at `formats`.

- [ ] **Step 3: Implement**

`Comm.lua`: schemas `lfj  = { id = word(8), r = oneOf("T", "H", "D") },` and `lfjx = { id = word(8) },`; `REQUIRED` gains `lfj = { "id", "r" }, lfjx = { "id" }`.

`LFG.lua`:
- in the `lfg` handler replace `	G.ads[f.id] = { name = name, d = f.d, r = f.r, n = f.n, endsAt = endsAt }` with `	G.ads[f.id] = { id = f.id, name = name, d = f.d, r = f.r, n = f.n, endsAt = endsAt, joined = known and known.joined or {} }   -- a re-send keeps its joins`;
- in `G.Post` replace `	G.mine = { id = id, d = dungeonId, r = r, n = fields.n, endsAt = now + DURATION }` with `	G.mine = { id = id, d = dungeonId, r = r, n = fields.n, endsAt = now + DURATION, joined = {} }`;
- at the end add:

```lua

-- "Join": who joins which ad. Everyone keeps them (the card tooltip shows them); the poster gets the notices.
G.myJoins = {}   -- ad id -> my role
local function adById(id) if G.mine and G.mine.id == id then return G.mine end; return G.ads[id] end
local function joinedCount(ad) local n = 0; for _ in pairs(ad.joined or {}) do n = n + 1 end; return n end
local function me() return (UnitName("player")) end

-- Called from a click (a card's menu).
function G.Join(id, role)
	local ad = G.ads[id]
	if not ad or not (role == "T" or role == "H" or role == "D") then return false end
	if not C.Send("lfj", { id = id, r = role }, "now") then ns.Say(L.HELP_NEEDS_SHARE); return false end
	G.myJoins[id] = role
	ad.joined = ad.joined or {}
	ad.joined[me()] = role
	ns.Fire("LM_LFG_CHANGED")
	return true
end

function G.Leave(id)
	if not G.myJoins[id] then return false end
	C.Send("lfjx", { id = id }, "now")
	G.myJoins[id] = nil
	local ad = G.ads[id]
	if ad and ad.joined then ad.joined[me()] = nil end
	ns.Fire("LM_LFG_CHANGED")
	return true
end

C.OnMessage("lfj", function(f, name)
	if not R.mates[name] then return end   -- only people the roster knows
	local ad = adById(f.id)
	if not ad or ad.name == name then return end
	ad.joined = ad.joined or {}
	local new = ad.joined[name] == nil
	ad.joined[name] = f.r
	if ad == G.mine then
		if new then ns.Notice(L.LFJ_NOTICE, name, D.Name(ad.d), L["ROLE_" .. f.r]) end
		if not ad.fullTold and joinedCount(ad) >= 4 then ad.fullTold = true; ns.Notice(L.LFJ_FULL, D.Name(ad.d)) end
	end
	ns.Fire("LM_LFG_CHANGED")
end)

C.OnMessage("lfjx", function(f, name)
	local ad = adById(f.id)
	if ad and ad.joined and ad.joined[name] then ad.joined[name] = nil; ns.Fire("LM_LFG_CHANGED") end
end)

-- A newcomer (or a poster back from a /reload) gets my joins again, while their ads live.
ns.On("LM_PING_ANSWERED", function()
	for id, role in pairs(G.myJoins) do
		if G.ads[id] then C.Send("lfj", { id = id, r = role }) else G.myJoins[id] = nil end
	end
end)
```
(`R` must be the roster local in `LFG.lua`; it already is, as the `lfg` handler uses `R.mates`.)

`Board.lua`:
- in `B.AdsFor`, the mine entry becomes `{ name = (UnitName("player")), r = LFG.mine.r, n = LFG.mine.n, mine = true, joined = LFG.mine.joined, id = LFG.mine.id }`;
- in `B.DungeonTooltip`, after the ad's `AddLine` add:

```lua
		local who = {}
		for name, role in pairs(a.joined or {}) do who[#who + 1] = name .. " (" .. L["ROLE_" .. role] .. ")" end
		if #who > 0 then table.sort(who); GameTooltip:AddLine("   " .. string.format(L.LFJ_JOINED, table.concat(who, ", ")), 0.4, 1, 0.4, true) end
```
- in `B.OpenDungeonMenu`, replace the per-ad body with:

```lua
			if a.mine then
				local who = {}
				for name, role in pairs(a.joined or {}) do who[#who + 1] = { name = name, role = role } end
				table.sort(who, function(x, y) return x.name < y.name end)
				for _, w in ipairs(who) do root:CreateButton(string.format(L.LFJ_INVITE, w.name, L["ROLE_" .. w.role]), function() B.Invite(w.name) end) end
				root:CreateButton(L.LFG_CANCEL_MINE, function() ns.LFG.Cancel() end)
			else
				if ns.LFG.myJoins[a.id] then
					root:CreateButton(string.format(L.LFJ_LEAVE, a.name), function() ns.LFG.Leave(a.id) end)
				else
					for _, role in ipairs({ "T", "H", "D" }) do
						root:CreateButton(string.format(L.LFJ_JOIN, a.name, L["ROLE_" .. role]), function() ns.LFG.Join(a.id, role) end)
					end
				end
				root:CreateButton(string.format(L.LFG_WHISPER, a.name), function() B.Whisper(a.name) end)
				root:CreateButton(string.format(L.LFG_INVITE, a.name), function() B.Invite(a.name) end)
			end
```

Locales — enUS: `L.LFJ_JOIN = "Join %s as %s"; L.LFJ_LEAVE = "Leave %s's group"; L.LFJ_INVITE = "Invite %s (%s)"; L.LFJ_JOINED = "joined: %s"; L.LFJ_NOTICE = "%s joins your %s group as %s."; L.LFJ_FULL = "Your %s group is full! Invite them from the card."`. esES: `L.LFJ_JOIN = "Me apunto con %s como %s"; L.LFJ_LEAVE = "Me borro del grupo de %s"; L.LFJ_INVITE = "Invitar a %s (%s)"; L.LFJ_JOINED = "apuntados: %s"; L.LFJ_NOTICE = "%s se apunta a tu grupo de %s como %s."; L.LFJ_FULL = "¡Tu grupo de %s está completo! Invítalos desde la tarjeta."`.

- [ ] **Step 4: Run** test and `npm test` (`board_lfg` still `ok`: whisper/invite entries remain). **Step 5: Commit** — `feat(lfg): join a group from its dungeon card`.

---

### Task 7: Simulation and documentation

**Files:** Modify `Sim.lua`, `README.md`, `CHANGELOG.md`; create `tests/sim_crafts.test.lua`.

- [ ] **Step 1: Failing test** — `tests/sim_crafts.test.lua`:

```lua
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local P = ns.Professions
local sentBefore = #STUB.sent
SlashCmdList["LEVELMATES"]("sim oficios")
assert(#P.List() == 3, "Mario's two and Ana's one: " .. #P.List())
assert(#STUB.sent == sentBefore, "the simulation sends nothing")
SlashCmdList["LEVELMATES"]("sim off")
assert(#P.List() == 0, "sim off removes them")
```

- [ ] **Step 2: Run** — Expected: LUA ERROR at `Mario's two and Ana's one`.

- [ ] **Step 3: Implement** — `Sim.lua`: after `simWishes` add

```lua
local function simCrafts()
	ns.Professions.AddSample("Mario", { { id = 171, rank = 120 }, { id = 182, rank = 140 } })
	ns.Professions.AddSample("Ana", { { id = 197, rank = 90 } })
end
```
`off()`: add `ns.Professions.RemoveSamples()` to the RemoveSamples line; slash: `	elseif rest == "oficios" or rest == "professions" then simCrafts()` after the `deseos` branch.

README (both languages) and CHANGELOG lines: headings per tab; screen notices; newer-version notice; [Congratulate] on level-ups; your pace in the journal; the Professions tab (`/lm oficios`) with `pf`; "join" on dungeon cards with `lfj`/`lfjx`; `/lm sim oficios`.

- [ ] **Step 4: Run** `npm test`. **Step 5: Commit** — `feat: simulation and docs for the extras`.
