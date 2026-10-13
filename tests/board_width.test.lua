-- a wider book (900); columns grow in proportion; five dungeon cards a row; every tab still draws
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
ns.char.groupsView = "catalog"   -- these checks are about the catalogue cards (the Groups section opens on Groups)
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(30)
local B = ns.Board
B.Toggle()
assert(B.frame:GetWidth() == 900, "900 wide: " .. tostring(B.frame:GetWidth()))
B.ShowTab("mates")
local sum = 0
for i = 1, 5 do sum = sum + B.headText[i]:GetWidth() end
local usable = B.LIST_W - 4 * B.GAP
assert(math.abs(sum - usable) <= 2, "the columns fill the page: " .. sum .. " of " .. usable)
B.ShowTab("lfg")
assert(B.CARD_COLS == 5, "five cards a row")
local c1, c6 = B.cards[1], B.cards[6]
assert(c6.point[4] == c1.point[4], "card 6 under card 1")
for _, k in ipairs(B.CONTENT_KEYS) do B.ShowTab(k) end
