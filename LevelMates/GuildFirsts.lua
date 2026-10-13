-- GuildFirsts.lua: the guild's firsts: the first to reach level 10, 20… 60, and 300 in each profession. Whoever gets
-- there says so with a record of their own (`gfi`, kept by everyone and handed to late logins), stamped with the
-- server's time; the earliest stamp is the first, and the same second is shared (nobody picks a winner between two).
-- Only what happens with LevelMates running counts: a level reached before has no time to prove. Dungeon clears
-- are left out: Forever hides the combat log from addons, so a clear can't be told from a visit.
local _, ns = ...
local GF = {}
ns.GuildFirsts = GF
local L, C, R, S = ns.L, ns.Comm, ns.Roster, ns.Sync
GF.LIFE = 3 * 365 * 86400

GF.LIST = {}
for lvl = 10, 60, 10 do GF.LIST[#GF.LIST + 1] = { w = "lvl" .. lvl, level = lvl } end
for _, id in ipairs(ns.Professions.IDS) do GF.LIST[#GF.LIST + 1] = { w = "p" .. id, prof = id } end
local BY_W = {}
for _, f in ipairs(GF.LIST) do BY_W[f.w] = f end

function GF.Name(w)
	local f = BY_W[w]
	if not f then return w end
	if f.level then return string.format(L.GF_LEVEL, f.level) end
	return string.format(L.GF_PROF, ns.Professions.Name(f.prof))
end
function GF.Icon(w)
	local f = BY_W[w]
	if f and f.prof then return ns.Professions.Icon(f.prof) end
	return ns.Skin.Banner()
end

-- The first for a milestone: { names (all who share the earliest second), a (that time) }, or nil.
function GF.First(w)
	local best, names
	for _, rec in ipairs(S.List("gfi")) do
		local d = rec.d
		if d and d.w == w and d.a then
			if not best or d.a < best then best, names = d.a, { rec.o }
			elseif d.a == best then names[#names + 1] = rec.o end
		end
	end
	if not best then return nil end
	table.sort(names)
	return { names = names, a = best }
end

local function me() return ns.Me() end
local function myId(w) return w .. "-" .. ns.NameKey(me()) end
-- Mine, when nobody got there before me (a claim behind someone else's would only add a record).
function GF.Claim(w)
	if not BY_W[w] or not ns.db.settings.shareAchievements then return false end
	local now = GetServerTime()
	local first = GF.First(w)
	if first and first.a < now then return false end
	S.Put("gfi", myId(w), { w = w, a = now })
	return true
end

-- A claim the sender can back: their own name in the id, a time not in the future, and a level they have reached
-- (when the guild list knows it).
local function idOwner(id, owner) return id:match("%-(%x+)$") == ns.NameKey(owner) end
local function accept(f, owner)
	local m = BY_W[f.w]
	if not m or (tonumber(f.a) or 0) > GetServerTime() + 300 then return false end
	local mate = R.mates[ns.ShortName(owner)]
	if m.level and mate and mate.level and mate.level < m.level then return false end
	return true
end
local told = {}
S.Define("gfi", { class = "board", life = GF.LIFE, fields = { w = C.V.word(8), a = C.V.int(1000000000, 4000000000) }, required = { "w", "a" },
	idOwner = idOwner, accept = accept,
	onChange = function(rec, _, how)
		if how ~= "live" or not rec.d or rec.o == me() or told[rec.id] then return end
		local first = GF.First(rec.d.w)
		if not first or first.a ~= rec.d.a then return end   -- not (or no longer) the first
		told[rec.id] = true
		ns.Notice(L.GF_TOLD, rec.o, GF.Name(rec.d.w))
	end })

-- When: a level-up to 10, 20… 60; a profession reaching 300 (seen going up, not at login).
ns.On("LM_POINT_EVENT", function(cat, level)
	if cat == "l" and level and level >= 10 and level % 10 == 0 then GF.Claim("lvl" .. level) end
end)
local lastRank
ns.On("LM_SKILLS_CHANGED", function()
	local skills = ns.char.skills or {}
	if lastRank then
		for id, s in pairs(skills) do
			if (s.rank or 0) >= 300 and (lastRank[id] or 0) < 300 then GF.Claim("p" .. id) end
		end
	end
	lastRank = {}
	for id, s in pairs(skills) do lastRank[id] = s.rank or 0 end
end)
