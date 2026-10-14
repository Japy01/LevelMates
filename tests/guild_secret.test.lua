-- Forever hands some players (seen 2026-10-14 on a guild member, not on the guild master) the community member list
-- as a secret value: ipairs over it errors ("table expected, got secret"), which broke the guild history, the Members
-- page, the roster whitelist and, through the roster, the whole Home page. When the list is secret, the classic guild
-- roster API is read instead; a secret member entry is skipped.
local SECRET = setmetatable({}, { __tostring = function() return "secret" end })
issecretvalue = function(v) return v == SECRET end
C_Club.GetClubMembers = function() return SECRET end
-- the classic roster: name, rank name, rank index, level, class name, zone, note, officer note, online, status, class file
local classic = {
	{ "Tester-Testrealm", "Guild Master", 0, 20, "Warrior", "Mulgore", "", "", true, 0, "WARRIOR" },
	{ "Mario-Testrealm", "Officer", 1, 30, "Mage", "Barrens", "", "", true, 0, "MAGE" },
	{ "Pepe-Testrealm", "Member", 3, 33, "Hunter", "Ashenvale", "", "", false, 0, "HUNTER" },
	{ "Rosa-Testrealm", "Member", 3, 12, "Priest", "", "", "", false, 0, "PRIEST" },
}
GetNumGuildMembers = function() return #classic, #classic, 2 end
local unpack = unpack or table.unpack
GetGuildRosterInfo = function(i) local m = classic[i]; if m then return unpack(m) end end
GetGuildRosterLastOnline = function(i) if i == 3 then return 0, 0, 20, 3 elseif i == 4 then return 0, 1, 2, 0 end end
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(30)
local R, B, L = ns.Roster, ns.Board, ns.L

-- the roster whitelist and the officers, from the classic API
assert(R.IsGuildmate("Pepe") and R.IsGuildmate("Mario") and not R.IsGuildmate("Nadie"), "guildmates from the classic roster")
assert(R.IsOfficer("Mario") and not R.IsOfficer("Pepe"), "officers by rank index")
-- the guild history scans without error and sees the levels
local ok, err = pcall(ns.GuildHistory.Scan)
assert(ok, "history scan: " .. tostring(err))
-- Members: everyone, with level, online and days away
local list = ns.Members.List("all")
local by = {}
for _, m in ipairs(list) do by[m.name] = m end
assert(by.Pepe and by.Pepe.level == 33 and not by.Pepe.online and by.Pepe.days == 20, "Pepe from the classic roster: " .. tostring(by.Pepe and by.Pepe.days))
assert(by.Mario and by.Mario.online, "Mario online")
-- Inactive: Pepe (20 days) is listed for 14 days, Mario is not
local names = {}
for _, m in ipairs(ns.Inactive.List(14)) do names[m.name] = m.days end
assert(names.Pepe == 20 and not names.Mario, "inactive from the classic roster")
-- Home draws whole: the numbers are there and the ink pass ran
B.Toggle(); B.ShowTab("home")
local okH, errH = pcall(B.Refresh)
assert(okH, "Home draws: " .. tostring(errH))
local DB = ns.Dashboard
assert(DB.stats[2].value.text == "1", "online count drawn: " .. tostring(DB.stats[2].value.text))
-- a secret member entry (the list is readable, one member is not): skipped, no error
C_Club.GetClubMembers = function() return { "Tester", "Mario", "Ana" } end
C_Club.GetMemberInfo = function(_, id) if id == "Ana" then return SECRET end; return { name = id, level = 20, presence = 1, role = 4, guildRankOrder = 4, classID = 8 } end
R.InvalidateGuildRoster(); ns.Members.Invalidate()
assert(R.IsGuildmate("Mario") and not R.IsGuildmate("Ana"), "a secret entry is skipped")
