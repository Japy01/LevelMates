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
local resendPending = false

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
	G.mine = { id = id, d = dungeonId, r = r, n = fields.n, endsAt = now + DURATION }
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
	if not known then
		local seen = lastSeen[name]
		if seen and seen.id ~= f.id and now - seen.at < MIN_GAP then return end   -- one new ad per player every 30 s
		local hasOwn = false
		for _, a in pairs(G.ads) do if a.name == name then hasOwn = true end end
		if count() >= MAX_ADS and not hasOwn then return end                      -- full list; replacing your own still works
		for id, a in pairs(G.ads) do if a.name == name then G.ads[id] = nil end end -- one ad per player
		lastSeen[name] = { id = f.id, at = now }
	end
	G.ads[f.id] = { name = name, d = f.d, r = f.r, n = f.n, endsAt = now + f.m * 60 }
	if not known and ns.db.settings.lfgNotices and D.Fits(f.d, UnitLevel("player")) then
		ns.Say(L.LFG_NOTICE, name, D.Name(f.d), G.RolesText(f.r))
	end
	ns.Fire("LM_LFG_CHANGED")
end)

C.OnMessage("lfgx", function(f, name)
	local ad = G.ads[f.id]
	if ad and ad.name == name then G.ads[f.id] = nil; ns.Fire("LM_LFG_CHANGED") end   -- only the author withdraws it
end)

-- A newcomer's ping: re-send my ad with the minutes that remain, jittered 0-5 s and coalesced into one answer.
C.OnMessage("ping", function()
	if not G.mine or resendPending then return end
	resendPending = true
	C_Timer.After(math.random() * 5, function()
		resendPending = false
		if not G.mine then return end
		local left = math.ceil((G.mine.endsAt - GetTime()) / 60)
		if left < 1 then return end
		local fields = { d = G.mine.d, r = G.mine.r, id = G.mine.id, m = math.min(20, left) }
		if G.mine.n then fields.n = G.mine.n end
		C.Send("lfg", fields)
	end)
end)

local groupFrame = CreateFrame("Frame")
groupFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
groupFrame:SetScript("OnEvent", function()
	if G.mine and GetNumGroupMembers() >= GROUP_FULL then ns.Say(L.LFG_FULL); G.Cancel() end
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
