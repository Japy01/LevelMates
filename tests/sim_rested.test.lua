STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
STUB.player.realm = "Classic Beta PvP"
STUB.ambiguateKeepsRealm = true
local X = ns.Rested
SlashCmdList["LEVELMATES"]("sim")
local sentBefore = #STUB.sent
SlashCmdList["LEVELMATES"]("sim rested")
assert(X.Of("Mario") == 80 and X.Of("Luis") == 150, "fake shared values")
assert(#STUB.sent == sentBefore, "the simulation sends nothing")
SlashCmdList["LEVELMATES"]("sim off")
assert(X.Of("Mario") == nil and X.Of("Luis") == nil, "sim off clears them")
