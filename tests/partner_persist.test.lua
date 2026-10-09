-- The box is remembered per character and announced again after a reload.
LevelMatesDB = { version = 1, settings = {}, chars = { ["Tester-Testrealm"] = { lookingPartner = true } } }
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", false, true); STUB.Advance(1)
assert(ns.Partner.IsOn(), "remembered across reloads")
local sentPal = false
for i = 1, #STUB.sent do
	local k, f = ns.Comm.Decode(STUB.sent[i].msg)
	if k == "pal" and f.p == 1 then sentPal = true end
end
assert(sentPal, "announced after the reload")
