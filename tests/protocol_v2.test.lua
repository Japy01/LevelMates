-- protocol v2: own prefix, v1 messages are not data; 0.3.x clients get one old-style heartbeat with my version
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local C, R = ns.Comm, ns.Roster
assert(C.PREFIX == "LVLM2" and STUB.prefixes["LVLM2"] and STUB.prefixes["LVLM"], "both prefixes registered")
for _, s in ipairs(STUB.sent) do assert(s.prefix == "LVLM2", "everything goes out on v2") end
STUB.Receive("LVLM2", C.Encode("hb", { l = 21, z = 1412, c = "MAGE" }), "GUILD", "Mario-Testrealm")
assert(R.mates["Mario"] and R.mates["Mario"].level == 21, "v2 heard")
local n = #STUB.sent
STUB.Receive("LVLM", "v1\031hb\031c=MAGE;l=15;v=0.3.2;z=1412", "GUILD", "Ana-Testrealm")
assert(not (R.mates["Ana"] and R.mates["Ana"].level), "no v1 data")
assert(R.legacy["Ana"], "Ana marked as old")
local old
for i = n + 1, #STUB.sent do if STUB.sent[i].prefix == "LVLM" then old = STUB.sent[i] end end
assert(old and old.msg:find("^v1\031hb\031") and old.msg:find("v=" .. ns.VERSION, 1, true), "one old-style heartbeat with my version")
n = #STUB.sent
STUB.Receive("LVLM", "v1\031hb\031c=MAGE;l=15;v=0.3.2;z=1412", "GUILD", "Ana-Testrealm")
for i = n + 1, #STUB.sent do assert(STUB.sent[i].prefix ~= "LVLM", "not again so soon") end
STUB.Advance(301)
STUB.Receive("LVLM", "v1\031hb\031c=MAGE;l=15;v=0.3.2;z=1412", "GUILD", "Ana-Testrealm")
local again = false
for i = n + 1, #STUB.sent do if STUB.sent[i].prefix == "LVLM" then again = true end end
assert(again, "again after 5 minutes")
-- the card says so
assert(table.concat(ns.MateCard.Lines("Ana"), "\n"):find(ns.L.CARD_OLD_VERSION, 1, true), "the card tells")
-- over 240 bytes is refused, never cut
assert(C.MAX_BYTES == 240, "limit 240")
