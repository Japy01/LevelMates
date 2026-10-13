-- Board look: height follows the number of rows, title counts mates, the sorted header shows its direction,
-- group and level are colour-coded, rows are striped.
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local C, B, L = ns.Comm, ns.Board, ns.L
STUB.player.level = 20
CLASS_ICON_TCOORDS = { MAGE = { 0.25, 0.5, 0, 0.25 }, WARRIOR = { 0, 0.25, 0, 0.25 } }
STUB.atlases["classicon-mage"] = true   -- Forever draws class icons from atlases; warrior is missing on purpose to exercise the fallback
local function hb(name, level, z, g, s, class) STUB.Receive("LVLM2", C.Encode("hb", { l = level, z = z, g = g or 0, s = s or 0, c = class }), "GUILD", name .. "-Testrealm") end
hb("Mario", 30, 1421, 1, 1, "MAGE"); hb("Ana", 12, 1412, 0, 0, "WARRIOR"); hb("Luis", 22, 1421, 1, 0)
B.Toggle(); B.ShowTab("mates")   -- the board opens on Home; this test is about Guildmates

local function same(a, b) if not (a and b) then return false end; local r, g, bl = ns.Skin.Ink(b[1], b[2], b[3]); return math.abs(a[1] - r) < 1e-9 and math.abs(a[2] - g) < 1e-9 and math.abs(a[3] - bl) < 1e-9 end   -- written in ink on the page
assert(B.frame:GetHeight() == B.CHROME + (B.MIN_ROWS + 3) * B.ROW_H, "compact with few mates: " .. tostring(B.frame:GetHeight()))
assert(B.frame.TitleText.text == L.BOARD_TITLE .. " - Test Guild (3)", "title counts mates: " .. tostring(B.frame.TitleText.text))
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
assert(B.frame:GetHeight() == B.CHROME + (12 + 3) * B.ROW_H, "twelve mates: " .. tostring(B.frame:GetHeight()))
for i = 10, 30 do hb("Extra" .. i, 10, 1421) end
B.Refresh()
assert(B.frame:GetHeight() == B.CHROME + (B.ROWS + 3) * B.ROW_H, "capped at 20 rows: " .. tostring(B.frame:GetHeight()))
-- every column fits inside the window (the XP/h column used to hang over the right edge)
do
	local total = B.MARGIN
	for i, w in ipairs(B.COLS) do total = total + w + (i > 1 and B.GAP or 0) end
	assert(total <= B.WIDTH - 10, "columns end at " .. total .. " but the window is " .. B.WIDTH .. " wide")
	assert(B.frame:GetWidth() == B.WIDTH, "window uses the declared width")
	assert(B.rows[1].button:GetWidth() == B.WIDTH - 2 * B.MARGIN, "row click area spans the page: " .. tostring(B.rows[1].button:GetWidth()))
end
-- bottom controls stay inside the inset's bottom margin instead of overlapping its border
assert(B.helpButton:GetHeight() + 4 <= B.BOTTOM, "help button fits under the inset: " .. B.helpButton:GetHeight() .. " vs " .. B.BOTTOM)
assert(B.nearCheck:GetHeight() + 3 <= B.BOTTOM, "filter box fits under the inset")

-- the guild name follows the player: no guild, a new guild
STUB.player.guild = nil; B.Refresh()
assert(B.frame.TitleText.text:find("^" .. L.BOARD_TITLE .. " %(") , "no guild: just the addon name: " .. tostring(B.frame.TitleText.text))
STUB.player.guild = "Los Hermanos"; STUB.Fire("PLAYER_GUILD_UPDATE", "player")
assert(B.frame.TitleText.text:find(" - Los Hermanos (", 1, true), "title follows a guild change: " .. tostring(B.frame.TitleText.text))
-- bigger than before: readable rows and a wide window
assert(B.ROW_H >= 20 and B.WIDTH >= 560 and B.MIN_ROWS >= 8, "roomier window")

-- class icon: shown with the class's coordinates when known, hidden otherwise
B.Refresh()
local first = B.rows[1]
assert(first.name.text == "Mario" and first.icon:IsShown(), "icon for a known class")
assert(first.icon.atlas == "classicon-mage", "uses the class atlas when the client has it: " .. tostring(first.icon.atlas))
local ana
for i = 1, #B.rows do if B.rows[i].name.text == "Ana" then ana = B.rows[i] end end   -- the list has grown by now
assert(ana and ana.icon:IsShown() and ana.icon.atlas == nil and ana.icon.texcoord and ana.icon.texcoord[2] == 0.25, "falls back to the circles sheet and its coordinates")
assert(not B.rows[2].icon:IsShown(), "no icon when the class is unknown")
assert(not B.rows[#B.rows].icon:IsShown(), "no icon on an empty row")
