-- Feed.lua: the guild wall. What I live (a level, a dungeon with guildmates, rare-or-better loot, my personal goal)
-- goes out as a sync record of type `fe` (kept and handed over by everyone, so a late login sees the last two days
-- even of guildmates who are offline); guild goals reached and level-ups seen by heartbeat are added locally.
-- Specs 2026-10-10-levelmates-social-leveling-design (A1) and 2026-10-12-levelmates-sync-v2-design.
local _, ns = ...
local F = {}
ns.Feed = F
local L, C, R, S = ns.L, ns.Comm, ns.Roster, ns.Sync
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
	elseif e.k == "join" then return L.FEED_JOIN
	elseif e.k == "leave" then return L.FEED_LEAVE
	elseif e.k == "r60" then return string.format(L.FEED_R60, e.a)
	elseif e.k == "ach" then local a = ns.Achievements and ns.Achievements.LIST[e.a]; return string.format(L.FEED_ACH, a and ns.Achievements.Link(a.id) or "?") end
	return ""
end
function F.Ago(e) return string.format(L.FEED_AGO, ns.Journal.Duration(math.max(0, F.Now() - e.t) * 60)) end

-- Newest first, the last 7 days, of people still in the guild; filtered by name or text, or to deaths only.
function F.List(search, deathsOnly)
	local s, out, cutoff, q = store(), {}, F.Now() - F.DAYS * 1440, (search or ""):lower()
	for i = #s, 1, -1 do if s[i].t < cutoff then table.remove(s, i) end end
	for _, e in ipairs(s) do
		if (not deathsOnly or e.k == "dth") and (e.k == "gol" or e.k == "leave" or e.k == "join" or e.sim or e.who == me() or R.IsGuildmate(e.who))
			and (q == "" or (F.Who(e) .. " " .. F.Text(e)):lower():find(q, 1, true)) then out[#out + 1] = e end
	end
	return out
end

-- My entries are records: the sync layer holds them inside a dungeon until I leave, and hands the last two days
-- (at most 40 entries) to whoever logs in later. A record id: the author, the minute, the kind and the value.
local function recordId(who, k, a, t)
	return string.format("%s%x%s%x", (tostring(who):gsub("[^%w]", "")):sub(1, 8), t, k, math.min(a or 0, 1048575))
end
S.Define("fe", { class = "board", life = F.DAYS * 86400,
	fields = { k = C.V.oneOf("lvl", "dun", "itm", "pgl", "dth", "ach"), a = C.V.int(0, 999999), b = C.V.text(60), t = C.V.int(0, 100000000) },
	required = { "k", "a", "t" },
	relayKeep = function(r)
		if r.o == me() and ((r.d.k == "dth" and not ns.db.settings.shareDeaths) or (r.d.k == "ach" and not ns.db.settings.shareAchievements) or not ns.db.settings.shareFeed) then return false end   -- switched off since: not handed on
		return r.d.t and r.d.t >= F.Now() - 2 * 1440
	end, relayMax = 40,
	onChange = function(rec, _, how)
		if rec.dead or how == "mine" or how == "expired" then return end
		local f, now = rec.d, F.Now()
		if f.t > now + 10 or f.t < now - F.DAYS * 1440 then return end
		F.Add({ who = rec.o, k = f.k, a = f.a, b = f.b, t = f.t })
	end })
local function share(k, a, b)
	local e = { who = me(), k = k, a = a or 0, b = b, t = F.Now() }
	F.Add(e)
	if ns.db.settings.shareFeed then
		S.Put("fe", recordId(e.who, k, e.a, e.t), { k = k, a = e.a, b = b, t = e.t, _exp = (e.t + F.DAYS * 1440) * 60 })
	end
end
F.Share = share   -- for other modules (achievements)

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


-- Simulation support (/lm sim muro): local samples, never sent.
function F.AddSample(who, k, a, b, minutesAgo) F.Add({ who = who, k = k, a = a or 0, b = b, t = F.Now() - (minutesAgo or 0), sim = true }) end
function F.RemoveSamples()
	local s = store()
	for i = #s, 1, -1 do if s[i].sim then table.remove(s, i) end end
	ns.Fire("LM_FEED_CHANGED")
end
