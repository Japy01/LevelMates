# LevelMates v1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. Every task also REQUIRES the `wow-forever-addons` skill (API facts, tools, policy).

**Goal:** A guild leveling addon for WoW Forever: a board of online guildmates with the addon, quest matching, and help requests, shareable on CurseForge, policy-compliant and configurable.

**Architecture:** Pure in-game Lua addon. `Comm.lua` moves tiny validated messages between guildmates over addon messages (GUILD or a hidden temporary channel, chosen by a setting); `Roster.lua` keeps an in-memory picture of mates that expires; features (`Board`, `Match`, `Help`) read the roster and ask `Comm` to send; `Settings.lua` exposes every switch; only settings and window position persist in `LevelMatesDB`.

**Tech Stack:** Lua 5.1 (WoW client 1.60.1, interface 16001, Mainline API), `Settings.*` panel API, `C_ChatInfo` addon messages, `C_Map` waypoints. Tests: node + fengari with the skill's `wow-stub.lua`; syntax via luaparse. Packaging: BigWigs packager on GitHub Actions.

**Spec:** `docs/superpowers/specs/2026-10-08-levelmates-v1-design.md`

## Global Constraints

- `## Interface: 16001`, `## AllowLoadGameType: camelot`; API verified against `reference/wow-ui-source` (branch `forever`), never from memory.
- Policy: no combat data; chat, whisper, invite and quest push only inside click handlers; ≤ 1 heartbeat / 30 s per player; message ≤ 255 bytes; nothing sent while `C_ChatInfo.InChatMessagingLockdown()`; no external program, no network.
- Privacy defaults: share level + zone only; position, quests, XP/h opt-in.
- Every player-visible string goes through `L` (enUS base, esES complete).
- Addon-message prefix `LVLM`; wire format `v1<US>kind<US>k=v;k=v` with `%XX` escaping of `%`, `;`, `=`, bytes < 0x20.
- Transport selection: `LevelMatesDB.settings.transport` = `"guild"` | `"channel"` | `"auto"`; default decided by the spike (`spike/LM_CommTest`): `"guild"` if GUILD delivers from a timer, else `"channel"`. Until then the code treats `"auto"` as GUILD with CHANNEL fallback when the GUILD send result is not 0.
- Tests run from the repo root: `node tools/check-lua.mjs LevelMates` and `node tools/run-lua-test.mjs LevelMates tests/<name>.test.lua`.

## Review Focus

1. A guildmate without the addon, or with an older/newer version, sends nothing or a different `v`: the roster must ignore it silently (Task 2 test: unknown version and malformed fields are dropped, counted in `Comm.stats.bad`).
2. A stranger who joins the hidden channel and spoofs messages: in `channel` transport a message whose sender is not in the guild roster must be ignored (Task 3 test: `Roster.IsGuildmate` gate).
3. Lockdown mid-session (dungeon boss): sends must queue, not error, and resume (Task 2 test: `STUB.lockdown` on then off; compaction keeps one `hb`).
4. Rapid zone changes / login storms: `hb` only when something changed and never more than once per 30 s; `ping` answers are jittered 0-5 s (Task 3 test).
5. A help request from someone whose map differs from mine must still show a notice but no waypoint on my map (Task 7 test).

---

### Task 0: Skeleton, locales, core and test harness

**Files:**
- Create: `LevelMates/LevelMates.toc`, `LevelMates/Locales/enUS.lua`, `LevelMates/Locales/esES.lua`, `LevelMates/Core.lua`
- Create: `tools/check-lua.mjs`, `tools/run-lua-test.mjs`, `tools/wow-stub.lua`, `tools/package.json` (copied from the skill), `tests/core.test.lua`
- Create: `.pkgmeta`, `LICENSE` (MIT), `README.md`

**Interfaces:**
- Produces: `ns` (addon namespace table, second vararg of every file), `ns.L` (locale table), `ns.db` (SavedVariables root, set on `ADDON_LOADED`), `ns.char` (per-character table), `ns.Log(fmt, ...)` (debug print when `ns.db.settings.debug`), `ns.On(event, fn)` (event registration), `ns.Fire(event, ...)` (internal event bus for modules), `ns.Slash(sub, fn)` (subcommand registration), `ns.VERSION`.

- [ ] **Step 1: Copy the skill's tools into the repo**

```bash
mkdir -p tools tests LevelMates/Locales
cp ~/.claude/skills/wow-forever-addons/tools/{check-lua.mjs,run-lua-test.mjs,wow-stub.lua,package.json} tools/
cd tools && npm install --silent && cd ..
```

- [ ] **Step 2: Write the failing test** `tests/core.test.lua`

```lua
-- Core: SavedVariables defaults, per-character table, event bus, slash dispatch.
STUB.Fire("ADDON_LOADED", "LevelMates")
assert(type(LevelMatesDB) == "table", "db created")
assert(LevelMatesDB.settings.share == true, "default share on")
assert(LevelMatesDB.settings.sharePos == false, "position off by default")
assert(LevelMatesDB.settings.transport == "auto", "transport auto")
local _, ns = ...
assert(ns.db == LevelMatesDB, "ns.db bound")
assert(ns.char and ns.char == LevelMatesDB.chars["Tester-Testrealm"], "per-character table")
local got
ns.On("LM_TEST", function(a) got = a end)
ns.Fire("LM_TEST", 42)
assert(got == 42, "internal bus")
local ran
ns.Slash("ping", function(rest) ran = rest end)
SlashCmdList["LEVELMATES"]("ping hola")
assert(ran == "hola", "slash subcommand with rest")
assert(ns.L.BOARD_TITLE == "LevelMates", "locale loaded")
STUB.locale = "esES"
```

- [ ] **Step 3: Run it to see it fail**

Run: `node tools/run-lua-test.mjs LevelMates tests/core.test.lua`
Expected: LOAD ERROR (no .toc yet).

- [ ] **Step 4: Write the TOC**

`LevelMates/LevelMates.toc`:
```
## Interface: 16001
## Title: LevelMates
## Notes: See which guildmates are online and where, match quests with them, and ask for a hand with elites.|nAddon messages only. No combat data. Your position and quests are shared only if you turn it on.
## Notes-esES: Ve qué hermanos están conectados y dónde, empareja misiones con ellos y pide ayuda con los elites.|nSolo mensajes de addon. Nada de combate. Tu posición y tus misiones solo se comparten si lo activas.
## Author: Diego and contributors
## Version: @project-version@
## SavedVariables: LevelMatesDB
## IconTexture: Interface\AddOns\LevelMates\Media\icon
## AllowLoadGameType: camelot
## X-License: MIT
## X-Website: https://github.com/<owner>/LevelMates
Locales\enUS.lua
Locales\esES.lua
Core.lua
```

- [ ] **Step 5: Write the locales**

`LevelMates/Locales/enUS.lua`:
```lua
local _, ns = ...
local L = setmetatable({}, { __index = function(t, k) return k end })
ns.L = L
L.BOARD_TITLE = "LevelMates"
L.COL_NAME = "Name"; L.COL_LEVEL = "Lv"; L.COL_ZONE = "Zone"; L.COL_GROUP = "Group"; L.COL_XPH = "XP/h"
L.GROUP_FREE = "open"; L.GROUP_FULL = "full"; L.SOLO = "solo"
L.EMPTY = "No guildmates with LevelMates online right now."
L.NOT_IN_GUILD = "You are not in a guild."
L.MENU_INVITE = "Invite"; L.MENU_WHISPER = "Whisper"; L.MENU_WAYPOINT = "Set waypoint"
L.BTN_HELP = "Ask for help"; L.BTN_HELP_CANCEL = "Cancel help request"; L.BTN_COMING = "On my way"
L.HELP_PROMPT = "What do you need help with? (up to 60 characters)"
L.HELP_NOTICE = "%s needs help with %s in %s."
L.HELP_COMING = "On my way: %s"
L.HELP_DONE = "%s no longer needs help."
L.MATCH_HAS = "%s also has %s."
L.MATCH_CAN = "%s could pick up %s."
L.MATCH_NEEDS = "%s still needs %s."
L.OPT_SHARE = "Appear on the board (send my level and zone)"
L.OPT_SHARE_TT = "Every 30 seconds, when something changed. Off: you are invisible to the addon and see nobody."
L.OPT_POS = "Share my position"; L.OPT_POS_TT = "Lets guildmates set a waypoint to you. Off by default."
L.OPT_QUESTS = "Share my quests"; L.OPT_QUESTS_TT = "Only quest ids, for quest matching. Off by default."
L.OPT_XPH = "Share my XP per hour"; L.OPT_XPH_TT = "Shown on the board."
L.OPT_MATCH = "Quest match notices"; L.OPT_MATCH_TT = "A line when a guildmate in your zone shares a quest with you."
L.OPT_HELP = "Receive help requests"; L.OPT_HELP_TT = "A notice and a map waypoint when a guildmate asks for help."
L.OPT_SOUND = "Sound on notices"
L.OPT_MINIMAP = "Minimap button"
L.OPT_TRANSPORT = "Transport"; L.OPT_TRANSPORT_TT = "How messages travel. Auto tries the guild channel, then a hidden channel."
L.TRANSPORT_AUTO = "Auto"; L.TRANSPORT_GUILD = "Guild channel"; L.TRANSPORT_CHANNEL = "Hidden channel"
L.OPT_DEBUG = "Debug lines in chat"
L.HELP_CMD = "LevelMates: /lm (board), /lm help <text>, /lm cancel, /lm options, /lm debug"
L.STATUS = "LevelMates: %d mates online, transport %s, sent %d, received %d, dropped %d"
```

`LevelMates/Locales/esES.lua`:
```lua
local _, ns = ...
local loc = GetLocale()
if loc ~= "esES" and loc ~= "esMX" then return end
local L = ns.L
L.COL_NAME = "Nombre"; L.COL_LEVEL = "Niv"; L.COL_ZONE = "Zona"; L.COL_GROUP = "Grupo"; L.COL_XPH = "XP/h"
L.GROUP_FREE = "hueco"; L.GROUP_FULL = "lleno"; L.SOLO = "solo"
L.EMPTY = "Ningún hermano con LevelMates conectado ahora mismo."
L.NOT_IN_GUILD = "No estás en una hermandad."
L.MENU_INVITE = "Invitar"; L.MENU_WHISPER = "Susurrar"; L.MENU_WAYPOINT = "Poner punto de ruta"
L.BTN_HELP = "Pedir ayuda"; L.BTN_HELP_CANCEL = "Cancelar petición"; L.BTN_COMING = "Voy"
L.HELP_PROMPT = "¿Con qué necesitas ayuda? (hasta 60 caracteres)"
L.HELP_NOTICE = "%s necesita ayuda con %s en %s."
L.HELP_COMING = "Voy: %s"
L.HELP_DONE = "%s ya no necesita ayuda."
L.MATCH_HAS = "%s también tiene %s."
L.MATCH_CAN = "%s podría coger %s."
L.MATCH_NEEDS = "A %s le falta %s."
L.OPT_SHARE = "Aparecer en el tablón (enviar mi nivel y zona)"
L.OPT_SHARE_TT = "Cada 30 segundos, cuando algo cambia. Apagado: eres invisible para el addon y no ves a nadie."
L.OPT_POS = "Compartir mi posición"; L.OPT_POS_TT = "Permite a los hermanos poner un punto de ruta hacia ti. Apagado por defecto."
L.OPT_QUESTS = "Compartir mis misiones"; L.OPT_QUESTS_TT = "Solo ids de misión, para emparejar. Apagado por defecto."
L.OPT_XPH = "Compartir mi XP por hora"; L.OPT_XPH_TT = "Se muestra en el tablón."
L.OPT_MATCH = "Avisos de misiones compartidas"; L.OPT_MATCH_TT = "Una línea cuando un hermano de tu zona comparte misión contigo."
L.OPT_HELP = "Recibir peticiones de ayuda"; L.OPT_HELP_TT = "Un aviso y un punto de ruta cuando un hermano pide ayuda."
L.OPT_SOUND = "Sonido en los avisos"
L.OPT_MINIMAP = "Botón del minimapa"
L.OPT_TRANSPORT = "Transporte"; L.OPT_TRANSPORT_TT = "Por dónde viajan los mensajes. Auto prueba el canal de hermandad y luego uno oculto."
L.TRANSPORT_AUTO = "Automático"; L.TRANSPORT_GUILD = "Canal de hermandad"; L.TRANSPORT_CHANNEL = "Canal oculto"
L.OPT_DEBUG = "Líneas de depuración en el chat"
L.HELP_CMD = "LevelMates: /lm (tablón), /lm ayuda <texto>, /lm cancelar, /lm opciones, /lm debug"
L.STATUS = "LevelMates: %d hermanos conectados, transporte %s, enviados %d, recibidos %d, descartados %d"
```

- [ ] **Step 6: Write Core.lua**

```lua
-- Core.lua: SavedVariables, event bus, slash commands. Nothing here talks to other players.
local ADDON, ns = ...
ns.VERSION = C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(ADDON, "Version") or "dev"

local DEFAULTS = {
	share = true, sharePos = false, shareQuests = false, shareXp = false,
	matchNotices = true, helpNotices = true, sound = true, minimap = true,
	transport = "auto", debug = false,
}

local bus = {}
function ns.On(event, fn) bus[event] = bus[event] or {}; table.insert(bus[event], fn) end
function ns.Fire(event, ...) local list = bus[event]; if not list then return end; for _, fn in ipairs(list) do fn(...) end end

function ns.Log(fmt, ...)
	if ns.db and ns.db.settings.debug then print("|cff7ec8ffLevelMates|r " .. string.format(fmt, ...)) end
end
function ns.Say(fmt, ...) print("|cff7ec8ffLevelMates|r " .. string.format(fmt, ...)) end

function ns.PlayerKey()
	local name, realm = UnitName("player")
	realm = realm and realm ~= "" and realm or GetRealmName()
	return name .. "-" .. realm
end

local subs = {}
function ns.Slash(sub, fn) subs[sub] = fn end
SLASH_LEVELMATES1 = "/lm"; SLASH_LEVELMATES2 = "/levelmates"
SlashCmdList["LEVELMATES"] = function(msg)
	msg = strtrim(msg or "")
	local sub, rest = msg:match("^(%S+)%s*(.-)$")
	local fn = subs[sub and sub:lower() or ""]
	if fn then fn(rest) else ns.Fire("LM_TOGGLE_BOARD") end
end

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("PLAYER_LOGOUT")
f:SetScript("OnEvent", function(_, event, arg1, ...)
	if event == "ADDON_LOADED" then
		if arg1 ~= ADDON then return end
		LevelMatesDB = LevelMatesDB or { version = 1, settings = {}, chars = {} }
		ns.db = LevelMatesDB
		ns.db.settings = ns.db.settings or {}
		for k, v in pairs(DEFAULTS) do if ns.db.settings[k] == nil then ns.db.settings[k] = v end end
		ns.db.chars = ns.db.chars or {}
		local key = ns.PlayerKey()
		ns.db.chars[key] = ns.db.chars[key] or {}
		ns.char = ns.db.chars[key]
		ns.Fire("LM_LOADED")
	elseif event == "PLAYER_ENTERING_WORLD" then
		ns.Fire("LM_WORLD", arg1, ...)   -- isInitialLogin, isReloadingUi
	elseif event == "PLAYER_LOGOUT" then
		ns.Fire("LM_LOGOUT")
	end
end)
```

- [ ] **Step 7: Run the test**

Run: `node tools/run-lua-test.mjs LevelMates tests/core.test.lua`
Expected: `ok tests/core.test.lua`. If `GetRealmName` or `C_AddOns` is missing in the stub, add `function GetRealmName() return STUB.player.realm end` and `C_AddOns = { GetAddOnMetadata = function() return "dev" end }` to `tools/wow-stub.lua`.

- [ ] **Step 8: Syntax, packaging metadata, commit**

`.pkgmeta`:
```yaml
package-as: LevelMates
enable-nolib-creation: no
ignore:
  - tests
  - tools
  - docs
  - spike
  - reference
```
Run: `node tools/check-lua.mjs LevelMates`
```bash
git add -A && git commit -m "feat: skeleton, locales, core, test harness"
```

---

### Task 1: Wire format (encode, decode, validate)

**Files:**
- Create: `LevelMates/Comm.lua` (first half), `tests/comm_format.test.lua`
- Modify: `LevelMates/LevelMates.toc` (add `Comm.lua` after `Core.lua`)

**Interfaces:**
- Produces: `ns.Comm.Encode(kind, fields) -> string|nil, err` (fields: table of string/number values; result ≤ 255 bytes or nil), `ns.Comm.Decode(text) -> kind, fields | nil, reason`, `ns.Comm.SCHEMA[kind]` (field name → validator), `ns.Comm.Validate(kind, fields) -> boolean, reason`.

- [ ] **Step 1: Write the failing test** `tests/comm_format.test.lua`

```lua
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
local C = ns.Comm
local s = C.Encode("hb", { l = 22, z = 1421, g = 1, s = 0, c = "WARRIOR" })
assert(s and s:sub(1, 2) == "v1", "starts with version: " .. tostring(s))
assert(not s:find("\n"), "no newlines")
local kind, f = C.Decode(s)
assert(kind == "hb" and f.l == 22 and f.z == 1421 and f.g == 1 and f.c == "WARRIOR", "roundtrip")
-- escaping of separators and percent
local e = C.Encode("help", { t = "Fuerte Colmillo; =50% elite", z = 1421, x = 44.4, y = 41.1, id = "a1b2" })
local k2, f2 = C.Decode(e)
assert(f2.t == "Fuerte Colmillo; =50% elite", "escaped text roundtrip: " .. tostring(f2.t))
-- size limit
local big = C.Encode("help", { t = string.rep("x", 300), z = 1, x = 1, y = 1, id = "a" })
assert(big == nil, "over 255 bytes refused")
-- validation
assert(C.Validate("hb", { l = 22, z = 1421 }) == true, "minimal hb valid")
assert(C.Validate("hb", { l = 999, z = 1421 }) == false, "level out of range")
assert(C.Validate("hb", { l = 22, z = "abc" }) == false, "map id must be number")
assert(C.Validate("help", { t = "x", z = 1, x = 50, y = 50, id = "a1b2" }) == true, "help valid")
assert(C.Validate("help", { t = "a|cffff0000x", z = 1, x = 50, y = 50, id = "a1b2" }) == false, "pipe refused in text")
assert(C.Validate("nope", {}) == false, "unknown kind")
assert(select(1, C.Decode("v9\31hb\31l=1")) == nil, "unknown version dropped")
assert(select(1, C.Decode("garbage")) == nil, "garbage dropped")
```

- [ ] **Step 2: Run it to see it fail**

Run: `node tools/run-lua-test.mjs LevelMates tests/comm_format.test.lua`
Expected: LUA ERROR `attempt to index a nil value (field 'Comm')`.

- [ ] **Step 3: Write Comm.lua (format part)**

```lua
-- Comm.lua: wire format and (Task 2) transport. Format: "v1<US>kind<US>k=v;k=v", US = \031.
local _, ns = ...
local C = {}
ns.Comm = C
C.VERSION = "v1"
C.PREFIX = "LVLM"
C.MAX_BYTES = 255
local US = "\031"

local function esc(s)
	return (tostring(s):gsub("[%%;=%c]", function(ch) return string.format("%%%02X", ch:byte()) end))
end
local function unesc(s)
	return (s:gsub("%%(%x%x)", function(h) return string.char(tonumber(h, 16)) end))
end

local function num(min, max) return function(v) v = tonumber(v); return v ~= nil and v >= min and v <= max end end
local function int(min, max) return function(v) v = tonumber(v); return v ~= nil and v == math.floor(v) and v >= min and v <= max end end
local function text(max) return function(v) return type(v) == "string" and #v >= 1 and #v <= max and not v:find("[%c|]") end end
local function word(max) return function(v) return type(v) == "string" and v:match("^[%w_%-]+$") ~= nil and #v <= max end end
local function idlist(max) return function(v) if type(v) == "number" then v = tostring(v) end; return type(v) == "string" and #v <= max and v:match("^%d+[,%d]*$") ~= nil end end

-- field validators; required fields are listed in REQUIRED
C.SCHEMA = {
	hb   = { l = int(1, 100), z = int(0, 100000), g = int(0, 1), s = int(0, 1), x = num(0, 100), y = num(0, 100), r = int(0, 999999), c = word(16), v = word(20) },
	q    = { i = word(7), ids = idlist(240) },
	help = { t = text(60), z = int(0, 100000), x = num(0, 100), y = num(0, 100), id = word(8) },
	helpok = { id = word(8) },
	bye  = {},
	ping = {},
}
local REQUIRED = { hb = { "l", "z" }, q = { "i", "ids" }, help = { "t", "z", "x", "y", "id" }, helpok = { "id" }, bye = {}, ping = {} }

function C.Validate(kind, fields)
	local schema = C.SCHEMA[kind]
	if not schema or type(fields) ~= "table" then return false, "kind" end
	for _, k in ipairs(REQUIRED[kind]) do if fields[k] == nil then return false, "missing " .. k end end
	for k, v in pairs(fields) do
		local check = schema[k]
		if not check then return false, "unknown " .. k end
		if not check(v) then return false, "bad " .. k end
	end
	return true
end

function C.Encode(kind, fields)
	local ok, why = C.Validate(kind, fields)
	if not ok then return nil, why end
	local parts, keys = {}, {}
	for k in pairs(fields) do keys[#keys + 1] = k end
	table.sort(keys)
	for _, k in ipairs(keys) do parts[#parts + 1] = k .. "=" .. esc(fields[k]) end
	local s = C.VERSION .. US .. kind .. US .. table.concat(parts, ";")
	if #s > C.MAX_BYTES then return nil, "too long" end
	return s
end

function C.Decode(s)
	if type(s) ~= "string" or #s > C.MAX_BYTES then return nil, "size" end
	local ver, kind, body = s:match("^([^\31]+)\31([^\31]+)\31(.*)$")
	if ver ~= C.VERSION then return nil, "version" end
	local fields = {}
	if body ~= "" then
		for pair in (body .. ";"):gmatch("([^;]*);") do
			local k, v = pair:match("^([%w_]+)=(.*)$")
			if not k then return nil, "pair" end
			v = unesc(v)
			local n = tonumber(v)
			fields[k] = (n ~= nil and v:match("^%-?%d+%.?%d*$")) and n or v
		end
	end
	local ok, why = C.Validate(kind, fields)
	if not ok then return nil, why end
	return kind, fields
end
```
Note: decoded numeric-looking strings become numbers; `ids` is validated by `idlist` which accepts both. `t` (help text) is validated after unescaping, so `|` and control bytes are refused even if escaped.

- [ ] **Step 4: Add `Comm.lua` to the TOC after `Core.lua`; run the test**

Run: `node tools/run-lua-test.mjs LevelMates tests/comm_format.test.lua`
Expected: `ok`.

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat(comm): wire format with validation and escaping"
```

---

### Task 2: Transport: queue, throttle, lockdown, GUILD/CHANNEL backends

**Files:**
- Modify: `LevelMates/Comm.lua` (second half), `tests/comm_transport.test.lua`
- Modify: `tools/wow-stub.lua` (add `GetChannelName`/`JoinTemporaryChannel` if missing, `IsInGuild`, `GetGuildInfo`)

**Interfaces:**
- Consumes: `ns.On`, `ns.db.settings.transport`, `C.Encode/Decode`.
- Produces: `C.Send(kind, fields, prio)` (prio `"now"` or `"normal"`), `C.OnMessage(kind, fn(fields, senderName, senderFull))`, `C.Start()`, `C.Stop()`, `C.stats = { sent, received, bad, queued, lockdownSkips }`, `C.ActiveTransport() -> "guild"|"channel"|"none"`, `C.IsReady()`.
- Internal event: fires `ns.Fire("LM_COMM_READY", transport)`.

- [ ] **Step 1: Write the failing test** `tests/comm_transport.test.lua`

```lua
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
local C = ns.Comm
C.Start()
STUB.Advance(1)
assert(STUB.prefixes["LVLM"], "prefix registered")
-- guild transport by default (auto → guild first)
C.Send("hb", { l = 22, z = 1421 })
STUB.Advance(0.5)
assert(#STUB.sent == 1 and STUB.sent[1].chatType == "GUILD", "hb sent on GUILD")
-- receive from another player
local got
C.OnMessage("hb", function(f, name, full) got = { f = f, name = name, full = full } end)
STUB.Receive("LVLM", C.Encode("hb", { l = 30, z = 1 }), "GUILD", "Mario-Testrealm")
assert(got and got.name == "Mario" and got.full == "Mario-Testrealm" and got.f.l == 30, "message dispatched")
-- own message ignored
got = nil
STUB.Receive("LVLM", C.Encode("hb", { l = 30, z = 1 }), "GUILD", "Tester-Testrealm")
assert(got == nil, "own echo ignored")
-- malformed counted, not dispatched
STUB.Receive("LVLM", "v1\31hb\31l=9999", "GUILD", "Mario-Testrealm")
assert(C.stats.bad == 1 and got == nil, "bad counted")
-- lockdown queues and compacts hb
STUB.lockdown = true
C.Send("hb", { l = 22, z = 1421 }); C.Send("hb", { l = 23, z = 1421 }); C.Send("help", { t = "x", z = 1, x = 1, y = 1, id = "ab" })
STUB.Advance(5)
assert(#STUB.sent == 1, "nothing sent in lockdown")
STUB.lockdown = false
STUB.Advance(1)
assert(#STUB.sent == 3, "queue flushed: latest hb + help, got " .. #STUB.sent)
assert(STUB.sent[2].msg:find("l=23") or STUB.sent[3].msg:find("l=23"), "only the latest hb kept")
-- throttle: 30 sends at once go out at most 10 then 1/s
for i = 1, 30 do C.Send("ping", {}, "normal") end
local before = #STUB.sent
STUB.Advance(0.2)
assert(#STUB.sent - before <= 10, "burst limited to 10")
STUB.Advance(30)
assert(#STUB.sent - before == 30, "all delivered within 30 s")
-- channel transport
ns.db.settings.transport = "channel"
C.Stop(); C.Start(); STUB.Advance(1)
C.Send("hb", { l = 22, z = 1421 }); STUB.Advance(0.5)
local last = STUB.sent[#STUB.sent]
assert(last.chatType == "CHANNEL" and type(last.target) == "number", "sent on hidden channel")
assert(C.ActiveTransport() == "channel")
```

- [ ] **Step 2: Run it to see it fail**

Run: `node tools/run-lua-test.mjs LevelMates tests/comm_transport.test.lua`
Expected: LUA ERROR `attempt to call a nil value (field 'Start')`.

- [ ] **Step 3: Append the transport to Comm.lua**

```lua
------------------------------------------------------------------ transport
local handlers = {}
C.stats = { sent = 0, received = 0, bad = 0, queued = 0, lockdownSkips = 0 }
local queue = {}            -- { text, kind, prio }
local allowance, lastTick = 10, 0   -- per-prefix: 10 burst, +1/s
local active = "none"
local channelId
local ticker

local function channelName()
	local g = GetGuildInfo("player")
	if not g then return nil end
	local h = 5381
	for i = 1, #g do h = (h * 33 + g:byte(i)) % 4294967296 end
	return "LM" .. string.format("%08x", h)
end

local function pickTransport()
	local want = ns.db.settings.transport
	if want == "channel" then return "channel" end
	return "guild"   -- "guild" and "auto" start on GUILD; auto falls back on a failed send
end

local function ensureChannel()
	local name = channelName()
	if not name then return nil end
	local id = GetChannelName(name)
	if not id or id == 0 then JoinTemporaryChannel(name); id = GetChannelName(name) end
	channelId = (id and id > 0) and id or nil
	return channelId
end

local function rawSend(text)
	if active == "channel" then
		local id = channelId or ensureChannel()
		if not id then return 7 end
		return C_ChatInfo.SendAddonMessage(C.PREFIX, text, "CHANNEL", id)
	end
	return C_ChatInfo.SendAddonMessage(C.PREFIX, text, "GUILD")
end

local function pump()
	local now = GetTime()
	allowance = math.min(10, allowance + (now - lastTick))
	lastTick = now
	if #queue == 0 then return end
	if C_ChatInfo.InChatMessagingLockdown() then C.stats.lockdownSkips = C.stats.lockdownSkips + 1; return end
	while #queue > 0 and allowance >= 1 do
		local item = table.remove(queue, 1)
		local r = rawSend(item.text)
		if r == 11 then table.insert(queue, 1, item); C.stats.lockdownSkips = C.stats.lockdownSkips + 1; return end
		if r ~= 0 and ns.db.settings.transport == "auto" and active == "guild" then
			ns.Log("GUILD send failed (%s); switching to hidden channel", tostring(r))
			active = "channel"; ensureChannel(); table.insert(queue, 1, item); ns.Fire("LM_COMM_READY", active); return
		end
		if r == 0 then C.stats.sent = C.stats.sent + 1; allowance = allowance - 1 else C.stats.bad = C.stats.bad + 1 end
	end
end

function C.Send(kind, fields, prio)
	if not IsInGuild() then return false end
	local text, why = C.Encode(kind, fields)
	if not text then ns.Log("encode %s failed: %s", kind, tostring(why)); return false end
	if kind == "hb" then   -- only the newest heartbeat waits in the queue
		for i = #queue, 1, -1 do if queue[i].kind == "hb" then table.remove(queue, i) end end
	end
	local item = { text = text, kind = kind, prio = prio or "normal" }
	if item.prio == "now" then table.insert(queue, 1, item) else queue[#queue + 1] = item end
	C.stats.queued = #queue
	pump()
	return true
end

function C.OnMessage(kind, fn) handlers[kind] = handlers[kind] or {}; table.insert(handlers[kind], fn) end

local me
local function onAddonMessage(prefix, text, channel, sender)
	if prefix ~= C.PREFIX then return end
	if issecretvalue and (issecretvalue(text) or issecretvalue(sender)) then return end
	if channel ~= "GUILD" and channel ~= "CHANNEL" then return end
	if channel == "CHANNEL" and active ~= "channel" then return end
	local name = Ambiguate(sender, "guild")
	if name == me then return end
	if channel == "CHANNEL" and ns.Roster and ns.Roster.IsGuildmate and not ns.Roster.IsGuildmate(name) then C.stats.bad = C.stats.bad + 1; return end
	local kind, fields = C.Decode(text)
	if not kind then C.stats.bad = C.stats.bad + 1; return end
	C.stats.received = C.stats.received + 1
	for _, fn in ipairs(handlers[kind] or {}) do fn(fields, name, sender) end
end

local frame
function C.Start()
	me = UnitName("player")
	C_ChatInfo.RegisterAddonMessagePrefix(C.PREFIX)
	active = pickTransport()
	if active == "channel" then ensureChannel() end
	if not frame then
		frame = CreateFrame("Frame")
		frame:SetScript("OnEvent", function(_, _, ...) onAddonMessage(...) end)
	end
	frame:RegisterEvent("CHAT_MSG_ADDON")
	lastTick = GetTime()
	ticker = C_Timer.NewTicker(0.2, pump)
	ns.Fire("LM_COMM_READY", active)
end
function C.Stop()
	if ticker then ticker:Cancel(); ticker = nil end
	if frame then frame:UnregisterEvent("CHAT_MSG_ADDON") end
	queue = {}; active = "none"; channelId = nil
end
function C.ActiveTransport() return active end
function C.IsReady() return active ~= "none" end

ns.On("LM_LOADED", function() if ns.db.settings.share then C.Start() end end)
ns.On("LM_LOGOUT", function() if C.IsReady() then rawSend(C.Encode("bye", {})) end end)
```

- [ ] **Step 4: Run the test; fix the stub if needed**

Run: `node tools/run-lua-test.mjs LevelMates tests/comm_transport.test.lua`
Expected: `ok`. The stub's `SendAddonMessage` already returns 11 under `STUB.lockdown`; make sure the stub's `GetChannelName` returns a number > 0 after `JoinTemporaryChannel` (it does in the skill's stub).

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat(comm): queue with per-prefix allowance, lockdown handling, guild/channel transports"
```

---

### Task 3: Roster: heartbeats, expiry, ping, own quests

**Files:**
- Create: `LevelMates/Roster.lua`, `tests/roster.test.lua`
- Modify: TOC (add `Roster.lua` after `Comm.lua`); `tools/wow-stub.lua` (add `C_Club` stubs, `GetNumGroupMembers`, `GetTime` already present)

**Interfaces:**
- Consumes: `ns.Comm.Send/OnMessage`, `ns.db.settings.*`, `ns.On`.
- Produces: `ns.Roster.mates` (`name -> { level, mapId, inGroup, hasSlot, x, y, xph, class, quests (set of ids), seenAt, version }`), `ns.Roster.List() -> sorted array of names`, `ns.Roster.IsGuildmate(name)`, `ns.Roster.MyQuests() -> set of ids`, `ns.Roster.Snapshot() -> fields table for hb`, `ns.Roster.SendHeartbeat(force)`, `ns.Roster.Expire()`, events `LM_ROSTER_CHANGED`, `LM_MATE_QUESTS(name)`.

- [ ] **Step 1: Write the failing test** `tests/roster.test.lua`

```lua
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
local R, C = ns.Roster, ns.Comm
STUB.Fire("PLAYER_ENTERING_WORLD", true, false)
STUB.Advance(1)
-- login sends ping + hb
local kinds = {}
for _, s in ipairs(STUB.sent) do kinds[#kinds + 1] = select(1, C.Decode(s.msg)) end
assert(table.concat(kinds, ",") == "ping,hb" or table.concat(kinds, ",") == "hb,ping", "ping and hb at login: " .. table.concat(kinds, ","))
-- unchanged state: no hb for 30 s ticks
local n = #STUB.sent
STUB.Advance(31); STUB.Advance(31)
assert(#STUB.sent == n, "no heartbeat without change")
-- level up → hb at the next tick, but not before 30 s since the last
STUB.player.level = 21
STUB.Fire("PLAYER_LEVEL_UP", 21)
STUB.Advance(1)
assert(#STUB.sent == n + 1 and STUB.sent[#STUB.sent].msg:find("l=21"), "level change sends hb")
-- receive mates
STUB.Receive("LVLM", C.Encode("hb", { l = 30, z = 1421, g = 1, s = 1, c = "MAGE" }), "GUILD", "Mario-Testrealm")
STUB.Receive("LVLM", C.Encode("hb", { l = 12, z = 1412 }), "GUILD", "Ana-Testrealm")
assert(R.mates.Mario and R.mates.Mario.level == 30 and R.mates.Mario.inGroup and R.mates.Mario.hasSlot, "mate stored")
assert(#R.List() == 2, "two mates")
-- ping from a newcomer → we answer with hb within 0-5 s
n = #STUB.sent
STUB.Receive("LVLM", C.Encode("ping", {}), "GUILD", "Luis-Testrealm")
STUB.Advance(6)
assert(#STUB.sent == n + 1, "answered ping")
-- expiry
STUB.Advance(121)
R.Expire()
assert(#R.List() == 0, "expired after 120 s")
-- bye removes at once
STUB.Receive("LVLM", C.Encode("hb", { l = 30, z = 1421 }), "GUILD", "Mario-Testrealm")
STUB.Receive("LVLM", C.Encode("bye", {}), "GUILD", "Mario-Testrealm")
assert(R.mates.Mario == nil, "bye removes")
-- quests only when sharing is on
STUB.quests = { 1098, 6562 }
ns.db.settings.shareQuests = false
n = #STUB.sent; STUB.Fire("QUEST_LOG_UPDATE"); STUB.Advance(3)
assert(#STUB.sent == n, "quests not sent when off")
ns.db.settings.shareQuests = true
STUB.Fire("QUEST_LOG_UPDATE"); STUB.Advance(3)
assert(STUB.sent[#STUB.sent].msg:find("ids=1098,6562"), "quest ids sent: " .. STUB.sent[#STUB.sent].msg)
-- mates' quests
STUB.Receive("LVLM", C.Encode("q", { i = "1/1", ids = "1098,959" }), "GUILD", "Ana-Testrealm")
assert(R.mates.Ana.quests[1098] and R.mates.Ana.quests[959], "mate quests stored")
```

- [ ] **Step 2: Extend the stub** (`tools/wow-stub.lua`)

```lua
STUB.quests = {}
C_QuestLog.GetNumQuestLogEntries = function() return #STUB.quests, #STUB.quests end
C_QuestLog.GetInfo = function(i) local id = STUB.quests[i]; if not id then return nil end; return { questID = id, title = "Quest " .. id, isHeader = false, level = 20 } end
C_QuestLog.IsComplete = function(id) return STUB.completed and STUB.completed[id] or false end
C_QuestLog.IsPushableQuest = function() return true end
function GetNumGroupMembers() return STUB.groupSize or 0 end
function GetNumSubgroupMembers() return math.max(0, (STUB.groupSize or 0) - 1) end
STUB.guildMembers = { Tester = true, Mario = true, Ana = true, Luis = true }
C_Club = {
	GetGuildClubId = function() return 1 end,
	GetClubMembers = function() local out = {}; for k in pairs(STUB.guildMembers) do out[#out + 1] = k end; return out end,
	GetMemberInfo = function(_, id) return { name = id, level = 1, presence = 1 } end,
}
function UnitXP() return STUB.player.xp or 0 end
function UnitXPMax() return 1000 end
```

- [ ] **Step 3: Run it to see it fail**, then write `Roster.lua`

```lua
-- Roster.lua: what I know about guildmates with the addon, and what I say about myself.
local _, ns = ...
local R = {}
ns.Roster = R
local C = ns.Comm
local HB_EVERY, EXPIRE, PING_JITTER = 30, 120, 5

R.mates = {}
local lastSent, lastHb, lastQuestsSig = nil, -math.huge, nil
local xpWindow = {}   -- { t, xp } samples for XP/h over the last hour

function R.IsGuildmate(name)
	local clubId = C_Club and C_Club.GetGuildClubId and C_Club.GetGuildClubId()
	if not clubId then return true end   -- no roster API: don't block (GUILD transport already filters)
	for _, id in ipairs(C_Club.GetClubMembers(clubId) or {}) do
		local info = C_Club.GetMemberInfo(clubId, id)
		if info and info.name and Ambiguate(info.name, "guild") == name then return true end
	end
	return false
end

function R.MyQuests()
	local set = {}
	local n = C_QuestLog.GetNumQuestLogEntries()
	for i = 1, n do
		local info = C_QuestLog.GetInfo(i)
		if info and not info.isHeader and info.questID and not C_QuestLog.IsComplete(info.questID) then set[info.questID] = true end
	end
	return set
end

local function xph()
	local now, xp = GetTime(), UnitXP("player")
	xpWindow[#xpWindow + 1] = { t = now, xp = xp }
	while xpWindow[1] and now - xpWindow[1].t > 3600 do table.remove(xpWindow, 1) end
	local first = xpWindow[1]
	if not first or now - first.t < 60 then return 0 end
	local gained = xp - first.xp
	if gained < 0 then xpWindow = { { t = now, xp = xp } }; return 0 end
	return math.floor(gained / (now - first.t) * 3600)
end

function R.Snapshot()
	local s = ns.db.settings
	local f = { l = UnitLevel("player"), z = C_Map.GetBestMapForUnit("player") or 0, c = select(2, UnitClass("player")), v = ns.VERSION }
	local size = GetNumGroupMembers()
	f.g = size > 0 and 1 or 0
	f.s = (size > 0 and size < 5) and 1 or 0
	if s.sharePos and f.z > 0 then
		local pos = C_Map.GetPlayerMapPosition(f.z, "player")
		if pos then local x, y = pos:GetXY(); f.x = math.floor(x * 1000 + 0.5) / 10; f.y = math.floor(y * 1000 + 0.5) / 10 end
	end
	if s.shareXp then f.r = xph() end
	return f
end

local function sig(f) local keys = {}; for k in pairs(f) do keys[#keys + 1] = k end; table.sort(keys); local p = {}; for _, k in ipairs(keys) do p[#p + 1] = k .. "=" .. tostring(f[k]) end; return table.concat(p, ";") end

function R.SendHeartbeat(force)
	if not ns.db.settings.share or not C.IsReady() then return false end
	local f = R.Snapshot()
	local s = sig(f)
	local now = GetTime()
	if not force and s == lastSent then return false end
	if not force and now - lastHb < HB_EVERY then return false end
	if C.Send("hb", f) then lastSent, lastHb = s, now; return true end
end

function R.SendQuests()
	if not ns.db.settings.shareQuests or not C.IsReady() then return end
	local ids = {}
	for id in pairs(R.MyQuests()) do ids[#ids + 1] = id end
	table.sort(ids)
	local list = table.concat(ids, ",")
	if list == lastQuestsSig then return end
	lastQuestsSig = list
	-- split into ≤ 240-byte chunks
	local chunks = {}
	local cur = ""
	for _, id in ipairs(ids) do
		local piece = (cur == "" and "" or ",") .. id
		if #cur + #piece > 240 then chunks[#chunks + 1] = cur; cur = tostring(id) else cur = cur .. piece end
	end
	chunks[#chunks + 1] = cur
	for i, chunk in ipairs(chunks) do C.Send("q", { i = i .. "/" .. #chunks, ids = chunk }) end
end

function R.Expire()
	local now, changed = GetTime(), false
	for name, m in pairs(R.mates) do if now - m.seenAt > EXPIRE then R.mates[name] = nil; changed = true end end
	if changed then ns.Fire("LM_ROSTER_CHANGED") end
end

function R.List()
	local out = {}
	for name in pairs(R.mates) do out[#out + 1] = name end
	table.sort(out, function(a, b) local A, B = R.mates[a], R.mates[b]; if A.level ~= B.level then return A.level > B.level end; return a < b end)
	return out
end

C.OnMessage("hb", function(f, name)
	local m = R.mates[name] or { quests = {} }
	m.level, m.mapId, m.inGroup, m.hasSlot = f.l, f.z, f.g == 1, f.s == 1
	m.x, m.y, m.xph, m.class, m.version = f.x, f.y, f.r, f.c, f.v
	m.seenAt = GetTime()
	R.mates[name] = m
	ns.Fire("LM_ROSTER_CHANGED")
end)
C.OnMessage("bye", function(_, name) if R.mates[name] then R.mates[name] = nil; ns.Fire("LM_ROSTER_CHANGED") end end)
C.OnMessage("ping", function() C_Timer.After(math.random() * PING_JITTER, function() R.SendHeartbeat(true) end) end)
C.OnMessage("q", function(f, name)
	local m = R.mates[name]
	if not m then return end
	local idx, total = tostring(f.i):match("^(%d+)/(%d+)$")
	if idx == "1" then m.quests = {} end
	for id in tostring(f.ids):gmatch("%d+") do m.quests[tonumber(id)] = true end
	if idx == total then ns.Fire("LM_MATE_QUESTS", name) end
end)

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LEVEL_UP"); ev:RegisterEvent("ZONE_CHANGED_NEW_AREA"); ev:RegisterEvent("GROUP_ROSTER_UPDATE"); ev:RegisterEvent("QUEST_LOG_UPDATE")
local questDebounce
ev:SetScript("OnEvent", function(_, event)
	if event == "QUEST_LOG_UPDATE" then
		if questDebounce then return end
		questDebounce = C_Timer.After(2, function() questDebounce = nil; R.SendQuests() end)
	else
		C_Timer.After(0.5, function() R.SendHeartbeat(false) end)
	end
end)

ns.On("LM_WORLD", function(isInitial)
	if not isInitial then return end
	C_Timer.After(0.5, function()
		if not C.IsReady() then return end
		C.Send("ping", {}, "now")
		R.SendHeartbeat(true)
		R.SendQuests()
	end)
	C_Timer.NewTicker(HB_EVERY, function() R.SendHeartbeat(false); R.Expire() end)
end)
```
Note `C_Timer.After` in the stub returns nil, so `questDebounce` is a boolean flag in practice: set it to `true` before calling `C_Timer.After` instead of assigning the result:
```lua
		questDebounce = true
		C_Timer.After(2, function() questDebounce = nil; R.SendQuests() end)
```

- [ ] **Step 4: Run the test; adjust**

Run: `node tools/run-lua-test.mjs LevelMates tests/roster.test.lua`
Expected: `ok`. If the "level change" assertion fails because `lastHb` is within 30 s, the test advanced 62 s already; check `HB_EVERY` math.

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat(roster): heartbeats, expiry, ping, quests"
```

---

### Task 4: Settings panel

**Files:**
- Create: `LevelMates/Settings.lua`, `tests/settings.test.lua`
- Modify: TOC (add after `Roster.lua`)

**Interfaces:**
- Consumes: `Settings.*` API, `ns.db.settings`, `ns.Comm.Start/Stop`, `ns.L`.
- Produces: `ns.Settings.Open()`, `ns.Slash("options")`/`("opciones")`.

- [ ] **Step 1: Failing test** `tests/settings.test.lua`

```lua
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
assert(ns.Settings and ns.Settings.category, "category registered")
local names = {}
for _, s in ipairs(ns.Settings.category.settings) do names[#names + 1] = s.name end
assert(#names >= 9, "all switches registered: " .. #names)
-- toggling share stops/starts comm
local share
for _, s in ipairs(ns.Settings.category.settings) do if s.name == ns.L.OPT_SHARE then share = s end end
share:SetValue(false)
assert(ns.db.settings.share == false and ns.Comm.IsReady() == false, "share off stops comm")
share:SetValue(true)
assert(ns.Comm.IsReady() == true, "share on starts comm")
```

- [ ] **Step 2: Write Settings.lua**

```lua
local ADDON, ns = ...
local S = {}
ns.Settings = S
local L = ns.L

local function Bool(category, key, name, tooltip, onChange)
	local setting = Settings.RegisterAddOnSetting(category, "LevelMates_" .. key, key, ns.db.settings, Settings.VarType.Boolean, name, ns.db.settings[key])
	if onChange then setting:SetValueChangedCallback(function(_, v) onChange(v) end) end
	Settings.CreateCheckbox(category, setting, tooltip)
	return setting
end

ns.On("LM_LOADED", function()
	local category = Settings.RegisterVerticalLayoutCategory(L.BOARD_TITLE)
	S.category = category
	Bool(category, "share", L.OPT_SHARE, L.OPT_SHARE_TT, function(v) if v then ns.Comm.Start() else ns.Comm.Stop() end; ns.Fire("LM_ROSTER_CHANGED") end)
	Bool(category, "sharePos", L.OPT_POS, L.OPT_POS_TT, function() ns.Roster.SendHeartbeat(true) end)
	Bool(category, "shareQuests", L.OPT_QUESTS, L.OPT_QUESTS_TT, function(v) if v then ns.Roster.SendQuests() end end)
	Bool(category, "shareXp", L.OPT_XPH, L.OPT_XPH_TT)
	Bool(category, "matchNotices", L.OPT_MATCH, L.OPT_MATCH_TT)
	Bool(category, "helpNotices", L.OPT_HELP, L.OPT_HELP_TT)
	Bool(category, "sound", L.OPT_SOUND)
	Bool(category, "minimap", L.OPT_MINIMAP, nil, function() ns.Fire("LM_MINIMAP_CHANGED") end)
	-- transport as three radio-like checkboxes (no dropdowns on Forever)
	local function Radio(key, value, name)
		local proxy = Settings.RegisterProxySetting(category, "LevelMates_transport_" .. value, Settings.VarType.Boolean, name, ns.db.settings.transport == value,
			function() return ns.db.settings.transport == value end,
			function(v) if v then ns.db.settings.transport = value; if ns.Comm.IsReady() then ns.Comm.Stop(); ns.Comm.Start() end end end)
		Settings.CreateCheckbox(category, proxy, L.OPT_TRANSPORT_TT)
	end
	Radio("transport", "auto", L.OPT_TRANSPORT .. ": " .. L.TRANSPORT_AUTO)
	Radio("transport", "guild", L.OPT_TRANSPORT .. ": " .. L.TRANSPORT_GUILD)
	Radio("transport", "channel", L.OPT_TRANSPORT .. ": " .. L.TRANSPORT_CHANNEL)
	Bool(category, "debug", L.OPT_DEBUG)
	Settings.RegisterAddOnCategory(category)
end)

function S.Open() if S.category then Settings.OpenToCategory(S.category:GetID()) end end
ns.Slash("options", S.Open); ns.Slash("opciones", S.Open)
ns.Slash("debug", function()
	local c = ns.Comm.stats
	ns.Say(L.STATUS, #ns.Roster.List(), ns.Comm.ActiveTransport(), c.sent, c.received, c.bad)
end)
```

- [ ] **Step 3: Run, commit**

Run: `node tools/run-lua-test.mjs LevelMates tests/settings.test.lua` → `ok`.
```bash
git add -A && git commit -m "feat(settings): options page with privacy switches and transport choice"
```

---

### Task 5: Board window

**Files:**
- Create: `LevelMates/Board.lua`, `LevelMates/Media/icon.tga` (64x64, any placeholder until art exists), `tests/board.test.lua`
- Modify: TOC

**Interfaces:**
- Consumes: `ns.Roster`, `ns.L`, `ns.char.board` (saved point), events `LM_ROSTER_CHANGED`, `LM_TOGGLE_BOARD`.
- Produces: `ns.Board.Toggle()`, `ns.Board.Refresh()`, `ns.Board.frame`, row click actions (all click-driven): `C_PartyInfo.InviteUnit(name)`, `ChatFrameUtil.SendTell(name)`, waypoint via `ns.Help.WaypointTo(mapId, x, y)` (Task 7; until then `C_Map.SetUserWaypoint` inline).

- [ ] **Step 1: Failing test** `tests/board.test.lua`

```lua
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local C = ns.Comm
STUB.Receive("LVLM", C.Encode("hb", { l = 30, z = 1421, g = 1, s = 1, c = "MAGE" }), "GUILD", "Mario-Testrealm")
ns.Board.Toggle()
assert(ns.Board.frame:IsShown(), "shown")
assert(ns.Board.rows[1].name.text:find("Mario"), "row 1 is Mario: " .. tostring(ns.Board.rows[1].name.text))
assert(ns.Board.rows[1].group.text == ns.L.GROUP_FREE, "group column")
ns.Board.Toggle()
assert(not ns.Board.frame:IsShown(), "hidden")
-- invite only from a click handler: the row's OnClick calls C_PartyInfo.InviteUnit
local invited
C_PartyInfo = { InviteUnit = function(n) invited = n end }
ns.Board.rows[1].button.scripts.OnClick(ns.Board.rows[1].button, "RightButton")
assert(ns.Board.lastMenuFor == "Mario", "context menu opened for the row")
ns.Board.Invite("Mario")
assert(invited == "Mario", "invite called")
```

- [ ] **Step 2: Write Board.lua**

```lua
local _, ns = ...
local B = {}
ns.Board = B
local L, R = ns.L, ns.Roster
local ROWS, ROW_H = 20, 16

local function ClassColor(class)
	local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
	if c then return c.r, c.g, c.b end
	return 1, 1, 1
end

local function Build()
	local f = CreateFrame("Frame", "LevelMatesBoard", UIParent, "BasicFrameTemplateWithInset")
	B.frame = f
	f:SetSize(420, 60 + ROWS * ROW_H)
	f:SetMovable(true); f:EnableMouse(true); f:SetClampedToScreen(true); f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", f.StartMoving)
	f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing(); local p, _, rp, x, y = self:GetPoint(); ns.char.board = { p, rp, x, y } end)
	local saved = ns.char.board
	if saved then f:SetPoint(saved[1], UIParent, saved[2], saved[3], saved[4]) else f:SetPoint("CENTER") end
	if f.TitleText then f.TitleText:SetText(L.BOARD_TITLE) end
	tinsert(UISpecialFrames, "LevelMatesBoard")
	f:Hide()

	local function Col(parent, w, justify) local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); fs:SetWidth(w); fs:SetJustifyH(justify or "LEFT"); fs:SetWordWrap(false); return fs end
	local head = { Col(f, 120), Col(f, 30, "CENTER"), Col(f, 150), Col(f, 50, "CENTER"), Col(f, 50, "RIGHT") }
	head[1]:SetPoint("TOPLEFT", 12, -30)
	for i = 2, 5 do head[i]:SetPoint("LEFT", head[i - 1], "RIGHT", 4, 0) end
	head[1]:SetText(L.COL_NAME); head[2]:SetText(L.COL_LEVEL); head[3]:SetText(L.COL_ZONE); head[4]:SetText(L.COL_GROUP); head[5]:SetText(L.COL_XPH)
	for i = 1, 5 do head[i]:SetTextColor(1, 0.82, 0) end

	B.rows = {}
	for i = 1, ROWS do
		local btn = CreateFrame("Button", nil, f)
		btn:SetSize(400, ROW_H)
		btn:SetPoint("TOPLEFT", 12, -30 - i * ROW_H)
		btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
		local r = { button = btn, name = Col(btn, 120), level = Col(btn, 30, "CENTER"), zone = Col(btn, 150), group = Col(btn, 50, "CENTER"), xph = Col(btn, 50, "RIGHT") }
		r.name:SetPoint("LEFT", 0, 0); r.level:SetPoint("LEFT", r.name, "RIGHT", 4, 0); r.zone:SetPoint("LEFT", r.level, "RIGHT", 4, 0); r.group:SetPoint("LEFT", r.zone, "RIGHT", 4, 0); r.xph:SetPoint("LEFT", r.group, "RIGHT", 4, 0)
		btn:SetScript("OnClick", function(self, mouse)
			local name = self.mate
			if not name then return end
			if mouse == "RightButton" then B.OpenMenu(name) else ns.Fire("LM_ROW_CLICK", name) end
		end)
		B.rows[i] = r
	end
	f.empty = Col(f, 380, "CENTER"); f.empty:SetPoint("TOP", 0, -70)

	local help = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
	help:SetSize(120, 22); help:SetPoint("BOTTOMLEFT", 12, 8); help:SetText(L.BTN_HELP)
	help:SetScript("OnClick", function() ns.Fire("LM_HELP_BUTTON") end)
	B.helpButton = help
end

function B.Refresh()
	if not B.frame or not B.frame:IsShown() then return end
	local list = R.List()
	for i = 1, ROWS do
		local r, name = B.rows[i], list[i]
		r.button.mate = name
		if name then
			local m = R.mates[name]
			r.name:SetText(name); r.name:SetTextColor(ClassColor(m.class))
			r.level:SetText(m.level)
			local info = m.mapId and C_Map.GetMapInfo(m.mapId)
			r.zone:SetText(info and info.name or "")
			r.group:SetText(m.inGroup and (m.hasSlot and L.GROUP_FREE or L.GROUP_FULL) or L.SOLO)
			r.xph:SetText(m.xph and m.xph > 0 and tostring(m.xph) or "")
			r.button:Show()
		else
			r.name:SetText(""); r.level:SetText(""); r.zone:SetText(""); r.group:SetText(""); r.xph:SetText("")
			r.button:Hide()
		end
	end
	B.frame.empty:SetText(#list == 0 and (IsInGuild() and L.EMPTY or L.NOT_IN_GUILD) or "")
end

function B.Toggle()
	if not B.frame then Build() end
	B.frame:SetShown(not B.frame:IsShown())
	B.Refresh()
end

-- Actions below run only from click handlers (menu entries / row clicks): Forever drops them otherwise.
function B.Invite(name) C_PartyInfo.InviteUnit(name) end
function B.Whisper(name) ChatFrameUtil.SendTell(name) end
function B.OpenMenu(name)
	B.lastMenuFor = name
	local m = R.mates[name]
	MenuUtil.CreateContextMenu(B.frame, function(_, root)
		root:CreateTitle(name)
		root:CreateButton(L.MENU_INVITE, function() B.Invite(name) end)
		root:CreateButton(L.MENU_WHISPER, function() B.Whisper(name) end)
		if m and m.x and m.y and m.mapId then root:CreateButton(L.MENU_WAYPOINT, function() ns.Help.WaypointTo(m.mapId, m.x, m.y) end) end
	end)
end

ns.On("LM_ROSTER_CHANGED", B.Refresh)
ns.On("LM_TOGGLE_BOARD", B.Toggle)
ns.On("LM_LOADED", function()
	if AddonCompartmentFrame and ns.db.settings.minimap then
		AddonCompartmentFrame:RegisterAddon({ text = L.BOARD_TITLE, icon = "Interface\\AddOns\\LevelMates\\Media\\icon", func = B.Toggle })
	end
end)
```
Stub additions for the test: `RAID_CLASS_COLORS = {}`, `C_Map.GetMapInfo = function(id) return { name = "Map " .. id } end`, `MenuUtil = { CreateContextMenu = function(owner, fn) local root = { CreateTitle = function() end, CreateButton = function() end }; fn(owner, root) end }`, `ChatFrameUtil = { SendTell = function() end }`, `Region:RegisterForClicks`, `Region:GetPoint` returning `"CENTER", nil, "CENTER", 0, 0`, `AddonCompartmentFrame = { RegisterAddon = function() end }`. Verify `MenuUtil.CreateContextMenu` exists in the clone (`grep -rn "function MenuUtil.CreateContextMenu" reference/wow-ui-source/Interface`); if absent on Forever, replace the menu with three small buttons in the row.

- [ ] **Step 3: Run, then in-game smoke test, commit**

Run: `node tools/run-lua-test.mjs LevelMates tests/board.test.lua` → `ok`.
In game (two characters): `/lm` shows the other after ≤ 35 s; right-click → Invite works.
```bash
git add -A && git commit -m "feat(board): guildmates window with click-only actions"
```

---

### Task 6: Quest matching

**Files:**
- Create: `LevelMates/Match.lua`, `tests/match.test.lua`
- Modify: TOC

**Interfaces:**
- Consumes: `ns.Roster.mates[*].quests`, `ns.Roster.MyQuests()`, `C_QuestLog.GetTitleForQuestID`, `C_QuestLog.IsPushableQuest`, events `QUEST_ACCEPTED`, `LM_MATE_QUESTS`.
- Produces: `ns.Match.ForQuest(questID) -> { has = {names}, needs = {names} }` (mates on my map), `ns.Match.Notice(text)`, fires `LM_MATCH(questID, names)`.

- [ ] **Step 1: Failing test** `tests/match.test.lua`

```lua
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local C = ns.Comm
STUB.player.mapId = 1421
STUB.Receive("LVLM", C.Encode("hb", { l = 22, z = 1421 }), "GUILD", "Mario-Testrealm")
STUB.Receive("LVLM", C.Encode("q", { i = "1/1", ids = "1098,959" }), "GUILD", "Mario-Testrealm")
STUB.Receive("LVLM", C.Encode("hb", { l = 22, z = 1412 }), "GUILD", "Ana-Testrealm")   -- other map
STUB.Receive("LVLM", C.Encode("q", { i = "1/1", ids = "1098" }), "GUILD", "Ana-Testrealm")
local m = ns.Match.ForQuest(1098)
assert(#m.has == 1 and m.has[1] == "Mario", "only same-map mates: " .. table.concat(m.has, ","))
-- accepting a quest notifies
STUB.quests = { 1098 }
STUB.Fire("QUEST_ACCEPTED", 1098)
local last = STUB.printed[#STUB.printed]
assert(last and last:find("Mario") and last:find("Quest 1098"), "notice printed: " .. tostring(last))
-- notices off → silent
ns.db.settings.matchNotices = false
local n = #STUB.printed
STUB.Fire("QUEST_ACCEPTED", 1098)
assert(#STUB.printed == n, "no notice when off")
```
Stub: `C_QuestLog.GetTitleForQuestID = function(id) return "Quest " .. id end`.

- [ ] **Step 2: Write Match.lua**

```lua
local _, ns = ...
local M = {}
ns.Match = M
local L, R = ns.L, ns.Roster

function M.ForQuest(questID)
	local myMap = C_Map.GetBestMapForUnit("player")
	local out = { has = {}, needs = {} }
	for name, m in pairs(R.mates) do
		if m.mapId == myMap then
			if m.quests[questID] then out.has[#out.has + 1] = name end
		end
	end
	table.sort(out.has)
	return out
end

-- mates on my map who do not have a quest I can share (for "still needs")
function M.WhoNeeds(questID)
	local myMap = C_Map.GetBestMapForUnit("player")
	local out = {}
	for name, m in pairs(R.mates) do
		if m.mapId == myMap and next(m.quests) ~= nil and not m.quests[questID] then out[#out + 1] = name end
	end
	table.sort(out)
	return out
end

function M.Notice(fmt, ...)
	ns.Say(fmt, ...)
	if ns.db.settings.sound and PlaySound then PlaySound(SOUNDKIT and SOUNDKIT.IG_QUEST_LOG_OPEN or 844) end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("QUEST_ACCEPTED")
ev:SetScript("OnEvent", function(_, _, questID)
	if not ns.db.settings.matchNotices or type(questID) ~= "number" then return end
	local title = C_QuestLog.GetTitleForQuestID(questID) or tostring(questID)
	local m = M.ForQuest(questID)
	for _, name in ipairs(m.has) do M.Notice(L.MATCH_HAS, name, title) end
	ns.Fire("LM_MATCH", questID, m.has)
end)

ns.On("LM_MATE_QUESTS", function(name)
	if not ns.db.settings.matchNotices then return end
	local mine = R.MyQuests()
	local mate = R.mates[name]
	local myMap = C_Map.GetBestMapForUnit("player")
	if not mate or mate.mapId ~= myMap then return end
	for id in pairs(mine) do
		if mate.quests[id] then M.Notice(L.MATCH_HAS, name, C_QuestLog.GetTitleForQuestID(id) or tostring(id)); return end
	end
end)
```

- [ ] **Step 3: Run, commit**

```bash
node tools/run-lua-test.mjs LevelMates tests/match.test.lua && git add -A && git commit -m "feat(match): quest matching notices"
```

---

### Task 7: Help requests and waypoints

**Files:**
- Create: `LevelMates/Help.lua`, `tests/help.test.lua`
- Modify: TOC; Board button hook (`LM_HELP_BUTTON`)

**Interfaces:**
- Consumes: `C.Send("help"/"helpok")`, `C.OnMessage`, `C_Map.SetUserWaypoint`, `UiMapPoint.CreateFromCoordinates`, `StaticPopup_Show` for the text prompt, `ns.Board.Refresh`.
- Produces: `ns.Help.Ask(text)` (click only; sends `help` with my position), `ns.Help.Cancel()`, `ns.Help.WaypointTo(mapId, x, y)`, `ns.Help.active` (`id -> { name, text, mapId, x, y, at }`), slash `help`/`ayuda`, `cancel`/`cancelar`.

- [ ] **Step 1: Failing test** `tests/help.test.lua`

```lua
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local C, H = ns.Comm, ns.Help
local wp
C_Map.SetUserWaypoint = function(p) wp = p end
C_Map.CanSetUserWaypointOnMap = function() return true end
UiMapPoint = { CreateFromCoordinates = function(m, x, y) return { uiMapID = m, x = x, y = y } end }
STUB.player.mapId = 1421
-- ask
H.Ask("Fuerte Colmillo")
local last = STUB.sent[#STUB.sent]
local kind, f = C.Decode(last.msg)
assert(kind == "help" and f.t == "Fuerte Colmillo" and f.z == 1421 and f.x == 50 and f.y == 50, "help sent with position")
assert(H.mine and H.mine.id == f.id, "own request kept")
-- receive someone else's on my map → notice + waypoint
STUB.Receive("LVLM", C.Encode("help", { t = "Elite X", z = 1421, x = 10, y = 20, id = "zz11" }), "GUILD", "Mario-Testrealm")
assert(H.active.zz11 and H.active.zz11.name == "Mario", "stored")
assert(STUB.printed[#STUB.printed]:find("Mario"), "notice")
assert(wp and wp.uiMapID == 1421 and math.abs(wp.x - 0.1) < 0.001, "waypoint set on my map")
-- another map: notice, no waypoint
wp = nil
STUB.Receive("LVLM", C.Encode("help", { t = "Elite Y", z = 1412, x = 10, y = 20, id = "zz12" }), "GUILD", "Ana-Testrealm")
assert(wp == nil, "no waypoint for another map")
-- helpok clears
STUB.Receive("LVLM", C.Encode("helpok", { id = "zz11" }), "GUILD", "Mario-Testrealm")
assert(H.active.zz11 == nil, "cleared")
-- expiry 10 min
STUB.Advance(601); H.Expire()
assert(H.active.zz12 == nil, "expired")
-- cancel mine sends helpok
H.Cancel()
assert(select(1, C.Decode(STUB.sent[#STUB.sent].msg)) == "helpok", "cancel sends helpok")
```

- [ ] **Step 2: Write Help.lua**

```lua
local _, ns = ...
local H = {}
ns.Help = H
local L, C, R = ns.L, ns.Comm, ns.Roster
H.active = {}
H.mine = nil
local EXPIRE = 600

local function newId() return string.format("%04x%04x", math.random(0, 65535), math.random(0, 65535)):sub(1, 8) end

local function myPosition()
	local mapId = C_Map.GetBestMapForUnit("player")
	if not mapId then return nil end
	local pos = C_Map.GetPlayerMapPosition(mapId, "player")
	if not pos then return mapId end
	local x, y = pos:GetXY()
	return mapId, math.floor(x * 1000 + 0.5) / 10, math.floor(y * 1000 + 0.5) / 10
end

function H.WaypointTo(mapId, x, y)
	if not (C_Map.CanSetUserWaypointOnMap and C_Map.CanSetUserWaypointOnMap(mapId)) then return false end
	C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(mapId, x / 100, y / 100))
	return true
end

-- Called from a click (board button / slash command).
function H.Ask(text)
	text = strtrim(tostring(text or "")):gsub("[%c|]", ""):sub(1, 60)
	if text == "" then return false end
	local mapId, x, y = myPosition()
	if not mapId or not x then ns.Say(L.HELP_PROMPT); return false end
	local id = newId()
	if C.Send("help", { t = text, z = mapId, x = x, y = y, id = id }, "now") then
		H.mine = { id = id, text = text, at = GetTime() }
		ns.Fire("LM_HELP_CHANGED")
		return true
	end
end

function H.Cancel()
	if not H.mine then return end
	C.Send("helpok", { id = H.mine.id }, "now")
	H.mine = nil
	ns.Fire("LM_HELP_CHANGED")
end

function H.Expire()
	local now = GetTime()
	for id, h in pairs(H.active) do if now - h.at > EXPIRE then H.active[id] = nil end end
	if H.mine and now - H.mine.at > EXPIRE then H.mine = nil end
	ns.Fire("LM_HELP_CHANGED")
end

C.OnMessage("help", function(f, name)
	if not ns.db.settings.helpNotices then return end
	H.active[f.id] = { name = name, text = f.t, mapId = f.z, x = f.x, y = f.y, at = GetTime() }
	local info = C_Map.GetMapInfo and C_Map.GetMapInfo(f.z)
	ns.Say(L.HELP_NOTICE, name, f.t, info and info.name or tostring(f.z))
	if ns.db.settings.sound and PlaySound then PlaySound(SOUNDKIT and SOUNDKIT.RAID_WARNING or 8959) end
	if f.z == C_Map.GetBestMapForUnit("player") then H.WaypointTo(f.z, f.x, f.y) end
	ns.Fire("LM_HELP_CHANGED")
end)
C.OnMessage("helpok", function(f, name)
	if H.active[f.id] then H.active[f.id] = nil; ns.Say(L.HELP_DONE, name); ns.Fire("LM_HELP_CHANGED") end
end)

-- "On my way": a whisper, from a click only.
function H.Coming(id)
	local h = H.active[id]
	if not h then return end
	ChatFrameUtil.SendTell(h.name)   -- opens the edit box with /w name; the player types/sends
end

ns.Slash("help", function(rest) if H.mine then H.Cancel() else H.Ask(rest) end end)
ns.Slash("ayuda", function(rest) if H.mine then H.Cancel() else H.Ask(rest) end end)
ns.Slash("cancel", H.Cancel); ns.Slash("cancelar", H.Cancel)
ns.On("LM_HELP_BUTTON", function()
	if H.mine then H.Cancel(); return end
	StaticPopupDialogs["LEVELMATES_HELP"] = StaticPopupDialogs["LEVELMATES_HELP"] or {
		text = L.HELP_PROMPT, button1 = OKAY, button2 = CANCEL, hasEditBox = true, maxLetters = 60, timeout = 0, whileDead = true, hideOnEscape = true,
		OnAccept = function(self) H.Ask(self.editBox:GetText()) end,
		EditBoxOnEnterPressed = function(self) H.Ask(self:GetParent().editBox:GetText()); self:GetParent():Hide() end,
	}
	StaticPopup_Show("LEVELMATES_HELP")
end)
ns.On("LM_WORLD", function(isInitial) if isInitial then C_Timer.NewTicker(60, H.Expire) end end)
```
Stub: `StaticPopupDialogs = {}`, `StaticPopup_Show = function() end`, `OKAY = "Okay"`, `CANCEL = "Cancel"`, `PlaySound = function() end`.

- [ ] **Step 3: Board shows active requests** (modify `Board.lua`): add a line under the header listing `H.active` entries with a "On my way" button per entry that calls `ns.Help.Coming(id)`; the help button text flips to `L.BTN_HELP_CANCEL` while `H.mine` exists. Register `ns.On("LM_HELP_CHANGED", B.Refresh)`.

- [ ] **Step 4: Run, in-game test with two characters, commit**

```bash
node tools/run-lua-test.mjs LevelMates tests/help.test.lua && git add -A && git commit -m "feat(help): help requests with waypoints"
```

---

### Task 8: Policy tests and full suite

**Files:**
- Create: `tests/policy.test.mjs`, `tests/run-all.mjs`

- [ ] **Step 1: Write the policy test** `tests/policy.test.mjs`

```js
// Fails if a protected/click-only action appears outside an OnClick / slash / menu handler, or if any
// literal addon message could exceed limits. Static, conservative: a hit means "look at it".
import fs from 'node:fs';
import path from 'node:path';
const dir = 'LevelMates';
const CLICK_ONLY = /\b(SendChatMessage|C_PartyInfo\.InviteUnit|InviteUnit|QuestLogPushQuest|ChatFrameUtil\.SendTell|ChatFrame_SendTell)\s*\(/;
let bad = 0;
for (const f of fs.readdirSync(dir).filter(f => f.endsWith('.lua'))) {
  const lines = fs.readFileSync(path.join(dir, f), 'utf8').split(/\r?\n/);
  lines.forEach((line, i) => {
    if (CLICK_ONLY.test(line)) {
      // allowed only inside functions whose name says click/menu/slash, or the Board/Help action helpers
      const ctx = lines.slice(Math.max(0, i - 12), i + 1).join('\n');
      const ok = /OnClick|OnAccept|EditBoxOnEnterPressed|CreateButton\(|ns\.Slash\(|function [A-Z]\.(Invite|Whisper|Coming)\b/.test(ctx);
      if (!ok) { bad++; console.error(`${f}:${i + 1}: click-only action outside a click handler: ${line.trim()}`); }
    }
    if (/COMBAT_LOG_EVENT|UNIT_SPELLCAST|UNIT_AURA|C_UnitAuras|C_Spell\.GetSpellCooldown/.test(line)) { bad++; console.error(`${f}:${i + 1}: combat API: ${line.trim()}`); }
  });
}
if (bad) process.exit(1); else console.log('ok policy');
```

- [ ] **Step 2: Suite runner** `tests/run-all.mjs`

```js
import { spawnSync } from 'node:child_process';
import fs from 'node:fs';
let fail = 0;
const r0 = spawnSync('node', ['tools/check-lua.mjs', 'LevelMates'], { stdio: 'inherit' }); if (r0.status) fail++;
for (const t of fs.readdirSync('tests').filter(f => f.endsWith('.test.lua'))) {
  const r = spawnSync('node', ['tools/run-lua-test.mjs', 'LevelMates', 'tests/' + t], { stdio: 'inherit' }); if (r.status) fail++;
}
const r1 = spawnSync('node', ['tests/policy.test.mjs'], { stdio: 'inherit' }); if (r1.status) fail++;
process.exit(fail ? 1 : 0);
```
Add to a root `package.json`: `"scripts": { "test": "node tests/run-all.mjs" }`.

- [ ] **Step 3: Run everything, commit**

```bash
npm test && git add -A && git commit -m "test: policy checks and suite runner"
```

---

### Task 9: Questie integration (optional, guarded)

**Files:**
- Create: `LevelMates/Questie.lua`; Modify: TOC (`## OptionalDeps: Questie`)

- [ ] **Step 1: Investigate the installed Questie API**: `grep -rn "^function QuestieDB\.\(GetQuest\|QuestieDB.GetQuest\)" "/c/Program Files (x86)/World of Warcraft/_classic_beta_/Interface/AddOns/Questie/Database/QuestieDB.lua"` and `QuestieDB.IsDoable`. Record the exact names in `Questie.lua` comments.
- [ ] **Step 2: Implement** `ns.Questie.CanTake(questID, level) -> boolean|nil` using `QuestieDB.IsDoable(questID)` when `QuestieLoader` exists, else `nil`; `Match.lua` uses it to fill `needs` ("could pick up") only when it returns true. Everything inside `pcall`; absence of Questie changes nothing.
- [ ] **Step 3: Test with stub `QuestieDB = { IsDoable = function(id) return id == 959 end }`**; commit.

---

### Task 10: Packaging, docs, release

**Files:**
- Create: `.github/workflows/release.yml`, `README.md` (en + es), `CHANGELOG.md`, `LevelMates/Media/icon.tga`

- [ ] **Step 1: Workflow** (BigWigs packager; secrets `CF_API_KEY`, `WAGO_API_TOKEN` added in GitHub later):

```yaml
name: Release
on:
  push:
    tags: ['v*']
jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with: { fetch-depth: 0 }
      - uses: BigWigsMods/packager@v2
        env:
          CF_API_KEY: ${{ secrets.CF_API_KEY }}
          WAGO_API_TOKEN: ${{ secrets.WAGO_API_TOKEN }}
          GITHUB_OAUTH: ${{ secrets.GITHUB_TOKEN }}
```
Add to the TOC: `## X-Curse-Project-ID:` and `## X-Wago-ID:` once the projects exist.

- [ ] **Step 2: README** with: what it does, privacy (what is shared by default and what is not), policy statement (addon messages only, no combat, click-only actions), install, commands, Spanish section.
- [ ] **Step 3: Local release zip** for the guild before CurseForge: `git archive --format=zip --prefix=LevelMates/ HEAD:LevelMates -o dist/LevelMates-0.1.0.zip` (replace `@project-version@` by hand in the TOC for that zip).
- [ ] **Step 4: In-game acceptance with Diego and Mario** (spec §10): board, invite, quest match, help + waypoint, lockdown in a dungeon boss, transport switch, options page, esES texts. Fix, tag `v0.1.0`, commit.
