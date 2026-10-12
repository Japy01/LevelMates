-- Final review of the journal: collapsed skill headers, /reload, skipped levels, protected chat values.
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local C, J, L = ns.Comm, ns.Journal, ns.L
local function mate(name) STUB.Receive("LVLM2", C.Encode("hb", { l = 20, z = 1421 }), "GUILD", name .. "-Testrealm") end
local function first() return J.List("all", "")[1] end

-- 1a. a collapsed "Professions" header hides the lines; that is not unlearning, and expanding is not learning
STUB.skills = { { skillID = 182, name = "Herbalism", rank = 40, isHeader = false } }
STUB.Fire("SKILL_LINES_CHANGED")                       -- first sight: snapshot
local n = J.Count()
STUB.skills = { { skillID = 0, name = "Professions", isHeader = true, isCollapsed = true, rank = 0 } }
STUB.Fire("SKILL_LINES_CHANGED")
assert(ns.char.skills[182] and ns.char.skills[182].rank == 40, "hidden profession kept in the snapshot")
STUB.skills = { { skillID = 0, name = "Professions", isHeader = true, isCollapsed = false, rank = 0 }, { skillID = 182, name = "Herbalism", rank = 40, isHeader = false } }
STUB.Fire("SKILL_LINES_CHANGED")
assert(J.Count() == n, "expanding the header adds nothing")

-- 1b. when the client can look a skill up by ID, collapsing does not matter at all
local byId = { [182] = { skillID = 182, name = "Herbalism", rank = 40, isHeader = false } }
C_SkillInfo.GetSkillLineInfoByID = function(id) return byId[id] end
STUB.skills = { { skillID = 0, name = "Professions", isHeader = true, isCollapsed = true, rank = 0 } }
STUB.Fire("SKILL_LINES_CHANGED")
assert(J.Count() == n, "collapsed, by ID: nothing")
byId[186] = { skillID = 186, name = "Mining", rank = 1, isHeader = false }
STUB.Fire("SKILL_LINES_CHANGED")
assert(J.Count() == n + 1 and first().learned and first().name == "Mining", "learned Mining, seen by ID")
C_SkillInfo.GetSkillLineInfoByID = nil

-- 2. "Grouped with" once per session: a /reload is the same session, a new login is not
mate("Mario")
STUB.partyMembers = { Mario = true }
STUB.Fire("GROUP_ROSTER_UPDATE")
n = J.Count()
STUB.Fire("PLAYER_ENTERING_WORLD", false, true); STUB.Advance(1)   -- /reload
STUB.Fire("GROUP_ROSTER_UPDATE")
assert(J.Count() == n, "no repeat after /reload")
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)   -- a new login
mate("Mario")
STUB.Fire("GROUP_ROSTER_UPDATE")
assert(J.Count() == n + 1 and first().k == "group", "a new session can record it again")
STUB.partyMembers = {}

-- 3. levels gained without the addon: no time is claimed, and the text names the real previous level
J.Clear()
STUB.player.level = 21; STUB.Fire("PLAYER_LEVEL_UP", 21)
STUB.Advance(3 * 86400)
STUB.player.level = 26; STUB.Fire("PLAYER_LEVEL_UP", 26)
assert(first().level == 26 and first().took == nil, "skipped levels: no time claimed")
assert(J.Text(first()) == string.format(L.J_LEVEL, 26), "no 'since level' line: " .. J.Text(first()))
STUB.Advance(3600)
STUB.player.level = 27; STUB.Fire("PLAYER_LEVEL_UP", 27)
assert(first().took == 3600 and first().from == 26, "consecutive levels: time and previous level")
assert(J.Duration(2 * 86400 + 3 * 3600) == string.format(L.J_DUR_DH, 2, 3), "days in durations")

-- 4. a loot line whose values are protected (boss encounter) is skipped, never an error
local secret = setmetatable({}, { __index = function() error("attempt to use a secret value") end })
issecretvalue = function(v) return v == secret end
n = J.Count()
STUB.Fire("CHAT_MSG_LOOT", secret, secret, "", "", secret, "", 0, 0, "", 0, 1, secret)
assert(J.Count() == n, "protected loot line skipped")
issecretvalue = nil
