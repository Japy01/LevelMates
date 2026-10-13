-- LFG.lua: "looking for group" announcements between guildmates. Posting and cancelling run only from a click.
-- Rules (spec 2026-10-09): 20 minute ads, one per player, one new ad per player per 30 s, 50 in the list,
-- only the author withdraws, only people the roster knows may announce.
local _, ns = ...
local G = {}
ns.LFG = G
local L, C, R, D, A = ns.L, ns.Comm, ns.Roster, ns.Dungeons, ns.Activities
G.ads = {}     -- ad id -> { id, name, d, t, size, caps, lr, r, n, endsAt, joined, joinedAt }
G.mine = nil   -- the same, mine
-- A group "Now" (project 9): an activity (or a free name), its size and slots per role, the leader's role.
local DURATION, MIN_GAP, MAX_ADS, GROUP_FULL = 20 * 60, 30, 50, 5
local ROLE_ORDER = { "T", "H", "D" }
local lastPost = -math.huge
local lastSeen = {}          -- player name -> { id, at } of the last new ad accepted from them

local function newId() return string.format("%04x%04x", math.random(0, 65535), math.random(0, 65535)):sub(1, 8) end

-- "DT" -> "TD": canonical order, no repeats, only T/H/D; nil when nothing valid is left.
function G.NormRoles(roles)
	local want = {}
	for ch in tostring(roles or ""):upper():gmatch(".") do want[ch] = true end
	local out = ""
	for _, ch in ipairs(ROLE_ORDER) do if want[ch] then out = out .. ch end end
	return out ~= "" and out or nil
end

function G.RolesText(roles)
	if not roles then return "" end
	local names = {}
	for ch in tostring(roles):gmatch(".") do names[#names + 1] = L["ROLE_" .. ch] end
	return table.concat(names, ", ")
end

function G.RolesShort(roles)
	if not roles then return "" end
	local out = {}
	for ch in tostring(roles):gmatch(".") do out[#out + 1] = L["ROLE_SHORT_" .. ch] end
	return table.concat(out, " ")
end

-- What travels: the activity, its size when not its own, the slots when not the default, the free name, my role, and
-- the roles still wanted (for older readers of r).
local function wanted(ad)
	if not ad.caps.T and not ad.caps.H and not ad.caps.D then return nil end
	local s, out = G.Slots(ad), ""
	for _, role in ipairs(ROLE_ORDER) do if A.Free(s, ad.caps, role) then out = out .. role end end
	return out ~= "" and out or nil
end
local function fieldsOf(ad, minutes)
	local a = A.Get(ad.d)
	local f = { d = ad.d, id = ad.id, m = minutes, lr = ad.lr, n = ad.n, t = ad.t, r = wanted(ad), dc = ad.dc and 1 or nil }
	if a and ad.size ~= a.size then f.x = ad.size end
	if a and a.kind == "r" then
		local default = A.Caps(ad.d, ad.size)
		if A.EncodeCaps(default) ~= A.EncodeCaps(ad.caps) then f.c = A.EncodeCaps(ad.caps) end
	end
	return f
end
-- An ad as the views know it, from its fields.
local function adFrom(f, name)
	local a = A.Get(f.d)
	local t = f.t and A.CleanName(f.t) or nil
	if t == "" then t = nil end
	if not a and not t then return nil end   -- an activity this version does not know, with no name: ignore
	local size = A.SizeOf(f.d, f.x)
	local caps = A.Caps(f.d, size, f.c)
	local lr = f.lr
	if not caps[lr or ""] then lr = caps.A and "A" or (ns.Roles.Of(name) or "D") end
	return { id = f.id, name = name, d = f.d, t = t, size = size, caps = caps, lr = lr, r = f.r, n = f.n, dc = f.dc == 1 or nil }   -- dc: in Discord, so joins and leaves go there too
end

-- Who is in: the leader, then the joins by when each joined (their own clock, sent with the join), name to break a
-- tie: the same order on every client, whatever order the messages came in.
function G.Slots(ad)
	local names = {}
	for name in pairs(ad.joined or {}) do names[#names + 1] = name end
	local at = ad.joinedAt or {}
	table.sort(names, function(a, b)
		local x, y = at[a] or math.huge, at[b] or math.huge
		if x ~= y then return x < y end
		return a < b
	end)
	local joins = {}
	for _, name in ipairs(names) do joins[#joins + 1] = { name, ad.joined[name] } end
	return A.Place(ad.caps, ad.name, ad.lr, joins)
end
function G.IsFull(ad) return A.Count(G.Slots(ad), ad.caps) >= ad.size end

-- Called from a click (the form or a dialog). spec: { d, x, c, t, role, note, discord }. The old (dungeonId, roles,
-- note) still works. Returns true when the ad went out.
function G.Post(spec, roles, note)
	if type(spec) ~= "table" then spec = { d = spec, note = note, role = ns.Roles.Of(ns.Me()) } end
	local a = A.Get(spec.d)
	if not a then return false end
	local t = a.free and spec.t and A.CleanName(spec.t) or nil
	if t == "" then t = nil end
	if IsInInstance and IsInInstance() then ns.Say(L.LFG_NO_INSTANCE); return false end
	if not C.IsReady() then ns.Say(L.HELP_NEEDS_SHARE); return false end
	local now = GetTime()
	if now - lastPost < MIN_GAP then ns.Say(L.LFG_TOO_SOON); return false end
	note = strtrim(tostring(spec.note or ""))
	note = note:gsub("[%c|]", "")
	note = ns.CutUtf8(note, 40)
	local size = A.SizeOf(spec.d, spec.x)
	local caps = A.Caps(spec.d, size, spec.c)
	local role = caps[spec.role or ""] and spec.role or (caps.A and "A" or ns.Roles.Of(ns.Me()))
	local ad = { id = newId(), name = ns.Me(), d = spec.d, t = t, size = size, caps = caps, lr = role,
		n = note ~= "" and note or nil, joined = {}, joinedAt = {}, dc = spec.discord and true or nil }
	if not C.Send("lfg", fieldsOf(ad, 20), "now") then ns.Say(L.HELP_NEEDS_SHARE); ns.Fire("LM_LFG_CHANGED"); return false end   -- the old ad stays
	if G.mine then C.Send("lfgx", { id = G.mine.id }, "now") end   -- the new ad replaces the old one everywhere
	lastPost = now
	ad.endsAt = now + DURATION
	G.mine = ad
	if spec.discord then ns.Discord.Run("new", G.View(ad)) end
	ns.Fire("LM_LFG_CHANGED")
	return true
end

-- An ad in the shape the views and Discord share with runs: { id, d, t, by, role, caps, size, n, joined, now = true }.
function G.View(ad)
	return { id = ad.id, d = ad.d, t = ad.t, by = ad.name, role = ad.lr, caps = ad.caps, size = ad.size, n = ad.n,
		joined = ad.joined or {}, joinedAt = ad.joinedAt, now = true, dc = ad.dc, endsAt = ad.endsAt, mine = ad == G.mine }
end

function G.Cancel()
	if not G.mine then return end
	if G.mine.dc then ns.Discord.Run("cancel", G.View(G.mine)) end   -- from the Withdraw click
	C.Send("lfgx", { id = G.mine.id }, "now")
	G.mine = nil
	ns.Fire("LM_LFG_CHANGED")
end

-- Ad ids, newest first (the one that lives longest is the newest).
function G.List()
	local out = {}
	for id in pairs(G.ads) do out[#out + 1] = id end
	table.sort(out, function(a, b)
		local A, B = G.ads[a], G.ads[b]
		if A.endsAt ~= B.endsAt then return A.endsAt > B.endsAt end
		return a < b
	end)
	return out
end

function G.Expire()
	local now, changed = GetTime(), false
	for id, ad in pairs(G.ads) do if ad.endsAt <= now then G.ads[id] = nil; changed = true end end
	if G.mine and G.mine.endsAt <= now then G.mine = nil; changed = true end
	if changed then ns.Fire("LM_LFG_CHANGED") end
end

local function count() local n = 0; for _ in pairs(G.ads) do n = n + 1 end; return n end

C.OnMessage("lfg", function(f, name)
	if not R.mates[name] then return end        -- only people the roster knows: their level and class come from there
	local fresh = adFrom(f, name)
	if not fresh then return end                -- an activity this version does not know, unnamed: ignore silently
	local now = GetTime()
	local known = G.ads[f.id]
	if known and known.name ~= name then return end   -- an id belongs to whoever posted it: nobody else can take it over
	if not known then
		local seen = lastSeen[name]
		if seen and seen.id ~= f.id and now - seen.at < MIN_GAP then return end   -- one new ad per player every 30 s
		local hasOwn = false
		for _, a in pairs(G.ads) do if a.name == name then hasOwn = true end end
		if count() >= MAX_ADS and not hasOwn then return end                      -- full list; replacing your own still works
		for id, a in pairs(G.ads) do if a.name == name then G.ads[id] = nil end end -- one ad per player
		lastSeen[name] = { id = f.id, at = now }
	end
	local endsAt = now + f.m * 60
	if known then endsAt = math.min(known.endsAt, endsAt) end   -- a re-send never moves the clock forward
	fresh.endsAt, fresh.joined, fresh.joinedAt = endsAt, known and known.joined or {}, known and known.joinedAt or {}   -- a re-send keeps its joins
	G.ads[f.id] = fresh
	if G.myJoins[f.id] then C.Send("lfj", { id = f.id, r = G.myJoins[f.id], w = G.JoinedAt(f.id) }) end   -- a newcomer gets my join after the ad
	local a = A.Get(f.d)
	if not known and ns.db.settings.lfgNotices and (not a or a.kind ~= "d" or D.Fits(f.d, UnitLevel("player"))) then
		ns.NoticeAt("lfg", L.LFG_NOTICE, name, A.Name(f.d, fresh.t), fresh.r and G.RolesText(fresh.r) or L.ROLE_A)
	end
	ns.Fire("LM_LFG_CHANGED")
end)

C.OnMessage("lfgx", function(f, name)
	local ad = G.ads[f.id]
	if ad and ad.name == name then G.ads[f.id] = nil; ns.Fire("LM_LFG_CHANGED") end   -- only the author withdraws it
end)

-- A newcomer's ping: the roster answers with my heartbeat (jittered, coalesced) and then fires LM_HELLO_ANSWERED;
-- my ad goes out right after it, so the newcomer already knows me when the ad arrives. Whole minutes left, rounded down.
ns.On("LM_HELLO_ANSWERED", function()
	if not G.mine then return end
	local left = math.floor((G.mine.endsAt - GetTime()) / 60)
	if left < 1 then return end
	C.Send("lfg", fieldsOf(G.mine, math.min(20, left)))
end)

-- A poster who leaves takes the ad along.
C.OnMessage("bye", function(_, name)
	local changed = false
	for id, a in pairs(G.ads) do if a.name == name then G.ads[id] = nil; changed = true end end
	for _, a in pairs(G.ads) do if a.joined and a.joined[name] then a.joined[name] = nil; changed = true end end   -- and their joins
	if G.mine and G.mine.joined and G.mine.joined[name] then G.mine.joined[name] = nil; changed = true end
	if changed then ns.Fire("LM_LFG_CHANGED") end
end)

-- Logging out or turning sharing off: withdraw my ad while the transport can still send.
local function withdrawNow()
	if not G.mine then return end
	C.SendImmediate("lfgx", { id = G.mine.id })
	G.mine = nil
	ns.Fire("LM_LFG_CHANGED")
end
ns.On("LM_COMM_STOPPING", withdrawNow)
ns.On("LM_BEFORE_BYE", withdrawNow)

local groupFrame = CreateFrame("Frame")
groupFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
groupFrame:SetScript("OnEvent", function()
	if G.mine and GetNumGroupMembers() >= (G.mine.size or GROUP_FULL) then ns.Chat(L.LFG_FULL); G.Cancel() end
end)

ns.On("LM_COMM_STOPPED", function()   -- sharing off: you see nobody and have no ad
	G.mine = nil
	wipe(G.ads); wipe(lastSeen)
	ns.Fire("LM_LFG_CHANGED")
end)

local ticker
ns.On("LM_WORLD", function(isInitial, isReloading)
	if not (isInitial or isReloading) or ticker then return end
	ticker = C_Timer.NewTicker(60, G.Expire)
end)


-- "Join": who joins which ad. Everyone keeps them (the card tooltip shows them); the poster gets the notices.
-- My joins (ad id -> role) live in the character's saved data, so a /reload still offers "Leave"; they are
-- dropped 20 minutes after joining (no ad lives longer).
G.myJoins = {}
local JOIN_LIFE = 20 * 60
ns.On("LM_LOADED", function()
	ns.char.lfgJoins = ns.char.lfgJoins or {}
	ns.char.lfgJoinsAt = ns.char.lfgJoinsAt or {}
	G.myJoins = ns.char.lfgJoins
	for id, at in pairs(ns.char.lfgJoinsAt) do if time() - at > JOIN_LIFE then G.myJoins[id] = nil; ns.char.lfgJoinsAt[id] = nil end end
end)
function G.JoinedAt(id) return ns.char and ns.char.lfgJoinsAt and ns.char.lfgJoinsAt[id] or nil end
local function adById(id) if G.mine and G.mine.id == id then return G.mine end; return G.ads[id] end
local function joinedCount(ad) local n = 0; for _ in pairs(ad.joined or {}) do n = n + 1 end; return n end
local function me() return ns.Me() end

-- Called from a click (a card's menu).
function G.Join(id, role)
	local ad = G.ads[id]
	if not ad or not ad.caps[role] then return false end   -- a role this group has ("A" only where there are no roles)
	if not A.Free(G.Slots(ad), ad.caps, role) then ns.Say(L.RUN_ROLE_FULL); return false end
	local w = GetServerTime()
	if not C.Send("lfj", { id = id, r = role, w = w }, "now") then ns.Say(L.HELP_NEEDS_SHARE); return false end
	G.myJoins[id] = role
	if ns.char.lfgJoinsAt then ns.char.lfgJoinsAt[id] = w end
	ad.joined = ad.joined or {}
	ad.joinedAt = ad.joinedAt or {}
	ad.joinedAt[me()] = ad.joinedAt[me()] or w
	if ad.dc then ns.Discord.Run("join", G.View(ad), me(), role) end   -- before I count, so the places are right
	ad.joined[me()] = role
	ns.Fire("LM_LFG_CHANGED")
	return true
end

function G.Leave(id)
	if not G.myJoins[id] then return false end
	C.Send("lfjx", { id = id }, "now")
	G.myJoins[id] = nil
	local ad = G.ads[id]
	if ad and ad.dc then ns.Discord.Run("leave", G.View(ad), me()) end
	if ad and ad.joined then ad.joined[me()] = nil end
	ns.Fire("LM_LFG_CHANGED")
	return true
end

C.OnMessage("lfj", function(f, name)
	if not R.mates[name] then return end   -- only people the roster knows
	local ad = adById(f.id)
	if not ad or ad.name == name then return end
	if not ad.caps[f.r] then return end   -- a role this group does not have
	ad.joined = ad.joined or {}
	local new = ad.joined[name] == nil
	ad.joinedAt = ad.joinedAt or {}
	ad.joinedAt[name] = tonumber(f.w) or ad.joinedAt[name] or GetServerTime()   -- when they joined, by their clock
	ad.joined[name] = f.r
	if ad == G.mine then
		if new then ns.NoticeAt("lfg", L.LFJ_NOTICE, name, A.Name(ad.d, ad.t), L["ROLE_" .. f.r]) end
		if not ad.fullTold and G.IsFull(ad) then ad.fullTold = true; ns.NoticeAt("lfg", L.LFJ_FULL, A.Name(ad.d, ad.t)) end
	end
	ns.Fire("LM_LFG_CHANGED")
end)

C.OnMessage("lfjx", function(f, name)
	local ad = adById(f.id)
	if ad and ad.joined and ad.joined[name] then ad.joined[name] = nil; ns.Fire("LM_LFG_CHANGED") end
end)

-- A newcomer (or a poster back from a /reload) gets my joins again, while their ads live.
ns.On("LM_HELLO_ANSWERED", function()
	for id, role in pairs(G.myJoins) do
		if G.ads[id] then C.Send("lfj", { id = id, r = role, w = G.JoinedAt(id) }) end
	end
end)

-- Joiners whose roster entry expired (no bye: a crash, a disconnect) are no longer joined.
ns.On("LM_ROSTER_CHANGED", function()
	local changed, mine = false, me()
	local function prune(ad)
		for name in pairs(ad.joined or {}) do
			if name ~= mine and not R.mates[name] then ad.joined[name] = nil; changed = true end
		end
	end
	for _, a in pairs(G.ads) do prune(a) end
	if G.mine then prune(G.mine) end
	if changed then ns.Fire("LM_LFG_CHANGED") end
end)
