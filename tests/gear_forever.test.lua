-- Forever's model has no SetCustomRace (measured): someone out of sight is shown as their class crest and a note,
-- never an empty hole or my own body in their clothes
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(30)
local C, L, GE = ns.Comm, ns.L, ns.Gear
STUB.atlases["classicon-warrior"] = true
STUB.Receive("LVLM2", C.Encode("hb", { l = 30, z = 1412, c = "WARRIOR" }), "GUILD", "Mario-Testrealm")
STUB.Receive("LVLM2", C.Encode("eq", { g = GE.Encode({ [1] = { id = 9001, il = 33, en = 0 } }), a = 33, r = 1, x = 3 }), "GUILD", "Mario-Testrealm")
ns.GearWindow.Open("Mario")
local GW = ns.GearWindow
GW.model.SetCustomRace = false   -- as on Forever
GW.model.unit, GW.model.tried = nil, nil
GW.Open("Mario")
assert(not GW.model:IsShown(), "no model")
assert(GW.away:IsShown() and GW.away.crest.atlas == "classicon-warrior" and GW.away.text.text == L.GEAR_AWAY, "his class crest and a note")
assert(GW.model.unit ~= "player", "not my body in his clothes")
-- where the game can (SetCustomRace there): the model, no crest
GW.model.SetCustomRace = nil
GW.Open("Mario")
assert(GW.model:IsShown() and not GW.away:IsShown(), "the model where it works")
