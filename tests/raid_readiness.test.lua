STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local RR = ns.RaidReadiness
assert(not RR.Snapshot(5) and not RR.SetAccess(5, "yes"), "raid activities only")
local s = RR.Snapshot(101)
assert(s.access == "unknown" and s.lockouts.status == "unknown" and #s.items == 0)
assert(RR.SetAccess(101, "yes") and not RR.SetAccess(101, "maybe"))
assert(RR.SetItems(101, "13446:10, 13444:5"))
for _, text in ipairs({"1:0", "0:1", "1:1000", "1:2,1:3", "1:2,", ",1:2", "1:2,,2:1", "item:1", "1:2x"}) do assert(not RR.SetItems(101, text), text) end
local countCalls = 0
C_Item.GetItemCount = function(id, bank, uses, reagent, account)
 assert(not bank and not uses and not reagent and not account)
 countCalls = countCalls + 1
 return id == 13446 and 11 or 0
end
GetNumSavedInstances = function() return 2 end
GetSavedInstanceInfo = function(i)
 if i == 1 then return "Molten Core", 111, 3600, 1, true, false, 0, true end
 return "Dungeon", 222, 100, 1, true, false, 0, false
end
s = RR.Snapshot(101)
assert(s.access == "yes" and s.items[1].status == "enough" and s.items[2].status == "missing")
assert(s.items[1].required == 10 and s.items[2].required == 5, "invalid replacement leaves profile intact")
assert(s.lockouts.status == "cached" and #s.lockouts.rows == 1 and s.lockouts.rows[1].reset == 3600)
local before = #STUB.sent
assert(RR.Text(101):find(ns.L.READY_LIMITS, 1, true) and #STUB.sent == before, "snapshot sends nothing")
-- Protected, nil, infinite, negative and throwing API values stay unknown, never a pass.
local secret = {}
issecretvalue = function(v) return v == secret end
C_Item.GetItemCount = function() return secret end
GetNumSavedInstances = function() return secret end
s = RR.Snapshot(101)
assert(s.items[1].status == "unknown" and s.lockouts.status == "unknown")
C_Item.GetItemCount = function() error("unavailable") end
GetNumSavedInstances = function() error("unavailable") end
assert(RR.Snapshot(101).items[1].count == nil)
GetNumSavedInstances = function() return 1 end
GetSavedInstanceInfo = function() return secret, 1, 10, 1, true, false, 0, true end
assert(RR.Snapshot(101).lockouts.status == "unknown")
GetSavedInstanceInfo = function() return "Raid", 1, 10, 1, secret, false, 0, true end
assert(RR.Snapshot(101).lockouts.status == "unknown")
for _, value in ipairs({-1, math.huge, 0/0}) do
 C_Item.GetItemCount = function() return value end
 assert(RR.Snapshot(101).items[1].status == "unknown")
end
issecretvalue = nil
STUB.inCombat = true
local combatCalls = 0
GetNumSavedInstances = function() combatCalls = combatCalls + 1; return 0 end
C_Item.GetItemCount = function() combatCalls = combatCalls + 1; return 100 end
s = RR.Snapshot(101)
assert(s.combat and s.access == "unknown" and combatCalls == 0)
STUB.inCombat = false
GetNumSavedInstances = function() return 0 end
assert(RR.Snapshot(101).lockouts.status == "cached", "empty cache has no eligibility verdict")
STUB.now = STUB.now + RR.ACCESS_LIFE + 1
assert(RR.Snapshot(101).access == "unknown", "attestation expires")
local oldGuild = ns.GuildKey
ns.GuildKey = function() return "different-guild" end
assert(#RR.Snapshot(101).items == 0)
ns.GuildKey = oldGuild
assert(#RR.Snapshot(101).items == 2)
assert(RR.SetItems(101, "clear") and #RR.Snapshot(101).items == 0)
local opened
ns.DiscordCopy.OpenText = function(text) opened = text end
SlashCmdList.LEVELMATES("raidready access 101 no")
SlashCmdList.LEVELMATES("raidready items 101 13446:3")
SlashCmdList.LEVELMATES("raidready 101")
assert(opened:find(ns.L.READY_NO, 1, true) and opened:find("#13446", 1, true))
local combatFn = UnitAffectingCombat
UnitAffectingCombat = function() error("restricted") end
assert(RR.Snapshot(101).combat)
UnitAffectingCombat = combatFn
GetNumSavedInstances = function() return 1 end
GetSavedInstanceInfo = function() return "Extended raid", 1, 10, 1, false, true, 0, true end
s = RR.Snapshot(101)
assert(s.lockouts.rows[1].extended)
local items = {}; for i = 1, RR.MAX_ITEMS do items[i] = i .. ":1" end
assert(RR.SetItems(101, table.concat(items, ",")))
items[#items + 1] = "999:1"
assert(not RR.SetItems(101, table.concat(items, ",")) and #RR.Snapshot(101).items == RR.MAX_ITEMS)
-- Legacy item API remains supported if the modern API is absent.
C_Item.GetItemCount = nil
GetItemCount = function() return 0 end
assert(RR.Snapshot(101).items[1].status == "missing")
GetItemCount = nil
assert(RR.Snapshot(101).items[1].status == "unknown")
