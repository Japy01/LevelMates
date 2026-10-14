-- Inactive.lua: for officers, guild members who have not logged in for 14 or 30 days, with level, rank, last login
-- and join date. The game gives no join date: LevelMates notes the day it first sees each member (those already there
-- on the first look are "before" that day). Only reads the guild roster; never removes anyone.
-- Spec 2026-10-10-levelmates-guild-tanda-design.
local _, ns = ...
local I = {}
ns.Inactive = I
local L = ns.L

local function store()
	ns.db.joined = ns.db.joined or {}
	local k = GetGuildInfo("player") or "?"
	ns.db.joined[k] = ns.db.joined[k] or { who = {} }
	return ns.db.joined[k]
end

local function members() return ns.Roster.GuildMembers() or {} end   -- whatever API the client allows (the community list can be secret)

-- The member list, read at most every 30 seconds: big guilds have hundreds and the board redraws often.
local cache, cachedAt = nil, -math.huge
local function cached()
	if not cache or GetTime() - cachedAt > 30 then cache, cachedAt = members(), GetTime() end
	return cache
end
function I.Invalidate() cache = nil end

-- Notes when each member is first seen.
function I.Scan()
	if not (IsInGuild() and GetGuildInfo("player")) then return end
	local list = members()
	cache, cachedAt = list, GetTime()
	if #list == 0 then return end   -- the roster has not loaded yet: a look now would date everyone from today
	local s, now = store(), time()
	local firstLook = s.since == nil
	if firstLook then s.since = now end
	for _, info in ipairs(list) do
		local name = info.name
		if not s.who[name] then s.who[name] = firstLook and { t = now, before = true } or { t = now } end
	end
end


-- Offline for at least `days`, longest first.
function I.List(days, search)
	local s, q, out = store(), (search or ""):lower(), {}
	for _, info in ipairs(cached()) do
		local name = info.name
		local away = info.days or 0
		if not info.online and away >= days and (q == "" or name:lower():find(q, 1, true)) then
			local j = s.who[name]
			out[#out + 1] = { name = name, level = info.level or 0, rank = info.rankName or "", days = away, joined = j and j.t, before = j and j.before }
		end
	end
	table.sort(out, function(a, b) if a.days ~= b.days then return a.days > b.days end; return a.name < b.name end)
	return out
end

function I.JoinedText(e)
	if not e.joined then return "" end
	return string.format(e.before and L.INACTIVE_BEFORE or L.INACTIVE_SINCE, date("%d/%m/%y", e.joined))
end
function I.AwayText(e) return string.format(L.INACTIVE_AWAY, e.days) end

local ev = CreateFrame("Frame")
ev:RegisterEvent("CLUB_MEMBER_ADDED"); ev:RegisterEvent("CLUB_MEMBER_REMOVED"); ev:RegisterEvent("GUILD_ROSTER_UPDATE")
ev:SetScript("OnEvent", function(_, event) if event == "CLUB_MEMBER_ADDED" then I.Scan() else I.Invalidate() end end)
ns.On("LM_WORLD", function(isInitial) if isInitial then C_Timer.After(15, I.Scan) end end)
