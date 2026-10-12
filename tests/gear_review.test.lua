-- project 6 final review fixes
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(30)
local C, L, MC, GE = ns.Comm, ns.L, ns.MateCard, ns.Gear
STUB.Receive("LVLM2", C.Encode("hb", { l = 30, z = 1412, c = "WARRIOR" }), "GUILD", "Mario-Testrealm")
-- 1: the open card updates when his gear arrives
MC.Show("Mario")
assert(not MC.gear:IsShown(), "no gear yet")
STUB.Receive("LVLM2", C.Encode("eq", { g = GE.Encode({ [1] = { id = 9001, il = 33, en = 0 } }), a = 33, r = 1, x = 3 }), "GUILD", "Mario-Testrealm")
STUB.Advance(1)
assert(MC.gear:IsShown() and MC.frame.body.text:find(string.format(L.GEAR_LINE, 33, 1), 1, true), "1: updated")
-- 3: the button does not cover the text
assert(MC.frame.body:GetWidth() <= 260, "3: the text leaves room for the button")
-- 2: the model, out of sight: a player model first, then race and sex
MC.gear.scripts.OnClick(MC.gear)
local m = ns.GearWindow.model
assert(m.unit == "player" and m.race == 1 and m.sex == 1 and #m.tried == 1, "2: loaded, then dressed as him")
-- 4: my own card shows me
STUB.gear[1] = "|Hitem:5001::::|h[I]|h"; STUB.ilvl[5001] = 20
STUB.Fire("PLAYER_EQUIPMENT_CHANGED", 1); STUB.Advance(3)
ns.GearWindow.Open(ns.Me())
assert(m.unit == "player" and m.race == nil, "4: my real model")
