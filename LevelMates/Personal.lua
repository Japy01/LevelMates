-- Personal.lua: one personal goal per character ("me, level 40 by Sunday"), shown to the guild on the Goals tab.
-- Spec 2026-10-09-levelmates-goals-design (plan B). It travels in its own kind `gp` (l = 0 withdraws it).
local _, ns = ...
local P = {}
ns.Personal = P
local L, C, R, G = ns.L, ns.Comm, ns.Roster, ns.Goals
local DAYS_MAX = 30

local function today() return math.floor(time() / 86400) end
local function me() return ns.Me() end
local function expired(g) return today() > g.e + G.KEEP_DAYS end
local function theirs()
	ns.db.personal = ns.db.personal or {}
	local k = ns.GuildKey()
	ns.db.personal[k] = ns.db.personal[k] or {}
	return ns.db.personal[k]
end

function P.Mine()
	local g = ns.char.goal
	if g and expired(g) then ns.char.goal = nil; return nil end
	return g
end

-- My goal in `gp` (level 0 withdraws it): the sync layer's personal helper keeps a refused send pending in the
-- character's saved data (a /reload or a logout keeps it), sends it after the next heartbeat, and resends a goal to
-- newcomers.
local PS = ns.Sync.Personal("gp", function()
	local g = P.Mine()
	return { l = g and g.l or 0, e = g and g.e or today() }
end, { save = "goalPending", worth = function() return P.Mine() ~= nil end })
local function send(prio) return PS.Mark(prio) end

-- Called from a click (the "My goal" dialog).
function P.Set(level, days)
	if type(level) ~= "number" or level ~= math.floor(level) or level <= UnitLevel("player") or level > 60
		or type(days) ~= "number" or days < 1 or days > DAYS_MAX then
		ns.Say(L.MYGOAL_BAD)
		return false
	end
	ns.char.goal = { l = level, e = today() + days }
	send("now")
	ns.Fire("LM_GOALS_CHANGED")
	return true
end

function P.Clear()
	if not ns.char.goal then return false end
	ns.char.goal = nil
	send("now")
	ns.Fire("LM_GOALS_CHANGED")
	return true
end

-- Mine first, then guildmates' by deadline.
function P.List()
	local out, others, t = {}, {}, theirs()
	local mine = P.Mine()
	if mine then out[1] = { name = me(), l = mine.l, e = mine.e, mine = true } end
	for name, g in pairs(t) do
		if expired(g) then t[name] = nil
		elseif name ~= me() and (g.sim or R.IsGuildmate(name)) then others[#others + 1] = { name = name, l = g.l, e = g.e, sim = g.sim } end
	end
	table.sort(others, function(a, b) if a.e ~= b.e then return a.e < b.e end; return a.name < b.name end)
	for _, o in ipairs(others) do out[#out + 1] = o end
	return out
end

function P.Text(p) return string.format(L.MYGOAL_TEXT, p.l) end
function P.IsDone(p) local lvl = G.KnownLevel(p.name); return lvl ~= nil and lvl >= p.l end
function P.ProgressText(p) local lvl = G.KnownLevel(p.name); return string.format("%s/%d", lvl and tostring(math.min(lvl, p.l)) or "?", p.l) end

C.OnMessage("gp", function(f, name)
	if not R.mates[name] then return end   -- only people the roster knows
	local t = theirs()
	if f.l == 0 then t[name] = nil
	elseif f.l >= 2 and f.e + G.KEEP_DAYS >= today() and f.e <= today() + DAYS_MAX + 1 then t[name] = { l = f.l, e = f.e }
	else return end
	ns.Fire("LM_GOALS_CHANGED")
end)

-- Reached: announced once per goal.
local function check(level)
	local g = P.Mine()
	if g and not g.announced and math.max(UnitLevel("player"), level or 0) >= g.l then
		g.announced = true
		ns.Fire("LM_MYGOAL_REACHED", g.l)
		if ns.db.settings.goalNotices then ns.Notice(L.MYGOAL_REACHED, g.l) end
		ns.Fire("LM_GOALS_CHANGED")
	end
end
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LEVEL_UP")
ev:SetScript("OnEvent", function(_, _, level) check(level) end)
ns.On("LM_WORLD", function() check() end)



-- Simulation support (/lm sim metas): local samples, never sent.
function P.AddSample(name, l, e) theirs()[name] = { l = l, e = e, sim = true }; ns.Fire("LM_GOALS_CHANGED") end
function P.RemoveSamples()
	local t = theirs()
	for name, g in pairs(t) do if g.sim then t[name] = nil end end
	ns.Fire("LM_GOALS_CHANGED")
end
