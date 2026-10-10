STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
ns.db.settings.style = "classic"   -- the game's own frames
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local B = ns.Board
B.Toggle()
assert(B.frame.Tabs and #B.frame.Tabs == #B.TAB_KEYS and B.frame.numTabs == #B.TAB_KEYS, "classic tabs, one per key")
for i, key in ipairs(B.TAB_KEYS) do
	assert(B.tabs[key].template == "PanelTabButtonTemplate" and B.frame.Tabs[i] == B.tabs[key], "classic tab " .. key)
end
local first, second = B.tabs[B.TAB_KEYS[1]], B.tabs[B.TAB_KEYS[2]]
assert(first.point[1] == "TOPLEFT" and first.point[2] == B.frame and first.point[3] == "BOTTOMLEFT", "hanging under the window")
assert(second.point[1] == "LEFT" and second.point[2] == first, "side by side")
B.tabs.journal.scripts.OnClick(B.tabs.journal)
assert(B.frame.selectedTab == 3 and B.tabs.journal.enabled == false and B.tabs.mates.enabled == true, "journal selected")
assert(ns.char.boardTab == "journal", "remembered")
B.ShowTab("nonsense")
assert(B.tab == "mates" and B.frame.selectedTab == 1, "unknown keys fall back to guildmates")
