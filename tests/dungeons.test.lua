STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
local D, L = ns.Dungeons, ns.L
assert(#D.list == 14, "fourteen dungeons: " .. #D.list)
local seen = {}
for _, d in ipairs(D.list) do
	assert(not seen[d.id] and d.id >= 1 and d.id <= 14, "unique ids")
	seen[d.id] = true
	assert(type(L[d.key]) == "string" and L[d.key] ~= "", "named: " .. d.key)
	assert(d.min < d.max, "a level range")
end
assert(D.Name(5) == "The Deadmines" and D.Name(8) == "The Stockade" and D.Get(14).min == 33 and D.Get(14).max == 41, "known rows")
local sorted = D.Sorted()
for i = 2, #sorted do
	local a, b = sorted[i - 1], sorted[i]
	assert(a.min < b.min or a.min == b.min and (a.max < b.max or a.max == b.max and a.id < b.id), "by level")
end
local tex, coords = D.Art(2)
assert(tex == "Interface\\Glues\\LoadingScreens\\LoadScreenRagefireChasm" and coords[3] == 0.25, "game loading screen, cropped")
assert(D.Art(8) == 131870, "file ids work too")
-- only the game's own art: Forever's loading screens for its new dungeons, the Monastery screen for the Library
assert(D.Art(1) == 7963781 and D.Art(3) == 7963782, "Forever's own loading screens")
assert(D.Art(14) == "Interface\\Glues\\LoadingScreens\\LoadScreenScarletHalls", "the Library uses the Scarlet Halls screen")
for _, d in ipairs(D.list) do
	local tex = D.Art(d.id)
	assert(tex and not tostring(tex):find("AddOns", 1, true), "never another addon's files: " .. d.key)
end
