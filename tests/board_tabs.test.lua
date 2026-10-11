STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local B = ns.Board
B.Toggle()
assert(B.frame.Tabs and #B.frame.Tabs == #B.TAB_KEYS, "a tab per main key")
for i, key in ipairs(B.TAB_KEYS) do
	assert(B.tabs[key].skinTab and B.tabs[key].icon.texture and B.tabs[key].label == ns.L[B.TAB_LABELS[key]] and B.frame.Tabs[i] == B.tabs[key], "an icon tab with its name: " .. key)
end
local first, second = B.tabs[B.TAB_KEYS[1]], B.tabs[B.TAB_KEYS[2]]
assert(first.point[1] == "TOPLEFT" and first.point[2] == B.frame and first.point[3] == "TOPLEFT", "in the top band")
assert(second.point[1] == "LEFT" and second.point[2] == first, "side by side")
first.scripts.OnEnter(first)
assert(GameTooltip.lines[1] == ns.L.TAB_HOME, "its name on hover")
B.tabs.journal.scripts.OnClick(B.tabs.journal)
assert(B.frame.selectedTab == 5 and B.tabs.journal.enabled == false and B.tabs.mates.enabled == true, "journal selected")
assert(ns.char.boardTab == "journal", "remembered")
B.ShowTab("nonsense")
assert(B.tab == "home" and B.frame.selectedTab == 1, "unknown keys fall back to Home")
-- five main tabs; the Guild tab opens its last sub-section; old keys land inside it
assert(#B.TAB_KEYS == 5 and B.TAB_KEYS[1] == "home" and B.TAB_KEYS[4] == "guild", "five tabs")
B.tabs.guild.scripts.OnClick(B.tabs.guild)
assert(B.tab == "feed" and B.frame.selectedTab == 4 and B.subs.feed:IsShown() and not B.subtitle:IsShown(), "the wall first, sub-sections instead of the subtitle")
B.subs.crafts.scripts.OnClick(B.subs.crafts)
B.tabs.mates.scripts.OnClick(B.tabs.mates)
assert(not B.subs.crafts:IsShown(), "sub-sections only on the Guild tab")
B.tabs.guild.scripts.OnClick(B.tabs.guild)
assert(B.tab == "crafts", "back to the last sub-section")
SlashCmdList.LEVELMATES("metas")
assert(B.tab == "goals" and B.frame.selectedTab == 4, "/lm metas lands in the Guild tab")
B.frame:Hide(); B.Toggle()
assert(B.tab == "home" and B.frame.selectedTab == 1, "the board opens on Home")
