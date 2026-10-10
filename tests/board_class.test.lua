STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local B, L = ns.Board, ns.L
B.Toggle()
assert(B.WIDTH == 680 and B.frame:GetWidth() == 680, "a wider window for nine tabs")
local found
for i, key in ipairs(B.TAB_KEYS) do if key == "class" then found = i end end
assert(found and B.TAB_KEYS[found - 1] == "crafts", "the Class tab, after Professions")
assert(L.TAB_CLASS and L.HEAD_CLASS and L.SUB_CLASS and L.SEARCH_CLASS, "its texts")
B.ShowTab("class")
assert(B.tab == "class" and B.heading.text == L.HEAD_CLASS, "it opens")
