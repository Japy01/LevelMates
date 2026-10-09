STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
local D, L = ns.Dungeons, ns.L
assert(#D.list == 6, "six confirmed dungeons, got " .. #D.list)
assert(D.Get(2).min == 13 and D.Get(2).max == 18, "Ragefire Chasm is 13-18 in the journal")
assert(D.Get(1).min == 13 and D.Get(1).max == 20, "Hall of Thanes 13-20")
assert(D.Get(6).min == 20 and D.Get(6).max == 30, "Shadowfang Keep 20-30")
assert(D.Get(99) == nil, "unknown id")
assert(D.Name(2) == L.DUNGEON_RAGEFIRE_CHASM and D.Name(2) ~= "DUNGEON_RAGEFIRE_CHASM", "name goes through the locale")
assert(D.Name(99) == "#99", "unknown id has a visible fallback")
assert(D.Fits(2, 13) and D.Fits(2, 18) and not D.Fits(2, 12) and not D.Fits(2, 19), "range is inclusive")
assert(not D.Fits(99, 15), "unknown never fits")
for _, d in ipairs(D.list) do assert(d.id >= 1 and d.id <= 99 and d.min <= d.max, "ids fit the wire format: " .. d.key) end
