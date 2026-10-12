-- /reload: PLAYER_ENTERING_WORLD(false, true) with a fresh Lua state must start the roster like a login.
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
local R, C = ns.Roster, ns.Comm
STUB.Fire("PLAYER_ENTERING_WORLD", false, true)
STUB.Advance(1)
local kinds = {}
for _, s in ipairs(STUB.sent) do kinds[#kinds + 1] = select(1, C.Decode(s.msg)) end
table.sort(kinds)
assert(table.concat(kinds, ",") == "hb,ping", "ping and hb after /reload: " .. table.concat(kinds, ","))
-- the periodic ticker runs: mates expire on their own
STUB.Receive("LVLM2", C.Encode("hb", { l = 30, z = 1421 }), "GUILD", "Mario-Testrealm")
assert(#R.List() == 1, "mate stored")
STUB.Advance(200)
assert(#R.List() == 0, "expired by the ticker without calling Expire")
-- a zone change later (isInitial=false, isReloading=false) does not restart anything
local n = #STUB.sent
STUB.Fire("PLAYER_ENTERING_WORLD", false, false)
STUB.Advance(1)
assert(#STUB.sent == n, "no re-announce on a plain zone transition")
