-- Points.lua: guild progress. Each player counts their own points (levels, dungeons with guildmates, quests, helps,
-- gifts, meetups) and shares them in kind `pt`; the guild adds up everyone's: guild level, the weekly challenge and
-- soft weekly rankings (top three only). Spec 2026-10-11-levelmates-libro-design.
local _, ns = ...
local PT = {}
ns.Points = PT
local L, C, R = ns.L, ns.Comm, ns.Roster
PT.FORGET_DAYS = 30
PT.VALUE = { l = 10, d = 15, q = 1, h = 5, g = 5, m = 10 }
PT.CHALLENGES = { { cat = "d", base = 25 }, { cat = "l", base = 60 }, { cat = "h", base = 15 }, { cat = "q", base = 200 } }
local MONDAY = 4 * 86400   -- 1970-01-01 was a Thursday: the first Monday is four days later

local function me() return (UnitName("player")) end
local function now() return GetServerTime and GetServerTime() or time() end
function PT.Week(t) return math.floor(((t or now()) - MONDAY) / (7 * 86400)) end

local function mine()
	ns.char.points = ns.char.points or { t = 0, w = PT.Week(), l = 0, d = 0, h = 0, q = 0 }
	local p = ns.char.points
	if p.w ~= PT.Week() then p.w, p.l, p.d, p.h, p.q = PT.Week(), 0, 0, 0, 0 end   -- a new week: weekly counters start again
	return p
end
local function store()
	ns.db.points = ns.db.points or {}
	local k = GetGuildInfo("player") or "?"
	ns.db.points[k] = ns.db.points[k] or {}
	return ns.db.points[k]
end

function PT.Mine() local p = mine(); return { t = p.t, w = p.w, l = p.l, d = p.d, h = p.h, q = p.q } end

------------------------------------------------------------------ sharing
local lastSent, dirty, announced = -math.huge, false, false
local function fields()
	if not ns.db.settings.sharePoints then return {} end
	local p = mine()
	return { t = p.t, w = p.w, l = p.l, d = p.d, h = p.h, q = p.q }
end
local function send(prio)
	if C.Send("pt", fields(), prio) then ns.char.pointsPending, lastSent, dirty = nil, GetTime(), false; return true end
	ns.char.pointsPending = true
	return false
end
function PT.SetSharing() send("now") end

local function changed()
	ns.Fire("LM_POINTS_CHANGED")
	PT.CheckMilestones()
	if not announced then return end
	if dirty then return end   -- a send is already waiting: it takes the newest
	dirty = true
	-- a couple of seconds to gather what happens together, and never more than once a minute
	C_Timer.After(math.max(2, 60 - (GetTime() - lastSent)), function() if dirty then send() end end)
end

-- What I do: points and this week's counter.
local function add(cat)
	local p = mine()
	p.t = p.t + PT.VALUE[cat]
	if p[cat] then p[cat] = p[cat] + 1 end
	changed()
end
PT.Add = add

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LEVEL_UP"); ev:RegisterEvent("QUEST_TURNED_IN")
ev:SetScript("OnEvent", function(_, event) if not ns.db then return end; add(event == "PLAYER_LEVEL_UP" and "l" or "q") end)
ns.On("LM_JOURNAL_ADDED", function(e) if e.k == "dungeon" and e.mates and #e.mates > 0 and not e.sim then add("d") end end)
local helped = {}
ns.On("LM_HELP_GIVEN", function(id) if id and helped[id] then return end; if id then helped[id] = true end; add("h") end)
ns.On("LM_GIFT_GIVEN", function() add("g") end)

-- A meetup attended: during its hour, grouped with its creator (or, mine, with someone who joined); once each.
local function checkMeetups()
	if not ns.db then return end
	ns.char.meetCounted = ns.char.meetCounted or {}
	local nowMin = ns.Meetups.Now()
	for _, m in ipairs(ns.Meetups.List()) do
		if not ns.char.meetCounted[m.id] and nowMin >= m.at and nowMin <= m.at + 60 then
			local with = false
			if m.by == me() then
				for name in pairs(m.joined or {}) do if UnitInParty(name) or UnitInRaid(name) then with = true end end
			elseif ns.Meetups.MyRole(m.id) and (UnitInParty(m.by) or UnitInRaid(m.by)) then
				with = true
			end
			if with then ns.char.meetCounted[m.id] = true; add("m") end
		end
	end
end
C_Timer.NewTicker(30, checkMeetups)

ns.On("LM_ANNOUNCED", function() announced = true; if (fields().t or 0) > 0 then send() end end)   -- nothing yet: nothing sent
ns.On("LM_PING_ANSWERED", function() if (fields().t or 0) > 0 then send() end end)
ns.On("LM_HB_SENT", function() if ns.char.pointsPending then send() end end)   -- a refused send (dungeon) goes with the next heartbeat
ns.On("LM_COMM_DROPPED", function(kind) if kind == "pt" then ns.char.pointsPending = true end end)

C.OnMessage("pt", function(f, name)
	if not R.mates[name] then return end
	local s = store()
	if f.t == nil then s[name] = nil
	else s[name] = { t = f.t, w = f.w or 0, l = f.l or 0, d = f.d or 0, h = f.h or 0, q = f.q or 0, at = time() } end
	ns.Fire("LM_POINTS_CHANGED")
	PT.CheckMilestones()
end)

------------------------------------------------------------------ the guild
-- Everyone counted: me (when sharing) and guildmates seen in the last 30 days, still in the guild.
function PT.Members()
	local out, s, cutoff = {}, store(), time() - PT.FORGET_DAYS * 86400
	if ns.db.settings.sharePoints then local p = PT.Mine(); p.name, p.mine = me(), true; out[#out + 1] = p end
	for name, e in pairs(s) do
		if e.at < cutoff then s[name] = nil
		elseif name ~= me() and (e.sim or R.IsGuildmate(name)) then
			out[#out + 1] = { name = name, t = e.t, w = e.w, l = e.l, d = e.d, h = e.h, q = e.q }
		end
	end
	return out
end

function PT.GuildTotal()
	local n = 0
	for _, m in ipairs(PT.Members()) do n = n + (m.t or 0) end
	return n
end

-- Level N needs 100 * N more points than level N - 1 had: level, points into it, points it needs.
function PT.Level(total)
	local level, base = 1, 0
	while total >= base + 100 * level do base = base + 100 * level; level = level + 1 end
	return level, total - base, 100 * level
end

local function thisWeek() local w = PT.Week(); local out = {}; for _, m in ipairs(PT.Members()) do if m.w == w then out[#out + 1] = m end end; return out end

function PT.Challenge()
	local w = PT.Week()
	local c = PT.CHALLENGES[w % #PT.CHALLENGES + 1]
	local players = thisWeek()
	local goal = math.ceil(c.base * math.min(3, math.max(0.4, #players / 5)))
	local have = 0
	for _, m in ipairs(players) do have = have + (m[c.cat] or 0) end
	return { cat = c.cat, goal = goal, have = math.min(have, goal), done = have >= goal, text = string.format(L["CHALLENGE_" .. c.cat], goal) }
end

function PT.Rankings()
	local out, players = {}, thisWeek()
	for _, cat in ipairs({ "l", "d", "h" }) do
		local list = {}
		for _, m in ipairs(players) do if (m[cat] or 0) > 0 then list[#list + 1] = { name = m.name, n = m[cat] } end end
		table.sort(list, function(a, b) if a.n ~= b.n then return a.n > b.n end; return a.name < b.name end)
		while #list > 3 do table.remove(list) end
		out[cat] = list
	end
	return out
end

-- The guild's milestones, told once each (saved): a new guild level, the week's challenge done.
function PT.CheckMilestones()
	if not (ns.db and IsInGuild()) then return end
	local guild = GetGuildInfo("player") or "?"
	ns.db.milestones = ns.db.milestones or {}
	ns.db.milestones[guild] = ns.db.milestones[guild] or {}
	local ms = ns.db.milestones[guild]
	local level = PT.Level(PT.GuildTotal())
	if not ms.level then ms.level = level
	elseif level > ms.level then
		ms.level = level
		ns.Notice(L.GUILD_LEVEL_UP, level)
		ns.Feed.Add({ who = "", k = "gol", a = 0, b = string.format(L.GUILD_LEVEL_WALL, level), t = ns.Feed.Now() })
	end
	local ch, w = PT.Challenge(), PT.Week()
	if ch.done and ms.challenge ~= w then
		ms.challenge = w
		ns.Notice(L.CHALLENGE_DONE, ch.text)
		ns.Feed.Add({ who = "", k = "gol", a = 0, b = ch.text, t = ns.Feed.Now() })
	end
end

function PT.AddSample(name, e) e.at, e.sim, e.w = time(), true, e.w or PT.Week(); store()[name] = e; ns.Fire("LM_POINTS_CHANGED") end
function PT.RemoveSamples() local s = store(); for name, e in pairs(s) do if e.sim then s[name] = nil end end; ns.Fire("LM_POINTS_CHANGED") end
