-- Comm.lua: wire format and (Task 2) transport. Format: "v1<US>kind<US>k=v;k=v", US = \031.
local _, ns = ...
local C = {}
ns.Comm = C
C.VERSION = "v1"
C.PREFIX = "LVLM"
C.MAX_BYTES = 255
local US = "\031"

local function esc(s)
	return (tostring(s):gsub("[%%;=%c]", function(ch) return string.format("%%%02X", ch:byte()) end))
end
local function unesc(s)
	return (s:gsub("%%(%x%x)", function(h) return string.char(tonumber(h, 16)) end))
end

local NUMERIC = {} -- set of numeric validators, so Decode coerces by schema type
local CANON = "^%-?%d+%.?%d*$"
local function canon(v)
	if type(v) == "string" and not v:match(CANON) then return nil end
	return tonumber(v)
end
local function num(min, max)
	local f = function(v) v = canon(v); return v ~= nil and v >= min and v <= max end
	NUMERIC[f] = true
	return f
end
local function int(min, max)
	local f = function(v) v = canon(v); return v ~= nil and v == math.floor(v) and v >= min and v <= max end
	NUMERIC[f] = true
	return f
end
local function text(max) return function(v) return type(v) == "string" and #v >= 1 and #v <= max and not v:find("[%c|]") end end
local function word(max) return function(v) return type(v) == "string" and v:match("^[%w_%.%-]+$") ~= nil and #v <= max end end
local function idlist(max) return function(v) if type(v) == "number" then v = tostring(v) end; return type(v) == "string" and #v <= max and v:match("^%d+[,%d]*$") ~= nil end end
local function chunkIndex(max) return function(v) return type(v) == "string" and #v <= max and v:match("^%d+/%d+$") ~= nil end end   -- "index/total"

-- roles: any non-empty subset of T (tank), H (healer), D (damage), each at most once
local function roles(v)
	if type(v) ~= "string" or #v < 1 or #v > 3 or not v:match("^[THD]+$") then return false end
	local seen = {}
	for ch in v:gmatch(".") do if seen[ch] then return false end; seen[ch] = true end
	return true
end

-- one of a closed set of words
local function oneOf(...)
	local set = {}
	for _, w in ipairs({ ... }) do set[w] = true end
	return function(v) return type(v) == "string" and set[v] == true end
end
-- Item ids "12,345,…": 1 to max ids, each 1-999999.
local function itemids(max)
	return function(v)
		if type(v) == "number" then v = tostring(v) end
		if type(v) ~= "string" or not v:match("^%d+$") and not v:match("^%d+[%d,]*%d$") or v:find(",,", 1, true) then return false end
		local n = 0
		for id in v:gmatch("%d+") do
			n = n + 1
			local x = tonumber(id)
			if x < 1 or x > 999999 then return false end
		end
		return n >= 1 and n <= max
	end
end
-- Professions "171:120:150,182:95": 1-6 entries of skill id (1-999), rank (1-450) and optionally the max rank (1-450).
local function profs(v)
	if type(v) ~= "string" or v == "" or v:find(",,", 1, true) or v:sub(-1) == "," then return false end
	local n = 0
	for pair in v:gmatch("[^,]+") do
		local id, rank, max = pair:match("^(%d+):(%d+):?(%d*)$")
		if not id then return false end
		id, rank, max = tonumber(id), tonumber(rank), tonumber(max)
		if id < 1 or id > 999 or rank < 1 or rank > 450 or (max and (max < 1 or max > 450)) then return false end
		n = n + 1
	end
	return n <= 6
end

-- Talent points per branch "1001:9,1002:0": 1-8 group:points pairs.
local function branchPoints(v)
	if type(v) ~= "string" or v == "" or #v > 80 then return false end
	local n = 0
	for pair in (v .. ","):gmatch("([^,]*),") do
		if not pair:match("^%d+:%d+$") then return false end
		n = n + 1
	end
	return n <= 8
end
-- A talent build code as the game exports it (base64 letters).
local function buildCode(v) return type(v) == "string" and #v >= 1 and #v <= 150 and v:match("^[%w%+/=]+$") ~= nil end

-- A macro body: up to 255 characters, lines allowed, no other control characters and no "|" codes.
local function macroBody(v) return type(v) == "string" and #v >= 1 and #v <= 255 and not v:find("|", 1, true) and not v:gsub("\n", ""):find("%c") end

-- Priced offers "2589:15000,765:1": 1-10 entries of item id (1-999999) and price in copper (1-99999999).
local function saleList(v)
	if type(v) ~= "string" or v == "" or v:find(",,", 1, true) or v:sub(-1) == "," then return false end
	local n = 0
	for pair in v:gmatch("[^,]+") do
		local id, price = pair:match("^(%d+):(%d+)$")
		if not id then return false end
		id, price = tonumber(id), tonumber(price)
		if id < 1 or id > 999999 or price < 1 or price > 99999999 then return false end
		n = n + 1
	end
	return n <= 10
end

-- Quest objectives "6/10,1/1": up to 60 characters of have/need pairs.
local function objectives(v) return type(v) == "string" and #v <= 60 and v:match("^%d+/%d+[%d/,]*$") ~= nil and not v:find(",,", 1, true) and v:sub(-1) ~= "," end

-- field validators; required fields are listed in REQUIRED
C.SCHEMA = {
	hb   = { l = int(1, 100), z = int(0, 100000), g = int(0, 1), s = int(0, 1), x = num(0, 100), y = num(0, 100), r = int(0, 999999), c = word(16), v = word(20) },
	q    = { i = chunkIndex(7), ids = idlist(240) },
	help = { t = text(60), z = int(0, 100000), x = num(0, 100), y = num(0, 100), id = word(8) },
	helpok = { id = word(8) },
	helpgo = { id = word(8) },
	lfg  = { d = int(1, 99), r = roles, n = text(40), id = word(8), m = int(1, 20) },
	lfgx = { id = word(8) },
	pal  = { p = int(0, 1) },
	rx   = { p = int(-1, 200) },
	go   = { id = word(8), ty = oneOf("lvl", "dun", "cnt"), a = int(1, 100000), w = oneOf("lvl", "qst", "dun"), s = int(0, 100000), e = int(0, 100000) },
	gx   = { id = word(8) },
	gd   = { id = word(8) },
	gc   = { id = word(8), n = int(0, 10000) },
	gp   = { l = int(0, 60), e = int(0, 100000) },
	wl   = { ids = itemids(10) },
	pf   = { p = profs },
	lfj  = { id = word(8), r = oneOf("T", "H", "D") },
	lfjx = { id = word(8) },
	qd   = { id = word(8), d = int(1, 99), at = int(0, 100000000), n = text(40) },
	qdx  = { id = word(8) },
	qj   = { id = word(8), r = oneOf("T", "H", "D") },
	qjx  = { id = word(8) },
	rt   = { i = int(1, 3), x = text(200), v = int(0, 4000000000) },
	rc   = { t = int(0, 4000000000) },
	gv   = { ids = itemids(10) },
	gr   = { i = int(1, 999999), to = text(24) },
	gro  = { i = int(1, 999999), by = text(24) },
	qo   = { i = int(1, 999999), o = objectives },
	rr   = { n = text(40), z = int(1, 100000), x = num(0, 100), y = num(0, 100) },
	fe   = { k = oneOf("lvl", "dun", "itm", "pgl", "dth", "ach"), a = int(0, 999999), b = text(60), t = int(0, 100000000) },
	tb   = { c = word(16), s = int(0, 100000), l = int(1, 100), p = branchPoints, b = buildCode },
	mc   = { n = text(16), x = macroBody },
	mcx  = { n = text(16) },
	xp   = { p = int(0, 100), l = int(1, 100) },
	ask  = { id = word(8), x = text(120) },
	al   = { n = text(120) },
	sl   = { p = saleList },
	pt   = { t = int(0, 100000000), w = int(0, 100000), l = int(0, 100000), d = int(0, 100000), h = int(0, 100000), q = int(0, 100000) },
	ac   = { ids = idlist(120) },
	bye  = {},
	ping = {},
}
local REQUIRED = { hb = { "l", "z" }, q = { "i", "ids" }, help = { "t", "z", "x", "y", "id" }, helpok = { "id" }, helpgo = { "id" }, lfg = { "d", "r", "id", "m" }, lfgx = { "id" }, pal = { "p" }, rx = { "p" }, go = { "id", "ty", "a", "s", "e" }, gx = { "id" }, gd = { "id" }, gc = { "id", "n" }, gp = { "l", "e" }, wl = {}, pf = {}, lfj = { "id", "r" }, lfjx = { "id" }, fe = { "k", "a", "t" }, rr = { "n", "z", "x", "y" }, qo = { "i", "o" }, gv = {}, gr = { "i", "to" }, rt = { "i", "v" }, rc = { "t" }, gro = { "i", "by" }, qd = { "id", "d", "at" }, qdx = { "id" }, qj = { "id", "r" }, qjx = { "id" }, tb = {}, mc = { "n", "x" }, mcx = { "n" }, xp = { "p", "l" }, ask = { "id", "x" }, al = {}, sl = {}, pt = {}, ac = {}, bye = {}, ping = {} }

function C.Validate(kind, fields)
	local schema = C.SCHEMA[kind]
	if not schema or type(fields) ~= "table" then return false, "kind" end
	for _, k in ipairs(REQUIRED[kind]) do if fields[k] == nil then return false, "missing " .. k end end
	for k, v in pairs(fields) do
		local check = schema[k]
		if not check then return false, "unknown " .. k end
		if not check(v) then return false, "bad " .. k end
	end
	return true
end

function C.Encode(kind, fields)
	local ok, why = C.Validate(kind, fields)
	if not ok then return nil, why end
	local parts, keys = {}, {}
	for k in pairs(fields) do keys[#keys + 1] = k end
	table.sort(keys)
	for _, k in ipairs(keys) do parts[#parts + 1] = k .. "=" .. esc(fields[k]) end
	local s = C.VERSION .. US .. kind .. US .. table.concat(parts, ";")
	if #s > C.MAX_BYTES then return nil, "too long" end
	return s
end

function C.Decode(s)
	if type(s) ~= "string" or #s > C.MAX_BYTES then return nil, "size" end
	local ver, kind, body = s:match("^([^\31]+)\31([^\31]+)\31(.*)$")
	if ver ~= C.VERSION then return nil, "version" end
	if body:find("%c") then return nil, "control" end
	local fields = {}
	if body ~= "" then
		for pair in (body .. ";"):gmatch("([^;]*);") do
			local k, v = pair:match("^([%w_]+)=(.*)$")
			if not k then return nil, "pair" end
			fields[k] = unesc(v)
		end
	end
	local schema = C.SCHEMA[kind]
	if schema then
		for k, v in pairs(fields) do
			if NUMERIC[schema[k]] and v:match(CANON) then fields[k] = tonumber(v) end
		end
	end
	local ok, why = C.Validate(kind, fields)
	if not ok then return nil, why end
	return kind, fields
end

------------------------------------------------------------------ transport
local handlers = {}
C.stats = { sent = 0, received = 0, bad = 0, queued = 0, lockdownSkips = 0, retries = 0 }
local queue = {}            -- { text, kind, prio }
local allowance, lastTick = 10, 0   -- per-prefix: 10 burst, +1/s
local active = "none"
local channelId
local ticker

local function channelName()
	local g = GetGuildInfo("player")
	if not g then return nil end
	local h = 5381
	for i = 1, #g do h = (h * 33 + g:byte(i)) % 4294967296 end
	return "LM" .. string.format("%04x%04x", math.floor(h / 65536), h % 65536)   -- two halves: safe on 5.1 doubles and 32-bit ints
end

local function pickTransport()
	local want = ns.db.settings.transport
	if want == "channel" then return "channel" end
	return "guild"   -- "guild" and "auto" start on GUILD; auto falls back on a failed send
end

local lastJoin = -math.huge
local function ensureChannel()
	local name = channelName()
	if not name then return nil end
	local id = GetChannelName(name)
	if (not id or id == 0) and GetTime() - lastJoin >= 5 then   -- joining is a server round-trip: ask, then poll on later pumps
		JoinTemporaryChannel(name); lastJoin = GetTime(); id = GetChannelName(name)
	end
	channelId = (id and id > 0) and id or nil
	return channelId
end

local function rawSend(text)
	if active == "channel" then
		local id = channelId or ensureChannel()
		if not id then return 7 end
		return C_ChatInfo.SendAddonMessage(C.PREFIX, text, "CHANNEL", id)
	end
	return C_ChatInfo.SendAddonMessage(C.PREFIX, text, "GUILD")
end

-- Inside an instance only help requests go out (spec 4.3): the group channels are the game's business there.
local INSTANCE_OK = { help = true, helpok = true }
local function inInstance() return IsInInstance and IsInInstance() == true end

local function pump()
	local now = GetTime()
	allowance = math.min(10, allowance + (now - lastTick))
	lastTick = now
	if #queue == 0 then return end
	if inInstance() then   -- entering an instance: whatever waited for a heartbeat is stale, drop it
		for i = #queue, 1, -1 do
			local kind = queue[i].kind
			if not INSTANCE_OK[kind] then table.remove(queue, i); ns.Fire("LM_COMM_DROPPED", kind) end   -- whole-state senders re-mark pending
		end
		C.stats.queued = #queue
		if #queue == 0 then return end
	end
	-- No pre-check of the restriction flags: on Forever they read true outside combat while sends still work
	-- (spike). SendAddonMessage returns 11 under a real lockdown and the loop below keeps the queue.
	while #queue > 0 and allowance >= 1 do
		local item = table.remove(queue, 1)
		local r = rawSend(item.text)
		if r == 0 then
			C.stats.sent = C.stats.sent + 1; allowance = allowance - 1
		elseif r == 11 then   -- lockdown: keep everything, try again later
			table.insert(queue, 1, item); C.stats.lockdownSkips = C.stats.lockdownSkips + 1; break
		elseif r == 3 or r == 8 or r == 7 then   -- throttled, or the hidden channel is not joined yet: retry on a later pump
			table.insert(queue, 1, item); C.stats.retries = C.stats.retries + 1; break
		elseif ns.db.settings.transport == "auto" and active == "guild" then
			ns.Log("GUILD send failed (%s); switching to hidden channel", tostring(r))
			active = "channel"; ensureChannel(); table.insert(queue, 1, item); ns.Fire("LM_COMM_READY", active); break
		else
			C.stats.bad = C.stats.bad + 1   -- invalid prefix/message/type: nothing a retry would fix
		end
	end
	C.stats.queued = #queue
end

local LATEST_ONLY = { wl = true, gp = true, pf = true, gv = true, tb = true, xp = true, al = true, sl = true, pt = true, ac = true }
function C.Send(kind, fields, prio)
	if active == "none" or not IsInGuild() then return false end
	if inInstance() and not INSTANCE_OK[kind] then return false end
	local text, why = C.Encode(kind, fields)
	if not text then ns.Log("encode %s failed: %s", kind, tostring(why)); return false end
	local item = { text = text, kind = kind, prio = prio or "normal" }
	if kind == "hb" then   -- only the newest heartbeat waits, in the queued one's place: what followed it stays after it
		local at
		for i = 1, #queue do if queue[i].kind == "hb" then at = at or i end end
		if at then
			for i = #queue, at + 1, -1 do if queue[i].kind == "hb" then table.remove(queue, i) end end
			queue[at] = item
			C.stats.queued = #queue
			pump()
			return true
		end
	end
	if LATEST_ONLY[kind] then   -- each one carries the whole state: an older copy still waiting would overwrite it
		for i = #queue, 1, -1 do if queue[i].kind == kind then table.remove(queue, i) end end
	end
	if item.prio == "now" then table.insert(queue, 1, item) else queue[#queue + 1] = item end
	C.stats.queued = #queue
	pump()
	return true
end

function C.OnMessage(kind, fn) handlers[kind] = handlers[kind] or {}; table.insert(handlers[kind], fn) end

-- My own echo comes back on GUILD/CHANNEL. Forever spells the sender "Name Realm" as well as "Name-Realm", so
-- compare on letters and digits only, against both "Name" and "NameRealm".
local function norm(s) return (tostring(s):lower():gsub("[^%w]", "")) end
local meKeys = {}
local function isMe(sender, name)
	return meKeys[norm(sender)] or meKeys[norm(name)] or false
end
local function onAddonMessage(prefix, text, channel, sender)
	if prefix ~= C.PREFIX then return end
	if issecretvalue and (issecretvalue(text) or issecretvalue(sender)) then return end
	if channel ~= "GUILD" and channel ~= "CHANNEL" then return end
	if channel == "CHANNEL" and active ~= "channel" then return end
	local name = ns.ShortName(sender)
	if isMe(sender, name) then return end
	if channel == "CHANNEL" and ns.Roster and ns.Roster.IsGuildmate and not ns.Roster.IsGuildmate(name) then C.stats.bad = C.stats.bad + 1; return end
	local kind, fields = C.Decode(text)
	if not kind then C.stats.bad = C.stats.bad + 1; return end
	C.stats.received = C.stats.received + 1
	for _, fn in ipairs(handlers[kind] or {}) do fn(fields, name, sender) end
end

-- Feed a message into the receive path as if it had arrived (used by /lm sim). Sends nothing.
function C.Inject(text, sender) onAddonMessage(C.PREFIX, text, "GUILD", sender) end

local frame
function C.Start()
	local myName, myRealm = ns.Me(), GetRealmName()
	meKeys = { [norm(myName)] = true, [norm(myName .. (myRealm or ""))] = true }
	C_ChatInfo.RegisterAddonMessagePrefix(C.PREFIX)
	active = pickTransport()
	if active == "channel" then ensureChannel() end
	if not frame then
		frame = CreateFrame("Frame")
		frame:SetScript("OnEvent", function(_, _, ...) onAddonMessage(...) end)
	end
	frame:RegisterEvent("CHAT_MSG_ADDON")
	lastTick = GetTime()
	if ticker then ticker:Cancel() end   -- Start is idempotent: one pump ticker at a time
	ticker = C_Timer.NewTicker(0.2, pump)
	ns.Fire("LM_COMM_READY", active)
end
-- Send now, bypassing the queue: only for goodbyes (logout, sharing off) when no later pump will run.
-- Same gates as C.Send; returns true when the client accepted it.
function C.SendImmediate(kind, fields)
	if active == "none" or not IsInGuild() then return false end
	if inInstance() and not INSTANCE_OK[kind] then return false end
	local text = C.Encode(kind, fields)
	if not text then return false end
	return rawSend(text) == 0
end

function C.Stop()
	if active ~= "none" then ns.Fire("LM_COMM_STOPPING") end   -- last chance to withdraw things while we can still send
	if ticker then ticker:Cancel(); ticker = nil end
	if frame then frame:UnregisterEvent("CHAT_MSG_ADDON") end
	queue = {}; active = "none"; channelId = nil
	ns.Fire("LM_COMM_STOPPED")
end
function C.ActiveTransport() return active end
function C.IsReady() return active ~= "none" end

ns.On("LM_LOADED", function() if ns.db.settings.share then C.Start() end end)
ns.On("LM_LOGOUT", function()
	if C.IsReady() and not inInstance() then
		ns.Fire("LM_BEFORE_BYE")   -- modules withdraw what they announced (group finder ad) before the goodbye
		rawSend(C.Encode("bye", {}))
	end
end)
