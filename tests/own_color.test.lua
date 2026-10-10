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
for _, tab in ipairs({ "crafts", "wishes", "goals" }) do
	B.ShowTab(tab)
	local r = mineRow()
	assert(r and r.name.color[1] == 0.78 and r.name.color[2] == 0.61, "my name in my class colour on " .. tab)
end
