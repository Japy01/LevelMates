STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local P = ns.Professions
local sentBefore = #STUB.sent
SlashCmdList["LEVELMATES"]("sim oficios")
assert(#P.List() == 3, "Mario's two and Ana's one: " .. #P.List())
assert(#STUB.sent == sentBefore, "the simulation sends nothing")
SlashCmdList["LEVELMATES"]("sim off")
assert(#P.List() == 0, "sim off removes them")
