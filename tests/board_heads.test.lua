STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local B, J, L = ns.Board, ns.Journal, ns.L
STUB.player.level = 20
for _, tab in ipairs({ "mates", "lfg", "goals", "wishes" }) do
	B.ShowTab(tab)
	local k = string.upper(tab)
	assert(B.heading.text == L["HEAD_" .. k] and B.subtitle.text == L["SUB_" .. k], "heading and help for " .. tab)
	assert(not B.searchBox.Instructions or B.searchBox.Instructions.text == L["SEARCH_" .. k], "search hint for " .. tab)
end
B.ShowTab("journal")
assert(B.heading.text == L.HEAD_JOURNAL and B.subtitle.text == L.SUB_JOURNAL and J.Pace() == nil, "no pace yet")
J.Add("level", { level = 10, from = 9, took = 3600 })
J.Add("level", { level = 11, from = 10, took = 1800 })
J.Add("level", { level = 12, from = 11, took = 2400 })
J.Add("level", { level = 13, sim = true, from = 12, took = 10 })
local p = J.Pace()
assert(p and p.avg == 2600 and p.fastest == 11 and p.fastestTook == 1800 and p.toMax == 2600 * 40, "average, fastest, to 60")
B.Refresh()
assert(B.subtitle.text == J.PaceText() and J.PaceText():find(J.Duration(2600), 1, true), "pace as the journal's help line")
STUB.player.level = 60
assert(J.Pace().toMax == nil and not J.PaceText():find(L.PACE_TO_MAX:gsub("%%s", ""), 1, true), "no projection at 60")
