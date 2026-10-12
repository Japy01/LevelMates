-- Sync.lua: shared records. Each is { t = type, id, o = owner, v = rev (server time of the owner's change), e = expiry,
-- dead = tombstone, d = data, pending = not out yet }. Board types are kept by everyone and relayed to whoever logs in
-- later; personal types come only from their owner. A newer rev wins; a tombstone keeps a record from coming back
-- until it expires. Spec 2026-10-12-levelmates-sync-v2-design (3).
local _, ns = ...
local S = {}
ns.Sync = S
local C, R = ns.Comm, ns.Roster
local types = {}
S.FUTURE = 300
S.BATCH = 20     -- records a catch-up hands over per type   -- a rev further ahead than this is a broken clock, not news
local inQueue = setmetatable({}, { __mode = "k" })   -- records queued but not out yet (never saved)

local function now() return GetServerTime() end
local function me() return ns.Me() end
local function store(t)
	ns.db.sync = ns.db.sync or {}
	local g = GetGuildInfo("player") or "?"
	ns.db.sync[g] = ns.db.sync[g] or {}
	ns.db.sync[g][t] = ns.db.sync[g][t] or {}
	return ns.db.sync[g][t]
end
S.Store = store

local function fire(spec, rec, old, how) if spec.onChange then spec.onChange(rec, old, how) end end

-- On the wire a record is a message of its own type: its data fields plus id, o (only when the owner is not the
-- sender), v and e. A tombstone is kind "x" with the type in t.
local function wire(rec, target)
	local f = { id = rec.id, v = rec.v, e = rec.e }
	if rec.o ~= me() or target then f.o = rec.o end
	for k, v in pairs(rec.d or {}) do f[k] = v end
	return f
end
local function send(rec, target)
	local spec = types[rec.t]
	local mine = rec.o == me() and not target
	local opts = mine and { hold = true, onSent = function() inQueue[rec] = nil; rec.pending = nil end } or { hold = true }
	local ok
	if rec.dead then
		local f = { t = rec.t, id = rec.id, v = rec.v, e = rec.e }
		if rec.o ~= me() or target then f.o = rec.o end
		if target then ok = C.Whisper("x", f, target, "normal", opts) else ok = C.Send("x", f, spec.lane, opts) end
	else
		ok = C.SendBig(rec.t, wire(rec, target), target and "normal" or spec.lane, target, opts)   -- catch-up never ahead of help
	end
	if ok and mine then inQueue[rec] = true end
	return ok
end
S.Send = send

-- spec: { class = "board"|"personal", life = seconds, fields = { name = check }, required = { names },
--         lane = "urgent"|"normal", may = function(rec, who) -> may who change it (default: its owner),
--         max = live records kept, onChange = function(rec, old, how) how = "mine"|"live"|"catchup"|"expired",
--         relayKeep = function(rec) -> hand it to newcomers, relayMax = n newest at most,
--         idOwner = function(id, owner) -> may this owner hold this id (ids made from a name) }
function S.Define(t, spec)
	spec.class = spec.class or "board"
	spec.may = spec.may or function(rec, who) return rec.o == who end
	types[t] = spec
	local schema = { id = C.V.word(24), o = C.V.text(48), v = C.V.int(0, 4000000000), e = C.V.int(0, 4000000000) }
	for k, fn in pairs(spec.fields or {}) do schema[k] = fn end
	C.SCHEMA[t] = schema
	local req = { "id", "v", "e" }
	for _, k in ipairs(spec.required or {}) do req[#req + 1] = k end
	C.REQUIRED[t] = req
	C.OnMessage(t, function(f, name, _, channel) S.Receive(t, f, name, channel == "WHISPER") end)
end

-- Mine: stored at once, sent (held inside an instance), pending until it really went. data._exp: an earlier end
-- than the type's life (a meetup ends after its hour). data.sim: a /lm sim sample, never sent.
function S.Put(t, id, data, owner)
	local spec = types[t]
	local s = store(t)
	local old = s[id]
	if old and not old.dead and not spec.may(old, me()) then return false end
	local exp = math.min(now() + spec.life, data._exp or (now() + spec.life))
	data._exp = nil
	local rec = { t = t, id = id, o = owner or me(), v = math.max(now(), (old and old.v or 0) + 1), e = exp, d = data }
	if old and old.dead and old.o ~= rec.o and not spec.may(old, me()) then return false end
	s[id] = rec
	if not data.sim then rec.pending = true; send(rec) end
	fire(spec, rec, old, "mine")
	return true
end

function S.Remove(t, id)
	local spec = types[t]
	local s = store(t)
	local old = s[id]
	if not old or old.dead or not spec.may(old, me()) then return false end
	local rec = { t = t, id = id, o = old.o, v = math.max(now(), old.v + 1), e = old.e, dead = true }
	s[id] = rec
	if not (old.d and old.d.sim) then rec.pending = true; send(rec) end
	fire(spec, rec, old, "mine")
	return true
end

local function trusted(name) return R.IsGuildmate(name) or R.mates[name] ~= nil end

function S.Receive(t, f, sender, catchup)
	local spec = types[t]
	if not spec then return end
	local owner = f.o or sender
	if owner ~= sender and spec.class == "personal" then return end   -- personal state only from its owner
	if owner == me() then return end
	if not trusted(owner) or not trusted(sender) then return end
	if f.v > now() + S.FUTURE or f.e < now() then return end
	if spec.idOwner and not spec.idOwner(f.id, owner) then return end   -- an id made from someone else's name
	local s = store(t)
	local old = s[f.id]
	if old and old.o ~= owner and not spec.may(old, owner) then return end   -- an id belongs to its owner
	if old and old.v >= f.v then return end
	local d = {}
	for k, v in pairs(f) do if k ~= "id" and k ~= "o" and k ~= "v" and k ~= "e" then d[k] = v end end
	if spec.max and not (old and not old.dead) then
		local n = 0
		for _, r in pairs(s) do if not r.dead and r.e >= now() then n = n + 1 end end
		if n >= spec.max then return end
	end
	local rec = { t = t, id = f.id, o = old and old.o or owner, v = f.v, e = math.min(f.e, now() + spec.life + S.FUTURE), d = d }   -- never longer than the type lives
	s[f.id] = rec
	fire(spec, rec, old and not old.dead and old or nil, catchup and "catchup" or "live")
end

C.SCHEMA.x = { t = C.V.word(12), id = C.V.word(24), o = C.V.text(48), v = C.V.int(0, 4000000000), e = C.V.int(0, 4000000000) }
C.REQUIRED.x = { "t", "id", "v", "e" }
C.OnMessage("x", function(f, sender)
	local spec = types[f.t]
	if not spec then return end
	local owner = f.o or sender
	if owner ~= sender and spec.class == "personal" then return end
	if owner == me() or not trusted(owner) or not trusted(sender) then return end
	if f.v > now() + S.FUTURE or f.e < now() then return end
	if spec.idOwner and not spec.idOwner(f.id, owner) then return end
	local s = store(f.t)
	local old = s[f.id]
	if old and old.v >= f.v then return end
	if old and not spec.may(old, owner) then return end
	s[f.id] = { t = f.t, id = f.id, o = old and old.o or owner, v = f.v, e = math.min(f.e, now() + spec.life + S.FUTURE), dead = true }
	if old and not old.dead then fire(spec, s[f.id], old, "live") end
end)

-- Live records (no tombstones, not expired), oldest change first.
function S.Get(t, id)
	local r = store(t)[id]
	if r and not r.dead and r.e >= now() then return r end
end
function S.List(t, keep)
	local out = {}
	for _, r in pairs(store(t)) do if not r.dead and r.e >= now() and (not keep or keep(r)) then out[#out + 1] = r end end
	table.sort(out, function(a, b) if a.v ~= b.v then return a.v < b.v end; return a.id < b.id end)
	return out
end
-- What a catch-up hands on: live records and tombstones, no samples, what the type keeps for newcomers.
local function relayable(spec, r)
	return r.e >= now() and not (r.d and r.d.sim) and (r.dead or not spec.relayKeep or spec.relayKeep(r))
end
-- How many of those I hold, and a sum of their revs: two clients with the same digest (almost certainly) hold the
-- same, so nobody answers a newcomer who already has it all.
function S.Digest(t)
	local spec, n, sum = types[t], 0, 0
	for _, r in pairs(store(t)) do
		if relayable(spec, r) then n = n + 1; sum = (sum + r.v + (r.dead and 7 or 0)) % 2147483647 end
	end
	return n, sum
end
function S.Types(class)
	local out = {}
	for t, spec in pairs(types) do if not class or spec.class == class then out[#out + 1] = t end end
	table.sort(out)
	return out
end
function S.Spec(t) return types[t] end

------------------------------------------------------------------ catch-up
-- At login I say hello with a digest of every board type. Whoever holds something different waits 1-6 s; the first
-- to finish claims the answer on GUILD (hc) and whispers me that type's records and tombstones, oldest first; the
-- others hear the claim and stay quiet. If nothing of a claimed type reached me, I ask the claimer once (hw).
S.stats = { answered = 0 }
C.SCHEMA.hc = { to = C.V.text(48), t = C.V.word(12) }; C.REQUIRED.hc = { "to", "t" }
C.SCHEMA.hw = { t = C.V.word(12) }; C.REQUIRED.hw = { "t" }
local function digestString()
	local parts = {}
	for _, t in ipairs(S.Types("board")) do local n, sum = S.Digest(t); parts[#parts + 1] = t .. ":" .. n .. ":" .. sum end
	local s = table.concat(parts, ",")
	return #s <= 200 and s or ""
end
function S.Hello() return C.Send("hi", { s = digestString() }, "urgent") end

local claimed = {}   -- [requester .. ":" .. type] = when someone claimed answering it
local function batch(t, to)
	local spec = types[t]
	local list = {}
	for _, r in pairs(store(t)) do
		if relayable(spec, r) and r.o ~= to then list[#list + 1] = r end   -- not what the asker made: they have it
	end
	table.sort(list, function(a, b) if a.v ~= b.v then return a.v < b.v end; return a.id < b.id end)
	local first = math.max(1, #list - (spec.relayMax or S.BATCH) + 1)   -- the newest, oldest first
	for i = first, #list do send(list[i], to) end
end
-- Two of us may claim in the same instant: the claimer waits 1.5 s and, if someone else claimed meanwhile, only the
-- one whose name sorts first sends.
local rivals = {}   -- [key] = the lowest other name that claimed it while mine was pending
local function answer(t, to)
	if IsInInstance and IsInInstance() then return end   -- my claim could not go out there: others answer
	local key = to .. ":" .. t
	if claimed[key] and GetTime() - claimed[key] < 30 then return end
	claimed[key] = GetTime()
	rivals[key] = nil
	C.Send("hc", { to = to, t = t }, "urgent")
	C_Timer.After(1.5, function()
		local rival = rivals[key]
		rivals[key] = nil
		if rival and rival < me() then return end
		S.stats.answered = S.stats.answered + 1
		batch(t, to)
	end)
end
C.OnMessage("hi", function(f, name)
	local theirs = {}
	for part in f.s:gmatch("[^,]+") do
		local t, n, sum = part:match("^([%w_]+):(%d+):(%d+)$")
		if t then theirs[t] = n .. ":" .. sum end
	end
	local differ = {}
	for _, t in ipairs(S.Types("board")) do
		local n, sum = S.Digest(t)
		if n > 0 and theirs[t] ~= n .. ":" .. sum then differ[#differ + 1] = t end
	end
	if #differ == 0 then return end
	-- one wait for the whole hello, then the types in name order (a run's line-up never before the run)
	C_Timer.After(1 + math.random() * 5, function() for _, t in ipairs(differ) do answer(t, name) end end)
end)
local asked = {}
C.OnMessage("hc", function(f, name)
	local key = f.to .. ":" .. f.t
	if claimed[key] and GetTime() - claimed[key] < 2 then   -- I claimed it too, just now: the lower name sends
		if not rivals[key] or name < rivals[key] then rivals[key] = name end
	end
	claimed[key] = GetTime()
	if f.to ~= me() or asked[f.t] then return end
	-- my answer is coming by whisper; if none of it arrived in 12 s, ask the claimer once more
	local n0 = S.Digest(f.t)
	C_Timer.After(12, function()
		if S.Digest(f.t) == n0 and not asked[f.t] then asked[f.t] = true; C.Whisper("hw", { t = f.t }, name, "urgent") end
	end)
end)
C.OnMessage("hw", function(f, name) if types[f.t] and types[f.t].class == "board" then batch(f.t, name) end end)

-- Expired records and tombstones go once a minute (never while a list is being read).
ns.Every("sync-prune", 60, function()
	for t, spec in pairs(types) do
		local s = store(t)
		for id, r in pairs(s) do
			if r.e < now() then s[id] = nil; if not r.dead then fire(spec, r, r, "expired") end end
		end
	end
end)
-- The queue dropped something (held too long, over its cap) or stopped: whatever of mine was waiting there is not
-- queued any more; still pending, it goes with the next heartbeat.
ns.On("LM_COMM_DROPPED", function() for r in pairs(inQueue) do inQueue[r] = nil end end)
ns.On("LM_COMM_STOPPED", function() for r in pairs(inQueue) do inQueue[r] = nil end end)
-- What did not go out (not ready, or lost with a /reload while held) goes with the next heartbeat.
ns.On("LM_HB_SENT", function()
	for t in pairs(types) do
		for _, r in pairs(store(t)) do
			if r.pending and r.o == me() and not inQueue[r] then send(r) end
		end
	end
end)

------------------------------------------------------------------ personal state
-- My whole-state messages (my partner flag, my wishes, my build…): sent on change, kept pending while they cannot
-- go (not ready, refused inside an instance, dropped from the queue) and sent with the next heartbeat, and resent
-- to newcomers once per burst of hellos. One helper for what each module used to copy.
-- build() returns the fields (or a list of field tables, or nil for "nothing to send"); opts.enabled() gates it;
-- opts.save names a flag in the character's saved data that keeps a pending state across a /reload; opts.worth()
-- says whether there is anything to tell newcomers and announces (an empty list is not resent).
function S.Personal(kind, build, opts)
	opts = opts or {}
	local P = {}
	local function setPending(v)
		P.pending = v
		if opts.save and ns.char then ns.char[opts.save] = v or nil end
	end
	local function isPending() return P.pending or (opts.save and ns.char and ns.char[opts.save]) or false end
	local function enabled() return not opts.enabled or opts.enabled() end
	local lastSent = -math.huge   -- when it last went out (big states skip hellos for a while)
	local function go(prio)
		if not enabled() then setPending(false); return false end
		local fields = build()
		if not fields then setPending(false); return true end
		local list = fields[1] and fields or { fields }
		local ok = C.IsReady()
		for _, f in ipairs(list) do ok = ok and C.SendBig(kind, f, prio) end
		setPending(not ok)
		if ok then lastSent = GetTime() end
		return ok
	end
	local function worth() return not opts.worth or opts.worth() end
	P.Mark = go
	P.IsPending = isPending
	ns.On("LM_HB_SENT", function() if isPending() then go() end end)
	ns.On("LM_COMM_DROPPED", function(k) if k == kind then setPending(true) end end)
	ns.On("LM_ANNOUNCED", function() if isPending() or worth() then go() end end)
	ns.On("LM_HELLO_ANSWERED", function()   -- the roster already jitters and coalesces hellos
		if not worth() then return end
		if opts.helloGap and GetTime() - lastSent < opts.helloGap then return end   -- big states: not for every login
		go()
	end)
	return P
end
