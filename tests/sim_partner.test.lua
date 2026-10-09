STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
STUB.player.realm = "Classic Beta PvP"
STUB.ambiguateKeepsRealm = true
STUB.player.level = 22
local P = ns.Partner
SlashCmdList["LEVELMATES"]("sim")
local sentBefore = #STUB.sent
SlashCmdList["LEVELMATES"]("sim pal")
assert(P.Marked("Luis") and P.Marked("Mario"), "two fake partners")
assert(#STUB.sent == sentBefore, "the simulation sends nothing")
P.SetOn(true)
assert(P.Matches("Luis") and not P.Matches("Mario"), "Luis (22) matches, Mario (30) does not")
SlashCmdList["LEVELMATES"]("sim off")
assert(not P.Marked("Luis") and not P.Marked("Mario"), "sim off clears them")
