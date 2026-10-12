-- shared records: owner, rev, expiry, tombstones; board types relayed, personal ones only from their owner
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(30)
local S, C, V = ns.Sync, ns.Comm, ns.Comm.V
local changes = {}
S.Define("tst", { class = "board", life = 3600, fields = { n = V.text(40) }, required = { "n" },
	onChange = function(rec, old, how) changes[#changes + 1] = { rec = rec, old = old, how = how } end })
local function last(kind) for i = #STUB.sent, 1, -1 do local k, f = C.Decode(STUB.sent[i].msg); if k == kind then return f end end end
local T = GetServerTime
-- mine: stored and sent, without the owner field
S.Put("tst", "a1", { n = "hola" }); STUB.Advance(2)
local f = last("tst")
assert(f and f.id == "a1" and f.n == "hola" and f.v and f.e and f.o == nil, "sent without owner (it is me)")
assert(S.Get("tst", "a1").d.n == "hola" and not S.Get("tst", "a1").pending, "stored, and no longer pending once it went")
-- someone else's, live
STUB.Receive("LVLM2", C.Encode("tst", { id = "b1", n = "de Mario", v = T(), e = T() + 600 }), "GUILD", "Mario-Testrealm")
assert(S.Get("tst", "b1") and S.Get("tst", "b1").o == "Mario" and changes[#changes].how == "live", "Mario's")
-- older copy ignored
STUB.Receive("LVLM2", C.Encode("tst", { id = "b1", n = "vieja", v = T() - 100, e = T() + 600 }), "GUILD", "Mario-Testrealm")
assert(S.Get("tst", "b1").d.n == "de Mario", "older ignored")
-- relayed by Luis for Ana: accepted (board), the owner stays Ana
STUB.Receive("LVLM2", C.Encode("tst", { id = "c1", o = "Ana", n = "reenviada", v = T(), e = T() + 600 }), "GUILD", "Luis-Testrealm")
assert(S.Get("tst", "c1") and S.Get("tst", "c1").o == "Ana", "relay keeps the owner")
-- Luis cannot take Mario's id as his own
STUB.Receive("LVLM2", C.Encode("tst", { id = "b1", n = "pirata", v = T() + 5, e = T() + 600 }), "GUILD", "Luis-Testrealm")
assert(S.Get("tst", "b1").d.n == "de Mario", "an id belongs to its owner")
-- tombstone from the owner; a relayed older copy cannot bring it back
STUB.Receive("LVLM2", C.Encode("x", { t = "tst", id = "b1", v = T() + 10, e = T() + 600 }), "GUILD", "Mario-Testrealm")
assert(not S.Get("tst", "b1"), "removed")
STUB.Receive("LVLM2", C.Encode("tst", { id = "b1", o = "Mario", n = "de Mario", v = T(), e = T() + 600 }), "GUILD", "Luis-Testrealm")
assert(not S.Get("tst", "b1"), "not resurrected by a relay")
-- a tombstone that arrives before its record (relayed)
STUB.Receive("LVLM2", C.Encode("x", { t = "tst", id = "d1", o = "Ana", v = T() + 10, e = T() + 600 }), "GUILD", "Luis-Testrealm")
STUB.Receive("LVLM2", C.Encode("tst", { id = "d1", n = "tarde", v = T(), e = T() + 600 }), "GUILD", "Ana-Testrealm")
assert(not S.Get("tst", "d1"), "the tombstone came first: still gone")
-- Luis cannot remove Ana's record
STUB.Receive("LVLM2", C.Encode("x", { t = "tst", id = "c1", v = T() + 20, e = T() + 600 }), "GUILD", "Luis-Testrealm")
assert(S.Get("tst", "c1"), "only the owner removes")
-- from the future: rejected
STUB.Receive("LVLM2", C.Encode("tst", { id = "e1", n = "futuro", v = T() + 1000, e = T() + 2000 }), "GUILD", "Mario-Testrealm")
assert(not S.Get("tst", "e1"), "future rejected")
-- personal: never relayed
S.Define("tsp", { class = "personal", life = 3600, fields = { n = V.text(40) }, required = { "n" } })
STUB.Receive("LVLM2", C.Encode("tsp", { id = "m", o = "Mario", n = "x", v = T(), e = T() + 600 }), "GUILD", "Luis-Testrealm")
assert(not S.Get("tsp", "m"), "personal: not relayed")
-- owner not in the guild
STUB.Receive("LVLM2", C.Encode("tst", { id = "z1", o = "Extrano", n = "x", v = T(), e = T() + 600 }), "GUILD", "Luis-Testrealm")
assert(not S.Get("tst", "z1"), "owner not in the guild")
-- expiry, with an "expired" change
STUB.Advance(700)
assert(not S.Get("tst", "c1") and changes[#changes].how == "expired", "expired")
-- inside an instance: held, still pending (saved) until it really goes
STUB.inInstance = true
S.Put("tst", "h1", { n = "dentro" }); STUB.Advance(5)
assert(S.Store("tst")["h1"].pending, "pending while held")
STUB.inInstance = false; STUB.Fire("ZONE_CHANGED_NEW_AREA"); STUB.Advance(5)
assert(not S.Store("tst")["h1"].pending and last("tst").id == "h1", "out after leaving")
-- a /reload inside: what was pending goes with the next heartbeat
S.Store("tst")["h1"].pending = true
STUB.Advance(90)   -- an unchanged heartbeat still goes every ~80 s
assert(not S.Store("tst")["h1"].pending, "pending resent with the heartbeat")
-- saved per guild
assert(ns.db.sync["Test Guild"].tst["a1"], "saved per guild")
