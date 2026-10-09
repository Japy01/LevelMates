STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local J = ns.Journal
J.Add("quest", { id = 1, name = "Real quest" })
local sentBefore = #STUB.sent
SlashCmdList["LEVELMATES"]("sim diario")
assert(J.Count() == 8, "seven sample entries, one per kind: " .. J.Count())
local kinds = {}
for _, e in ipairs(J.List("all", "")) do kinds[e.k] = true end
for _, k in ipairs(J.KINDS) do assert(kinds[k], "sample of kind " .. k) end
assert(#STUB.sent == sentBefore, "the simulation sends nothing")
SlashCmdList["LEVELMATES"]("sim off")
assert(J.Count() == 1 and J.List("all", "")[1].name == "Real quest", "sim off removes only the samples")
