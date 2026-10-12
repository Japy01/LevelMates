-- Findings of the final review of the group finder, each pinned by a test.
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local C, G = ns.Comm, ns.LFG
STUB.player.level = 15
local function mate(name) STUB.Receive("LVLM2", C.Encode("hb", { l = 15, z = 1421 }), "GUILD", name .. "-Testrealm") end
local function ad(from, f) STUB.Receive("LVLM2", C.Encode("lfg", f), "GUILD", from .. "-Testrealm") end

-- 1. a newcomer must get my heartbeat before my ad, every time (otherwise the ad arrives from a stranger and is dropped)
assert(G.Post(2, "T"))
for round = 1, 8 do
	local n = #STUB.sent
	STUB.Receive("LVLM2", C.Encode("ping", {}), "GUILD", "Nuevo" .. round .. "-Testrealm")
	STUB.Advance(6)
	local order = {}
	for i = n + 1, #STUB.sent do local k = C.Decode(STUB.sent[i].msg); if k == "hb" or k == "lfg" then order[#order + 1] = k end end
	assert(order[1] == "hb" and order[2] == "lfg", "round " .. round .. ": " .. table.concat(order, ","))
	STUB.Advance(30)
end
G.Cancel()

-- 2. a known ad id from someone else is not theirs to take
mate("Mario"); mate("Ana")
ad("Ana", { d = 3, r = "H", id = "a0000001", m = 20 })
ad("Mario", { d = 5, r = "T", id = "a0000001", m = 20 })
assert(G.ads.a0000001.name == "Ana" and G.ads.a0000001.d == 3, "Mario cannot take over Ana's ad")
STUB.Receive("LVLM2", C.Encode("lfgx", { id = "a0000001" }), "GUILD", "Ana-Testrealm")
assert(G.ads.a0000001 == nil, "and Ana can still withdraw it")

-- 3. a re-send never moves the clock forward
STUB.Advance(31)
ad("Ana", { d = 3, r = "H", id = "a0000002", m = 20 })
local ends = G.ads.a0000002.endsAt
STUB.Advance(600); mate("Ana")
ad("Ana", { d = 3, r = "H", id = "a0000002", m = 20 })
assert(G.ads.a0000002.endsAt == ends, "a lying or rounded-up re-send does not extend the ad")

-- 4a. a poster who logs off takes the ad along
mate("Mario")
ad("Mario", { d = 2, r = "T", id = "m0000001", m = 20 })
assert(G.ads.m0000001)
STUB.Receive("LVLM2", C.Encode("bye", {}), "GUILD", "Mario-Testrealm")
assert(G.ads.m0000001 == nil, "bye removes the poster's ad")

-- 4b. turning sharing off withdraws my ad before the transport stops
STUB.Advance(31)
assert(G.Post(2, "T"))
local myId = G.mine.id
ns.db.settings.share = false; C.Stop()
local k, f = C.Decode(STUB.sent[#STUB.sent].msg)
assert(k == "lfgx" and f.id == myId, "lfgx goes out before the transport stops: " .. tostring(k))

-- 4c. logging out withdraws it before saying bye
ns.db.settings.share = true; C.Start(); STUB.Advance(1)
STUB.Advance(31)
assert(G.Post(1, "H"))
local n = #STUB.sent
STUB.Fire("PLAYER_LOGOUT")
local kinds = {}
for i = n + 1, #STUB.sent do kinds[#kinds + 1] = (C.Decode(STUB.sent[i].msg)) end
assert(table.concat(kinds, ",") == "lfgx,bye", "logout order: " .. table.concat(kinds, ","))
