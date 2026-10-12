-- Together: suggested groups from who is online, by level and role
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(30)
local C = ns.Comm
STUB.Receive("LVLM2", C.Encode("hb", { l = 20, z = 1412, c = "PRIEST" }), "GUILD", "Mario-Testrealm")
STUB.Receive("LVLM2", C.Encode("rol", { r = "H" }), "GUILD", "Mario-Testrealm")
STUB.Receive("LVLM2", C.Encode("hb", { l = 21, z = 1412, c = "WARRIOR" }), "GUILD", "Ana-Testrealm")
STUB.Receive("LVLM2", C.Encode("hb", { l = 19, z = 1412, c = "MAGE" }), "GUILD", "Luis-Testrealm")
local sug = ns.Together.Suggest()
local dm
for _, s in ipairs(sug) do if s.d == 5 then dm = s end end   -- Deadmines 17-26
assert(dm and dm.filled == 4 and dm.candidates == 4, "four of us fit: " .. tostring(dm and dm.filled))
local byRole = {}
for _, r in ipairs(dm.rows) do byRole[r.role] = byRole[r.role] or r end
assert(byRole.H.name == "Mario" and not byRole.H.guessed and byRole.T.name == "Ana" and byRole.T.guessed, "chosen first, then guessed")
assert(#sug <= 5, "at most five")
for _, s in ipairs(sug) do assert(s.d ~= 11, "nobody fits Gnomeregan (29-38)") end
for i = 2, #sug do assert(sug[i - 1].filled >= sug[i].filled, "most filled first") end
-- with nobody online but me: nothing
for _, n in ipairs({ "Mario", "Ana", "Luis" }) do STUB.Receive("LVLM2", C.Encode("bye", {}), "GUILD", n .. "-Testrealm") end
assert(#ns.Together.Suggest() == 0, "alone: nothing")
