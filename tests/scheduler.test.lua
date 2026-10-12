-- one ticker for periodic jobs; views redraw at most twice a second, only while shown; roster events only on change
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local n = 0
ns.Every("t", 1, function() n = n + 1 end)
STUB.Advance(3.05)
assert(n == 3, "every second: " .. n)
ns.Cancel("t"); STUB.Advance(2); assert(n == 3, "cancelled")
local shown, draws = true, 0
ns.OnRedraw("v", function() return shown end, function() draws = draws + 1 end)
ns.Dirty("v"); assert(draws == 1, "the first at once")
for i = 1, 30 do ns.Dirty("v") end
assert(draws == 1, "the rest wait")
STUB.Advance(0.6); assert(draws == 2, "one more at the end of the window: " .. draws)
STUB.Advance(2); assert(draws == 2, "nothing left")
shown = false; ns.Dirty("v"); STUB.Advance(1); assert(draws == 2, "hidden: no redraw")
local C = ns.Comm
local fired = 0
ns.On("LM_ROSTER_CHANGED", function() fired = fired + 1 end)
STUB.Receive("LVLM2", C.Encode("hb", { l = 21, z = 1412, c = "MAGE" }), "GUILD", "Mario-Testrealm")
local f1 = fired
STUB.Receive("LVLM2", C.Encode("hb", { l = 21, z = 1412, c = "MAGE" }), "GUILD", "Mario-Testrealm")
assert(fired == f1, "the same heartbeat again: no event")
STUB.Receive("LVLM2", C.Encode("hb", { l = 22, z = 1412, c = "MAGE" }), "GUILD", "Mario-Testrealm")
assert(fired == f1 + 1, "a new level: an event")
