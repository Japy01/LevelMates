-- Meetups.lua: dungeon meetups ("Deadmines, Saturday 21:00"), made from a dungeon card, joined with a role and
-- reminded 15 minutes before. Records on the sync layer (kept and handed over by everyone, so a late login sees a
-- meetup even when its maker is offline): qd = a meetup (id = its id), qj = a join (id = meetupId.joinerKey).
-- Specs 2026-10-10-levelmates-social-leveling-design (A3) and 2026-10-12-levelmates-sync-v2-design.
local _, ns = ...
local M = {}
ns.Meetups = M
local L, C, R, D, S = ns.L, ns.Comm, ns.Roster, ns.Dungeons, ns.Sync
M.MAX, M.PER_PERSON, M.KEEP, M.REMIND = 10, 2, 180, 15   -- at once, per creator, minutes kept after the hour, reminder
local ROLES = { T = true, H = true, D = true }
local LIFE = 8 * 86400

local function me() return ns.Me() end
function M.Now() return math.floor(time() / 60) end   -- minutes since 1970
local function newId() return string.format("%04x%04x", math.random(0, 65535), math.random(0, 65535)):sub(1, 8) end
-- A joiner's part of a join id: a key of the whole name (names can hold spaces and accents; ids cannot).
local function key(name) return ns.NameKey(name) end
local function joinId(id, name) return id .. "." .. key(name) end
local function changed() ns.Fire("LM_MEETUPS_CHANGED") end

S.Define("qd", { class = "board", life = LIFE, lane = "urgent", max = M.MAX + 10,
	fields = { d = C.V.int(1, 99), at = C.V.int(0, 100000000), n = C.V.text(40) }, required = { "d", "at" },
	onChange = function(rec, old, how)
		if how == "live" and not old and not rec.dead and ns.db.settings.lfgNotices and D.Get(rec.d.d) then
			ns.Notice(L.MEET_NEW, rec.o, D.Name(rec.d.d), M.When({ at = rec.d.at }))
		end
		changed()
	end })
S.Define("qj", { class = "board", life = LIFE, lane = "urgent",
	idOwner = function(id, owner) return id:match("%.([^%.]+)$") == key(owner) end,   -- only my own join
	fields = { r = C.V.oneOf("T", "H", "D") }, required = { "r" },
	onChange = function(rec, old, how)
		local m = S.Get("qd", (rec.id:match("^([^%.]+)%.")))
		if how == "live" and not old and not rec.dead and m and m.o == me() then
			ns.Notice(L.MEET_JOINED, rec.o, D.Name(m.d.d), M.When(m.d), L["ROLE_" .. rec.d.r])
		end
		changed()
	end })

-- A meetup as the rest of the addon knows it: { id, d, at, n, by, joined = { [name] = role }, sim }.
local function view(rec)
	local m = { id = rec.id, d = rec.d.d, at = rec.d.at, n = rec.d.n, by = rec.o, joined = {}, sim = rec.d.sim }
	local prefix = rec.id .. "."
	for _, j in ipairs(S.List("qj", function(r) return r.id:sub(1, #prefix) == prefix end)) do m.joined[j.o] = j.d.r end
	for name, role in pairs(rec.d.sj or {}) do m.joined[name] = role end   -- a sample's joiners
	return m
end
local function live(rec) return M.Now() <= rec.d.at + M.KEEP and D.Get(rec.d.d) ~= nil end

-- Soonest first; of one dungeon when given.
function M.List(dungeonId)
	local out = {}
	for _, rec in ipairs(S.List("qd")) do
		if live(rec) and (not dungeonId or rec.d.d == dungeonId) then out[#out + 1] = view(rec) end
	end
	table.sort(out, function(a, b) if a.at ~= b.at then return a.at < b.at end; return a.id < b.id end)
	return out
end
local function count(by)
	local n = 0
	for _, m in ipairs(M.List()) do if not by or m.by == by then n = n + 1 end end
	return n
end

function M.When(m)
	local t = date("*t", m.at * 60)
	return string.format("%s %02d:%02d", L["DAY_" .. t.wday], t.hour, t.min)
end
function M.MyRole(id)   -- a join counts while its meetup does
	local j = S.Get("qd", id) and S.Get("qj", joinId(id, me()))
	return j and j.d.r
end

-- Called from a click (the meetup dialog). at: minutes since 1970.
function M.Create(d, at, note)
	if not D.Get(d) then return false end
	if not C.IsReady() then ns.Say(L.HELP_NEEDS_SHARE); return false end
	if type(at) ~= "number" or at < M.Now() + 5 or at > M.Now() + 7 * 1440 then ns.Say(L.MEET_BAD_TIME); return false end
	if count(me()) >= M.PER_PERSON or count() >= M.MAX then ns.Say(L.MEET_FULL); return false end
	local clean = strtrim(tostring(note or "")):gsub("[%c|]", "")
	clean = ns.CutUtf8(clean, 40)
	return S.Put("qd", newId(), { d = d, at = at, n = clean ~= "" and clean or nil, _exp = (at + M.KEEP) * 60 })
end

function M.Cancel(id)
	local rec = S.Get("qd", id)
	if not rec or rec.o ~= me() then return false end
	return S.Remove("qd", id)
end

function M.Join(id, role)
	local rec = S.Get("qd", id)
	if not rec or rec.o == me() or not ROLES[role] then return false end
	if not C.IsReady() then ns.Say(L.MEET_NOT_NOW); return false end
	return S.Put("qj", joinId(id, me()), { r = role, _exp = rec.e })
end

function M.Leave(id)
	if not S.Get("qj", joinId(id, me())) then return false end
	return S.Remove("qj", joinId(id, me()))
end

-- The reminder: 15 minutes before, once, for mine and the ones I joined.
-- Kept with the character, so a /reload inside the window does not repeat it.
function M.Tick()
	ns.char.meetReminded = ns.char.meetReminded or {}
	local reminded = ns.char.meetReminded
	for _, m in ipairs(M.List()) do
		local left = m.at - M.Now()
		if not reminded[m.id] and left >= 0 and left <= M.REMIND and (m.by == me() or M.MyRole(m.id)) then
			reminded[m.id] = true
			ns.Notice(L.MEET_SOON, D.Name(m.d), M.When(m))
		end
	end
end
ns.On("LM_WORLD", function() if not M.ticker then M.ticker = C_Timer.NewTicker(30, M.Tick) end end)

-- 0.3.x kept meetups per guild in ns.db.meetups and my joins in ns.char.meetJoins: into records, once.
ns.On("LM_WORLD", function()
	local g = GetGuildInfo("player")
	if not g or not ns.db.meetups or not ns.db.meetups[g] then return end
	local s = S.Store("qd")
	for id, m in pairs(ns.db.meetups[g]) do
		if type(m) == "table" and m.by and m.at and m.d and not m.sim and not s[id] then
			s[id] = { t = "qd", id = id, o = m.by, v = 1, e = (m.at + M.KEEP) * 60, d = { d = m.d, at = m.at, n = m.n } }
		end
	end
	local j = S.Store("qj")
	for id, role in pairs(ns.char.meetJoins or {}) do
		local jid = joinId(id, me())
		if s[id] and not j[jid] then j[jid] = { t = "qj", id = jid, o = me(), v = 1, e = s[id].e, d = { r = role }, pending = true } end
	end
	ns.db.meetups[g], ns.char.meetJoins = nil, nil
	changed()
end)

-- Simulation support (/lm sim quedada): local samples, never sent.
function M.AddSample(by, d, minutesFromNow, joined)
	local id = "sim" .. by:sub(1, 3):lower() .. d
	local at = M.Now() + minutesFromNow
	S.Store("qd")[id] = { t = "qd", id = id, o = by, v = GetServerTime(), e = (at + M.KEEP) * 60, d = { d = d, at = at, sim = true, sj = joined } }
	changed()
end
function M.RemoveSamples()
	local s = S.Store("qd")
	for id, r in pairs(s) do if r.d and r.d.sim then s[id] = nil end end
	changed()
end
