-- GuildHistory.lua: what changed in the guild list, as this client saw it: who joined, who left (leaving and being
-- removed look the same), who went up or down a rank; and the race to the level cap (who got there first, and first
-- of each class, when seen live). Local only: nothing is sent. Spec 2026-10-12-levelmates-guild-design (1.3, 1.5).
local _, ns = ...
local GH = {}
ns.GuildHistory = GH
local L = ns.L
GH.MAX, GH.SETTLE = 500, 2

local function store()
	ns.db.history = ns.db.history or {}
	local g = GetGuildInfo("player") or "?"
	ns.db.history[g] = ns.db.history[g] or { log = {}, snap = nil, race = {} }
	return ns.db.history[g]
end
local function maxLevel() return (GetMaxPlayerLevel and GetMaxPlayerLevel()) or 60 end

-- The guild list as it is now: name -> { level, rank, class }; nil when the game has not given it yet.
local function read()
	local club = C_Club and C_Club.GetGuildClubId and C_Club.GetGuildClubId()
	if not club then return nil end
	local out, n = {}, 0
	for _, id in ipairs(C_Club.GetClubMembers(club) or {}) do
		local info = C_Club.GetMemberInfo(club, id)
		if info and info.name then
			out[ns.ShortName(info.name)] = { level = info.level or 0, rank = info.guildRankOrder or 0, class = info.classID or info.classFileName }
			n = n + 1
		end
	end
	if n == 0 then return nil end
	return out, n
end

local function add(k, who, a)
	local s = store()
	table.insert(s.log, 1, { k = k, who = who, a = a, t = time() })
	while #s.log > GH.MAX do table.remove(s.log) end
	if (k == "join" or k == "leave" or k == "r60") and ns.Feed then ns.Feed.Add({ who = who, k = k, a = a or 0, t = ns.Feed.Now() }) end
end

-- The race: everyone's level; who reached the cap while I was watching, first overall and first of their class.
local function race(name, level, class, live)
	local s, cap = store(), maxLevel()
	local r = s.race[name] or {}
	local was = r.level
	r.level, r.class = level, class or r.class
	if level >= cap and not r.at and not r.before then
		if not live or not was then r.before = true
		else
			r.at = time()
			local first, firstClass = true, true
			for other, o in pairs(s.race) do
				if other ~= name and o.at then
					first = false
					if o.class == r.class then firstClass = false end
				end
			end
			r.first, r.firstClass = first, firstClass
			add("r60", name, level)
			if ns.db.settings.levelNotices then ns.Notice(first and L.RACE_FIRST or L.RACE_REACHED, name, level) end
		end
	end
	s.race[name] = r
end

local pendingShrink
local seenThisSession = false   -- what changed while I was away is not "live"
function GH.Scan()
	local now, rows = read()
	if not now then return end
	local total = GetNumGuildMembers and GetNumGuildMembers() or rows
	local partial = (total or 0) > rows
	local s = store()
	if not s.snap and partial then return end   -- never a baseline from a list still loading
	local live = s.snap ~= nil and seenThisSession
	seenThisSession = true
	for name, m in pairs(now) do race(name, m.level, m.class, live) end
	if not s.snap then s.snap = now; s.since = time(); return end   -- the first look: a baseline, no events
	local gone = {}
	if not partial then for name in pairs(s.snap) do if not now[name] then gone[#gone + 1] = name end end end
	local before = 0
	for _ in pairs(s.snap) do before = before + 1 end
	if #gone > 5 and #gone * 2 > before then   -- half the guild at once: wait for a second look to agree
		table.sort(gone)
		local sig = table.concat(gone, ",")
		if pendingShrink ~= sig then pendingShrink = sig; return end
	end
	pendingShrink = nil
	for name, m in pairs(now) do
		local old = s.snap[name]
		if not old then add("join", name)
		elseif m.rank < old.rank then add("rankup", name, m.rank)
		elseif m.rank > old.rank then add("rankdown", name, m.rank) end
		if old and m.level > (old.level or 0) and m.level >= 10 and live then add("level", name, m.level) end
	end
	table.sort(gone)
	for _, name in ipairs(gone) do add("leave", name); s.race[name] = nil end
	if partial then for name, m in pairs(s.snap) do if not now[name] then now[name] = m end end end   -- keep who we could not read
	s.snap = now
	ns.Fire("LM_HISTORY_CHANGED")
end

function GH.List() return store().log end
function GH.KnownSince() return store().since end
-- Everyone in the race, highest level first; at the same level, who got there first.
function GH.Race()
	local out = {}
	for name, r in pairs(store().race) do
		out[#out + 1] = { name = name, level = r.level or 0, class = r.class, at = r.at, first = r.first, firstClass = r.firstClass, before = r.before }
	end
	table.sort(out, function(a, b)
		if a.level ~= b.level then return a.level > b.level end
		if (a.at or 0) ~= (b.at or 0) then
			if not a.at then return false elseif not b.at then return true end
			return a.at < b.at
		end
		return a.name < b.name
	end)
	return out
end

-- The list arrives in bursts: read it once things are quiet for two seconds.
local due
local ev = CreateFrame("Frame")
ev:RegisterEvent("GUILD_ROSTER_UPDATE")
ev:SetScript("OnEvent", function()
	due = GetTime() + GH.SETTLE
	C_Timer.After(GH.SETTLE + 0.05, function() if due and GetTime() >= due then due = nil; GH.Scan() end end)
end)
