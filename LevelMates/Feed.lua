-- Feed.lua: the guild wall. What I live (a level, a dungeon with guildmates, rare-or-better loot, my personal goal)
-- goes out in its own kind `fe`; guildmates' arrive the same way; guild goals reached and level-ups seen by
-- heartbeat are added locally. Spec 2026-10-10-levelmates-social-leveling-design (A1).
local _, ns = ...
local F = {}
ns.Feed = F
local L, C, R = ns.L, ns.Comm, ns.Roster
F.MAX, F.DAYS, F.RESEND = 200, 7, 5

local function me() return ns.Me() end
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
	local seq = 0
	for _, x in ipairs(s) do seq = math.max(seq, x.seq or 0) end
	e.seq = seq + 1   -- arrival order breaks ties within a minute
	s[#s + 1] = e
	table.sort(s, function(a, b) if a.t ~= b.t then return a.t > b.t end; return (a.seq or 0) > (b.seq or 0) end)   -- newest first
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
	elseif e.k == "gol" then return string.format(L.FEED_GOL, e.b or "")
	elseif e.k == "dth" then return string.format(L.FEED_DTH, e.a, e.b or "?")
	elseif e.k == "ach" then local a = ns.Achievements and ns.Achievements.LIST[e.a]; return string.format(L.FEED_ACH, a and ns.Achievements.Link(a.id) or "?") end
	return ""
end
function F.Ago(e) return string.format(L.FEED_AGO, ns.Journal.Duration(math.max(0, F.Now() - e.t) * 60)) end

-- Newest first, the last 7 days, of people still in the guild; filtered by name or text, or to deaths only.
function F.List(search, deathsOnly)
	local s, out, cutoff, q = store(), {}, F.Now() - F.DAYS * 1440, (search or ""):lower()
	for i = #s, 1, -1 do if s[i].t < cutoff then table.remove(s, i) end end
	for _, e in ipairs(s) do
		if (not deathsOnly or e.k == "dth") and (e.k == "gol" or e.sim or e.who == me() or R.IsGuildmate(e.who))
			and (q == "" or (F.Who(e) .. " " .. F.Text(e)):lower():find(q, 1, true)) then out[#out + 1] = e end
	end
	return out
end

-- Dungeons and loot happen inside instances, where nothing can be sent: what cannot go out stays pending and
-- goes after the next heartbeat outside (the newest five of the last day).
local function sendEntry(e)
	if C.Send("fe", { k = e.k, a = e.a, b = e.b, t = e.t }) then e.pending = nil; return true end
	e.pending = true
	return false
end
local function share(k, a, b)
	local e = { who = me(), k = k, a = a or 0, b = b, t = F.Now() }
	F.Add(e)
	if ns.db.settings.shareFeed then sendEntry(e) end
end
F.Share = share   -- for other modules (achievements)
ns.On("LM_HB_SENT", function()
	if not ns.db.settings.shareFeed then return end
	local n, cutoff = 0, F.Now() - 1440
	for _, e in ipairs(store()) do
		if e.t < cutoff or n >= F.RESEND then break end
		if e.pending and e.who == me() and (e.k ~= "dth" or ns.db.settings.shareDeaths) and (e.k ~= "ach" or ns.db.settings.shareAchievements) then n = n + 1; sendEntry(e) end
	end
end)
ns.On("LM_COMM_DROPPED", function(kind)
	if kind ~= "fe" then return end
	local cutoff = F.Now() - 10
	for _, e in ipairs(store()) do if e.who == me() and e.k ~= "gol" and e.t >= cutoff then e.pending = true end end
end)

ns.On("LM_JOURNAL_ADDED", function(e)
	if e.sim then return end
	if e.k == "level" then share("lvl", e.level)
	elseif e.k == "dungeon" and e.mates and #e.mates > 0 then
		share("dun", 0, ns.CutUtf8(e.name .. " · " .. table.concat(e.mates, ", "), 60))
	elseif e.k == "death" and ns.db.settings.shareDeaths then   -- level and zone only: nothing from combat
		share("dth", e.level or UnitLevel("player"), e.zone and e.zone ~= "" and ns.CutUtf8(e.zone, 60) or nil)
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
		if e.who == me() and e.k ~= "gol" and not e.sim and (e.k ~= "dth" or ns.db.settings.shareDeaths) then
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
