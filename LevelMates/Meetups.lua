-- Meetups.lua: dungeon runs ("Deadmines, Saturday 21:00"), made from a dungeon card, with five slots (1 tank, 1 healer,
-- 3 damage): the leader holds one, others join a free role, and the leader's line-up (qm) is the truth; reminded 15
-- minutes before. Spec 2026-10-12-levelmates-runs-discord-design (1). Records on the sync layer (kept and handed over by everyone, so a late login sees a
-- meetup even when its maker is offline): qd = a meetup (id = its id), qj = a join (id = meetupId.joinerKey).
-- Specs 2026-10-10-levelmates-social-leveling-design (A3) and 2026-10-12-levelmates-sync-v2-design.
local _, ns = ...
local M = {}
ns.Meetups = M
local L, C, R, D, S, A = ns.L, ns.Comm, ns.Roster, ns.Dungeons, ns.Sync, ns.Activities
M.MAX, M.PER_PERSON, M.KEEP, M.REMIND = 10, 2, 180, 15   -- at once, per creator, minutes kept after the hour, reminder
local ROLES = { T = true, H = true, D = true, A = true }
local LIFE = 8 * 86400

local function me() return ns.Me() end
function M.Now() return math.floor(time() / 60) end   -- minutes since 1970
local function newId() return string.format("%04x%04x", math.random(0, 65535), math.random(0, 65535)):sub(1, 8) end
-- A joiner's part of a join id: a key of the whole name (names can hold spaces and accents; ids cannot).
local function key(name) return ns.NameKey(name) end
local function joinId(id, name) return id .. "." .. key(name) end
local function changed() ns.Fire("LM_MEETUPS_CHANGED") end

S.Define("qd", { class = "board", life = LIFE, lane = "urgent", max = M.MAX + 10,
	fields = { d = C.V.int(1, 399), at = C.V.int(0, 100000000), n = C.V.text(40), r = C.V.oneOf("T", "H", "D", "A"), dc = C.V.int(0, 1),
		x = C.V.int(2, 40), c = C.V.caps, t = C.V.text(60) },
	required = { "d", "at" },
	onChange = function(rec, old, how)
		if how == "live" and not old and not rec.dead and ns.db.settings.lfgNotices and (A.Get(rec.d.d) or rec.d.t) then
			ns.NoticeAt("lfg", L.MEET_NEW, rec.o, A.Name(rec.d.d, rec.d.t), M.When({ at = rec.d.at }))
		end
		changed()
	end })
local place   -- the leader's placement (below)
S.Define("qj", { class = "board", life = LIFE, lane = "urgent", relayMax = (M.MAX + 10) * 40,   -- a late login gets every join of a raid
	idOwner = function(id, owner) return id:match("%.([^%.]+)$") == key(owner) end,   -- only my own join
	fields = { r = C.V.oneOf("T", "H", "D", "A") }, required = { "r" },
	onChange = function(rec, old, how)
		local mid = rec.id:match("^([^%.]+)%.")
		local m = S.Get("qd", mid)
		if how == "live" and not old and not rec.dead and m and m.o == me() then
			ns.NoticeAt("lfg", L.MEET_JOINED, rec.o, A.Name(m.d.d, m.d.t), M.When(m.d), L["ROLE_" .. rec.d.r])
		end
		if m and m.o == me() and how ~= "expired" then place(mid) end
		changed()
	end })
-- The leader's line-up: "T=Name,H=Name,D=Name,…", only from the run's leader.
S.Define("qm", { class = "board", life = LIFE, lane = "urgent", fields = { m = C.V.text(200) }, required = { "m" },
	idOwner = function(id, owner) local r = S.Get("qd", id); return r ~= nil and r.o == owner end,
	onChange = function() changed() end })

-- A run as the rest of the addon knows it: { id, d, t, at, n, by, role (the leader's), size, caps, dc, joined, sim }.
local function view(rec)
	local t = rec.d.t and A.CleanName(rec.d.t) or nil
	local size = A.SizeOf(rec.d.d, rec.d.x)
	local caps = A.Caps(rec.d.d, size, rec.d.c)
	local role = rec.d.r
	if not caps[role or ""] then role = caps.A and "A" or ns.Roles.Of(rec.o) end
	local m = { id = rec.id, d = rec.d.d, t = t ~= "" and t or nil, at = rec.d.at, n = rec.d.n, by = rec.o, joined = {}, sim = rec.d.sim,
		role = role, size = size, caps = caps, dc = rec.d.dc == 1 }
	local prefix = rec.id .. "."
	for _, j in ipairs(S.List("qj", function(r) return r.id:sub(1, #prefix) == prefix end)) do m.joined[j.o] = j.d.r end
	for name, role in pairs(rec.d.sj or {}) do m.joined[name] = role end   -- a sample's joiners
	return m
end
local function live(rec) return M.Now() <= rec.d.at + M.KEEP and (A.Get(rec.d.d) ~= nil or (rec.d.t ~= nil and rec.d.t ~= "")) end

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
	for _, m in ipairs(M.List()) do if not m.sim and (not by or m.by == by) then n = n + 1 end end   -- /lm sim samples never count
	return n
end

------------------------------------------------------------------ slots
M.CAP = { T = 1, H = 1, D = 3 }
local ORDER = { "T", "H", "D" }
local function parse(text)
	local out = { T = {}, H = {}, D = {}, A = {} }
	for role, name in tostring(text):gmatch("([THDA])=([^,]+)") do table.insert(out[role], name) end
	return out
end
local function encode(slots)
	local parts = {}
	for _, role in ipairs({ "T", "H", "D", "A" }) do for _, name in ipairs(slots[role] or {}) do parts[#parts + 1] = role .. "=" .. name end end
	return table.concat(parts, ",")
end
-- The leader keeps a line-up only for small groups (it travels in one message); bigger ones place by order of joining.
local LINEUP_MAX = 5
local function joinsOf(id)   -- { { name, role } } in the order they came
	local prefix, out = id .. ".", {}
	for _, j in ipairs(S.List("qj", function(r) return r.id:sub(1, #prefix) == prefix end)) do out[#out + 1] = { j.o, j.d.r } end
	return out
end
local function has(slots, name) for _, role in ipairs({ "T", "H", "D", "A" }) do for _, n in ipairs(slots[role] or {}) do if n == name then return role end end end end
local function capsOf(m) return m.caps or A.Caps(m.d, m.size) end
-- Who is in which slot: the leader's line-up when there is one (confirmed, small groups), else the leader and the
-- joins in the order they came while their role has room (not confirmed yet). waiting: joins without a place.
function M.Slots(m)
	local caps = capsOf(m)
	local qm = (m.size or 5) <= LINEUP_MAX and S.Get("qm", m.id)
	local slots, confirmed
	if qm and qm.o == m.by then
		local listed = parse(qm.d.m)
		slots, confirmed = {}, true
		for role, cap in pairs(caps) do
			slots[role] = {}
			for _, name in ipairs(listed[role] or {}) do if #slots[role] < cap and not has(slots, name) then table.insert(slots[role], name) end end
		end
		local waiting = {}
		for _, j in ipairs(joinsOf(m.id)) do if not has(slots, j[1]) then waiting[#waiting + 1] = j[1] end end
		slots.waiting = waiting
	else
		local joins = joinsOf(m.id)
		if m.sim then
			local names = {}
			for name in pairs(m.joined or {}) do names[#names + 1] = name end
			table.sort(names)
			for _, name in ipairs(names) do joins[#joins + 1] = { name, m.joined[name] } end   -- samples' joiners
		end
		slots, confirmed = A.Place(caps, m.by, m.role, joins), false
	end
	for role in pairs(caps) do slots[role] = slots[role] or {} end
	for _, role in ipairs({ "T", "H", "D", "A" }) do slots[role] = slots[role] or {} end   -- every role reads as a list
	slots.confirmed = confirmed
	return slots
end
function M.Free(m, role) local caps = capsOf(m); return caps[role] ~= nil and #M.Slots(m)[role] < caps[role] end
function M.Count(m) return A.Count(M.Slots(m), capsOf(m)) end
function M.IsFull(m) return M.Count(m) >= (m.size or 5) end

-- The leader's side: people added by hand and people removed, kept with the character.
local function hand(id) ns.char.runHand = ns.char.runHand or {}; ns.char.runHand[id] = ns.char.runHand[id] or {}; return ns.char.runHand[id] end
local function kicked(id) ns.char.runKicked = ns.char.runKicked or {}; ns.char.runKicked[id] = ns.char.runKicked[id] or {}; return ns.char.runKicked[id] end
-- Recompute my run's line-up from what I know and publish it when it changed: members whose join still stands (or
-- added by hand) stay, new joins come in order while their role has room.
place = function(id)
	local rec = S.Get("qd", id)
	if not rec or rec.o ~= me() then return end
	local qm = S.Get("qm", id)
	local before = qm and qm.d.m or ""
	local m = view(rec)
	if m.size > LINEUP_MAX then return true end   -- big groups place by order of joining: no line-up to keep
	local caps = m.caps
	local current = qm and parse(qm.d.m) or { T = {}, H = {}, D = {}, A = {} }
	local joined = {}
	for _, j in ipairs(joinsOf(id)) do joined[j[1]] = j[2] end
	local slots = {}
	for role in pairs(caps) do slots[role] = {} end
	table.insert(slots[m.role], me())
	local function room(role) return caps[role] and #slots[role] < caps[role] end
	for _, role in ipairs({ "T", "H", "D", "A" }) do
		for _, name in ipairs(current[role] or {}) do
			if name ~= me() and not kicked(id)[name] and (joined[name] == role or hand(id)[name] == role) and room(role) then
				table.insert(slots[role], name)
			end
		end
	end
	for name, role in pairs(hand(id)) do if not has(slots, name) and room(role) then table.insert(slots[role], name) end end
	for _, j in ipairs(joinsOf(id)) do
		local name, role = j[1], j[2]
		if not has(slots, name) and not kicked(id)[name] and room(role) then table.insert(slots[role], name) end
	end
	local text = encode(slots)
	if #text > 200 then ns.Say(L.RUN_TOO_LONG); return false end   -- five long names: the line-up cannot travel
	if text ~= before then S.Put("qm", id, { m = text, _exp = rec.e }) end
	return true
end
M.Place = function(id) return place(id) end

-- Called from clicks (the dungeon panel): the leader adds someone to a free role, or takes someone out.
function M.AddMember(id, name, role)
	local rec = S.Get("qd", id)
	if not rec or rec.o ~= me() or name == me() then return false end
	local m = view(rec)
	if not m.caps[role] then return false end
	if has(M.Slots(m), name) or not M.Free(m, role) then return false end
	kicked(id)[name] = nil
	hand(id)[name] = role
	if not place(id) then hand(id)[name] = nil; return false end
	ns.Discord.Run("add", view(rec), name, role)
	return true
end
function M.RemoveMember(id, name)
	local rec = S.Get("qd", id)
	if not rec or rec.o ~= me() or name == me() then return false end
	hand(id)[name] = nil
	kicked(id)[name] = true
	place(id)
	ns.Discord.Run("remove", view(rec), name)
	return true
end

function M.When(m)
	local t = date("*t", m.at * 60)
	return string.format("%s %02d:%02d", L["DAY_" .. t.wday], t.hour, t.min)
end
function M.MyRole(id)   -- a join counts while its meetup does
	local j = S.Get("qd", id) and S.Get("qj", joinId(id, me()))
	return j and j.d.r
end

-- Called from a click (the form or the meetup dialog). spec: { d, at (minutes since 1970), x, c, t, role, note,
-- discord }. The old (d, at, note, role, discord) still works.
function M.Create(spec, at, note, role, discord)
	if type(spec) ~= "table" then spec = { d = spec, at = at, note = note, role = role, discord = discord } end
	local d, a = spec.d, A.Get(spec.d)
	at, note, role, discord = spec.at, spec.note, spec.role, spec.discord
	if not a then return false end
	local t = a.free and spec.t and A.CleanName(spec.t) or nil
	if t == "" then t = nil end
	if not C.IsReady() then ns.Say(L.HELP_NEEDS_SHARE); return false end
	if type(at) ~= "number" or at < M.Now() + 5 or at > M.Now() + 7 * 1440 then ns.Say(L.MEET_BAD_TIME); return false end
	if count(me()) >= M.PER_PERSON or count() >= M.MAX then ns.Say(L.MEET_FULL); return false end
	local clean = strtrim(tostring(note or "")):gsub("[%c|]", "")
	clean = ns.CutUtf8(clean, 40)
	local size = A.SizeOf(d, spec.x)
	local caps = A.Caps(d, size, spec.c)
	role = caps[role or ""] and role or (caps.A and "A" or ns.Roles.Of(me()))
	local fields = { d = d, at = at, n = clean ~= "" and clean or nil, r = role, dc = discord and 1 or 0, t = t, _exp = (at + M.KEEP) * 60 }
	if size ~= a.size then fields.x = size end
	if a.kind == "r" and A.EncodeCaps(caps) ~= A.EncodeCaps(A.Caps(d, size)) then fields.c = A.EncodeCaps(caps) end
	local id = newId()
	if not S.Put("qd", id, fields) then return false end
	place(id)
	if discord then ns.Discord.Run("new", view(S.Get("qd", id))) end
	return true
end

function M.Cancel(id)
	local rec = S.Get("qd", id)
	if not rec or rec.o ~= me() then return false end
	local m = view(rec)
	if S.Get("qm", id) then S.Remove("qm", id) end
	if not S.Remove("qd", id) then return false end
	ns.Discord.Run("cancel", m)
	return true
end

function M.Join(id, role)
	local rec = S.Get("qd", id)
	if not rec or rec.o == me() or not ROLES[role] then return false end
	if not C.IsReady() then ns.Say(L.MEET_NOT_NOW); return false end
	local m = view(rec)
	if not m.caps[role] then return false end   -- a role this group has ("A" only where there are no roles)
	if not M.Free(m, role) and has(M.Slots(m), me()) ~= role then ns.Say(L.RUN_ROLE_FULL); return false end
	if not S.Put("qj", joinId(id, me()), { r = role, _exp = rec.e }) then return false end
	ns.Discord.Run("join", view(rec), me(), role)
	return true
end

function M.Leave(id)
	if not S.Get("qj", joinId(id, me())) then return false end
	if not S.Remove("qj", joinId(id, me())) then return false end
	local rec = S.Get("qd", id)
	if rec then ns.Discord.Run("leave", view(rec), me()) end
	return true
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
			ns.NoticeAt("lfg", L.MEET_SOON, A.Name(m.d, m.t), M.When(m))
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
