STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local B = ns.Board
RAID_CLASS_COLORS.WARRIOR = { r = 0.78, g = 0.61, b = 0.43 }
STUB.player.level = 20
ns.char.skills = { [171] = { name = "Alchemy", rank = 50 } }
assert(ns.Wishlist.Add("|cff1eff00|Hitem:2589::::::::20:::::::|h[Linen]|h|r"))
assert(ns.Personal.Set(30, 7))
local function mineRow() for i = 1, #B.rows do local r = B.rows[i]; if r.button:IsShown() and r.name.text:gsub("^%s+", "") == "Tester" then return r end end end
B.ShowTab("crafts")
do
	local CV, mine = ns.CraftsView, nil
	for _, it in ipairs(CV.profs.items) do if it:IsShown() then CV.Select(it.prof) end end
	for _, r in ipairs(CV.rows) do if r:IsShown() and r.name.text == "Tester" then mine = r end end
	local ir, ig = ns.Skin.Ink(0.78, 0.61)
	assert(mine and math.abs(mine.name.color[1] - ir) < 1e-9 and math.abs(mine.name.color[2] - ig) < 1e-9, "my name in my class colour (in ink) on crafts")
end
for _, tab in ipairs({ "wishes", "goals" }) do
	B.ShowTab(tab)
	local r = mineRow()
	local ir, ig = ns.Skin.Ink(0.78, 0.61)
	assert(r and math.abs(r.name.color[1] - ir) < 1e-9 and math.abs(r.name.color[2] - ig) < 1e-9, "my name in my class colour (in ink) on " .. tab)
end
