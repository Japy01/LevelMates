STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local C = ns.Comm
STUB.player.mapId = 1421
STUB.Receive("LVLM", C.Encode("hb", { l = 22, z = 1421 }), "GUILD", "Mario-Testrealm")
STUB.Receive("LVLM", C.Encode("q", { i = "1/1", ids = "1098,959" }), "GUILD", "Mario-Testrealm")
STUB.Receive("LVLM", C.Encode("hb", { l = 22, z = 1412 }), "GUILD", "Ana-Testrealm")   -- other map
STUB.Receive("LVLM", C.Encode("q", { i = "1/1", ids = "1098" }), "GUILD", "Ana-Testrealm")
local m = ns.Match.ForQuest(1098)
assert(#m.has == 1 and m.has[1] == "Mario", "only same-map mates: " .. table.concat(m.has, ","))
-- accepting a quest notifies
STUB.quests = { 1098 }
STUB.Fire("QUEST_ACCEPTED", 1098)
local last = STUB.printed[#STUB.printed]
assert(last and last:find("Mario") and last:find("Quest 1098"), "notice printed: " .. tostring(last))
-- notices off → silent
ns.db.settings.matchNotices = false
local n = #STUB.printed
STUB.Fire("QUEST_ACCEPTED", 1098)
assert(#STUB.printed == n, "no notice when off")
