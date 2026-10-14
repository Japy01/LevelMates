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

local function me() return ns.Me() end
local function theirs()
	ns.db.professions = ns.db.professions or {}
	local k = ns.GuildKey()
	ns.db.professions[k] = ns.db.professions[k] or {}
	return ns.db.professions[k]
end

-- At the top of a rank (75, 150, 225): the trainer to visit next. nil otherwise (and at 300, the last).
local NEXT = { [75] = "TRAIN_JOURNEYMAN", [150] = "TRAIN_EXPERT", [225] = "TRAIN_ARTISAN" }
function P.TrainHint(rank, max)
	if not rank or not max or rank < max or not NEXT[max] then return nil end
	return L[NEXT[max]]
end

function P.Name(id) return L["PROF_" .. id] or ("#" .. tostring(id)) end

-- Each profession's icon: the apprentice spell's, as the game draws it; a fixed icon when the client has no such call.
local SPELL = { [171] = 2259, [164] = 2018, [333] = 7411, [202] = 4036, [182] = 2383, [165] = 2108, [186] = 2580, [393] = 8613, [197] = 3908, [129] = 3273, [185] = 2550, [356] = 7620 }
local ICON = { [171] = "Trade_Alchemy", [164] = "Trade_BlackSmithing", [333] = "Trade_Engraving", [202] = "Trade_Engineering", [182] = "Trade_Herbalism", [165] = "Trade_LeatherWorking",
	[186] = "Trade_Mining", [393] = "INV_Misc_Pelt_Wolf_01", [197] = "Trade_Tailoring", [129] = "Spell_Holy_SealOfSacrifice", [185] = "INV_Misc_Food_15", [356] = "Trade_Fishing" }
function P.Icon(id)
	local tex = C_Spell and C_Spell.GetSpellTexture and SPELL[id] and C_Spell.GetSpellTexture(SPELL[id])
	return tex or ("Interface\\Icons\\" .. (ICON[id] or "INV_Misc_QuestionMark"))
end

-- Rows for the tab: a header per profession (by name) with who has it underneath (highest rank first). A search
-- by profession keeps the whole group; a search by name keeps that person under their header.
function P.Groups(search)
	local q, groups, order = (search or ""):lower(), {}, {}
	for _, c in ipairs(P.List()) do
		if q == "" or P.Name(c.id):lower():find(q, 1, true) or c.name:lower():find(q, 1, true) then
			if not groups[c.id] then groups[c.id] = {}; order[#order + 1] = c.id end
			table.insert(groups[c.id], c)
		end
	end
	local out = {}
	for _, id in ipairs(order) do
		out[#out + 1] = { header = id, count = #groups[id] }
		for _, c in ipairs(groups[id]) do out[#out + 1] = c end
	end
	return out
end

function P.Mine()
	local out = {}
	for id, s in pairs(ns.char.skills or {}) do
		if KNOWN[id] and (s.rank or 0) > 0 then
			out[#out + 1] = { id = id, rank = math.min(450, s.rank), max = s.max and s.max > 0 and math.min(450, s.max) or nil }
		end
	end
	table.sort(out, function(a, b) return a.id < b.id end)
	while #out > 6 do table.remove(out) end
	return out
end

local function encode()
	if not ns.db.settings.shareProfessions then return "" end
	local parts = {}
	for _, p in ipairs(P.Mine()) do parts[#parts + 1] = p.id .. ":" .. p.rank .. (p.max and (":" .. p.max) or "") end
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

-- What changed decides when it goes out: a profession learned or dropped at once; rank points at most once a
-- minute, with a heartbeat (a herbing or fishing session would otherwise send one message per point).
local announced, dirty = false, false
local function ids(p) return (tostring(p or ""):gsub(":%d+", "")) end
ns.On("LM_SKILLS_CHANGED", function()
	if not announced then return end   -- the first share goes with my announce
	local p = encode()
	if p == lastSent then return end
	if ids(p) ~= ids(lastSent) then send() else dirty = true end
end)
ns.On("LM_ANNOUNCED", function() announced = true; if encode() ~= "" then resend() end end)
ns.On("LM_HELLO_ANSWERED", function() if encode() ~= "" then resend() end end)
ns.On("LM_HB_SENT", function()
	if ns.char.profPending or (dirty and GetTime() - (sentAt or -math.huge) >= 60) then dirty = false; send() end
end)
ns.On("LM_COMM_DROPPED", function(kind) if kind == "pf" then ns.char.profPending = true end end)

C.OnMessage("pf", function(f, name)
	if not R.mates[name] then return end   -- only people the roster knows
	local t = theirs()
	if f.p == nil then
		t[name] = nil
	else
		local list = {}
		for pair in tostring(f.p):gmatch("[^,]+") do
			local id, rank, max = pair:match("^(%d+):(%d+):?(%d*)$")
			id = tonumber(id)
			if id and KNOWN[id] then list[#list + 1] = { id = id, rank = tonumber(rank), max = tonumber(max) } end
		end
		t[name] = { list = list, t = time() }
	end
	ns.Fire("LM_PROFESSIONS_CHANGED")
end)

-- Rows for the Professions tab: me and guildmates (seen in the last 30 days, still in the guild), by profession,
-- then rank (highest first), then name.
function P.List()
	local out, t, cutoff = {}, theirs(), time() - P.FORGET_DAYS * 86400
	for _, p in ipairs(P.Mine()) do out[#out + 1] = { name = me(), id = p.id, rank = p.rank, max = p.max, t = time(), mine = true } end
	for name, e in pairs(t) do
		if e.t < cutoff then t[name] = nil
		elseif name ~= me() and (e.sim or R.IsGuildmate(name)) then
			for _, p in ipairs(e.list) do out[#out + 1] = { name = name, id = p.id, rank = p.rank, max = p.max, t = e.t } end
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
