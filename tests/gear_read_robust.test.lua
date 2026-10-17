-- my gear read: an empty read never wipes a filled one (Forever can hand the item links as secret values for a
-- while, e.g. in an instance); it is tried again later, after a zone change, and when Home shows no gear; the report
-- says what the last read found
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
local GE = ns.Gear
STUB.gear[1] = "|cff1eff00|Hitem:9001:0:0:0:0:0:0:0:20|h[Casco]|h|r"
STUB.gear[5] = "|cff1eff00|Hitem:9005:0:0:0:0:0:0:0:20|h[Peto]|h|r"
STUB.ilvl[9001], STUB.ilvl[9005] = 20, 22
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(3)
assert(GE.Mine() and GE.Mine().filled == 2 and GE.Mine().avg == 21, "read: two items")
-- the links come back secret: the read keeps what it had and says so
local SECRET = setmetatable({}, {})
issecretvalue = function(v) return v == SECRET end
local real = GetInventoryItemLink
GetInventoryItemLink = function(unit, slot) if STUB.gear[slot] then return SECRET end end
STUB.Fire("PLAYER_EQUIPMENT_CHANGED", 1); STUB.Advance(3)
assert(GE.Mine().filled == 2 and GE.Mine().avg == 21, "a secret read keeps the old gear: " .. tostring(GE.Mine().filled))
assert(GE.lastRead and GE.lastRead.secret == 2 and GE.lastRead.parsed == 0, "the read noted the secrets: " .. tostring(GE.lastRead and GE.lastRead.secret))
assert(ns.Report.Text():find("2/17", 1, true), "the report tells the last good read")
-- a plain empty read (nothing worn, nothing secret) with gear before: kept too, tried again later
GetInventoryItemLink = function() return nil end
STUB.Fire("PLAYER_EQUIPMENT_CHANGED", 1); STUB.Advance(3)
assert(GE.Mine().filled == 2, "an empty read keeps the old gear")
-- the links are back: a zone change reads again
GetInventoryItemLink = real
STUB.gear[5] = nil
STUB.Fire("ZONE_CHANGED_NEW_AREA"); STUB.Advance(3)
assert(GE.Mine().filled == 1 and GE.Mine().avg == 20, "read again: one item now")
-- Home with no gear asks for a read
ns.char.gear = nil
ns.Board.Toggle(); ns.Board.ShowTab("home"); STUB.Advance(3)
assert(GE.Mine() and GE.Mine().filled == 1, "Home with no gear: read")
