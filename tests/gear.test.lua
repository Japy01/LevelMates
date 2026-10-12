-- my gear: read out of combat, my own average over 17 slots (filled only), shared; theirs stored
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(30)
local GE, C = ns.Gear, ns.Comm
local function item(id, ench) return "|cff1eff00|Hitem:" .. id .. ":" .. (ench or "") .. ":::::::20:::::::|h[I" .. id .. "]|h|r" end
-- 14 filled: slots 1-3, 5-12, 16, plus shirt (4) and tabard (19), off hand (17) empty
local ilvls = { [1] = 20, [2] = 18, [3] = 22, [5] = 24, [6] = 16, [7] = 20, [8] = 18, [9] = 14, [10] = 20, [11] = 15, [12] = 15, [16] = 30 }
for slot, il in pairs(ilvls) do STUB.gear[slot] = item(5000 + slot, slot == 16 and 1897 or nil); STUB.ilvl[5000 + slot] = il end
STUB.gear[4] = item(6000); STUB.ilvl[6000] = 1
STUB.gear[19] = item(6001); STUB.ilvl[6001] = 1
STUB.raceId, STUB.sex = 3, 3
local n = #STUB.sent
STUB.Fire("PLAYER_EQUIPMENT_CHANGED", 1); STUB.Advance(0.4); STUB.Fire("PLAYER_EQUIPMENT_CHANGED", 2); STUB.Advance(0.4); STUB.Fire("PLAYER_EQUIPMENT_CHANGED", 3)
local reads = GE.reads
STUB.Advance(2)
assert(GE.reads == reads + 1, "one read for a burst")
local mine = GE.Mine()
local sum, cnt = 0, 0
for _, il in pairs(ilvls) do sum = sum + il; cnt = cnt + 1 end
assert(mine.filled == cnt and mine.avg == math.floor(sum / cnt + 0.5), "average over the filled 17: " .. tostring(mine.avg))
assert(mine.slots[16].en == 1897 and mine.r == 3 and mine.x == 3, "enchant, race, sex")
-- round trip
local back = GE.Decode(GE.Encode(mine.slots))
assert(back[16].id == 5016 and back[16].il == 30 and back[16].en == 1897 and not back[17], "round trip")
-- shared
STUB.Advance(12)
local f
for i = #STUB.sent, n + 1, -1 do local k, ff = C.Decode(STUB.sent[i].msg); if k == "eq" then f = ff; break end end
assert(f and f.a == mine.avg and f.r == 3 and f.x == 3, "eq sent")
-- in combat: wait
STUB.inCombat = true
STUB.gear[1] = item(7001); STUB.ilvl[7001] = 40
STUB.Fire("PLAYER_EQUIPMENT_CHANGED", 1); STUB.Advance(3)
assert(GE.Mine().slots[1].id == 5001, "not in combat")
STUB.inCombat = false; STUB.Fire("PLAYER_REGEN_ENABLED"); STUB.Advance(3)
assert(GE.Mine().slots[1].id == 7001, "after the fight")
-- an item not loaded: its level is unknown and left out; read again when it arrives
STUB.gear[2] = item(7002); STUB.ilvl[7002] = nil
STUB.Fire("PLAYER_EQUIPMENT_CHANGED", 2); STUB.Advance(3)
assert(GE.Mine().slots[2].il == 0 and GE.Mine().filled == cnt - 1, "unknown level left out")
STUB.ilvl[7002] = 26
STUB.Fire("GET_ITEM_INFO_RECEIVED", 7002, true); STUB.Advance(3)
assert(GE.Mine().slots[2].il == 26, "read again when it arrives")
-- theirs
STUB.Receive("LVLM2", C.Encode("hb", { l = 30, z = 1412, c = "WARRIOR" }), "GUILD", "Mario-Testrealm")
STUB.Receive("LVLM2", C.Encode("eq", { g = GE.Encode({ [1] = { id = 9001, il = 33, en = 0 } }), a = 33, r = 1, x = 2 }), "GUILD", "Mario-Testrealm")
assert(GE.Of("Mario") and GE.Of("Mario").avg == 33 and GE.Of("Mario").slots[1].id == 9001, "Mario's gear")
-- sharing off
ns.db.settings.shareGear = false
n = #STUB.sent
STUB.gear[3] = item(7003); STUB.ilvl[7003] = 30
STUB.Fire("PLAYER_EQUIPMENT_CHANGED", 3); STUB.Advance(12)
for i = n + 1, #STUB.sent do assert((C.Decode(STUB.sent[i].msg)) ~= "eq", "sharing off: nothing") end
