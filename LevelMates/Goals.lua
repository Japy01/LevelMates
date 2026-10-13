-- Goals.lua: guild goals (plan A): everyone to level X, dungeon together, counters. Officers create and delete;
-- every addon keeps them per guild and re-shares them from officers and creators.
-- Spec 2026-10-09-levelmates-goals-design.
local _, ns = ...
local G = {}
ns.Goals = G
local L, C, R, D, J = ns.L, ns.Comm, ns.Roster, ns.Dungeons, ns.Journal
G.MAX, G.KEEP_DAYS, G.SEEN_DAYS = 5, 2, 30
local COUNT_KIND = { lvl = "level", qst = "quest", dun = "dungeon" }

local function today() return math.floor(time() / 86400) end
local function me() return ns.Me() end
local function guildKey() return GetGuildInfo("player") or "?" end
local function store()
	ns.db.goals = ns.db.goals or {}
	local k = guildKey()
	ns.db.goals[k] = ns.db.goals[k] or {}
	return ns.db.goals[k]
end
local function seen()
	ns.db.seen = ns.db.seen or {}
	local k = guildKey()
	ns.db.seen[k] = ns.db.seen[k] or {}
	return ns.db.seen[k]
end
local function newId() return string.format("%04x%04x", math.random(0, 65535), math.random(0, 65535)):sub(1, 8) end

-- A deleted goal stays as a marker ({ gone = true }) until it would have expired, so a re-share from an officer who
-- missed the delete cannot bring it back.
function G.Get(id) local g = store()[id]; if g and not g.gone then return g end end
local function bury(id, e) store()[id] = { id = id, gone = true, e = e or today() } end

-- Active goals, soonest deadline first; goals 2 days past their deadline are dropped here.
function G.List()
	local s, out = store(), {}
	for id, g in pairs(s) do
		if today() > g.e + G.KEEP_DAYS then s[id] = nil elseif not g.gone then out[#out + 1] = g end
	end
	table.sort(out, function(a, b) if a.e ~= b.e then return a.e < b.e end; return a.id < b.id end)
	return out
end

-- Goals that may go out on the wire: simulation samples never do.
local function shared()
	local out = {}
	for _, g in ipairs(G.List()) do if not g.sim then out[#out + 1] = g end end
	return out
end

local function valid(ty, a, w)
	if ty == "lvl" then return type(a) == "number" and a >= 2 and a <= 60
	elseif ty == "dun" then return D.Get(a) ~= nil
	elseif ty == "cnt" then return type(a) == "number" and a >= 1 and a <= 10000 and COUNT_KIND[w] ~= nil end
	return false
end

local function fields(g)
	local f = { id = g.id, ty = g.ty, a = g.a, s = g.s, e = g.e }
	if g.ty == "cnt" then f.w = g.w end
	return f
end
G.Fields = fields

function G.Text(g)
	if g.ty == "lvl" then return string.format(L.GOAL_LVL, g.a)
	elseif g.ty == "dun" then return string.format(L.GOAL_DUN, D.Name(g.a)) end
	return string.format(L["GOAL_CNT_" .. string.upper(g.w)], g.a)
end
function G.UntilText(g) return date("%d/%m", g.e * 86400) end

-- My part of a counter: journal entries of the counted kind from the start of the goal's first day.
function G.MyContribution(g)
	if g.ty ~= "cnt" then return 0 end
	local from, n = g.s * 86400, 0
	for _, e in ipairs(J.List(COUNT_KIND[g.w], "")) do if e.t >= from and not e.sim then n = n + 1 end end
	return n
end

-- A guildmate's level as I know it: online now, else last seen (up to 30 days).
function G.KnownLevel(name)
	if name == me() then return UnitLevel("player") end
	local m = R.mates[name]
	if m then return m.level end
	local s = seen()[name]
	return s and s.l
end

-- lvl: reached, total, missing names; dun: 1|0, 1, by; cnt: sum, target.
function G.Progress(g)
	if g.ty == "lvl" then
		local levels, cutoff = {}, time() - G.SEEN_DAYS * 86400
		local sn = seen()
		for name, s in pairs(sn) do
			if s.t < cutoff then sn[name] = nil   -- forgotten after 30 days
			elseif R.IsGuildmate(name) then levels[name] = s.l end   -- someone who left the guild no longer counts
		end
		for name, m in pairs(R.mates) do levels[name] = m.level end
		levels[me()] = UnitLevel("player")
		local reached, total, missing = 0, 0, {}
		for name, l in pairs(levels) do
			total = total + 1
			if l >= g.a then reached = reached + 1 else missing[#missing + 1] = name end
		end
		table.sort(missing)
		return reached, total, missing
	elseif g.ty == "dun" then
		return g.doneBy and 1 or 0, 1, g.doneBy
	end
	local sum = G.MyContribution(g)
	for name, n in pairs(g.contrib or {}) do if name ~= me() then sum = sum + n end end   -- never count my part twice
	return sum, g.a
end

function G.IsDone(g)
	local a, b = G.Progress(g)
	if g.ty == "lvl" then return b > 0 and a == b end
	return a >= b
end

function G.ProgressText(g)
	if g.ty == "dun" then return g.doneBy and string.format(L.GOAL_DONE_BY, g.doneBy) or L.GOAL_PENDING end
	local a, b = G.Progress(g)
	return string.format("%d/%d", math.min(a, b), b)
end

-- Reached: announced once per goal.
function G.CheckDone(g)
	if not g.announced and G.IsDone(g) then
		g.announced = true
		ns.Fire("LM_GOAL_REACHED", g)
		if ns.db.settings.goalNotices then ns.NoticeAt("goals", L.GOAL_REACHED, G.Text(g)) end
	end
end

-- Called from a click (the officers' dialog).
function G.Create(ty, a, w, days)
	if not R.IAmOfficer() then ns.Say(L.GOAL_NOT_OFFICER); return false end
	if not C.IsReady() then ns.Say(L.HELP_NEEDS_SHARE); return false end
	if not valid(ty, a, w) or type(days) ~= "number" or days < 1 or days > 30 then ns.Say(L.GOAL_BAD_VALUE); return false end
	if #G.List() >= G.MAX then ns.Say(L.GOAL_FULL); return false end
	local g = { id = newId(), ty = ty, a = a, w = ty == "cnt" and w or nil, s = today(), e = today() + days, by = me(), contrib = {} }
	if not C.Send("go", fields(g), "now") then return false end
	store()[g.id] = g
	ns.Fire("LM_GOALS_CHANGED")
	return true
end

function G.CanDelete(id) local g = G.Get(id); return g ~= nil and (g.by == me() or R.IAmOfficer()) end

function G.Delete(id)
	if not G.CanDelete(id) then return false end
	C.Send("gx", { id = id }, "now")   -- if it cannot go out now, officers repeat it to newcomers
	bury(id, G.Get(id).e)
	ns.Fire("LM_GOALS_CHANGED")
	return true
end

C.OnMessage("go", function(f, name)
	if not R.IsOfficer(name) or not valid(f.ty, f.a, f.w) then return end
	local s = store()
	local g = s[f.id]
	if g and g.gone then return end
	if not g then
		if #G.List() >= G.MAX then return end
		g = { id = f.id, contrib = {}, by = name }
		s[f.id] = g
		if ns.db.settings.goalNotices then ns.NoticeAt("goals", L.GOAL_NEW, name, G.Text({ ty = f.ty, a = f.a, w = f.w })) end
	end
	g.ty, g.a, g.w, g.s, g.e = f.ty, f.a, f.w, f.s, f.e
	ns.Fire("LM_GOALS_CHANGED")
end)

C.OnMessage("gx", function(f, name)
	local g = G.Get(f.id)
	if g and (g.by == name or R.IsOfficer(name)) then bury(f.id, g.e); ns.Fire("LM_GOALS_CHANGED") end
end)

-- Levels last seen per guildmate, for "everyone to level X".
C.OnMessage("hb", function(f, name)
	seen()[name] = { l = f.l, t = time() }
	for _, g in ipairs(G.List()) do if g.ty == "lvl" then G.CheckDone(g) end end   -- the last one to arrive may be them
end)

-- A newcomer: officers re-send every goal they hold and every delete they know of, others only the goals they created.
ns.On("LM_HELLO_ANSWERED", function()
	local officer = R.IAmOfficer()
	for _, g in ipairs(shared()) do
		if officer or g.by == me() then C.Send("go", fields(g)) end
	end
	if officer then
		G.List()   -- drops expired markers first
		for id, g in pairs(store()) do if g.gone then C.Send("gx", { id = id }) end end
	end
end)

-- Dungeon together, done by someone else (any guildmate).
C.OnMessage("gd", function(f, name)
	local g = G.Get(f.id)
	if not g or g.ty ~= "dun" or g.doneBy or not R.mates[name] then return end
	g.doneBy = name
	G.CheckDone(g)
	ns.Fire("LM_GOALS_CHANGED")
end)

-- A guildmate's part of a counter (my own echo is ignored by Progress).
C.OnMessage("gc", function(f, name)
	local g = G.Get(f.id)
	if not g or g.ty ~= "cnt" or not R.mates[name] then return end
	g.contrib = g.contrib or {}
	g.contrib[name] = f.n
	G.CheckDone(g)
	ns.Fire("LM_GOALS_CHANGED")
end)

-- My journal: a dungeon with a guildmate completes a dungeon goal; any entry may move a counter.
ns.On("LM_JOURNAL_ADDED", function(e)
	if e.sim then return end   -- /lm sim diario: practice entries never complete a real goal
	for _, g in ipairs(shared()) do
		if g.ty == "dun" and not g.doneBy and e.k == "dungeon" and D.Matches(g.a, e.name) and e.mates and #e.mates > 0 then
			g.doneBy = me()
			C.Send("gd", { id = g.id }, "now")
		end
		G.CheckDone(g)
	end
	ns.Fire("LM_GOALS_CHANGED")
end)

-- My counter parts go out after a heartbeat when they changed, at most once a minute per goal.
local sentN, sentAt = {}, {}
ns.On("LM_HB_SENT", function()
	local now = GetTime()
	for _, g in ipairs(shared()) do
		if g.ty == "cnt" then
			local n = math.min(10000, G.MyContribution(g))
			if n ~= (sentN[g.id] or 0) and now - (sentAt[g.id] or -math.huge) >= 60 then
				if C.Send("gc", { id = g.id, n = n }) then sentN[g.id], sentAt[g.id] = n, now end
			end
		end
	end
end)

-- A newcomer also gets my counter parts and the dungeons I completed.
ns.On("LM_HELLO_ANSWERED", function()
	for _, g in ipairs(shared()) do
		if g.ty == "cnt" then
			local n = G.MyContribution(g)
			if n > 0 then C.Send("gc", { id = g.id, n = math.min(10000, n) }) end
		elseif g.ty == "dun" and g.doneBy == me() then
			C.Send("gd", { id = g.id })
		end
	end
end)

-- Simulation support (/lm sim metas): local sample goals, never sent.
function G.AddSample(g) g.sim = true; g.contrib = g.contrib or {}; store()[g.id] = g; ns.Fire("LM_GOALS_CHANGED") end
function G.RemoveSamples()
	local s = store()
	for id, g in pairs(s) do if g.sim then s[id] = nil end end
	ns.Fire("LM_GOALS_CHANGED")
end
