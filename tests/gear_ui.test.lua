-- the card: item level line and a Gear button; the Gear window (paper doll, model); builds of every class
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(30)
local C, L, MC, GE = ns.Comm, ns.L, ns.MateCard, ns.Gear
STUB.Receive("LVLM2", C.Encode("hb", { l = 30, z = 1412, c = "WARRIOR" }), "GUILD", "Mario-Testrealm")
STUB.Receive("LVLM2", C.Encode("eq", { g = GE.Encode({ [1] = { id = 9001, il = 33, en = 0 }, [16] = { id = 9016, il = 35, en = 1897 } }), a = 34, r = 1, x = 2 }), "GUILD", "Mario-Testrealm")
MC.Show("Mario")
local text = table.concat(MC.Lines("Mario"), "\n")
assert(text:find(string.format(L.GEAR_LINE, 34, 2), 1, true), "item level line: " .. text)
assert(MC.gear:IsShown(), "a Gear button")
MC.gear.scripts.OnClick(MC.gear)
local GW = ns.GearWindow
assert(GW.frame:IsShown() and GW.slots[1] and GW.slots[19], "the window, nineteen slots")
assert(GW.slots[1].icon.texture == 1000 + 9001 and GW.slots[1].itemId == 9001, "slot 1 shows his item")
GW.slots[16].scripts.OnEnter(GW.slots[16])
assert(GameTooltip.link or GameTooltip.lines, "a tooltip on enter")
assert(GW.model.race == 1 and GW.model.sex == 0 and #GW.model.tried == 2, "the model, dressed: " .. tostring(GW.model.race))
-- without gear: no line, no button
STUB.Receive("LVLM2", C.Encode("hb", { l = 20, z = 1412, c = "MAGE" }), "GUILD", "Ana-Testrealm")
MC.Show("Ana")
assert(not MC.gear:IsShown() and not table.concat(MC.Lines("Ana"), "\n"):find(string.format(L.GEAR_LINE, 0, 0), 1, true), "no gear: nothing")
-- builds of every class on cards (I am a warrior); the Class tab only mine
STUB.Receive("LVLM2", C.Encode("tb", { c = "MAGE", s = 62, l = 20, p = "1001:11", b = "CODEana" }), "GUILD", "Ana-Testrealm")
assert(ns.Builds.Of("Ana") and ns.Builds.Of("Ana").b == "CODEana", "her build, though not my class")
MC.Show("Ana")
assert(MC.build:IsShown(), "View build on her card")
for _, e in ipairs(ns.Builds.List()) do assert(e.name ~= "Ana", "the Class tab: only my class") end
