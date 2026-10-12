STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local C, R = ns.Comm, ns.Roster
local function last(kind) for i = #STUB.sent, 1, -1 do local k, f = C.Decode(STUB.sent[i].msg); if k == kind then return f end end end
ns.db.settings.shareQuests = true
STUB.quests = { 101 }
R.SendQuests()
assert(last("q").ids == 101 or last("q").ids == "101", "mine")
-- the last quest turned in: an empty list goes out too
STUB.quests = {}
R.SendQuests()
assert(tostring(last("q").ids) == "0" and last("q").i == "1/1", "an empty list: " .. tostring(last("q").ids))
-- sharing off withdraws
ns.db.settings.shareQuests = false
R.WithdrawQuests()
assert(last("q").i == "0/0", "withdrawn")
-- receiving: empty clears, withdraw forgets that they share
STUB.Receive("LVLM2", C.Encode("hb", { l = 20, z = 1421 }), "GUILD", "Mario-Testrealm")
STUB.Receive("LVLM2", C.Encode("q", { i = "1/1", ids = "101,102" }), "GUILD", "Mario-Testrealm")
assert(R.mates.Mario.quests[101] and R.mates.Mario.questsKnown, "his quests")
STUB.Receive("LVLM2", C.Encode("q", { i = "1/1", ids = "0" }), "GUILD", "Mario-Testrealm")
assert(not R.mates.Mario.quests[101] and R.mates.Mario.questsKnown, "none now")
STUB.Receive("LVLM2", C.Encode("q", { i = "0/0", ids = "0" }), "GUILD", "Mario-Testrealm")
assert(not R.mates.Mario.questsKnown, "no longer shared")
-- a send refused (in a dungeon) is tried again later
ns.db.settings.shareQuests = true
STUB.quests = { 103 }
STUB.inInstance = true
R.SendQuests()
STUB.inInstance = false
R.SendQuests()
assert(tostring(last("q").ids) == "103", "sent once out")
