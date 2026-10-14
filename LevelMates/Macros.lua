-- Macros.lua: a small library of macros per class (written for LevelMates with spell ids, shown with the client's
-- own spell names) and macros guildmates share (kinds `mc` / `mcx`). Creating a macro happens only from a click.
-- Spec 2026-10-10-levelmates-class-tanda-design.
local _, ns = ...
local MA = {}
ns.Macros = MA
local L, C, R = ns.L, ns.Comm, ns.Roster
MA.FORGET_DAYS, MA.MAX_SHARED, MA.ICON = 30, 5, 134400   -- 134400: the question mark, which #showtooltip replaces

-- Helpful spells on whoever is under the mouse, my target if friendly, or me.
local function help(id) return "#showtooltip {s:" .. id .. "}\n/cast [@mouseover,help,nodead][help,nodead][@player] {s:" .. id .. "}" end
-- Harmful spells on whoever is under the mouse, else my target.
local function harm(id) return "#showtooltip {s:" .. id .. "}\n/cast [@mouseover,harm,nodead][] {s:" .. id .. "}" end

MA.LIBRARY = {
	WARRIOR = {
		{ en = "LM Charge", es = "LM Carga", body = "#showtooltip {s:100}\n/cast [stance:1] {s:100}; {s:2457}" },
		{ en = "LM Taunt", es = "LM Provocar", body = "#showtooltip {s:355}\n/cast [stance:2] {s:355}; {s:71}" },
		{ en = "LM Interrupt", es = "LM Interrumpir", body = "#showtooltip\n/cast [stance:3] {s:6552}; {s:72}" },
		{ en = "LM Strike", es = "LM Golpe", body = "#showtooltip {s:78}\n/startattack\n/cast {s:78}" },
	},
	PALADIN = {
		{ en = "LM Holy Light", es = "LM Luz Sagrada", body = help(635) },
		{ en = "LM Blessing", es = "LM Bendición", body = help(19740) },
		{ en = "LM Hammer", es = "LM Martillo", body = harm(853) },
		{ en = "LM Judgement", es = "LM Sentencia", body = "#showtooltip {s:20271}\n/startattack\n/cast {s:20271}" },
	},
	HUNTER = {
		{ en = "LM Mark", es = "LM Marca", body = harm(1130) },
		{ en = "LM Pet", es = "LM Mascota", body = "#showtooltip\n/cast [nopet] {s:883}; [@pet,dead] {s:982}; {s:136}" },
		{ en = "LM Arcane Shot", es = "LM Disparo", body = "#showtooltip {s:3044}\n/cast !{s:75}\n/cast {s:3044}" },
		{ en = "LM Concussive", es = "LM Conmoción", body = harm(5116) },
	},
	ROGUE = {
		{ en = "LM Strike", es = "LM Siniestro", body = "#showtooltip {s:1752}\n/startattack\n/cast {s:1752}" },
		{ en = "LM Kick", es = "LM Patada", body = harm(1766) },
		{ en = "LM Sap", es = "LM Aporrear", body = harm(6770) },
		{ en = "LM Stealth", es = "LM Sigilo", body = "#showtooltip {s:1784}\n/cast [nostealth] {s:1784}" },
	},
	PRIEST = {
		{ en = "LM Shield", es = "LM Escudo", body = help(17) },
		{ en = "LM Renew", es = "LM Renovar", body = help(139) },
		{ en = "LM Heal", es = "LM Sanar", body = help(2050) },
		{ en = "LM Fortitude", es = "LM Entereza", body = help(1243) },
	},
	SHAMAN = {
		{ en = "LM Healing Wave", es = "LM Ola", body = help(331) },
		{ en = "LM Purge", es = "LM Purgar", body = harm(370) },
		{ en = "LM Earth Shock", es = "LM Choque", body = harm(8042) },
	},
	MAGE = {
		{ en = "LM Polymorph", es = "LM Oveja", body = "#showtooltip {s:118}\n/cast [@focus,harm,nodead][] {s:118}" },
		{ en = "LM Counterspell", es = "LM Contrahechizo", body = harm(2139) },
		{ en = "LM Intellect", es = "LM Intelecto", body = help(1459) },
	},
	WARLOCK = {
		{ en = "LM Corruption", es = "LM Corrupción", body = harm(172) },
		{ en = "LM Agony", es = "LM Agonía", body = harm(980) },
		{ en = "LM Fear", es = "LM Miedo", body = "#showtooltip {s:5782}\n/cast [@focus,harm,nodead][] {s:5782}" },
		{ en = "LM Funnel", es = "LM Canalizar", body = "#showtooltip {s:755}\n/cast [pet] {s:755}" },
	},
	DRUID = {
		{ en = "LM Rejuvenation", es = "LM Rejuvenecer", body = help(774) },
		{ en = "LM Healing Touch", es = "LM Toque", body = help(5185) },
		{ en = "LM Mark", es = "LM Marca", body = help(1126) },
		{ en = "LM Roots", es = "LM Raíces", body = harm(339) },
	},
}

function MA.Title(m) return ns.spanish and m.es or m.en end

-- The library for a class with the client's spell names; a macro naming a spell this client lacks is left out.
function MA.Library(class)
	local out = {}
	for _, m in ipairs(MA.LIBRARY[class] or {}) do
		local missing = false
		local body = m.body:gsub("{s:(%d+)}", function(id)
			local name = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(tonumber(id))
			if not name then missing = true end
			return name or ""
		end)
		local first = tonumber(m.body:match("{s:(%d+)}"))
		if not missing then out[#out + 1] = { name = MA.Title(m), body = body, library = true, icon = first and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(first) } end
	end
	return out
end

-- A new macro for this character. Runs only from a click; refuses in combat, a name in use, or no room.
function MA.Create(name, body)
	if InCombatLockdown and InCombatLockdown() then ns.Notice(L.MACRO_COMBAT); return false end
	if GetMacroIndexByName(name) > 0 then ns.Notice(L.MACRO_EXISTS, name); return false end
	local _, chars = GetNumMacros()
	if (chars or 0) >= (MAX_CHARACTER_MACROS or 30) then ns.Notice(L.MACRO_FULL); return false end
	local ok, index = pcall(CreateMacro, name, MA.ICON, body, true)
	ok = ok and type(index) == "number" and index > 0   -- the game returns the new macro's index, nothing when it refused
	if ok then ns.Notice(L.MACRO_MADE, name) end
	return ok
end

------------------------------------------------------------------ sharing
local function me() return ns.Me() end
local function myClass() return select(2, UnitClass("player")) end
local function shared() ns.char.sharedMacros = ns.char.sharedMacros or {}; return ns.char.sharedMacros end
local function store()
	ns.db.macros = ns.db.macros or {}
	local k = ns.GuildKey()
	ns.db.macros[k] = ns.db.macros[k] or {}
	return ns.db.macros[k]
end
local function bodyOf(name)
	local i = GetMacroIndexByName(name)
	if i and i > 0 then local _, _, body = GetMacroInfo(i); return body end
end

-- Macros that run code or change settings: a word of warning before creating someone else's.
function MA.Risky(body)
	local b = tostring(body or ""):lower()
	for _, cmd in ipairs({ "/run", "/script", "/console", "/gquit", "/guildquit", "/gdisband" }) do if b:find(cmd, 1, true) then return true end end
	return false
end

-- A shared macro's icon: the first spell it casts, as this client draws it.
function MA.IconOf(body)
	local spell = tostring(body or ""):match("/cast%s+%b[]%s*([^\n;%[]+)") or tostring(body or ""):match("/cast%s+!?([^\n;%[]+)")
	spell = spell and strtrim(spell)
	return spell and spell ~= "" and C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(spell) or nil
end

function MA.IsShared(name) for _, n in ipairs(shared()) do if n == name then return true end end; return false end

-- My macros (account and character), for the "Share macro" menu.
function MA.Mine()
	local out, accounts, chars = {}, GetNumMacros()
	local function add(i) local n, _, body = GetMacroInfo(i); if n then out[#out + 1] = { name = n, body = body or "", shared = MA.IsShared(n) } end end
	for i = 1, accounts or 0 do add(i) end
	for i = 1, chars or 0 do add((MAX_ACCOUNT_MACROS or 120) + i) end
	return out
end

local function sendOne(name)
	local body = bodyOf(name)
	if not body then return nil end
	return C.Send("mc", { n = name, x = body })
end

function MA.Share(name)
	if MA.IsShared(name) then return true end
	if #shared() >= MA.MAX_SHARED then ns.Notice(L.MACRO_MAX, MA.MAX_SHARED); return false end
	local body = bodyOf(name)
	if not body or body == "" then return false end
	if #name > 16 then ns.Notice(L.MACRO_LONG, name); return false end   -- 16 bytes on the wire: accents take two
	local ok, why = C.Encode("mc", { n = name, x = body })
	if not ok then ns.Notice(why == "too long" and L.MACRO_LONG or L.MACRO_BAD, name); return false end
	table.insert(shared(), name)
	if not sendOne(name) then ns.char.macroPending = true end
	return true
end

function MA.Unshare(name)
	local list = shared()
	for i = #list, 1, -1 do if list[i] == name then table.remove(list, i) end end
	if not C.Send("mcx", { n = name }) then ns.char.macroPending = true end
	return true
end

-- Everything again (a newcomer, a dropped send): a macro deleted since stops being shared.
local function resendAll()
	ns.char.macroPending = nil
	local copy = {}
	for i, n in ipairs(shared()) do copy[i] = n end
	for _, name in ipairs(copy) do
		if not bodyOf(name) then MA.Unshare(name)
		elseif not sendOne(name) then ns.char.macroPending = true end
	end
end
ns.On("LM_ANNOUNCED", function() if #shared() > 0 then resendAll() end end)
ns.On("LM_HELLO_ANSWERED", function() if #shared() > 0 then resendAll() end end)
ns.On("LM_HB_SENT", function() if ns.char.macroPending then resendAll() end end)
ns.On("LM_COMM_DROPPED", function(kind) if kind == "mc" or kind == "mcx" then ns.char.macroPending = true end end)

C.OnMessage("mc", function(f, name)
	local m = R.mates[name]
	if not m then return end
	local t = store()
	t[name] = t[name] or {}
	local count = 0
	for _ in pairs(t[name]) do count = count + 1 end
	if not t[name][f.n] and count >= MA.MAX_SHARED then return end
	t[name][f.n] = { x = f.x, c = m.class, t = time() }
	ns.Fire("LM_MACROS_CHANGED")
end)
C.OnMessage("mcx", function(f, name)
	local t = store()
	if t[name] and t[name][f.n] then t[name][f.n] = nil; ns.Fire("LM_MACROS_CHANGED") end
end)

-- Guildmates' shared macros for my class: { by, name, body }.
function MA.Guild(search)
	local q, out, cutoff = (search or ""):lower(), {}, time() - MA.FORGET_DAYS * 86400
	for by, list in pairs(store()) do
		for n, e in pairs(list) do
			if e.t < cutoff then list[n] = nil
			elseif by ~= me() and e.c == myClass() and (e.sim or R.IsGuildmate(by))
				and (q == "" or by:lower():find(q, 1, true) or n:lower():find(q, 1, true)) then
				out[#out + 1] = { by = by, name = n, body = e.x, icon = MA.IconOf(e.x) }
			end
		end
	end
	table.sort(out, function(a, b) if a.by ~= b.by then return a.by < b.by end; return a.name < b.name end)
	return out
end

function MA.AddSample(by, name, body, class) local t = store(); t[by] = t[by] or {}; t[by][name] = { x = body, c = class or myClass(), t = time(), sim = true }; ns.Fire("LM_MACROS_CHANGED") end
function MA.RemoveSamples()
	for _, list in pairs(store()) do for n, e in pairs(list) do if e.sim then list[n] = nil end end end
	ns.Fire("LM_MACROS_CHANGED")
end
