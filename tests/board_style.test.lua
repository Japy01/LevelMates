-- Board look: height follows the number of rows, title counts mates, the sorted header shows its direction,
-- group and level are colour-coded, rows are striped.
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local C, B, L = ns.Comm, ns.Board, ns.L
STUB.player.level = 20
local function hb(name, level, z, g, s) STUB.Receive("LVLM", C.Encode("hb", { l = level, z = z, g = g or 0, s = s or 0 }), "GUILD", name .. "-Testrealm") end
hb("Mario", 30, 1421, 1, 1); hb("Ana", 12, 1412); hb("Luis", 22, 1421, 1, 0)
B.Toggle()

local function same(a, b) return a and b and a[1] == b[1] and a[2] == b[2] and a[3] == b[3] end
assert(B.frame:GetHeight() == B.CHROME + (6 + 3) * 16, "compact with few mates: " .. tostring(B.frame:GetHeight()))
assert(B.frame.TitleText.text == L.BOARD_TITLE .. " (3)", "title counts mates: " .. tostring(B.frame.TitleText.text))
assert(B.headText[2].text == L.COL_LEVEL .. " v" and B.headText[3].text == L.COL_ZONE, "level header shows high-to-low: " .. tostring(B.headText[2].text))
B.headers.level.scripts.OnClick(B.headers.level)
assert(B.headText[2].text == L.COL_LEVEL .. " ^", "ascending marker: " .. tostring(B.headText[2].text))
B.headers.zone.scripts.OnClick(B.headers.zone)
assert(B.headText[3].text == L.COL_ZONE .. " ^" and B.headText[2].text == L.COL_LEVEL, "marker moves to zone: " .. tostring(B.headText[3].text))
B.headers.level.scripts.OnClick(B.headers.level)   -- back to level, high to low: Mario, Luis, Ana
assert(B.rows[1].name.text == "Mario" and B.rows[2].name.text == "Luis" and B.rows[3].name.text == "Ana", "order for the colour checks")
assert(same(B.rows[1].group.color, B.GROUP_COLORS.open), "slot free is green")
assert(same(B.rows[2].group.color, B.GROUP_COLORS.full), "group full is red")
assert(same(B.rows[3].group.color, B.GROUP_COLORS.solo), "solo is grey")
assert(same(B.rows[2].level.color, B.LEVEL_COLORS.near), "within 5 levels of mine stands out")
assert(same(B.rows[1].level.color, B.LEVEL_COLORS.far) and same(B.rows[3].level.color, B.LEVEL_COLORS.far), "others are muted")
assert(B.rows[1].bg and B.rows[2].bg, "rows have a background texture for striping")
-- grows with the list, capped at the 20 rows
for i = 1, 9 do hb("Extra" .. i, 10 + i, 1421) end
B.Refresh()
assert(B.frame:GetHeight() == B.CHROME + (12 + 3) * 16, "twelve mates: " .. tostring(B.frame:GetHeight()))
for i = 10, 30 do hb("Extra" .. i, 10, 1421) end
B.Refresh()
assert(B.frame:GetHeight() == B.CHROME + (20 + 3) * 16, "capped at 20 rows: " .. tostring(B.frame:GetHeight()))
-- every column fits inside the window (the XP/h column used to hang over the right edge)
do
	local total = B.MARGIN
	for i, w in ipairs(B.COLS) do total = total + w + (i > 1 and B.GAP or 0) end
	assert(total <= B.WIDTH - 10, "columns end at " .. total .. " but the window is " .. B.WIDTH .. " wide")
	assert(B.frame:GetWidth() == B.WIDTH, "window uses the declared width")
	assert(B.rows[1].button:GetWidth() == total - B.MARGIN, "row click area spans the columns: " .. tostring(B.rows[1].button:GetWidth()))
end
-- bottom controls stay inside the inset's bottom margin instead of overlapping its border
assert(B.helpButton:GetHeight() + 4 <= B.BOTTOM, "help button fits under the inset: " .. B.helpButton:GetHeight() .. " vs " .. B.BOTTOM)
assert(B.nearCheck:GetHeight() + 3 <= B.BOTTOM, "filter box fits under the inset")
