-- crafters in item tooltips (three names, online first, "+N"); a hint to train when a rank is at its cap
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(30)
local C, L, RC, B = ns.Comm, ns.L, ns.Recipes, ns.Board
for _, n in ipairs({ "Mario", "Ana", "Luis", "Pepe", "Zoe" }) do
	STUB.guildMembers[n] = true
	STUB.Receive("LVLM2", C.Encode("hb", { l = 30, z = 1412, c = "MAGE" }), "GUILD", n .. "-Testrealm")
	STUB.Receive("LVLM2", C.Encode("rcp", { p = 171, r = 120, m = 150, i = RC.Encode({ 858 }) }), "GUILD", n .. "-Testrealm")
end
ns.Roster.InvalidateGuildRoster()
STUB.Receive("LVLM2", C.Encode("bye", {}), "GUILD", "Zoe-Testrealm")   -- offline now
GameTooltip.lines = {}
STUB.TooltipPost(Enum.TooltipDataType.Item, GameTooltip, { id = 858 })
local line
for _, l in ipairs(GameTooltip.lines) do if l:find(L.RC_TOOLTIP:gsub("%%s.*", ""), 1, true) then line = l end end
assert(line and line:find("+2", 1, true) and not line:find("Zoe", 1, true), "three names, online first, +2: " .. tostring(line))
STUB.TooltipPost(Enum.TooltipDataType.Item, GameTooltip, nil)   -- no data: no error
STUB.TooltipPost(Enum.TooltipDataType.Item, GameTooltip, { id = 1 })   -- nobody crafts it: nothing
-- train hint
assert(ns.Professions.TrainHint(75, 75) == L.TRAIN_JOURNEYMAN and ns.Professions.TrainHint(150, 150) == L.TRAIN_EXPERT and ns.Professions.TrainHint(225, 225) == L.TRAIN_ARTISAN, "hints")
assert(ns.Professions.TrainHint(300, 300) == nil and ns.Professions.TrainHint(74, 75) == nil, "none at 300 or below the cap")
ns.Professions.AddSample("Mario", { { id = 171, rank = 75, max = 75 } })
B.Toggle(); B.ShowTab("crafts")
local shown = false
for _, r in ipairs(B.rows) do if r.button:IsShown() and r.xph.text and r.xph.text:find(L.TRAIN_JOURNEYMAN, 1, true) then shown = true end end
assert(shown, "the hint on the row")
