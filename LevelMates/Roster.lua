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

-- The guild list as one plain list, whatever the client allows: { name (short), level, rank (its index: 0 is the
-- guild master), rankName, role (1 owner, 2 leader, 3 moderator, 4 member), classID, classFile, online, zone, days
-- (since last seen; nil when online), note }. Forever hands some players (not the guild master) the community list
-- as a secret value (2026-10-14: "table expected, got secret"): then the classic roster is read. A secret entry or
-- field is skipped. nil when the game has not given the list yet.
local function secret(v) return issecretvalue ~= nil and issecretvalue(v) end
local function plain(v) if secret(v) then return nil end; return v end
local OFFLINE = 3   -- Enum.ClubMemberPresence.Offline
-- Read once per change: the game says when the list changes (GUILD_ROSTER_UPDATE, the club's member events), and
-- a short TTL covers whatever it does not say; the book asks many times a redraw.
local membersCache, membersAt = nil, -math.huge
R.MEMBERS_TTL = 60
local function readGuildMembers()
	local out = {}
	local club = plain(C_Club and C_Club.GetGuildClubId and C_Club.GetGuildClubId())
	local okIds, ids = pcall(function() return club and C_Club.GetClubMembers(club) end)
	ids = okIds and plain(ids) or nil
	if type(ids) == "table" then
		for _, id in ipairs(ids) do
			local ok, info = pcall(C_Club.GetMemberInfo, club, id)
			info = ok and plain(info) or nil
			local full = type(info) == "table" and plain(info.name) or nil
			if full then
				local pr = plain(info.presence)
				local online = pr ~= nil and pr ~= OFFLINE   -- unreadable: offline, not online
				local days
				if not online then
					local y, mo, d, h = plain(info.lastOnlineYear), plain(info.lastOnlineMonth), plain(info.lastOnlineDay), plain(info.lastOnlineHour)
					if y or mo or d or h then days = (y or 0) * 365 + (mo or 0) * 30 + (d or 0) + math.floor((h or 0) / 24) end
				end
				out[#out + 1] = { name = ns.ShortName(full), level = plain(info.level) or 0, rank = plain(info.guildRankOrder) or 4, rankName = plain(info.guildRank),
					role = plain(info.role) or 4, classID = plain(info.classID), classFile = plain(info.classFileName), online = online, zone = plain(info.zone), days = days, note = plain(info.memberNote) }
			end
		end
	elseif GetNumGuildMembers and GetGuildRosterInfo then
		local n = plain(GetNumGuildMembers()) or 0
		for i = 1, n do
			local full, rankName, rankIndex, level, _, zone, note, _, online, _, classFile = GetGuildRosterInfo(i)
			full = plain(full)
			if full then
				online = plain(online) and true or false
				local days
				if not online and GetGuildRosterLastOnline then
					local y, m, d, h = GetGuildRosterLastOnline(i)
					y = plain(y)
					if y then days = y * 365 + (plain(m) or 0) * 30 + (plain(d) or 0) + math.floor((plain(h) or 0) / 24) end
				end
				rankIndex = plain(rankIndex) or 4
				out[#out + 1] = { name = ns.ShortName(full), level = plain(level) or 0, rank = rankIndex, rankName = plain(rankName),
					role = rankIndex == 0 and 1 or rankIndex == 1 and 2 or 4, classFile = plain(classFile), online = online, zone = plain(zone), days = days, note = plain(note) }
			end
		end
	end
	if #out == 0 then return nil end
	return out
end
function R.GuildMembers()
	if membersCache and GetTime() - membersAt < R.MEMBERS_TTL then return membersCache end
	membersCache, membersAt = readGuildMembers(), GetTime()
	return membersCache
end

-- Guild roster as a name set, cached: the hidden channel is open to anyone, so the roster is the whitelist.
local guildSet, guildSetAt = nil, -math.huge
local ROSTER_TTL = 300
local function buildGuildSet()
	local set = {}
	for _, m in ipairs(R.GuildMembers() or {}) do set[m.name] = m.role or 4 end
	return set
end
function R.InvalidateGuildRoster() guildSet = nil; membersCache = nil end
-- The guild list has arrived from the server (I am on it): until then nobody can be told apart from a stranger.
function R.RosterLoaded() return R.IsGuildmate(ns.Me()) end
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
-- A secret or failing answer is "not an officer" (never a right by mistake); the rank index 0 is the guild master.
function R.IAmOfficer()
	local ok, leader = pcall(function() return IsGuildLeader and IsGuildLeader() end)
	if ok and ns.Plain(leader) == true then return true end
	local ok2, officer = pcall(function() return C_GuildInfo and C_GuildInfo.IsGuildOfficer and C_GuildInfo.IsGuildOfficer() end)
	if ok2 and ns.Plain(officer) == true then return true end
	local ok3, _, _, rank = pcall(GetGuildInfo, "player")
	return ok3 and ns.Plain(rank) == 0
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

-- Who had the addon lately: each heartbeat is remembered in the guild's saved data (level, zone, class, when), so the
-- Guildmates page can list who was seen today though offline now. Kept a week.
R.SEEN_DAYS, R.SEEN_HOURS = 7, 24
local function seenStore() ns.db.lastSeen = ns.db.lastSeen or {}; local k = ns.GuildKey(); ns.db.lastSeen[k] = ns.db.lastSeen[k] or {}; return ns.db.lastSeen[k] end   -- (db.seen belongs to Goals)
function R.Remember(name, m)
	if not ns.db or m.sim then return end
	seenStore()[name] = { t = time(), level = m.level, mapId = m.mapId, class = m.class }
end
-- Offline now, seen in the last hours, still in the guild: newest first.
function R.Seen(hours)
	local out, s, now = {}, seenStore(), time()
	local cutoff = now - (hours or R.SEEN_HOURS) * 3600
	for name, e in pairs(s) do
		if now - (e.t or 0) > R.SEEN_DAYS * 86400 then s[name] = nil
		elseif not R.mates[name] and name ~= ns.Me() and (e.t or 0) >= cutoff and R.IsGuildmate(name) then
			out[#out + 1] = { name = name, level = e.level, mapId = e.mapId, class = e.class, t = e.t }
		end
	end
	table.sort(out, function(a, b) if a.t ~= b.t then return a.t > b.t end; return a.name < b.name end)
	return out
end

-- Online guildmates without the addon (the roster knows them: level, zone, class), highest level first; and how
-- many are online in all (the roster's count, never less than those with the addon).
local CLASS_OF_ID = { [1] = "WARRIOR", [2] = "PALADIN", [3] = "HUNTER", [4] = "ROGUE", [5] = "PRIEST", [7] = "SHAMAN", [8] = "MAGE", [9] = "WARLOCK", [11] = "DRUID" }
function R.ClassFileOf(m) return m.classFile or (m.classID and CLASS_OF_ID[m.classID]) end
function R.OnlineWithout()
	local out = {}
	for _, m in ipairs(R.GuildMembers() or {}) do
		if m.online and not R.mates[m.name] and m.name ~= ns.Me() then out[#out + 1] = { name = m.name, level = m.level or 0, zone = m.zone or "", class = R.ClassFileOf(m) } end
	end
	table.sort(out, function(a, b) if a.level ~= b.level then return a.level > b.level end; return a.name < b.name end)
	return out
end
function R.OnlineCount()
	local n = 0
	for _, m in ipairs(R.GuildMembers() or {}) do if m.online then n = n + 1 end end
	return math.max(n, #R.List() + 1)
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
	-- what the pages show: only a change of these redraws them (a heartbeat every 30 s per mate adds up)
	local same = before ~= nil and m.level == f.l and m.mapId == f.z and m.inGroup == (f.g == 1) and m.hasSlot == (f.s == 1)
		and m.xph == f.r and m.class == f.c and m.version == f.v
	local moved = m.x ~= f.x or m.y ~= f.y
	m.level, m.mapId, m.inGroup, m.hasSlot = f.l, f.z, f.g == 1, f.s == 1
	m.x, m.y, m.xph, m.class, m.version = f.x, f.y, f.r, f.c, f.v
	m.seenAt = GetTime()
	if f.x and f.y then m.posAt = GetTime() end   -- the map drops positions older than five minutes
	R.mates[name] = m
	R.Remember(name, m)
	if before and f.l > before then ns.Fire("LM_MATE_LEVELUP", name, f.l) end   -- a mate I already knew
	if not same then ns.Fire("LM_ROSTER_CHANGED") elseif moved then ns.Fire("LM_MATE_MOVED", name) end
end)
-- Guildmates heard only on the 0.3.x prefix: they do not see us (clean cut); their card says so.
R.legacy = {}
ns.On("LM_LEGACY_SEEN", function(name) R.legacy[name] = GetTime() end)
C.OnMessage("bye", function(_, name) if R.mates[name] then R.mates[name] = nil; ns.Fire("LM_ROSTER_CHANGED") end end)
-- A newcomer's hello gets my heartbeat and my quest list (so matching works both ways), jittered 0-5 s and
-- coalesced: a login storm of hellos produces one answer. (The record layer answers the same hello on its own.)
local pingPending = false
C.OnMessage("hi", function()
	if pingPending then return end
	pingPending = true
	C_Timer.After(math.random() * PING_JITTER, function()
		pingPending = false
		lastQuestsSig = nil
		R.SendHeartbeat(true); R.SendQuests()
		ns.Fire("LM_HELLO_ANSWERED")   -- others (the group finder) answer after the heartbeat, so the newcomer knows us first
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
ev:RegisterEvent("CLUB_MEMBER_PRESENCE_UPDATED"); ev:RegisterEvent("CLUB_MEMBER_UPDATED")   -- someone came, went or changed
local questDebounce = false
ev:SetScript("OnEvent", function(_, event)
	if event == "QUEST_LOG_UPDATE" then
		if questDebounce then return end
		questDebounce = true
		C_Timer.After(2, function() questDebounce = false; R.SendQuests() end)
	elseif event == "GUILD_ROSTER_UPDATE" or event == "CLUB_MEMBER_ADDED" or event == "CLUB_MEMBER_REMOVED" or event == "CLUB_MEMBER_PRESENCE_UPDATED" or event == "CLUB_MEMBER_UPDATED" then
		R.InvalidateGuildRoster()
		ns.Fire("LM_GUILD_ROSTER")   -- what waited for the list (catch-up arriving at login) is looked at again
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
	R.SendHeartbeat(true)   -- first, so they know me before they answer my hello
	ns.Sync.Hello()
	R.SendQuests()
	ns.Fire("LM_ANNOUNCED")   -- modules re-announce their own state (partner flag) after the roster's
end
R.Announce = announce
ns.On("LM_WORLD", function(isInitial, isReloading)
	if not (isInitial or isReloading) then return end
	inWorld = true
	C_Timer.After(0.5, announce)
	if not ticker then ticker = C_Timer.NewTicker(HB_EVERY, function() R.SendHeartbeat(false); R.Expire() end) end
end)
ns.On("LM_COMM_READY", function() if inWorld then C_Timer.After(0.5, announce) end end)
ns.On("LM_COMM_STOPPED", function() if next(R.mates) then wipe(R.mates); ns.Fire("LM_ROSTER_CHANGED") end end)
