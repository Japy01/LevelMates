STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
STUB.player.realm = "Classic Beta PvP"
STUB.ambiguateKeepsRealm = true
local G = ns.Goals
local sentBefore = #STUB.sent
SlashCmdList["LEVELMATES"]("sim metas")
assert(#G.List() == 3, "three sample goals: " .. #G.List())
assert(#STUB.sent == sentBefore, "the simulation sends nothing")
SlashCmdList["LEVELMATES"]("sim off")
assert(#G.List() == 0, "sim off removes them")

-- a simulated journal never completes a real goal (nor tells the guild)
STUB.iAmOfficer = true
assert(G.Create("dun", 2, nil, 3), "real dungeon goal")
local real = G.List()[1]
sentBefore = #STUB.sent
SlashCmdList["LEVELMATES"]("sim diario")
assert(not real.doneBy and #STUB.sent == sentBefore, "sim journal leaves real goals alone")
assert(G.Create("cnt", 10, "qst", 3), "real counter")
SlashCmdList["LEVELMATES"]("sim diario")
for _, g in ipairs(G.List()) do if g.ty == "cnt" then assert(G.MyContribution(g) == 0, "sim quests do not count") end end
