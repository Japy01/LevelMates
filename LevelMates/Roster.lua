-- Roster.lua: what I know about guildmates with the addon, and what I say about myself.
local _, ns = ...
local R = {}
ns.Roster = R
local C = ns.Comm
local HB_EVERY, EXPIRE, PING_JITTER = 30, 120, 5
local KEEPALIVE = 80   -- an unchanged player still announces itself, well inside the 120 s expiry (ticks every 30 s -> ~90 s)

R.mates = {}
local lastSent, lastHb, lastQuestsSig = nil, -math.huge, nil
local xpWindow = {}   -- { t, xp } samples for XP/h over the last hour

-- Guild roster as a name set, cached: the hidden channel is open to anyone, so the roster is the whitelist.
local guildSet, guildSetAt = nil, -math.huge
local ROSTER_TTL = 300
local function buildGuildSet()
	local set = {}
	local clubId = C_Club and C_Club.GetGuildClubId and C_Club.GetGuildClubId()
	if clubId then
		for _, id in ipairs(C_Club.GetClubMembers(clubId) or {}) do
			local info = C_Club.GetMemberInfo(clubId, id)
			if info and info.name then set[ns.ShortName(info.name)] = info.role or 4 end
		end
	elseif GetNumGuildMembers and GetGuildRosterInfo then
		for i = 1, GetNumGuildMembers() do
			local full = GetGuildRosterInfo(i)
			if full then set[ns.ShortName(full)] = 4 end
		end
	end
	return set
end
function R.InvalidateGuildRoster() guildSet = nil end
function R.IsGuildmate(name)
	if not guildSet or GetTime() - guildSetAt > ROSTER_TTL then
		guildSet = buildGuildSet(); guildSetAt = GetTime()
		if next(guildSet) == nil then guildSet = nil; return false end   -- not loaded yet (login): ask again next time
	end
	return guildSet[name] ~= nil   -- no roster available: nobody is trusted
end

-- Officers: community role Owner (1, guild master) or Leader (2, officer), the rule Blizzard's own UI uses.
function R.IsOfficer(name)
	if not R.IsGuildmate(name) then return false end
	local role = guildSet[name]
	return role == 1 or role == 2
end
function R.IAmOfficer()
	return (IsGuildLeader and IsGuildLeader()) or (C_GuildInfo and C_GuildInfo.IsGuildOfficer and C_GuildInfo.IsGuildOfficer()) or false
end

function R.MyQuests()
	local set = {}
	local n = C_QuestLog.GetNumQuestLogEntries()
	for i = 1, n do
		local info = C_QuestLog.GetInfo(i)
		if info and not info.isHeader and info.questID and not C_QuestLog.IsComplete(info.questID) then set[info.questID] = true end
	end
	return set
end

local function xph()
	local now, xp = GetTime(), UnitXP("player")
	xpWindow[#xpWindow + 1] = { t = now, xp = xp }
	while xpWindow[1] and now - xpWindow[1].t > 3600 do table.remove(xpWindow, 1) end
	local first = xpWindow[1]
	if not first or now - first.t < 60 then return 0 end
	local gained = xp - first.xp
	if gained < 0 then xpWindow = { { t = now, xp = xp } }; return 0 end
	return math.floor(gained / (now - first.t) * 3600)
end

function R.Snapshot()
	local s = ns.db.settings
	local f = { l = UnitLevel("player"), z = C_Map.GetBestMapForUnit("player") or 0, c = select(2, UnitClass("player")) }
	local v = ns.VERSION   -- an unpackaged checkout reports "@project-version@", which is not a valid word
	if type(v) == "string" and #v <= 20 and v:match("^[%w_%.%-]+$") then f.v = v end
	local size = GetNumGroupMembers()
	f.g = size > 0 and 1 or 0
	f.s = (size > 0 and size < 5) and 1 or 0
	if s.sharePos and f.z > 0 then
		local pos = C_Map.GetPlayerMapPosition(f.z, "player")
		if pos then local x, y = pos:GetXY(); f.x = math.floor(x * 1000 + 0.5) / 10; f.y = math.floor(y * 1000 + 0.5) / 10 end
	end
	if s.shareXp then f.r = xph() end
	return f
end

local function sig(f) local keys = {}; for k in pairs(f) do keys[#keys + 1] = k end; table.sort(keys); local p = {}; for _, k in ipairs(keys) do p[#p + 1] = k .. "=" .. tostring(f[k]) end; return table.concat(p, ";") end

function R.SendHeartbeat(force)
	if not ns.db.settings.share or not C.IsReady() then return false end
	local f = R.Snapshot()
	local s = sig(f)
	local now = GetTime()
	if not force and s == lastSent and now - lastHb < KEEPALIVE then return false end
	if not force and now - lastHb < HB_EVERY then return false end
	if C.Send("hb", f) then
		lastSent, lastHb = s, now
		ns.Fire("LM_HB_SENT")   -- state that rides along with the heartbeat (partner mark) goes right after it
		return true
	end
	return false
end

function R.SendQuests()
	if not ns.db.settings.shareQuests or not C.IsReady() then return end
	local ids = {}
	for id in pairs(R.MyQuests()) do ids[#ids + 1] = id end
	table.sort(ids)
	local list = table.concat(ids, ",")
	if list == lastQuestsSig then return end
	-- split into ≤ 240-byte chunks
	local chunks = {}
	local cur = ""
	for _, id in ipairs(ids) do
		local piece = (cur == "" and "" or ",") .. id
		if #cur + #piece > 240 then chunks[#chunks + 1] = cur; cur = tostring(id) else cur = cur .. piece end
	end
	chunks[#chunks + 1] = cur ~= "" and cur or "0"   -- "0": an empty list (the last quest turned in) goes out too
	local ok = true
	for i, chunk in ipairs(chunks) do ok = C.Send("q", { i = i .. "/" .. #chunks, ids = chunk }) and ok end
	if ok then lastQuestsSig = list end   -- refused (in a dungeon): tried again on the next change or heartbeat
end

-- Sharing turned off: "0/0" tells guildmates to forget my quests.
function R.WithdrawQuests()
	lastQuestsSig = nil
	if C.IsReady() then C.Send("q", { i = "0/0", ids = "0" }) end
end

function R.Expire()
	local now, changed = GetTime(), false
	for name, m in pairs(R.mates) do if now - m.seenAt > EXPIRE then R.mates[name] = nil; changed = true end end
	if changed then ns.Fire("LM_ROSTER_CHANGED") end
end

function R.List()
	local out = {}
	for name in pairs(R.mates) do out[#out + 1] = name end
	table.sort(out, function(a, b) local A, B = R.mates[a], R.mates[b]; if A.level ~= B.level then return A.level > B.level end; return a < b end)
	return out
end

C.OnMessage("hb", function(f, name)
	local m = R.mates[name] or { quests = {} }
	local before = m.level
	m.level, m.mapId, m.inGroup, m.hasSlot = f.l, f.z, f.g == 1, f.s == 1
	m.x, m.y, m.xph, m.class, m.version = f.x, f.y, f.r, f.c, f.v
	m.seenAt = GetTime()
	R.mates[name] = m
	if before and f.l > before then ns.Fire("LM_MATE_LEVELUP", name, f.l) end   -- a mate I already knew
	ns.Fire("LM_ROSTER_CHANGED")
end)
C.OnMessage("bye", function(_, name) if R.mates[name] then R.mates[name] = nil; ns.Fire("LM_ROSTER_CHANGED") end end)
-- A newcomer's ping gets my heartbeat and my quest list (so matching works both ways), jittered 0-5 s and
-- coalesced: a login storm of pings produces one answer.
local pingPending = false
C.OnMessage("ping", function()
	if pingPending then return end
	pingPending = true
	C_Timer.After(math.random() * PING_JITTER, function()
		pingPending = false
		lastQuestsSig = nil
		R.SendHeartbeat(true); R.SendQuests()
		ns.Fire("LM_PING_ANSWERED")   -- others (the group finder) answer after the heartbeat, so the newcomer knows us first
	end)
end)
C.OnMessage("q", function(f, name)
	local m = R.mates[name]
	if not m then return end
	local idx, total = tostring(f.i):match("^(%d+)/(%d+)$")
	if idx == "0" then m.quests, m.questsKnown = {}, nil; ns.Fire("LM_MATE_QUESTS", name); return end   -- they stopped sharing
	if idx == "1" then m.quests = {} end
	m.questsKnown = true   -- they share their quests (the empty default means "unknown")
	for id in tostring(f.ids):gmatch("%d+") do if id ~= "0" then m.quests[tonumber(id)] = true end end
	if idx == total then ns.Fire("LM_MATE_QUESTS", name) end
end)

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LEVEL_UP"); ev:RegisterEvent("ZONE_CHANGED_NEW_AREA"); ev:RegisterEvent("GROUP_ROSTER_UPDATE"); ev:RegisterEvent("QUEST_LOG_UPDATE")
ev:RegisterEvent("GUILD_ROSTER_UPDATE"); ev:RegisterEvent("CLUB_MEMBER_ADDED"); ev:RegisterEvent("CLUB_MEMBER_REMOVED")
local questDebounce = false
ev:SetScript("OnEvent", function(_, event)
	if event == "QUEST_LOG_UPDATE" then
		if questDebounce then return end
		questDebounce = true
		C_Timer.After(2, function() questDebounce = false; R.SendQuests() end)
	elseif event == "GUILD_ROSTER_UPDATE" or event == "CLUB_MEMBER_ADDED" or event == "CLUB_MEMBER_REMOVED" then
		R.InvalidateGuildRoster()
	else
		if event == "PLAYER_LEVEL_UP" then xpWindow = {} end   -- the XP bar resets: old samples would give nonsense
		C_Timer.After(0.5, function() R.SendHeartbeat(false) end)
	end
end)

-- Ask the server for the guild list early: officer checks need it as soon as goals arrive.
ns.On("LM_WORLD", function() if C_GuildInfo and C_GuildInfo.GuildRoster then C_GuildInfo.GuildRoster() end end)

-- Lifecycle: announce myself (ping + forced hb + quests) at login, after /reload, and whenever the transport
-- (re)starts while I am in the world; forget everyone when it stops ("off: you see nobody").
local inWorld, ticker = false, nil
local function announce()
	if not C.IsReady() then return end
	lastSent, lastHb, lastQuestsSig = nil, -math.huge, nil
	C.Send("ping", {}, "now")
	R.SendHeartbeat(true)
	R.SendQuests()
	ns.Fire("LM_ANNOUNCED")   -- modules re-announce their own state (partner flag) after the roster's
end
ns.On("LM_WORLD", function(isInitial, isReloading)
	if not (isInitial or isReloading) then return end
	inWorld = true
	C_Timer.After(0.5, announce)
	if not ticker then ticker = C_Timer.NewTicker(HB_EVERY, function() R.SendHeartbeat(false); R.Expire() end) end
end)
ns.On("LM_COMM_READY", function() if inWorld then C_Timer.After(0.5, announce) end end)
ns.On("LM_COMM_STOPPED", function() if next(R.mates) then wipe(R.mates); ns.Fire("LM_ROSTER_CHANGED") end end)
