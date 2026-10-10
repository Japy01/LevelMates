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
ns.On("LM_PING_ANSWERED", function() if encode() ~= "" then resend() end end)
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
