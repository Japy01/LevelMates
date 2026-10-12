-- Optional Questie integration: absent Questie changes nothing; present Questie fills "could pick up".
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local C, M = ns.Comm, ns.Match
STUB.player.mapId = 1421
STUB.Receive("LVLM2", C.Encode("hb", { l = 30, z = 1421 }), "GUILD", "Mario-Testrealm")
STUB.Receive("LVLM2", C.Encode("q", { i = "1/1", ids = "1098" }), "GUILD", "Mario-Testrealm")
STUB.Receive("LVLM2", C.Encode("hb", { l = 12, z = 1421 }), "GUILD", "Ana-Testrealm")
STUB.Receive("LVLM2", C.Encode("q", { i = "1/1", ids = "1098" }), "GUILD", "Ana-Testrealm")

-- no Questie installed: nothing changes
assert(ns.Questie.CanTake(959, 30) == nil, "no Questie -> nil")
assert(#M.ForQuest(959).needs == 0, "no Questie -> nobody listed")
STUB.quests = { 959 }
local printedBefore = #STUB.printed
STUB.Fire("QUEST_ACCEPTED", 959)
assert(#STUB.printed == printedBefore, "no notice at all for a quest nobody shares and no Questie")

-- Questie present
Questie = { db = {} }
QuestieDB = {
	IsDoable = function(id) return id == 959 end,
	QueryQuestSingle = function(id, field) if field == "requiredLevel" then return 20 end end,
}
QuestieLoader = { ImportModule = function() return QuestieDB end }
assert(ns.Questie.CanTake(959, 30) == true, "doable and level ok")
assert(ns.Questie.CanTake(959, 12) == false, "level below the quest's required level")
assert(ns.Questie.CanTake(1, 30) == false, "not doable")
local needs = M.ForQuest(959).needs
assert(#needs == 1 and needs[1] == "Mario", "only Mario could pick it up (Ana is too low): " .. table.concat(needs, ","))
-- a mate who already has it is not listed as needing it
STUB.quests = { 1098 }
assert(#M.ForQuest(1098).needs == 0, "mates who have it are not 'could pick up'")
-- the notice on accepting
STUB.quests = { 959 }
STUB.Fire("QUEST_ACCEPTED", 959)
local last = STUB.printed[#STUB.printed]
assert(last:find("Mario") and last:find("Quest 959"), "could-pick-up notice: " .. tostring(last))
-- an error inside Questie never reaches the player
QuestieDB.IsDoable = function() error("boom") end
assert(ns.Questie.CanTake(959, 30) == nil, "Questie error -> nil, not a crash")
STUB.Fire("QUEST_ACCEPTED", 959)
