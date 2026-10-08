-- Roster.lua: what I know about guildmates with the addon, and what I say about myself.
local _, ns = ...
local R = {}
ns.Roster = R
local C = ns.Comm
local HB_EVERY, EXPIRE, PING_JITTER = 30, 120, 5

R.mates = {}
local lastSent, lastHb, lastQuestsSig = nil, -math.huge, nil
local xpWindow = {}   -- { t, xp } samples for XP/h over the last hour

function R.IsGuildmate(name)
	local clubId = C_Club and C_Club.GetGuildClubId and C_Club.GetGuildClubId()
	if not clubId then return true end   -- no roster API: don't block (GUILD transport already filters)
	for _, id in ipairs(C_Club.GetClubMembers(clubId) or {}) do
		local info = C_Club.GetMemberInfo(clubId, id)
		if info and info.name and Ambiguate(info.name, "guild") == name then return true end
	end
	return false
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
	if not force and s == lastSent then return false end
	if not force and now - lastHb < HB_EVERY then return false end
	if C.Send("hb", f) then lastSent, lastHb = s, now; return true end
	return false
end

function R.SendQuests()
	if not ns.db.settings.shareQuests or not C.IsReady() then return end
	local ids = {}
	for id in pairs(R.MyQuests()) do ids[#ids + 1] = id end
	table.sort(ids)
	local list = table.concat(ids, ",")
	if list == lastQuestsSig then return end
	lastQuestsSig = list
	-- split into ≤ 240-byte chunks
	local chunks = {}
	local cur = ""
	for _, id in ipairs(ids) do
		local piece = (cur == "" and "" or ",") .. id
		if #cur + #piece > 240 then chunks[#chunks + 1] = cur; cur = tostring(id) else cur = cur .. piece end
	end
	chunks[#chunks + 1] = cur
	for i, chunk in ipairs(chunks) do C.Send("q", { i = i .. "/" .. #chunks, ids = chunk }) end
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
	m.level, m.mapId, m.inGroup, m.hasSlot = f.l, f.z, f.g == 1, f.s == 1
	m.x, m.y, m.xph, m.class, m.version = f.x, f.y, f.r, f.c, f.v
	m.seenAt = GetTime()
	R.mates[name] = m
	ns.Fire("LM_ROSTER_CHANGED")
end)
C.OnMessage("bye", function(_, name) if R.mates[name] then R.mates[name] = nil; ns.Fire("LM_ROSTER_CHANGED") end end)
C.OnMessage("ping", function() C_Timer.After(math.random() * PING_JITTER, function() R.SendHeartbeat(true) end) end)
C.OnMessage("q", function(f, name)
	local m = R.mates[name]
	if not m then return end
	local idx, total = tostring(f.i):match("^(%d+)/(%d+)$")
	if idx == "1" then m.quests = {} end
	for id in tostring(f.ids):gmatch("%d+") do m.quests[tonumber(id)] = true end
	if idx == total then ns.Fire("LM_MATE_QUESTS", name) end
end)

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LEVEL_UP"); ev:RegisterEvent("ZONE_CHANGED_NEW_AREA"); ev:RegisterEvent("GROUP_ROSTER_UPDATE"); ev:RegisterEvent("QUEST_LOG_UPDATE")
local questDebounce = false
ev:SetScript("OnEvent", function(_, event)
	if event == "QUEST_LOG_UPDATE" then
		if questDebounce then return end
		questDebounce = true
		C_Timer.After(2, function() questDebounce = false; R.SendQuests() end)
	else
		C_Timer.After(0.5, function() R.SendHeartbeat(false) end)
	end
end)

ns.On("LM_WORLD", function(isInitial)
	if not isInitial then return end
	C_Timer.After(0.5, function()
		if not C.IsReady() then return end
		C.Send("ping", {}, "now")
		R.SendHeartbeat(true)
		R.SendQuests()
	end)
	C_Timer.NewTicker(HB_EVERY, function() R.SendHeartbeat(false); R.Expire() end)
end)
