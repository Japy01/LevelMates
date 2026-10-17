-- Rows with a picture (audit 2026-10-17): the journal, the wall, the goals and the wishes carry an icon per entry
-- (the item's own for items); sortable headers show the game's arrow texture instead of " v"/" ^"; the Members
-- list sorts by name, level, rank or last seen from its headers
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(30)
local B, L, C = ns.Board, ns.L, ns.Comm
local function shownRows() local out = {}; for _, r in ipairs(B.rows) do if r.button:IsShown() then out[#out + 1] = r end end; return out end

-- journal: a picture per kind
ns.Journal.Add("quest", { name = "Q1" }); ns.Journal.Add("death", { level = 10 })
B.Toggle(); B.ShowTab("journal")
local rows = shownRows()
assert(#rows == 2 and rows[1].icon:IsShown() and rows[2].icon:IsShown(), "journal rows with icons")
assert(rows[1].icon.texture ~= rows[2].icon.texture, "a death and a quest look different")
assert(rows[1].icon.texcoord and rows[1].icon.texcoord[1] > 0, "the icon's border trimmed")

-- the wall: the kind's picture; an item: the item's own
ns.Feed.AddSample("Mario", "lvl", 20); ns.Feed.AddSample("Mario", "itm", 9001)
B.ShowTab("feed")
rows = shownRows()
local lvl, itm
for _, r in ipairs(rows) do if r.button.feedItem == 9001 then itm = r elseif r.zone.text:find("20", 1, true) then lvl = r end end
assert(lvl and lvl.icon:IsShown() and lvl.icon.texture == ns.Dashboard.WallIcon("lvl"), "the level-up picture on the wall")
assert(itm and itm.icon.texture == C_Item.GetItemIconByID(9001), "the item's own icon")

-- wishes: the item's icon
ns.Wishlist.AddSample("Mario", { 9001 })
B.ShowTab("wishes")
rows = shownRows()
assert(#rows >= 1 and rows[1].icon:IsShown() and rows[1].icon.texture == C_Item.GetItemIconByID(9001), "a wish shows its item")

-- goals: a picture per goal type
ns.Goals.AddSample({ id = "g1", ty = "lvl", a = 30, s = math.floor(time() / 86400), e = math.floor(time() / 86400) + 7, by = "Jefa" })
B.ShowTab("goals")
rows = shownRows()
assert(#rows >= 1 and rows[1].icon:IsShown() and rows[1].icon.texture, "a goal row with its picture")

-- sort arrows on Guildmates: the texture, flipped for ascending; the header text stays clean
STUB.Receive("LVLM2", C.Encode("hb", { l = 24, z = 1421, c = "MAGE" }), "GUILD", "Mario-Testrealm")
B.ShowTab("mates")
assert(B.headText[2].text == L.COL_LEVEL, "no v/^ in the text: " .. tostring(B.headText[2].text))
assert(B.headArrows[2]:IsShown() and not B.headArrows[3]:IsShown(), "the arrow on the sorted column")
assert(B.headArrows[2].texture:find("SortArrow", 1, true), "the game's own arrow")
local down = B.headArrows[2].texcoord[3]
B.headers[2].scripts.OnClick(B.headers[2])
assert(B.headArrows[2].texcoord[3] ~= down, "ascending: flipped")
B.headers[3].scripts.OnClick(B.headers[3])
assert(B.headArrows[3]:IsShown() and not B.headArrows[2]:IsShown(), "the arrow moves to zone")

-- Members: sortable by name, level, rank, last seen
STUB.guildMembers = { Tester = true, Mario = true, Ana = true, Luis = true }
STUB.memberInfo = { Mario = { level = 30 }, Ana = { level = 25 }, Luis = { level = 40 }, Tester = { level = 20 } }
ns.Roster.InvalidateGuildRoster(); ns.Members.Invalidate()
B.ShowTab("members")
assert(not B.headArrows[2]:IsShown(), "no sort chosen: no arrow")
B.headers[2].scripts.OnClick(B.headers[2])
rows = shownRows()
assert(ns.char.memberSort and ns.char.memberSort.mode == "level" and rows[1].name.text:find("Luis", 1, true) and rows[#rows].name.text:find("Tester", 1, true), "by level, high first: " .. tostring(rows[1].name.text))
assert(B.headArrows[2]:IsShown(), "the arrow on level")
B.headers[2].scripts.OnClick(B.headers[2])
rows = shownRows()
assert(rows[1].name.text:find("Tester", 1, true), "low first: " .. tostring(rows[1].name.text))
B.headers[1].scripts.OnClick(B.headers[1])
rows = shownRows()
assert(ns.char.memberSort.mode == "name" and rows[1].name.text:find("Ana", 1, true), "by name: " .. tostring(rows[1].name.text))
print("ok")
