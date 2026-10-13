-- LFG.lua: "looking for group" announcements between guildmates. Posting and cancelling run only from a click.
-- Rules (spec 2026-10-09): 20 minute ads, one per player, one new ad per player per 30 s, 50 in the list,
-- only the author withdraws, only people the roster knows may announce.
local _, ns = ...
local G = {}
ns.LFG = G
local L, C, R, D = ns.L, ns.Comm, ns.Roster, ns.Dungeons
G.ads = {}     -- ad id -> { name, d, r, n, endsAt }
G.mine = nil   -- { id, d, r, n, endsAt }
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
	local names = {}
	for ch in tostring(roles):gmatch(".") do names[#names + 1] = L["ROLE_" .. ch] end
	return table.concat(names, ", ")
end

function G.RolesShort(roles)
	local out = {}
	for ch in tostring(roles):gmatch(".") do out[#out + 1] = L["ROLE_SHORT_" .. ch] end
	return table.concat(out, " ")
end

-- Called from a click (dialog button). Returns true when the ad went out.
function G.Post(dungeonId, roles, note)
	if not D.Get(dungeonId) then return false end
	local r = G.NormRoles(roles)
	if not r then return false end
	if IsInInstance and IsInInstance() then ns.Say(L.LFG_NO_INSTANCE); return false end
	if not C.IsReady() then ns.Say(L.HELP_NEEDS_SHARE); return false end
	local now = GetTime()
	if now - lastPost < MIN_GAP then ns.Say(L.LFG_TOO_SOON); return false end
	note = strtrim(tostring(note or ""))
	note = note:gsub("[%c|]", "")
	note = ns.CutUtf8(note, 40)
	local id = newId()
	local fields = { d = dungeonId, r = r, id = id, m = 20 }
	if note ~= "" then fields.n = note end
	if G.mine then   -- a new ad replaces the old one everywhere
		C.Send("lfgx", { id = G.mine.id }, "now")
		G.mine = nil
	end
	if not C.Send("lfg", fields, "now") then ns.Fire("LM_LFG_CHANGED"); return false end
	lastPost = now
	G.mine = { id = id, d = dungeonId, r = r, n = fields.n, endsAt = now + DURATION, joined = {} }
	ns.Fire("LM_LFG_CHANGED")
	return true
end

function G.Cancel()
	if not G.mine then return end
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
	if not D.Get(f.d) then return end           -- a dungeon this version does not know (newer addon): ignore silently
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
	G.ads[f.id] = { id = f.id, name = name, d = f.d, r = f.r, n = f.n, endsAt = endsAt, joined = known and known.joined or {} }   -- a re-send keeps its joins
	if G.myJoins[f.id] then C.Send("lfj", { id = f.id, r = G.myJoins[f.id] }) end   -- a newcomer gets my join after the ad
	if not known and ns.db.settings.lfgNotices and D.Fits(f.d, UnitLevel("player")) then
		ns.Notice(L.LFG_NOTICE, name, D.Name(f.d), G.RolesText(f.r))
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
	local fields = { d = G.mine.d, r = G.mine.r, id = G.mine.id, m = math.min(20, left) }
	if G.mine.n then fields.n = G.mine.n end
	C.Send("lfg", fields)
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
	if G.mine and GetNumGroupMembers() >= GROUP_FULL then ns.Chat(L.LFG_FULL); G.Cancel() end
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
local function adById(id) if G.mine and G.mine.id == id then return G.mine end; return G.ads[id] end
local function joinedCount(ad) local n = 0; for _ in pairs(ad.joined or {}) do n = n + 1 end; return n end
local function me() return ns.Me() end

-- Called from a click (a card's menu).
function G.Join(id, role)
	local ad = G.ads[id]
	if not ad or not (role == "T" or role == "H" or role == "D") then return false end
	if not C.Send("lfj", { id = id, r = role }, "now") then ns.Say(L.HELP_NEEDS_SHARE); return false end
	G.myJoins[id] = role
	if ns.char.lfgJoinsAt then ns.char.lfgJoinsAt[id] = time() end
	ad.joined = ad.joined or {}
	ad.joined[me()] = role
	ns.Fire("LM_LFG_CHANGED")
	return true
end

function G.Leave(id)
	if not G.myJoins[id] then return false end
	C.Send("lfjx", { id = id }, "now")
	G.myJoins[id] = nil
	local ad = G.ads[id]
	if ad and ad.joined then ad.joined[me()] = nil end
	ns.Fire("LM_LFG_CHANGED")
	return true
end

C.OnMessage("lfj", function(f, name)
	if not R.mates[name] then return end   -- only people the roster knows
	local ad = adById(f.id)
	if not ad or ad.name == name then return end
	ad.joined = ad.joined or {}
	local new = ad.joined[name] == nil
	ad.joined[name] = f.r
	if ad == G.mine then
		if new then ns.Notice(L.LFJ_NOTICE, name, D.Name(ad.d), L["ROLE_" .. f.r]) end
		if not ad.fullTold and joinedCount(ad) >= 4 then ad.fullTold = true; ns.Notice(L.LFJ_FULL, D.Name(ad.d)) end
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
		if G.ads[id] then C.Send("lfj", { id = id, r = role }) end
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
