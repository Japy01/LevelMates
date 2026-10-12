-- my recipes: compact encoding; read only from my own profession window, once things settle
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(30)
local RC = ns.Recipes
-- encoding
local ids, seen = {}, {}
for i = 1, 200 do local v = math.random(1, 9000000); if not seen[v] then seen[v] = true; ids[#ids + 1] = v end end
local back = RC.Decode(RC.Encode(ids))
table.sort(ids)
assert(back and #back == #ids, "round trip count")
for i = 1, #ids do assert(back[i] == ids[i], "round trip " .. i) end
local d = RC.Decode(RC.Encode({ 5, 3, 3, 9 }))
assert(#d == 3 and d[1] == 3 and d[3] == 9, "sorted, no repeats")
assert(RC.Decode("0") == nil and RC.Decode("a-0") == nil and RC.Decode("zz!") == nil, "garbage refused")
local many = {}; for i = 1, 801 do many[i] = i end
assert(RC.Decode(RC.Encode(many)) == nil, "more than 800 refused")
assert(#RC.Decode("") == 0, "empty is empty")
-- the scan: my window, settled
STUB.trade = { line = 171, rank = 120, max = 150, recipes = { { id = 2330, item = 118 }, { id = 2331, item = 858 }, { id = 7836, spell = true }, { id = 9999, item = 999, learned = false } } }
STUB.Fire("TRADE_SKILL_SHOW"); STUB.Advance(0.5); STUB.Fire("TRADE_SKILL_LIST_UPDATE"); STUB.Advance(0.5); STUB.Fire("TRADE_SKILL_LIST_UPDATE")
local scans = RC.scans
STUB.Advance(2)
local mine = RC.Mine()[171]
assert(mine and #mine.items == 2 and #mine.spells == 1 and mine.r == 120 and mine.m == 150, "two items, one enchant, rank")
assert(RC.scans == scans + 1, "three events, one read")
-- someone else's window: ignored
STUB.trade = { line = 164, rank = 200, max = 225, linked = true, recipes = { { id = 1, item = 2 } } }
STUB.Fire("TRADE_SKILL_SHOW"); STUB.Advance(2)
assert(not RC.Mine()[164], "a linked window is not mine")
-- an empty read never wipes a filled one
STUB.trade = { line = 171, rank = 120, max = 150, recipes = {} }
STUB.Fire("TRADE_SKILL_LIST_UPDATE"); STUB.Advance(2)
assert(#RC.Mine()[171].items == 2, "empty read ignored")
