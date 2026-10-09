STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
STUB.player.realm = "Classic Beta PvP"
STUB.ambiguateKeepsRealm = true
STUB.player.level = 15
local sentBefore = #STUB.sent
SlashCmdList["LEVELMATES"]("sim")
SlashCmdList["LEVELMATES"]("sim lfg")
local list = ns.LFG.List()
assert(#list == 2, "two fake ads: " .. #list)
assert(#STUB.sent == sentBefore, "the simulation sends nothing")
local names = {}
for _, id in ipairs(list) do names[ns.LFG.ads[id].name] = true end
assert(names.Mario and names.Luis, "from Mario and Luis")

SlashCmdList["LEVELMATES"]("lfg")
assert(ns.Board.frame:IsShown() and ns.Board.tab == "lfg", "/lm lfg opens the Dungeons tab")

SlashCmdList["LEVELMATES"]("sim off")
assert(#ns.LFG.List() == 0 and #ns.Roster.List() == 0, "sim off removes the ads and the mates")
