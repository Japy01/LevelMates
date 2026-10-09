# LevelMates: Leveling Partner Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. Every task also REQUIRES the `wow-forever-addons` skill (API facts, tools, policy).

**Goal:** A "Looking for a partner" check box on the Guildmates tab; guildmates who also tick it and are within 3 levels show at the top of the list, tinted, with a one-time chat notice; the box turns itself off when you group with someone who was also looking.

**Architecture:** A new addon-message kind `pal` (one field `p`, 0/1) — deliberately not a new field on `hb`, which older versions would reject wholesale. A new `Partner.lua` owns my flag (saved per character), the marks received from guildmates, matching, notices and the auto-off. The roster fires `LM_ANNOUNCED` after its login/reload announce; the existing `LM_PING_ANSWERED` (fired right after the roster answers a newcomer's ping) carries the re-send, so the newcomer always knows us first. `Board.lua` adds the check box, ordering, tint and tooltip.

**Tech Stack:** Lua 5.1 (WoW Forever client, interface 16001), the repo's fengari harness (`node tools/run-lua-test.mjs LevelMates tests/<name>.test.lua`), `npm test` for everything.

**Spec:** `docs/superpowers/specs/2026-10-09-levelmates-partner-design.md`

## Global Constraints

- Ticking and unticking the box is always a player click; the only automatic change is turning it **off** when grouping with someone who was also looking.
- Requires "Appear on the board" (`ns.db.settings.share`); with it off nothing is sent and nobody is seen. Turning it off sends `p = 0` immediately, before the transport stops; the player's own choice is kept.
- Inside an instance nothing but `help`/`helpok` is sent (`INSTANCE_OK` in `Comm.lua` unchanged).
- Message `pal`: field `p`, integer 0 or 1, required. Never a field on `hb`.
- A match: both marked, level difference ≤ 3, any zone. Matches go to the top of the Guildmates list, same zone first, then level high to low, then name; the rest keeps the chosen sort. The ±5 filter and the search box still apply first.
- Notice "Ana (21) también busca compañero, en Los Baldíos." once per person per session, only while my box is ticked; option "Avisos de compañero de leveo" (`palNotices`, default on). No sound.
- My flag is saved per character (`ns.char.lookingPartner`) and survives reloads; marks received from others live only in memory and disappear with `bye`, roster expiry, or sharing off.
- Every player-visible string goes through `L` (enUS and esES). `npm test` green after every task.

## Review Focus

1. A guildmate on an older version: our heartbeats must stay readable to them, so the flag must never ride on `hb` (Task 1 test: the `hb` we send has no `p` field).
2. A `pal` from someone the roster does not know is ignored, and a mark disappears when its owner leaves (`bye`) or sends `p = 0` (Task 1 tests).
3. Notice spam: toggling the box on and off, or the same mate re-sending `pal`, never repeats a notice in a session (Task 1 tests).
4. The automatic change only ever turns the box off, and only when grouping with someone who was marked; grouping with an unmarked mate leaves it on (Task 1 tests).
5. Sharing off and instances: nothing goes out; `p = 0` goes out before the transport stops; turning the box on without sharing is refused with a message (Task 1 tests; Task 2 test that the box re-syncs when refused).

---

## File Structure

| File | Responsibility |
|---|---|
| `LevelMates/Partner.lua` (new) | My flag, received marks, matching, notices, sends, auto-off. No UI. |
| `LevelMates/Comm.lua` (modify) | Schema for `pal`. |
| `LevelMates/Roster.lua` (modify) | Fire `LM_ANNOUNCED` after `announce()`. |
| `LevelMates/Core.lua`, `Settings.lua`, `Locales/*.lua`, `LevelMates.toc` (modify) | Default, option, strings, load order (`Partner.lua` after `LfgDialog.lua`). |
| `LevelMates/Board.lua` (modify) | Check box, ordering, tint, tooltip; also hides the near-level label on the Dungeons tab. |
| `LevelMates/Sim.lua`, `README.md`, `CHANGELOG.md` (modify) | `/lm sim pal`, docs. |
| `tools/wow-stub.lua` (modify) | `SetColorTexture` records its colour. |

---

### Task 1: The `pal` message and Partner.lua

**Files:**
- Create: `LevelMates/Partner.lua`, `tests/partner.test.lua`, `tests/partner_persist.test.lua`
- Modify: `LevelMates/Comm.lua`, `LevelMates/Roster.lua`, `LevelMates/Core.lua`, `LevelMates/Settings.lua`, `LevelMates/Locales/enUS.lua`, `LevelMates/Locales/esES.lua`, `LevelMates/LevelMates.toc`, `tests/comm_format.test.lua`, `tests/comm_transport.test.lua`

**Interfaces:**
- Consumes: `ns.Comm.Send/SendImmediate/OnMessage/IsReady`, `ns.Roster.mates`, events `LM_ROSTER_CHANGED`, `LM_PING_ANSWERED`, `LM_COMM_STOPPING`, `LM_COMM_STOPPED`, `ns.char`, `ns.db.settings.palNotices`.
- Produces: `ns.Partner.IsOn() -> boolean`, `ns.Partner.SetOn(on) -> boolean` (false when turning on is refused), `ns.Partner.Marked(name) -> boolean`, `ns.Partner.Matches(name) -> boolean`, event `LM_PARTNER_CHANGED`; Roster event `LM_ANNOUNCED`.

- [ ] **Step 1: Write the failing tests**

Append to `tests/comm_format.test.lua` just before the final `print("ok")`:

```lua
-- leveling partner flag
local kp, fp = C.Decode(C.Encode("pal", { p = 1 }))
assert(kp == "pal" and fp.p == 1, "pal roundtrip")
assert(C.Validate("pal", { p = 2 }) == false and C.Validate("pal", {}) == false and C.Validate("pal", { p = "x" }) == false, "p must be 0 or 1")
```

In `tests/comm_transport.test.lua`, right after the line containing `"group finder messages refused in an instance")` add:

```lua
assert(C.Send("pal", { p = 1 }) == false, "partner flag refused in an instance")
```

`tests/partner.test.lua`:

```lua
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local C, P, L = ns.Comm, ns.Partner, ns.L
STUB.player.level = 20
local function mate(name, level, z) STUB.Receive("LVLM", C.Encode("hb", { l = level, z = z or 1421 }), "GUILD", name .. "-Testrealm") end
local function pal(name, p) STUB.Receive("LVLM", C.Encode("pal", { p = p }), "GUILD", name .. "-Testrealm") end
local function lastKind() return (C.Decode(STUB.sent[#STUB.sent].msg)) end
assert(ns.db.settings.palNotices == true, "notices on by default")
assert(P.IsOn() == false, "off by default")
mate("Mario", 23); mate("Ana", 24); mate("Luis", 17)

-- a click turns it on and tells the guild, on a kind of its own
assert(P.SetOn(true) == true and P.IsOn() and ns.char.lookingPartner == true, "on")
local k, f = C.Decode(STUB.sent[#STUB.sent].msg)
assert(k == "pal" and f.p == 1, "pal p=1 sent")
for i = 1, #STUB.sent do
	local kk, ff = C.Decode(STUB.sent[i].msg)
	if kk == "hb" then assert(ff.p == nil, "the flag never rides on hb (older versions would drop the hb)") end
end

-- matching: both marked and within 3 levels; one notice per person
local printed = #STUB.printed
pal("Mario", 1)
assert(P.Marked("Mario") and P.Matches("Mario"), "Mario 23 vs 20: match")
assert(#STUB.printed == printed + 1 and STUB.printed[#STUB.printed]:find("Mario", 1, true) and STUB.printed[#STUB.printed]:find("23", 1, true), "notice with name and level")
pal("Mario", 1)
assert(#STUB.printed == printed + 1, "notice once per person")
pal("Ana", 1)
assert(P.Marked("Ana") and not P.Matches("Ana"), "Ana 24 vs 20: 4 levels, no match")
assert(#STUB.printed == printed + 1, "no notice for a non-match")
assert(not P.Matches("Luis"), "Luis not marked")
pal("Stranger", 1)
assert(not P.Marked("Stranger"), "unknown to the roster: ignored")

-- my level changes: Ana comes in range and is announced then
STUB.player.level = 21
ns.Fire("LM_ROSTER_CHANGED")
assert(P.Matches("Ana") and #STUB.printed == printed + 2, "Ana now matches and is announced once")

-- my box off: no matches, marks stay known; toggling back does not repeat notices
P.SetOn(false)
k, f = C.Decode(STUB.sent[#STUB.sent].msg)
assert(k == "pal" and f.p == 0 and not P.Matches("Mario") and P.Marked("Mario"), "off: p=0 sent, no matches")
P.SetOn(true)
assert(#STUB.printed == printed + 2, "toggling does not repeat notices")

-- notices off
ns.db.settings.palNotices = false
mate("Rosa", 21); pal("Rosa", 1)
assert(P.Matches("Rosa") and #STUB.printed == printed + 2, "notices off: silent")
ns.db.settings.palNotices = true

-- marks go away with bye and with p=0
STUB.Receive("LVLM", C.Encode("bye", {}), "GUILD", "Mario-Testrealm")
assert(not P.Marked("Mario"), "bye clears the mark")
pal("Ana", 0)
assert(not P.Marked("Ana"), "p=0 clears")

-- a newcomer gets my mark right after my heartbeat
local n = #STUB.sent
STUB.Receive("LVLM", C.Encode("ping", {}), "GUILD", "Nuevo-Testrealm")
STUB.Advance(6)
local order = {}
for i = n + 1, #STUB.sent do local kk = C.Decode(STUB.sent[i].msg); if kk == "hb" or kk == "pal" then order[#order + 1] = kk end end
assert(order[1] == "hb" and order[2] == "pal", "hb then pal: " .. table.concat(order, ","))

-- grouping with someone who was looking turns mine off; with someone who was not, it stays
STUB.partyMembers = { Rosa = true }
STUB.Fire("GROUP_ROSTER_UPDATE")
assert(not P.IsOn() and ns.char.lookingPartner == false, "found: off")
assert(lastKind() == "pal" and STUB.printed[#STUB.printed]:find("Rosa", 1, true), "p=0 sent and the user is told")
P.SetOn(true)
STUB.partyMembers = { Luis = true }
STUB.Fire("GROUP_ROSTER_UPDATE")
assert(P.IsOn(), "Luis was not looking: stays on")
STUB.partyMembers = {}

-- inside an instance nothing goes out
STUB.inInstance = true
n = #STUB.sent
P.SetOn(false); P.SetOn(true)
assert(#STUB.sent == n, "nothing sent inside an instance")
STUB.inInstance = false

-- sharing off: p=0 goes out first, my choice is kept, their marks are forgotten
ns.db.settings.share = false; C.Stop()
k, f = C.Decode(STUB.sent[#STUB.sent].msg)
assert(k == "pal" and f.p == 0, "p=0 before the transport stops")
assert(P.IsOn() and not P.Marked("Rosa"), "my choice kept, their marks forgotten")
-- turning it on without sharing is refused
P.SetOn(false)
assert(P.SetOn(true) == false and not P.IsOn() and STUB.printed[#STUB.printed]:find(L.HELP_NEEDS_SHARE, 1, true), "needs sharing")
```

`tests/partner_persist.test.lua`:

```lua
-- The box is remembered per character and announced again after a reload.
LevelMatesDB = { version = 1, settings = {}, chars = { ["Tester-Testrealm"] = { lookingPartner = true } } }
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", false, true); STUB.Advance(1)
assert(ns.Partner.IsOn(), "remembered across reloads")
local sentPal = false
for i = 1, #STUB.sent do
	local k, f = ns.Comm.Decode(STUB.sent[i].msg)
	if k == "pal" and f.p == 1 then sentPal = true end
end
assert(sentPal, "announced after the reload")
```

- [ ] **Step 2: Run the tests to see them fail**

Run: `node tools/run-lua-test.mjs LevelMates tests/comm_format.test.lua` — Expected: LUA ERROR at `pal roundtrip`.
Run: `node tools/run-lua-test.mjs LevelMates tests/partner.test.lua` — Expected: LUA ERROR at `notices on by default` (or `ns.Partner` nil).
Run: `node tools/run-lua-test.mjs LevelMates tests/partner_persist.test.lua` — Expected: LUA ERROR (`ns.Partner` nil).
Run: `node tools/run-lua-test.mjs LevelMates tests/comm_transport.test.lua` — Expected: `ok` (the new assertion is a regression guard: an unknown kind is already refused).

- [ ] **Step 3: Implement**

`LevelMates/Comm.lua`: in `C.SCHEMA` add `pal  = { p = int(0, 1) },` next to `lfgx`, and in `REQUIRED` add `pal = { "p" },`.

`LevelMates/Roster.lua`: in `local function announce()`, after the line `R.SendQuests()` add:

```lua
	ns.Fire("LM_ANNOUNCED")   -- modules re-announce their own state (partner flag) after the roster's
```

`LevelMates/Core.lua`: in `DEFAULTS` change `lfgNotices = true,` to `lfgNotices = true, palNotices = true,`.

`LevelMates/Settings.lua`: after `Bool(category, "lfgNotices", L.OPT_LFG, L.OPT_LFG_TT)` add `Bool(category, "palNotices", L.OPT_PAL, L.OPT_PAL_TT)`.

`LevelMates/Locales/enUS.lua` append:

```lua
L.FILTER_PAL = "Looking for a partner"; L.PAL_TOOLTIP = "Looking for a leveling partner"
L.PAL_NOTICE = "%s (%d) is also looking for a leveling partner, in %s."
L.PAL_FOUND = "You found a partner: %s."
L.UNKNOWN_ZONE = "an unknown zone"
L.OPT_PAL = "Leveling partner notices"; L.OPT_PAL_TT = "A chat line when a guildmate within 3 levels is also looking for a partner."
```

`LevelMates/Locales/esES.lua` append:

```lua
L.FILTER_PAL = "Busco compañero"; L.PAL_TOOLTIP = "Busca compañero de leveo"
L.PAL_NOTICE = "%s (%d) también busca compañero, en %s."
L.PAL_FOUND = "Has encontrado compañero: %s."
L.UNKNOWN_ZONE = "una zona desconocida"
L.OPT_PAL = "Avisos de compañero de leveo"; L.OPT_PAL_TT = "Una línea en el chat cuando un hermano a 3 niveles o menos también busca compañero."
```

`LevelMates/LevelMates.toc`: add `Partner.lua` right after `LfgDialog.lua`.

Create `LevelMates/Partner.lua`:

```lua
-- Partner.lua: "looking for a leveling partner". Ticking the box is a click; the only automatic change is turning
-- it off when you group with someone who was also looking. Spec 2026-10-09-levelmates-partner-design.
-- The flag travels in its own message kind `pal`: older versions reject an hb with an unknown field.
local _, ns = ...
local P = {}
ns.Partner = P
local L, C, R = ns.L, ns.Comm, ns.Roster
local RANGE = 3
local marked = {}     -- name -> true: guildmates whose last pal said p=1
local notified = {}   -- name -> true: already announced this session

function P.IsOn() return ns.char ~= nil and ns.char.lookingPartner == true end
function P.Marked(name) return marked[name] == true end
function P.Matches(name)
	local m = R.mates[name]
	return P.IsOn() and marked[name] == true and m ~= nil and math.abs((m.level or 0) - UnitLevel("player")) <= RANGE
end

local function zoneName(m)
	local info = m.mapId and C_Map.GetMapInfo and C_Map.GetMapInfo(m.mapId)
	return info and info.name or L.UNKNOWN_ZONE
end

-- Forget marks of people the roster no longer has, then announce new matches once.
local function recompute()
	for name in pairs(marked) do if not R.mates[name] then marked[name] = nil end end
	if not P.IsOn() then return end
	for name in pairs(marked) do
		if not notified[name] and P.Matches(name) and ns.db.settings.palNotices then
			notified[name] = true
			local m = R.mates[name]
			ns.Say(L.PAL_NOTICE, name, m.level, zoneName(m))
		end
	end
end

-- Called from a click (the board check box). Returns false when turning on is refused.
function P.SetOn(on)
	if on and not C.IsReady() then ns.Say(L.HELP_NEEDS_SHARE); return false end
	ns.char.lookingPartner = on and true or false
	if C.IsReady() then C.Send("pal", { p = on and 1 or 0 }, "now") end
	recompute()
	ns.Fire("LM_PARTNER_CHANGED")
	return true
end

C.OnMessage("pal", function(f, name)
	if not R.mates[name] then return end   -- only people the roster knows
	marked[name] = f.p == 1 or nil
	recompute()
	ns.Fire("LM_PARTNER_CHANGED")
end)

-- Re-announce my flag after the roster's own announce (login, reload, transport restart) and to newcomers,
-- right after my heartbeat, so they already know me.
local function announceMine() if P.IsOn() then C.Send("pal", { p = 1 }) end end
ns.On("LM_ANNOUNCED", announceMine)
ns.On("LM_PING_ANSWERED", announceMine)
ns.On("LM_ROSTER_CHANGED", recompute)

-- Sharing off: say "no longer looking" while we still can; forget everyone else's marks.
ns.On("LM_COMM_STOPPING", function() if P.IsOn() then C.SendImmediate("pal", { p = 0 }) end end)
ns.On("LM_COMM_STOPPED", function() wipe(marked); wipe(notified); ns.Fire("LM_PARTNER_CHANGED") end)

-- Found a partner: grouping with someone who was looking turns mine off.
local groupFrame = CreateFrame("Frame")
groupFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
groupFrame:SetScript("OnEvent", function()
	if not P.IsOn() then return end
	for name in pairs(marked) do
		if UnitInParty(name) or UnitInRaid(name) then
			ns.char.lookingPartner = false
			C.Send("pal", { p = 0 }, "now")
			ns.Say(L.PAL_FOUND, name)
			ns.Fire("LM_PARTNER_CHANGED")
			return
		end
	end
end)
```

- [ ] **Step 4: Run the tests and the whole suite**

Run: `node tools/run-lua-test.mjs LevelMates tests/partner.test.lua` and `node tools/run-lua-test.mjs LevelMates tests/partner_persist.test.lua` — Expected: `ok` for both.
Run: `npm test` — Expected: every line `ok`, exit code 0.

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat(partner): pal message, flag, matching, notices and auto-off"
```

---

### Task 2: The board — check box, order, tint, tooltip

**Files:**
- Modify: `LevelMates/Board.lua`, `tools/wow-stub.lua`
- Create: `tests/board_partner.test.lua`

**Interfaces:**
- Consumes: `ns.Partner.IsOn/SetOn/Matches`, event `LM_PARTNER_CHANGED`, the existing `Visible`, `FillMates`, `FillLfg`, `RefreshTabs`, row `bg` textures.
- Produces: `ns.Board.palCheck`, `ns.Board.palLabel`, `ns.Board.nearLabel`, `ns.Board.PAL_TINT` (`{ 0.2, 0.8, 0.3, 0.15 }`).

- [ ] **Step 1: Write the failing test**

In `tools/wow-stub.lua` replace `function Region:SetColorTexture() end` with:

```lua
function Region:SetColorTexture(r, g, b, a) self.colorTexture = { r, g, b, a } end
```

`tests/board_partner.test.lua`:

```lua
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local C, B, P, L = ns.Comm, ns.Board, ns.Partner, ns.L
STUB.player.level = 20; STUB.player.mapId = 1421
local function mate(name, level, z) STUB.Receive("LVLM", C.Encode("hb", { l = level, z = z }), "GUILD", name .. "-Testrealm") end
local function pal(name) STUB.Receive("LVLM", C.Encode("pal", { p = 1 }), "GUILD", name .. "-Testrealm") end
mate("Alto", 40, 1421); mate("Lejos", 22, 1412); mate("Cerca", 19, 1421); mate("Solo", 21, 1421); mate("Marcado", 30, 1421)
pal("Lejos"); pal("Cerca"); pal("Marcado")
B.Toggle()
local function shown()
	local out = {}
	for i = 1, #B.rows do local r = B.rows[i]; if r.button:IsShown() then out[#out + 1] = r.name.text end end
	return table.concat(out, ",")
end
local function rowOf(name) for i = 1, #B.rows do if B.rows[i].name.text == name then return B.rows[i] end end end
local function same(a, b) return a and b and a[1] == b[1] and a[2] == b[2] and a[3] == b[3] and a[4] == b[4] end

assert(B.palCheck and B.palCheck:IsShown() and not B.palCheck:GetChecked(), "check box on the guildmates tab, unticked")
assert(shown() == "Alto,Marcado,Lejos,Solo,Cerca", "not looking: the usual order: " .. shown())
B.palCheck:SetChecked(true); B.palCheck.scripts.OnClick(B.palCheck)
assert(P.IsOn(), "the check box turns it on")
assert(shown() == "Cerca,Lejos,Alto,Marcado,Solo", "matches first, my zone first, then the usual order: " .. shown())
assert(same(rowOf("Cerca").bg.colorTexture, B.PAL_TINT) and same(rowOf("Lejos").bg.colorTexture, B.PAL_TINT), "matches are tinted")
assert(not same(rowOf("Marcado").bg.colorTexture, B.PAL_TINT), "marked but 10 levels away: not tinted")

-- tooltip only on matches
local cerca = rowOf("Cerca")
cerca.button.scripts.OnEnter(cerca.button)
assert(GameTooltip.lines[1] == L.PAL_TOOLTIP and not GameTooltip.hidden, "tooltip on a match")
cerca.button.scripts.OnLeave(cerca.button)
local alto = rowOf("Alto")
alto.button.scripts.OnEnter(alto.button)
assert(GameTooltip.hidden, "no tooltip on a non-match")

-- the near-level filter and the search still apply
B.nearCheck:SetChecked(true); B.nearCheck.scripts.OnClick(B.nearCheck)
assert(shown() == "Cerca,Lejos,Solo", "near filter first, then matches on top: " .. shown())
B.nearCheck:SetChecked(false); B.nearCheck.scripts.OnClick(B.nearCheck)
B.searchBox:SetText("lej"); B.searchBox.scripts.OnTextChanged(B.searchBox)
assert(shown() == "Lejos", "search still filters")
B.searchBox:SetText(""); B.searchBox.scripts.OnTextChanged(B.searchBox)

-- the box and both labels belong to the guildmates tab
B.tabs.lfg.scripts.OnClick(B.tabs.lfg)
assert(not B.palCheck:IsShown() and not B.palLabel:IsShown() and not B.nearLabel:IsShown(), "hidden on the Dungeons tab")
B.tabs.mates.scripts.OnClick(B.tabs.mates)
assert(B.palCheck:IsShown() and B.palLabel:IsShown() and B.nearLabel:IsShown() and B.palCheck:GetChecked(), "back, still ticked")

-- the dungeon rows are not tinted by partner state
B.tabs.lfg.scripts.OnClick(B.tabs.lfg)
B.tabs.mates.scripts.OnClick(B.tabs.mates)

-- unticking restores the usual order
B.palCheck:SetChecked(false); B.palCheck.scripts.OnClick(B.palCheck)
assert(not P.IsOn() and shown() == "Alto,Marcado,Lejos,Solo,Cerca", "off: usual order again: " .. shown())
assert(not same(rowOf("Cerca").bg.colorTexture, B.PAL_TINT), "tint removed")

-- a refused tick (sharing off) re-syncs the box
ns.db.settings.share = false; C.Stop()
B.Toggle(); B.Toggle()
B.palCheck:SetChecked(true); B.palCheck.scripts.OnClick(B.palCheck)
assert(not P.IsOn() and not B.palCheck:GetChecked(), "box unticked again when refused")
```

- [ ] **Step 2: Run the test to see it fail**

Run: `node tools/run-lua-test.mjs LevelMates tests/board_partner.test.lua`
Expected: LUA ERROR at `check box on the guildmates tab, unticked` (`B.palCheck` is nil).

- [ ] **Step 3: Implement** (all in `LevelMates/Board.lua`)

(a) After the line `nearLabel:SetPoint("LEFT", near, "RIGHT", 2, 0); nearLabel:SetText(L.FILTER_NEAR)` add `B.nearLabel = nearLabel`, and after the line `B.nearCheck = near` add:

```lua

	-- "Looking for a partner" (guildmates tab), in the header under the search box.
	local pal = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
	pal:SetSize(22, 22); pal:SetPoint("TOPRIGHT", -(B.MARGIN + 130), -(insetTop + 32))
	pal:SetScript("OnClick", function(self)
		if not ns.Partner.SetOn(self:GetChecked() and true or false) then self:SetChecked(ns.Partner.IsOn()) end
		B.Refresh()
	end)
	local palLabel = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	palLabel:SetPoint("LEFT", pal, "RIGHT", 2, 0); palLabel:SetText(L.FILTER_PAL)
	B.palCheck, B.palLabel = pal, palLabel
```

(b) Replace the row `OnEnter` handler (the block starting `btn:SetScript("OnEnter", function(self)   -- Dungeons tab: the whole note on hover` through its `end)`) with:

```lua
		btn:SetScript("OnEnter", function(self)
			if not GameTooltip then return end
			if B.tab == "lfg" and self.adId then   -- Dungeons tab: the whole note
				local a = ns.LFG.ads[self.adId]
				if a and a.n then GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:AddLine(a.n, 1, 1, 1, true); GameTooltip:Show() end
			elseif B.tab == "mates" and self.mate and ns.Partner and ns.Partner.Matches(self.mate) then   -- a partner match
				GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:AddLine(L.PAL_TOOLTIP, 0.4, 1, 0.4); GameTooltip:Show()
			end
		end)
```

(c) In `local function Visible()`, replace the final `return out` with:

```lua
	-- Partner matches go to the top: same zone first, then level high to low, then name; the rest keeps its order.
	if ns.Partner and ns.Partner.IsOn() then
		local myMap = C_Map.GetBestMapForUnit("player")
		local top, rest = {}, {}
		for _, name in ipairs(out) do if ns.Partner.Matches(name) then top[#top + 1] = name else rest[#rest + 1] = name end end
		table.sort(top, function(a, b)
			local A, B2 = R.mates[a], R.mates[b]
			local za, zb = A.mapId == myMap, B2.mapId == myMap
			if za ~= zb then return za end
			if A.level ~= B2.level then return A.level > B2.level end
			return a < b
		end)
		for _, name in ipairs(rest) do top[#top + 1] = name end
		out = top
	end
	return out
```

(d) Before `local function FillMates(list)` add:

```lua
B.PAL_TINT = { 0.2, 0.8, 0.3, 0.15 }
-- Row background: the partner tint for a match, otherwise the zebra stripe.
local function RowBg(r, i, tint)
	if tint then r.bg:SetColorTexture(unpack(B.PAL_TINT)) else r.bg:SetColorTexture(1, 1, 1, i % 2 == 0 and 0.06 or 0) end
end
```

In `FillMates`, right after `r.button:Show()` (inside `if name then`) add `RowBg(r, i, ns.Partner and ns.Partner.Matches(name))`. In `FillLfg`, right after its `r.button:Show()` add `RowBg(r, i, false)`.

(e) In `local function RefreshTabs()`, after `B.helpButton:SetShown(not lfg); B.nearCheck:SetShown(not lfg)` add:

```lua
	B.nearLabel:SetShown(not lfg); B.palCheck:SetShown(not lfg); B.palLabel:SetShown(not lfg)
	B.palCheck:SetChecked(ns.Partner and ns.Partner.IsOn() or false)
```

(f) At the end of the file add `ns.On("LM_PARTNER_CHANGED", B.Refresh)`.

- [ ] **Step 4: Run the test and the whole suite**

Run: `node tools/run-lua-test.mjs LevelMates tests/board_partner.test.lua` — Expected: `ok`.
Run: `npm test` — Expected: all `ok`.

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat(board): partner check box, matches on top, tint and tooltip"
```

---

### Task 3: Simulation and documentation

**Files:**
- Modify: `LevelMates/Sim.lua`, `README.md`, `CHANGELOG.md`
- Create: `tests/sim_partner.test.lua`

**Interfaces:**
- Consumes: `ns.Comm.Inject`, `ns.Partner`, `ns.Roster`.
- Produces: `/lm sim pal` (Luis and Mario send `pal p=1`, local only); `/lm sim off` removes them (their `bye` clears the marks).

- [ ] **Step 1: Write the failing test**

`tests/sim_partner.test.lua`:

```lua
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
STUB.player.realm = "Classic Beta PvP"
STUB.ambiguateKeepsRealm = true
STUB.player.level = 22
local P = ns.Partner
SlashCmdList["LEVELMATES"]("sim")
local sentBefore = #STUB.sent
SlashCmdList["LEVELMATES"]("sim pal")
assert(P.Marked("Luis") and P.Marked("Mario"), "two fake partners")
assert(#STUB.sent == sentBefore, "the simulation sends nothing")
P.SetOn(true)
assert(P.Matches("Luis") and not P.Matches("Mario"), "Luis (22) matches, Mario (30) does not")
SlashCmdList["LEVELMATES"]("sim off")
assert(not P.Marked("Luis") and not P.Marked("Mario"), "sim off clears them")
```

- [ ] **Step 2: Run the test to see it fail**

Run: `node tools/run-lua-test.mjs LevelMates tests/sim_partner.test.lua` — Expected: LUA ERROR at `two fake partners`.

- [ ] **Step 3: Implement**

In `LevelMates/Sim.lua`, after the `simLfg` function add:

```lua
local function simPal()
	if not R.mates.Luis then run() end   -- the marks need their owners in the roster
	inject("pal", { p = 1 }, "Luis"); inject("pal", { p = 1 }, "Mario")
end
```

and in the slash handler add a branch before `else run() end`:

```lua
	elseif rest == "pal" or rest == "compa" then simPal()
```

`README.md`, English "What it does" list, add:
`- **Leveling partner** (Guildmates tab): tick "Looking for a partner"; guildmates within 3 levels who also tick it appear at the top, tinted, with a chat line. It turns itself off when you group with one of them.`
English Commands: add `/lm sim pal` after `/lm sim lfg`.
Spanish "Qué hace" list, add:
`- **Compañero de leveo** (pestaña Hermanos): marca "Busco compañero"; los hermanos a 3 niveles o menos que también lo marcan salen arriba, resaltados, con una línea en el chat. Se desmarca solo al agruparte con uno de ellos.`
Spanish Comandos: add `/lm sim pal` after `/lm sim lfg`.
`CHANGELOG.md` append:

```
- Leveling partner: a "Looking for a partner" check box on the Guildmates tab; matches (within 3 levels, both ticked) go to the top, tinted, with a one-time chat line; it turns off when you group with one of them. New message kind `pal`; older versions ignore it.
```

- [ ] **Step 4: Run the whole suite**

Run: `npm test` — Expected: all `ok`, exit code 0.

- [ ] **Step 5: In-game check (with the user), then commit**

In game: `/reload`, `/lm sim`, `/lm sim pal`, tick "Busco compañero": Luis goes to the top, tinted, chat line; hover shows the tooltip; the box and its label sit under the search box without overlapping the subtitle (screenshot). With a second real player: both tick, see each other, group, both boxes untick.

```bash
git add -A && git commit -m "feat(partner): simulation and docs"
```

---

## Self-Review notes

- Spec §4 (message, when sent) → Task 1 (`pal`, `LM_ANNOUNCED`, `LM_PING_ANSWERED`, `LM_COMM_STOPPING`); §5 (matching, notices, option) → Task 1; §6 (UI) → Task 2; §7 (auto-off) → Task 1; §8 (tests) → each task; simulation → Task 3; §3 policy → Global Constraints and Task 1 instance/sharing tests.
- Names consistent: `ns.Partner.IsOn/SetOn/Marked/Matches`, `LM_PARTNER_CHANGED`, `LM_ANNOUNCED`, `B.palCheck/palLabel/nearLabel/PAL_TINT`.
- Task 2 also fixes a small existing bug the spec does not name: the near-level label stayed visible on the Dungeons tab (its check box was hidden but not its label).
