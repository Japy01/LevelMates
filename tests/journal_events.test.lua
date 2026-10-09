STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local C, J = ns.Comm, ns.Journal
local function mate(name) STUB.Receive("LVLM", C.Encode("hb", { l = 20, z = 1421 }), "GUILD", name .. "-Testrealm") end
local function first() return J.List("all", "")[1] end
mate("Mario"); mate("Ana")

-- group: once per guildmate per session; strangers are not guildmates
STUB.partyMembers = { Mario = true }
STUB.Fire("GROUP_ROSTER_UPDATE")
assert(first() and first().k == "group" and first().name == "Mario", "grouped with Mario")
local n = J.Count()
STUB.Fire("GROUP_ROSTER_UPDATE")
assert(J.Count() == n, "not twice")
STUB.partyMembers = { Mario = true, Ana = true, Stranger = true }
STUB.Fire("GROUP_ROSTER_UPDATE")
assert(J.Count() == n + 1 and first().name == "Ana", "Ana added; the stranger is not a guildmate")

-- dungeon: once per entry, with the guildmates in the group
STUB.inInstance = true; STUB.instanceName = "Ragefire Chasm"; STUB.instanceId = 389
STUB.Fire("PLAYER_ENTERING_WORLD", false, false); STUB.Advance(1)
local d = first()
assert(d.k == "dungeon" and d.name == "Ragefire Chasm" and table.concat(d.mates, ",") == "Ana,Mario", "dungeon with guildmates: " .. tostring(d.name))
n = J.Count()
STUB.Fire("PLAYER_ENTERING_WORLD", false, false); STUB.Fire("ZONE_CHANGED_NEW_AREA"); STUB.Advance(1)
assert(J.Count() == n, "another loading screen inside is not a new entry")
STUB.Fire("PLAYER_ENTERING_WORLD", false, true); STUB.Advance(1)
assert(J.Count() == n, "nor a /reload inside")
STUB.inInstance = false; STUB.Fire("ZONE_CHANGED_NEW_AREA"); STUB.Advance(1)
STUB.inInstance = true; STUB.Fire("ZONE_CHANGED_NEW_AREA"); STUB.Advance(1)
assert(J.Count() == n + 1, "going in again is a new entry")
STUB.inInstance = false; STUB.Fire("ZONE_CHANGED_NEW_AREA"); STUB.Advance(1)
STUB.partyMembers = {}

-- loot: mine only, uncommon or better
local me = UnitGUID("player")
local green = "|cff1eff00|Hitem:2589::::::::20:::::::|h[Linen Cloth]|h|r"
local grey = "|cff9d9d9d|Hitem:117::::::::20:::::::|h[Tough Jerky]|h|r"
local function loot(text, guid, who) STUB.Fire("CHAT_MSG_LOOT", text, who or "Tester", "", "", who or "Tester", "", 0, 0, "", 0, 1, guid) end
n = J.Count()
loot("You receive loot: " .. green .. ".", me)
assert(J.Count() == n + 1 and first().k == "item" and first().link == green and first().q == 2, "green item recorded (quality from the colour)")
loot("You receive loot: " .. grey .. ".", me)
assert(J.Count() == n + 1, "grey ignored")
loot("Mario receives loot: " .. green .. ".", "Player-1-OTHER", "Mario")
assert(J.Count() == n + 1, "someone else's loot ignored")
loot("You receive loot: " .. green .. ".", "", "Tester")
assert(J.Count() == n + 2, "empty guid: the sender name decides")
C_Item = { GetItemQualityByID = function() return 4 end }
loot("You receive loot: " .. grey .. ".", me)
assert(J.Count() == n + 3 and first().q == 4, "quality from the item info when the client has it")
C_Item = nil
loot("You receive loot: nothing to link here.", me)
assert(J.Count() == n + 3, "no item link, no entry")

-- professions: no snapshot while skills are not loaded; the first readable sight is a snapshot only
STUB.skills = nil
STUB.Fire("SKILL_LINES_CHANGED")
assert(ns.char.skills == nil, "no snapshot while nothing is readable")
n = J.Count()
STUB.skills = {
	{ skillID = 182, name = "Herbalism", rank = 40, isHeader = false },
	{ skillID = 98, name = "Language: Orcish", rank = 300, isHeader = false },
}
STUB.Fire("SKILL_LINES_CHANGED")
assert(ns.char.skills and ns.char.skills[182] and ns.char.skills[182].rank == 40 and J.Count() == n, "first sight: snapshot only")
STUB.skills[1].rank = 49; STUB.Fire("SKILL_LINES_CHANGED")
assert(J.Count() == n, "40 to 49: no new multiple of 25")
STUB.skills[1].rank = 50; STUB.Fire("SKILL_LINES_CHANGED")
assert(J.Count() == n + 1 and first().k == "skill" and first().rank == 50 and first().name == "Herbalism", "reached 50")
STUB.skills[2].rank = 301; STUB.Fire("SKILL_LINES_CHANGED")
assert(J.Count() == n + 1, "languages are not professions")
table.insert(STUB.skills, { skillID = 186, name = "Mining", rank = 1, isHeader = false })
STUB.Fire("SKILL_LINES_CHANGED")
assert(J.Count() == n + 2 and first().learned and first().name == "Mining", "learned Mining")
