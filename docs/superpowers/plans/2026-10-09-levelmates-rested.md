# LevelMates: Rested XP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. Every task also REQUIRES the `wow-forever-addons` skill (API facts, tools, policy).

**Goal:** Show my rested XP (percent of a level) next to the board heading, notify once when it reaches the cap, and let guildmates who opt in share theirs, shown on hover over their row.

**Architecture:** A new `Rested.lua` computes my percent from `GetXPExhaustion()` / `UnitXPMax("player")`, owns the cap notice, the opt-in sharing and the values received from others. A new message kind `rx` (field `p`, -1..200; -1 = no longer sharing) — never a field on `hb`. Sends ride the roster hooks that already exist: `LM_HB_SENT` (after every heartbeat), `LM_ANNOUNCED`, `LM_PING_ANSWERED`, `LM_COMM_STOPPING`. `Board.lua` adds a header text and extends the row tooltip.

**Tech Stack:** Lua 5.1 (WoW Forever client, interface 16001), the repo's fengari harness (`node tools/run-lua-test.mjs LevelMates tests/<name>.test.lua`), `npm test`.

**Spec:** `docs/superpowers/specs/2026-10-09-levelmates-rested-design.md`

## Global Constraints

- Sharing my rested XP is opt-in, **off by default** (`shareRested = false`); the cap notice is on by default (`restedNotices = true`).
- Requires "Appear on the board" to send anything; nothing but `help`/`helpok` inside instances (`INSTANCE_OK` unchanged).
- Percent = `floor(rested / UnitXPMax("player") × 100 + 0.5)`, `GetXPExhaustion()` nil = 0, capped at 150; nothing shown or shared at level ≥ 60.
- Message `rx`: field `p`, integer -1..200, required; `-1` = withdraw. Never a field on `hb`.
- Sends: when sharing is turned on (and `-1` when off); right after my heartbeat on login/reload and to a newcomer; after a heartbeat only if the value changed ≥ 5 points and ≥ 60 s passed since the last send; `-1` immediately when "Appear on the board" is turned off.
- A received value disappears with `-1`, `bye`, roster expiry, or sharing off. Values from names the roster does not know are ignored.
- Strings through `L` (enUS, esES). `npm test` green after every task.

## Review Focus

1. Privacy: with the default settings nothing about rested XP leaves the client, even after many heartbeats (Task 1 test "not shared by default").
2. Older versions: the value never rides on `hb` (Task 1 test checks every `hb` we send has no `p`).
3. Chatter: small changes (< 5 points) and changes within a minute are not sent; a newcomer still gets the current value right after my heartbeat (Task 1 tests).
4. Withdrawal: turning sharing off, or turning "Appear on the board" off, sends `-1` before anything stops; others' values disappear with `bye` (Task 1 tests).
5. Edge values: no rested XP, the cap, max level — no division by zero, no "nil%" in the header (Task 1 calculation tests; Task 2 header test at level 60).

---

## File Structure

| File | Responsibility |
|---|---|
| `LevelMates/Rested.lua` (new) | My percent, cap notice, opt-in sharing, received values. No UI. |
| `LevelMates/Comm.lua` (modify) | Schema for `rx`. |
| `LevelMates/Core.lua`, `Settings.lua`, `Locales/*.lua`, `LevelMates.toc` (modify) | Defaults, two options, strings, load order (`Rested.lua` after `Partner.lua`). |
| `LevelMates/Board.lua` (modify) | Header text next to the heading; tooltip line. |
| `LevelMates/Sim.lua`, `README.md`, `CHANGELOG.md` (modify) | `/lm sim rested`, docs. |
| `tools/wow-stub.lua` (modify) | `GetXPExhaustion()` from `STUB.player.rested`. |

---

### Task 1: The `rx` message and Rested.lua

**Files:**
- Create: `LevelMates/Rested.lua`, `tests/rested.test.lua`, `tests/rested_login.test.lua`, `tests/rested_options.test.lua`
- Modify: `LevelMates/Comm.lua`, `LevelMates/Core.lua`, `LevelMates/Settings.lua`, `LevelMates/Locales/enUS.lua`, `LevelMates/Locales/esES.lua`, `LevelMates/LevelMates.toc`, `tools/wow-stub.lua`, `tests/comm_format.test.lua`

**Interfaces:**
- Consumes: `ns.Comm.Send/SendImmediate/OnMessage`, `ns.Roster.mates`, events `LM_HB_SENT`, `LM_ANNOUNCED`, `LM_PING_ANSWERED`, `LM_ROSTER_CHANGED`, `LM_COMM_STOPPING`, `LM_COMM_STOPPED`, `LM_WORLD`.
- Produces: `ns.Rested.Mine() -> integer|nil`, `ns.Rested.Of(name) -> integer|nil`, `ns.Rested.SetSharing(on)`, `ns.Rested.CAP` (150), event `LM_RESTED_CHANGED`.

- [ ] **Step 1: Write the failing tests**

In `tools/wow-stub.lua`, after `function UnitXPMax() return 1000 end` add:

```lua
function GetXPExhaustion() return STUB.player.rested end
```

Append to `tests/comm_format.test.lua` before the final `print("ok")`:

```lua
-- rested XP
local kr, fr = C.Decode(C.Encode("rx", { p = 45 }))
assert(kr == "rx" and fr.p == 45, "rx roundtrip")
assert(C.Validate("rx", { p = -1 }) == true, "-1 withdraws")
assert(C.Validate("rx", { p = -2 }) == false and C.Validate("rx", { p = 201 }) == false and C.Validate("rx", {}) == false, "range and required")
```

`tests/rested.test.lua`:

```lua
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local C, X, L = ns.Comm, ns.Rested, ns.L
local function mate(name) STUB.Receive("LVLM", C.Encode("hb", { l = 20, z = 1421 }), "GUILD", name .. "-Testrealm") end
local function rx(name, p) STUB.Receive("LVLM", C.Encode("rx", { p = p }), "GUILD", name .. "-Testrealm") end
local function sentRx(from)
	local out = {}
	for i = from, #STUB.sent do local k, f = C.Decode(STUB.sent[i].msg); if k == "rx" then out[#out + 1] = f.p end end
	return out
end
assert(ns.db.settings.restedNotices == true and ns.db.settings.shareRested == false, "defaults: notice on, sharing off")

-- calculation (UnitXPMax is 1000 in the stub)
STUB.player.level = 20
STUB.player.rested = nil
assert(X.Mine() == 0, "no rested XP: 0")
STUB.player.rested = 454
assert(X.Mine() == 45, "rounded percent of a level: " .. X.Mine())
STUB.player.rested = 2000
assert(X.Mine() == 150, "capped at 150")
STUB.player.level = 60
assert(X.Mine() == nil, "hidden at max level")
STUB.player.level = 20

-- the cap notice, once per session
local printed = #STUB.printed
STUB.player.rested = 1500
STUB.Fire("UPDATE_EXHAUSTION")
assert(#STUB.printed == printed + 1 and STUB.printed[#STUB.printed]:find("150", 1, true), "max notice")
STUB.Fire("UPDATE_EXHAUSTION"); STUB.Fire("PLAYER_UPDATE_RESTING")
assert(#STUB.printed == printed + 1, "only once")

-- nothing shared by default, and never on hb
local n = #STUB.sent + 1
STUB.Advance(200)
assert(#sentRx(n) == 0, "not shared by default")
for i = 1, #STUB.sent do
	local k, f = C.Decode(STUB.sent[i].msg)
	if k == "hb" then assert(f.p == nil, "never rides on hb") end
end

-- turning sharing on sends at once
ns.db.settings.shareRested = true; X.SetSharing(true)
local s = sentRx(n)
assert(#s == 1 and s[1] == 150, "sent when turned on: " .. table.concat(s, ","))

-- after heartbeats: only a 5-point change, at most once a minute
n = #STUB.sent + 1
STUB.player.rested = 1480
STUB.Advance(200)
assert(#sentRx(n) == 0, "a 2-point change is not sent")
STUB.player.rested = 1000
STUB.Advance(200)
s = sentRx(n)
assert(#s == 1 and s[1] == 100, "a big change goes out with a heartbeat: " .. table.concat(s, ","))

-- a newcomer gets it right after my heartbeat
n = #STUB.sent
STUB.Receive("LVLM", C.Encode("ping", {}), "GUILD", "Nuevo-Testrealm")
STUB.Advance(6)
local order = {}
for i = n + 1, #STUB.sent do local k = C.Decode(STUB.sent[i].msg); if k == "hb" or k == "rx" then order[#order + 1] = k end end
assert(order[1] == "hb" and order[2] == "rx", "hb then rx: " .. table.concat(order, ","))

-- inside an instance nothing goes out
STUB.inInstance = true
n = #STUB.sent + 1
STUB.player.rested = 200
STUB.Advance(200)
assert(#sentRx(n) == 0, "nothing inside an instance")
STUB.inInstance = false

-- turning sharing off withdraws at once
n = #STUB.sent + 1
ns.db.settings.shareRested = false; X.SetSharing(false)
s = sentRx(n)
assert(#s == 1 and s[1] == -1, "withdrawn: " .. table.concat(s, ","))

-- receiving
mate("Mario"); mate("Ana")
rx("Mario", 45)
assert(X.Of("Mario") == 45, "stored")
rx("Stranger", 30)
assert(X.Of("Stranger") == nil, "unknown ignored")
rx("Mario", -1)
assert(X.Of("Mario") == nil, "-1 clears")
rx("Ana", 80)
STUB.Receive("LVLM", C.Encode("bye", {}), "GUILD", "Ana-Testrealm")
assert(X.Of("Ana") == nil, "bye clears")

-- "Appear on the board" off: -1 before the transport stops, others forgotten
ns.db.settings.shareRested = true; X.SetSharing(true)
mate("Luis"); rx("Luis", 10)
ns.db.settings.share = false; C.Stop()
local k, f = C.Decode(STUB.sent[#STUB.sent].msg)
assert(k == "rx" and f.p == -1, "rx -1 before the transport stops")
assert(X.Of("Luis") == nil, "others forgotten")
```

`tests/rested_login.test.lua`:

```lua
-- Logging in with full rested XP says so.
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.player.level = 20; STUB.player.rested = 1600
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(2)
local found = false
for _, line in ipairs(STUB.printed) do if line:find(string.format(ns.L.RESTED_MAX, ns.Rested.CAP), 1, true) then found = true end end
assert(found, "max notice at login")
```

`tests/rested_options.test.lua`:

```lua
-- The cap notice can be turned off.
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
ns.db.settings.restedNotices = false
STUB.player.level = 20; STUB.player.rested = 1600
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(2)
STUB.Fire("UPDATE_EXHAUSTION")
for _, line in ipairs(STUB.printed) do assert(not line:find(string.format(ns.L.RESTED_MAX, ns.Rested.CAP), 1, true), "no max notice with the option off") end
```

- [ ] **Step 2: Run the tests to see them fail**

Run each: `node tools/run-lua-test.mjs LevelMates tests/comm_format.test.lua` (Expected: LUA ERROR at `rx roundtrip`), `tests/rested.test.lua` (Expected: LUA ERROR at `defaults: notice on, sharing off`), `tests/rested_login.test.lua` (Expected: LUA ERROR, `ns.Rested` nil or notice missing), `tests/rested_options.test.lua` (Expected: LUA ERROR, `ns.Rested` nil).

- [ ] **Step 3: Implement**

`LevelMates/Comm.lua`: in `C.SCHEMA` add `rx   = { p = int(-1, 200) },` next to `pal`, and in `REQUIRED` add `rx = { "p" },`.

`LevelMates/Core.lua`: change `shareQuests = false, shareXp = false,` to `shareQuests = false, shareXp = false, shareRested = false,` and `palNotices = true,` to `palNotices = true, restedNotices = true,`.

`LevelMates/Settings.lua`: after `Bool(category, "shareXp", L.OPT_XPH, L.OPT_XPH_TT)` add:

```lua
	Bool(category, "shareRested", L.OPT_RESTED, L.OPT_RESTED_TT, function(v) ns.Rested.SetSharing(v) end)
```

and after `Bool(category, "palNotices", L.OPT_PAL, L.OPT_PAL_TT)` add:

```lua
	Bool(category, "restedNotices", L.OPT_RESTED_NOTICE, L.OPT_RESTED_NOTICE_TT)
```

`LevelMates/Locales/enUS.lua` append:

```lua
L.RESTED_MINE = "Rested: %d%%"; L.RESTED_THEIRS = "Rested: %d%% of a level"
L.RESTED_MAX = "Your rested XP is at its maximum (%d%%)."
L.OPT_RESTED = "Share my rested XP"; L.OPT_RESTED_TT = "Guildmates see it when they hover your name. Off by default."
L.OPT_RESTED_NOTICE = "Rested XP maximum notice"; L.OPT_RESTED_NOTICE_TT = "A chat line when your rested XP reaches its maximum."
```

`LevelMates/Locales/esES.lua` append:

```lua
L.RESTED_MINE = "Descansada: %d%%"; L.RESTED_THEIRS = "Descansada: %d%% de un nivel"
L.RESTED_MAX = "Tu XP descansada está al máximo (%d%%)."
L.OPT_RESTED = "Compartir mi XP descansada"; L.OPT_RESTED_TT = "Los hermanos la ven al pasar el ratón por tu nombre. Apagado por defecto."
L.OPT_RESTED_NOTICE = "Aviso de XP descansada al máximo"; L.OPT_RESTED_NOTICE_TT = "Una línea en el chat cuando tu XP descansada llega al máximo."
```

`LevelMates/LevelMates.toc`: add `Rested.lua` right after `Partner.lua`.

Create `LevelMates/Rested.lua`:

```lua
-- Rested.lua: my rested XP (percent of a level), the cap notice, and opt-in sharing with the guild.
-- The value travels in its own kind `rx` (-1 = no longer sharing): older versions reject an hb with an unknown field.
local _, ns = ...
local X = {}
ns.Rested = X
local L, C, R = ns.L, ns.Comm, ns.Roster
X.CAP, X.MAX_LEVEL = 150, 60
local STEP, MIN_GAP = 5, 60
local theirs = {}                 -- name -> percent shared by that guildmate
local lastSentPct, lastSentAt = nil, -math.huge
local notifiedMax = false

-- My rested XP as a percent of the current level, capped; nil at max level.
function X.Mine()
	if UnitLevel("player") >= X.MAX_LEVEL then return nil end
	local max = UnitXPMax("player") or 0
	if max <= 0 then return 0 end
	local pct = math.floor((GetXPExhaustion() or 0) / max * 100 + 0.5)
	return math.min(X.CAP, pct)
end

function X.Of(name) return theirs[name] end

local function sharing() return ns.db.settings.shareRested == true end

local function send(p, prio)
	if C.Send("rx", { p = p }, prio) then lastSentPct, lastSentAt = p, GetTime(); return true end
	return false
end

-- force: login, newcomers, turning sharing on. Otherwise only a 5-point change, at most once a minute.
local function sendMine(force)
	if not sharing() then return end
	local p = X.Mine()
	if not p then return end
	if force then
		if lastSentAt == GetTime() and lastSentPct == p then return end   -- a heartbeat already carried it this instant
	else
		if lastSentPct and math.abs(p - lastSentPct) < STEP then return end
		if GetTime() - lastSentAt < MIN_GAP then return end
	end
	send(p)
end

-- Called from the settings check box (a click).
function X.SetSharing(on)
	if on then sendMine(true) else send(-1, "now"); lastSentPct = nil end
end

-- The cap notice and the header refresh.
function X.Check()
	local p = X.Mine()
	if p and p >= X.CAP and not notifiedMax and ns.db.settings.restedNotices then
		notifiedMax = true
		ns.Say(L.RESTED_MAX, X.CAP)
	end
	ns.Fire("LM_RESTED_CHANGED")
end

C.OnMessage("rx", function(f, name)
	if not R.mates[name] then return end   -- only people the roster knows
	theirs[name] = f.p >= 0 and f.p or nil
	ns.Fire("LM_RESTED_CHANGED")
end)

ns.On("LM_HB_SENT", function() sendMine(false) end)
ns.On("LM_ANNOUNCED", function() sendMine(true) end)
ns.On("LM_PING_ANSWERED", function() sendMine(true) end)
ns.On("LM_ROSTER_CHANGED", function()   -- bye and expiry take the value along
	for name in pairs(theirs) do if not R.mates[name] then theirs[name] = nil end end
end)
ns.On("LM_COMM_STOPPING", function() if sharing() then C.SendImmediate("rx", { p = -1 }) end end)
ns.On("LM_COMM_STOPPED", function() wipe(theirs); lastSentPct = nil; ns.Fire("LM_RESTED_CHANGED") end)
ns.On("LM_WORLD", function() C_Timer.After(1, X.Check) end)

local ev = CreateFrame("Frame")
ev:RegisterEvent("UPDATE_EXHAUSTION"); ev:RegisterEvent("PLAYER_UPDATE_RESTING")
ev:RegisterEvent("PLAYER_XP_UPDATE"); ev:RegisterEvent("PLAYER_LEVEL_UP")
ev:SetScript("OnEvent", function() X.Check() end)
```

- [ ] **Step 4: Run the tests and the whole suite**

Run: `node tools/run-lua-test.mjs LevelMates tests/rested.test.lua`, `tests/rested_login.test.lua`, `tests/rested_options.test.lua` — Expected: `ok` each.
Run: `npm test` — Expected: all `ok`.

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat(rested): rx message, my percent, cap notice and opt-in sharing"
```

---

### Task 2: Board header text and tooltip

**Files:**
- Modify: `LevelMates/Board.lua`
- Create: `tests/board_rested.test.lua`

**Interfaces:**
- Consumes: `ns.Rested.Mine/Of`, event `LM_RESTED_CHANGED`, the existing heading and row `OnEnter`.
- Produces: `ns.Board.restedText` (FontString next to the heading).

- [ ] **Step 1: Write the failing test**

`tests/board_rested.test.lua`:

```lua
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local C, B, L = ns.Comm, ns.Board, ns.L
STUB.player.level = 20; STUB.player.rested = 450
STUB.Receive("LVLM", C.Encode("hb", { l = 21, z = 1421 }), "GUILD", "Mario-Testrealm")
STUB.Receive("LVLM", C.Encode("rx", { p = 80 }), "GUILD", "Mario-Testrealm")
STUB.Receive("LVLM", C.Encode("hb", { l = 40, z = 1421 }), "GUILD", "Ana-Testrealm")
B.Toggle()
local function rowOf(name) for i = 1, #B.rows do if B.rows[i].name.text == name then return B.rows[i] end end end

assert(B.restedText and B.restedText.text == string.format(L.RESTED_MINE, 45), "my rested next to the heading: " .. tostring(B.restedText and B.restedText.text))
STUB.player.rested = 1000; STUB.Fire("UPDATE_EXHAUSTION")
assert(B.restedText.text == string.format(L.RESTED_MINE, 100), "updates on the event")
B.tabs.lfg.scripts.OnClick(B.tabs.lfg)
assert(B.restedText.text == string.format(L.RESTED_MINE, 100), "also on the Dungeons tab")
B.tabs.mates.scripts.OnClick(B.tabs.mates)

local mario = rowOf("Mario")
mario.button.scripts.OnEnter(mario.button)
assert(GameTooltip.lines[1] == string.format(L.RESTED_THEIRS, 80) and not GameTooltip.hidden, "their rested on hover")
mario.button.scripts.OnLeave(mario.button)
local ana = rowOf("Ana")
ana.button.scripts.OnEnter(ana.button)
assert(GameTooltip.hidden, "no tooltip when there is nothing to say")

STUB.player.level = 60; STUB.Fire("PLAYER_LEVEL_UP", 60)
assert(B.restedText.text == "", "hidden at max level")
```

- [ ] **Step 2: Run the test to see it fail**

Run: `node tools/run-lua-test.mjs LevelMates tests/board_rested.test.lua` — Expected: LUA ERROR at `my rested next to the heading` (`B.restedText` is nil).

- [ ] **Step 3: Implement** (all in `LevelMates/Board.lua`)

(a) After the line `B.heading:SetPoint("TOPLEFT", B.MARGIN, -(insetTop + 10)); B.heading:SetText(L.BOARD_HEADING); B.heading:SetJustifyH("LEFT")` add:

```lua
	B.restedText = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")   -- my rested XP, next to the heading
	B.restedText:SetPoint("LEFT", B.heading, "RIGHT", 12, 0); B.restedText:SetTextColor(0.6, 0.8, 1)
```

(b) Replace the mates branch of the row `OnEnter` handler:

```lua
			elseif B.tab == "mates" and self.mate and ns.Partner and ns.Partner.Matches(self.mate) then   -- a partner match
				GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:AddLine(L.PAL_TOOLTIP, 0.4, 1, 0.4); GameTooltip:Show()
			end
```

with:

```lua
			elseif B.tab == "mates" and self.mate then   -- partner match and shared rested XP
				local lines = {}
				if ns.Partner and ns.Partner.Matches(self.mate) then lines[#lines + 1] = { L.PAL_TOOLTIP, 0.4, 1, 0.4 } end
				local rx = ns.Rested and ns.Rested.Of(self.mate)
				if rx then lines[#lines + 1] = { string.format(L.RESTED_THEIRS, rx), 0.6, 0.8, 1 } end
				if #lines > 0 then
					GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
					for _, l in ipairs(lines) do GameTooltip:AddLine(l[1], l[2], l[3], l[4]) end
					GameTooltip:Show()
				end
			end
```

(c) In `function B.Refresh()`, replace the two lines

```lua
	B.SetTitle(B.TitleString())
	if lfg then FillLfg(list) else FillMates(list) end
```

with:

```lua
	B.SetTitle(B.TitleString())
	local rested = ns.Rested and ns.Rested.Mine()
	B.restedText:SetText(rested and string.format(L.RESTED_MINE, rested) or "")
	if lfg then FillLfg(list) else FillMates(list) end
```

(d) At the end of the file add `ns.On("LM_RESTED_CHANGED", B.Refresh)`.

- [ ] **Step 4: Run the test and the whole suite**

Run: `node tools/run-lua-test.mjs LevelMates tests/board_rested.test.lua` — Expected: `ok`. Run: `npm test` — Expected: all `ok` (the partner tooltip test still passes: its line is now the first of a list).

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat(board): rested XP next to the heading and on hover"
```

---

### Task 3: Simulation and documentation

**Files:**
- Modify: `LevelMates/Sim.lua`, `README.md`, `CHANGELOG.md`
- Create: `tests/sim_rested.test.lua`

**Interfaces:**
- Consumes: `ns.Comm.Inject`, `ns.Rested.Of`, `ns.Roster`.
- Produces: `/lm sim rested` (Mario 80 %, Luis 150 %, local only); `/lm sim off` clears them through `bye`.

- [ ] **Step 1: Write the failing test**

`tests/sim_rested.test.lua`:

```lua
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
STUB.player.realm = "Classic Beta PvP"
STUB.ambiguateKeepsRealm = true
local X = ns.Rested
SlashCmdList["LEVELMATES"]("sim")
local sentBefore = #STUB.sent
SlashCmdList["LEVELMATES"]("sim rested")
assert(X.Of("Mario") == 80 and X.Of("Luis") == 150, "fake shared values")
assert(#STUB.sent == sentBefore, "the simulation sends nothing")
SlashCmdList["LEVELMATES"]("sim off")
assert(X.Of("Mario") == nil and X.Of("Luis") == nil, "sim off clears them")
```

- [ ] **Step 2: Run the test to see it fail**

Run: `node tools/run-lua-test.mjs LevelMates tests/sim_rested.test.lua` — Expected: LUA ERROR at `fake shared values`.

- [ ] **Step 3: Implement**

In `LevelMates/Sim.lua`, after the `simPal` function add:

```lua
local function simRested()
	if not R.mates.Mario then run() end   -- the values need their owners in the roster
	inject("rx", { p = 80 }, "Mario"); inject("rx", { p = 150 }, "Luis")
end
```

and in the slash handler, after the line `elseif rest == "pal" or rest == "compa" then simPal()`, add:

```lua
	elseif rest == "rested" or rest == "descanso" then simRested()
```

`README.md`, English "What it does", add:
`- **Rested XP**: yours next to the board heading, with a chat line when it reaches the maximum; guildmates who opt in ("Share my rested XP", off by default) show theirs when you hover their name.`
and add `/lm sim rested` after `/lm sim pal` in the English Commands line. Spanish "Qué hace", add:
`- **XP descansada**: la tuya junto al título del tablón, con una línea en el chat cuando llega al máximo; los hermanos que lo activan ("Compartir mi XP descansada", apagado por defecto) muestran la suya al pasar el ratón por su nombre.`
and add `/lm sim rested` after `/lm sim pal` in the Comandos line. In the Privacy / Privacidad paragraphs, change "Your **position**, **quest ids** and **XP per hour**" to "Your **position**, **quest ids**, **XP per hour** and **rested XP**" and "Tu **posición**, tus **misiones** y tu **XP por hora**" to "Tu **posición**, tus **misiones**, tu **XP por hora** y tu **XP descansada**".
`CHANGELOG.md` append:

```
- Rested XP: yours next to the board heading and a chat line at the maximum; opt-in sharing (off by default) shows it to guildmates on hover. New message kind `rx`; older versions ignore it.
```

- [ ] **Step 4: Run the whole suite**

Run: `npm test` — Expected: all `ok`, exit code 0.

- [ ] **Step 5: In-game check (with the user), then commit**

In game: `/reload`; the header shows "Descansada: N%" next to "Hermanos conectados" without touching the search box; rest in an inn and watch it grow; `/lm sim rested` and hover Mario; check the cap (150 %?) and that it disappears at level 60.

```bash
git add -A && git commit -m "feat(rested): simulation and docs"
```

---

## Self-Review notes

- Spec §4 (calculation) and §5 (mine, notice) → Task 1 and Task 2; §6 (message, when sent) → Task 1; §7 (others, tooltip) → Task 2; §8 tests → each task; simulation → Task 3; §3 privacy → Global Constraints and the "not shared by default" test.
- Names consistent: `ns.Rested.Mine/Of/SetSharing/CAP/Check`, `LM_RESTED_CHANGED`, `B.restedText`, kind `rx`.
