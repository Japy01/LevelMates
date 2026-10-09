STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local W = ns.Wishlist
local sentBefore = #STUB.sent
SlashCmdList["LEVELMATES"]("sim deseos")
assert(#W.List() == 4 and #W.WantedBy(2589) == 1, "two wishes each for Mario and Ana: " .. #W.List())
assert(#STUB.sent == sentBefore, "the simulation sends nothing")
SlashCmdList["LEVELMATES"]("sim off")
assert(#W.List() == 0, "sim off removes them")
