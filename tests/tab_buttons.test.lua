-- the five sections as wide buttons in the top band: the icon and its name; the chosen one lit
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local B, L = ns.Board, ns.L
B.Toggle()
local labels = { home = L.TAB_HOME, mates = L.TAB_MATES, lfg = L.TAB_LFG, guild = L.TAB_GUILD, journal = L.TAB_JOURNAL }
local total = 0
for _, key in ipairs(B.TAB_KEYS) do
	local b = B.tabs[key]
	assert(b.text and b.text.text == labels[key], key .. ": its name on the button: " .. tostring(b.text and b.text.text))
	assert(b.icon and b.icon:IsShown(), key .. ": its icon")
	assert(b:GetWidth() > 60, key .. ": wide enough for icon and name")
	total = total + b:GetWidth() + 6
end
-- they fit between the portrait and the Discord button
assert(total <= B.WIDTH - 66 - (30 + 170 + 12 + 80) - 12, "the row fits: " .. total)
-- the chosen one is lit, the others not
assert(B.tabs.home.selected and not B.tabs.mates.selected, "Home lit")
B.tabs.lfg.scripts.OnClick(B.tabs.lfg)
assert(B.tab == "lfg" and B.tabs.lfg.selected and not B.tabs.home.selected, "Groups lit")

-- the book draws above the action bars (a HIGH window, as the dungeon panel beside it)
assert(B.frame:GetFrameStrata() == "HIGH", "the book above the action bars: " .. tostring(B.frame:GetFrameStrata()))
