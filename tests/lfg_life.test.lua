STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local C, G = ns.Comm, ns.LFG
STUB.player.level = 15
local function mate(name) STUB.Receive("LVLM2", C.Encode("hb", { l = 15, z = 1421 }), "GUILD", name .. "-Testrealm") end
local function ad(from, f) STUB.Receive("LVLM2", C.Encode("lfg", f), "GUILD", from .. "-Testrealm") end
mate("Mario"); mate("Ana")

-- the clock comes from the sender's remaining minutes
ad("Mario", { d = 2, r = "T", id = "m0000001", m = 5 })
STUB.Advance(4 * 60); G.Expire()
assert(G.ads.m0000001, "still there after 4 of 5 minutes")
STUB.Advance(2 * 60); G.Expire()
assert(G.ads.m0000001 == nil, "gone after its minutes ran out")
mate("Mario")   -- the roster forgets a player after 120 s without a heartbeat, so he announces himself again
ad("Mario", { d = 2, r = "T", id = "m0000002", m = 1 })
STUB.Advance(120)
assert(G.ads.m0000002 == nil, "expired by the 60 s ticker, nobody called Expire")

-- only the author withdraws
mate("Mario")
ad("Mario", { d = 2, r = "T", id = "m0000003", m = 20 })
STUB.Receive("LVLM2", C.Encode("lfgx", { id = "m0000003" }), "GUILD", "Ana-Testrealm")
assert(G.ads.m0000003, "someone else cannot withdraw Mario's ad")
STUB.Receive("LVLM2", C.Encode("lfgx", { id = "m0000003" }), "GUILD", "Mario-Testrealm")
assert(G.ads.m0000003 == nil, "the author can")

-- my own ad: re-sent to newcomers with the minutes that remain, one answer per storm
STUB.Advance(31)
assert(G.Post(2, "T", "hola"))
STUB.Advance(125)
local n = #STUB.sent
STUB.Receive("LVLM2", C.Encode("hi", { s = "" }), "GUILD", "Ana-Testrealm")
STUB.Advance(6)
local resent
for i = n + 1, #STUB.sent do
	local k, f = C.Decode(STUB.sent[i].msg)
	if k == "lfg" then resent = f end
end
assert(resent and resent.id == G.mine.id and resent.m <= 18 and resent.m >= 17, "re-sent with the minutes left: " .. tostring(resent and resent.m))
n = #STUB.sent
STUB.Receive("LVLM2", C.Encode("hi", { s = "" }), "GUILD", "Ana-Testrealm")
STUB.Receive("LVLM2", C.Encode("hi", { s = "" }), "GUILD", "Mario-Testrealm")
STUB.Advance(6)
local count = 0
for i = n + 1, #STUB.sent do if (C.Decode(STUB.sent[i].msg)) == "lfg" then count = count + 1 end end
assert(count == 1, "a login storm gets one answer, got " .. count)
STUB.Advance(20 * 60)
assert(G.mine == nil, "own ad expires after 20 minutes without renewing")

-- group full closes it
STUB.Advance(31)
G.Post(1, "H")
STUB.groupSize = 4; STUB.Fire("GROUP_ROSTER_UPDATE")
assert(G.mine, "four is not full")
STUB.groupSize = 5; STUB.Fire("GROUP_ROSTER_UPDATE")
assert(G.mine == nil and select(1, C.Decode(STUB.sent[#STUB.sent].msg)) == "lfgx", "closed and withdrawn at five")

-- sharing off: you see nobody and have no ad; posting says why
STUB.groupSize = 0
STUB.Advance(31)
mate("Mario")
ad("Mario", { d = 2, r = "T", id = "m0000004", m = 20 })
assert(G.ads.m0000004)
G.Post(2, "T")
ns.db.settings.share = false; C.Stop()
assert(next(G.ads) == nil and G.mine == nil, "sharing off clears every ad")
assert(G.Post(2, "T") == false and STUB.printed[#STUB.printed]:find(ns.L.HELP_NEEDS_SHARE, 1, true), "and posting tells the user to turn sharing on")
