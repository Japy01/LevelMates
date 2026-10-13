-- inspect: the gear of my target or a group member, even without LevelMates; one request at a time, only my own
-- answer, the same person at the end; the gear window says how old its data is and where it came from
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(30)
local C, L, GE, GW, MC = ns.Comm, ns.L, ns.Gear, nil, ns.MateCard
STUB.units.target = { name = "Pepe" }
local guids = { target = "Player-1-PEPE" }
UnitGUID = function(u) return guids[u] or "Player-1-TESTER" end
local asked = {}
CanInspect = function(u) return u == "target" end
NotifyInspect = function(u) asked[#asked + 1] = u end
local theirGear = { [1] = "|cff1eff00|Hitem:9001:0:0:0:0:0:0:0:20|h[Casco]|h|r", [5] = "|cff1eff00|Hitem:9005:0:0:0:0:0:-1043:0:20|h[Peto]|h|r" }
local realLink = GetInventoryItemLink
GetInventoryItemLink = function(unit, slot) if unit == "target" then return theirGear[slot] end; return realLink(unit, slot) end
STUB.ilvl[9001], STUB.ilvl[9005] = 22, 24

-- Pepe has no LevelMates: his card offers Gear while he is my target
STUB.Receive("LVLM2", C.Encode("hb", { l = 25, z = 1412, c = "ROGUE" }), "GUILD", "Pepe-Testrealm")   -- (in the guild list)
ns.db.gear = nil
MC.Show("Pepe")
assert(MC.gear:IsShown(), "Gear while he is my target")
MC.gear.scripts.OnClick(MC.gear)
GW = ns.GearWindow
assert(#asked == 1 and asked[1] == "target", "inspected")
assert(GW.frame:IsShown() and GW.frame.info.text == L.GEAR_INSPECTING, "waiting for the answer")
-- someone else's answer (another addon's inspect): ignored
STUB.Fire("INSPECT_READY", "Player-1-OTHER")
assert(GE.Of("Pepe") == nil, "not mine")
-- one at a time
GE.Inspect("target", "Pepe")
assert(#asked == 1, "one at a time")
STUB.Fire("INSPECT_READY", "Player-1-PEPE")
local g = GE.Of("Pepe")
assert(g and g.src == "inspect" and g.slots[1].id == 9001 and g.slots[5].sf == -1043 and g.avg == 23, "his gear, inspected")
assert(GW.frame.info.text:find(L.GEAR_SRC_INSPECT, 1, true), "the window says so: " .. tostring(GW.frame.info.text))
-- the target changed before the answer: not saved under his name
GE.Of("Pepe").t = 0
guids.target = "Player-1-PEPE"
GE.Inspect("target", "Pepe")
guids.target = "Player-1-LUIS"
STUB.Fire("INSPECT_READY", "Player-1-PEPE")
assert(GE.Of("Pepe").t == 0, "another target now: not saved")
-- no answer: free again after 8 s
STUB.Advance(9)
guids.target = "Player-1-PEPE"
local n = #asked
assert(GE.Inspect("target", "Pepe") and #asked == n + 1, "free again")

-- shared gear: its age and source; old in a warning colour
STUB.Receive("LVLM2", C.Encode("hb", { l = 30, z = 1412, c = "WARRIOR" }), "GUILD", "Mario-Testrealm")
STUB.Receive("LVLM2", C.Encode("eq", { g = GE.Encode({ [1] = { id = 9001, il = 33, en = 0 } }), a = 33, r = 1, x = 2 }), "GUILD", "Mario-Testrealm")
GW.Open("Mario")
assert(GW.frame.info.text:find(L.GEAR_SRC_SYNC, 1, true) and not GW.frame.info.text:find("|cff", 1, true), "fresh, shared")
GE.Of("Mario").t = time() - 5 * 86400
GW.Open("Mario")
assert(GW.frame.info.text:find("|cff", 1, true), "five days old: in a warning colour")
