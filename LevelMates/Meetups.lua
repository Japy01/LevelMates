-- Meetups.lua: dungeon meetups ("Deadmines, Saturday 21:00"), made from a dungeon card, joined with a role and
-- reminded 15 minutes before. Kinds qd/qdx (meetup, cancel) and qj/qjx (join, leave).
-- Spec 2026-10-10-levelmates-social-leveling-design (A3).
local _, ns = ...
local M = {}
ns.Meetups = M
local L, C, R, D = ns.L, ns.Comm, ns.Roster, ns.Dungeons
M.MAX, M.PER_PERSON, M.KEEP, M.REMIND = 10, 2, 180, 15   -- at once, per creator, minutes kept after the hour, reminder
local ROLES = { T = true, H = true, D = true }

local function me() return (UnitName("player")) end
function M.Now() return math.floor(time() / 60) end   -- minutes since 1970
local function store()
	ns.db.meetups = ns.db.meetups or {}
	local k = GetGuildInfo("player") or "?"
	ns.db.meetups[k] = ns.db.meetups[k] or {}
	return ns.db.meetups[k]
end
local function myJoins() ns.char.meetJoins = ns.char.meetJoins or {}; return ns.char.meetJoins end
local function newId() return string.format("%04x%04x", math.random(0, 65535), math.random(0, 65535)):sub(1, 8) end
local function prune()
	local s = store()
	for id, m in pairs(s) do if M.Now() > m.at + M.KEEP then s[id] = nil; myJoins()[id] = nil; if ns.char.meetReminded then ns.char.meetReminded[id] = nil end end end
end
local function count(by)
	local n = 0
	for _, m in pairs(store()) do if not by or m.by == by then n = n + 1 end end
	return n
end
local function changed() ns.Fire("LM_MEETUPS_CHANGED") end

-- Soonest first; of one dungeon when given.
function M.List(dungeonId)
	prune()
	local out = {}
	for _, m in pairs(store()) do
		if (not dungeonId or m.d == dungeonId) and (m.sim or m.by == me() or R.IsGuildmate(m.by)) then out[#out + 1] = m end
	end
	table.sort(out, function(a, b) if a.at ~= b.at then return a.at < b.at end; return a.id < b.id end)
	return out
end

function M.When(m)
	local t = date("*t", m.at * 60)
	return string.format("%s %02d:%02d", L["DAY_" .. t.wday], t.hour, t.min)
end
function M.MyRole(id) return myJoins()[id] end

-- Called from a click (the meetup dialog). at: minutes since 1970.
function M.Create(d, at, note)
	if not D.Get(d) then return false end
	if not C.IsReady() then ns.Say(L.HELP_NEEDS_SHARE); return false end
	if type(at) ~= "number" or at < M.Now() + 5 or at > M.Now() + 7 * 1440 then ns.Say(L.MEET_BAD_TIME); return false end
	prune()
	if count(me()) >= M.PER_PERSON or count() >= M.MAX then ns.Say(L.MEET_FULL); return false end
	local clean = strtrim(tostring(note or "")):gsub("[%c|]", "")
	clean = ns.CutUtf8(clean, 40)
	local m = { id = newId(), d = d, at = at, n = clean ~= "" and clean or nil, by = me(), joined = {} }
	if not C.Send("qd", { id = m.id, d = d, at = at, n = m.n }, "now") then ns.Say(L.MEET_NOT_NOW); return false end
	store()[m.id] = m
	changed()
	return true
end

function M.Cancel(id)
	local m = store()[id]
	if not m or m.by ~= me() then return false end
	if not C.Send("qdx", { id = id }, "now") then ns.Say(L.MEET_NOT_NOW); return false end   -- or guildmates would keep it
	store()[id] = nil
	changed()
	return true
end

function M.Join(id, role)
	local m = store()[id]
	if not m or m.by == me() or not ROLES[role] then return false end
	if not C.Send("qj", { id = id, r = role }, "now") then ns.Say(L.MEET_NOT_NOW); return false end
	myJoins()[id] = role
	m.joined = m.joined or {}
	m.joined[me()] = role
	changed()
	return true
end

function M.Leave(id)
	if not myJoins()[id] then return false end
	if not C.Send("qjx", { id = id }, "now") then ns.Say(L.MEET_NOT_NOW); return false end
	myJoins()[id] = nil
	local m = store()[id]
	if m and m.joined then m.joined[me()] = nil end
	changed()
	return true
end

C.OnMessage("qd", function(f, name)
	if not R.mates[name] or not D.Get(f.d) then return end
	if f.at < M.Now() - M.KEEP or f.at > M.Now() + 8 * 1440 then return end
	local s = store()
	local m = s[f.id]
	if m and m.by ~= name then return end   -- an id belongs to whoever made it
	if not m then
		prune()
		if count(name) >= M.PER_PERSON or count() >= M.MAX then return end
		m = { id = f.id, by = name, joined = {} }
		s[f.id] = m
		if ns.db.settings.lfgNotices then ns.Notice(L.MEET_NEW, name, D.Name(f.d), M.When({ at = f.at })) end
	end
	m.d, m.at, m.n = f.d, f.at, f.n
	changed()
end)

C.OnMessage("qdx", function(f, name)
	local m = store()[f.id]
	if m and m.by == name then store()[f.id] = nil; myJoins()[f.id] = nil; changed() end
end)

C.OnMessage("qj", function(f, name)
	if not R.mates[name] then return end
	local m = store()[f.id]
	if not m or m.by == name then return end
	m.joined = m.joined or {}
	local new = m.joined[name] == nil
	m.joined[name] = f.r
	if new and m.by == me() then ns.Notice(L.MEET_JOINED, name, D.Name(m.d), M.When(m), L["ROLE_" .. f.r]) end
	changed()
end)

C.OnMessage("qjx", function(f, name)
	local m = store()[f.id]
	if m and m.joined and m.joined[name] then m.joined[name] = nil; changed() end
end)

-- A newcomer gets my meetups and my joins.
ns.On("LM_PING_ANSWERED", function()
	for _, m in ipairs(M.List()) do
		if m.by == me() and not m.sim then C.Send("qd", { id = m.id, d = m.d, at = m.at, n = m.n }) end
	end
	for id, role in pairs(myJoins()) do if store()[id] then C.Send("qj", { id = id, r = role }) end end
end)

-- The reminder: 15 minutes before, once, for mine and the ones I joined.
-- Kept with the character, so a /reload inside the window does not repeat it.
function M.Tick()
	ns.char.meetReminded = ns.char.meetReminded or {}
	local reminded = ns.char.meetReminded
	for _, m in ipairs(M.List()) do
		local left = m.at - M.Now()
		if not reminded[m.id] and left >= 0 and left <= M.REMIND and (m.by == me() or myJoins()[m.id]) then
			reminded[m.id] = true
			ns.Notice(L.MEET_SOON, D.Name(m.d), M.When(m))
		end
	end
end
ns.On("LM_WORLD", function() if not M.ticker then M.ticker = C_Timer.NewTicker(30, M.Tick) end end)

-- Simulation support (/lm sim quedada): local samples, never sent.
function M.AddSample(by, d, minutesFromNow, joined)
	local id = "sim" .. by:sub(1, 3):lower() .. d
	store()[id] = { id = id, by = by, d = d, at = M.Now() + minutesFromNow, joined = joined or {}, sim = true }
	changed()
end
function M.RemoveSamples()
	local s = store()
	for id, m in pairs(s) do if m.sim then s[id] = nil end end
	changed()
end
