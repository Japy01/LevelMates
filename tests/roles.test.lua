-- a preferred role, shared; guessed from the class when unset
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(30)
local RO, C = ns.Roles, ns.Comm
assert(RO.Guess("WARRIOR") == "T" and RO.Guess("PRIEST") == "H" and RO.Guess("MAGE") == "D", "guesses")
assert(RO.Can("DRUID", "H") and RO.Can("PALADIN", "T") and not RO.Can("MAGE", "T") and RO.Can("MAGE", "D"), "who can")
STUB.Receive("LVLM2", C.Encode("hb", { l = 20, z = 1412, c = "PRIEST" }), "GUILD", "Mario-Testrealm")
local r, g = RO.Of("Mario"); assert(r == "H" and g, "Mario guessed healer")
STUB.Receive("LVLM2", C.Encode("rol", { r = "D" }), "GUILD", "Mario-Testrealm")
r, g = RO.Of("Mario"); assert(r == "D" and not g, "Mario chose damage")
local n = #STUB.sent
RO.Set("T"); STUB.Advance(2)
local sent; for i = n + 1, #STUB.sent do local k, f = C.Decode(STUB.sent[i].msg); if k == "rol" then sent = f.r end end
assert(sent == "T" and RO.Mine() == "T" and (RO.Of(ns.Me())) == "T", "mine chosen and shared")
-- a newcomer gets it
n = #STUB.sent
STUB.Receive("LVLM2", C.Encode("hi", { s = "" }), "GUILD", "Ana-Testrealm"); STUB.Advance(8)
sent = nil; for i = n + 1, #STUB.sent do local k, f = C.Decode(STUB.sent[i].msg); if k == "rol" then sent = f.r end end
assert(sent == "T", "handed to a newcomer")
