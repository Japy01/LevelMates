STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local C, X, L = ns.Comm, ns.Rested, ns.L
local function mate(name) STUB.Receive("LVLM2", C.Encode("hb", { l = 20, z = 1421 }), "GUILD", name .. "-Testrealm") end
local function rx(name, p) STUB.Receive("LVLM2", C.Encode("rx", { p = p }), "GUILD", name .. "-Testrealm") end
local function sentRx(from)
	local out = {}
	for i = from, #STUB.sent do local k, f = C.Decode(STUB.sent[i].msg); if k == "rx" then out[#out + 1] = f.p end end
	return out
end
assert(ns.db.settings.restedNotices == true and ns.db.settings.shareRested == false, "defaults: notice on, sharing off")

-- calculation (UnitXPMax is 1000 in the stub)
STUB.player.level = 20
STUB.player.rested = nil
assert(X.Mine() == 0, "no rested XP: 0")
STUB.player.rested = 454
assert(X.Mine() == 45, "rounded percent of a level: " .. X.Mine())
STUB.player.rested = 2000
assert(X.Mine() == 150, "capped at 150")
STUB.player.level = 60
assert(X.Mine() == nil, "hidden at max level")
STUB.player.level = 20

-- the cap notice, once per session
local printed = #STUB.printed
STUB.player.rested = 1500
STUB.Fire("UPDATE_EXHAUSTION")
assert(#STUB.printed == printed + 1 and STUB.printed[#STUB.printed]:find("150", 1, true), "max notice")
STUB.Fire("UPDATE_EXHAUSTION"); STUB.Fire("PLAYER_UPDATE_RESTING")
assert(#STUB.printed == printed + 1, "only once")

-- nothing shared by default, and never on hb
local n = #STUB.sent + 1
STUB.Advance(200)
assert(#sentRx(n) == 0, "not shared by default")
for i = 1, #STUB.sent do
	local k, f = C.Decode(STUB.sent[i].msg)
	if k == "hb" then assert(f.p == nil, "never rides on hb") end
end

-- turning sharing on sends at once
ns.db.settings.shareRested = true; X.SetSharing(true)
local s = sentRx(n)
assert(#s == 1 and s[1] == 150, "sent when turned on: " .. table.concat(s, ","))

-- after heartbeats: only a 5-point change, at most once a minute
n = #STUB.sent + 1
STUB.player.rested = 1480
STUB.Advance(200)
assert(#sentRx(n) == 0, "a 2-point change is not sent")
STUB.player.rested = 1000
STUB.Advance(200)
s = sentRx(n)
assert(#s == 1 and s[1] == 100, "a big change goes out with a heartbeat: " .. table.concat(s, ","))

-- a newcomer gets it right after my heartbeat
n = #STUB.sent
STUB.Receive("LVLM2", C.Encode("hi", { s = "" }), "GUILD", "Nuevo-Testrealm")
STUB.Advance(6)
local order = {}
for i = n + 1, #STUB.sent do local k = C.Decode(STUB.sent[i].msg); if k == "hb" or k == "rx" then order[#order + 1] = k end end
assert(order[1] == "hb" and order[2] == "rx", "hb then rx: " .. table.concat(order, ","))

-- inside an instance nothing goes out
STUB.inInstance = true
n = #STUB.sent + 1
STUB.player.rested = 200
STUB.Advance(200)
assert(#sentRx(n) == 0, "nothing inside an instance")
STUB.inInstance = false

-- turning sharing off withdraws at once
n = #STUB.sent + 1
ns.db.settings.shareRested = false; X.SetSharing(false)
s = sentRx(n)
assert(#s == 1 and s[1] == -1, "withdrawn: " .. table.concat(s, ","))

-- receiving
mate("Mario"); mate("Ana")
rx("Mario", 45)
assert(X.Of("Mario") == 45, "stored")
rx("Stranger", 30)
assert(X.Of("Stranger") == nil, "unknown ignored")
rx("Mario", -1)
assert(X.Of("Mario") == nil, "-1 clears")
rx("Ana", 80)
STUB.Receive("LVLM2", C.Encode("bye", {}), "GUILD", "Ana-Testrealm")
assert(X.Of("Ana") == nil, "bye clears")

-- "Appear on the board" off: -1 before the transport stops, others forgotten
ns.db.settings.shareRested = true; X.SetSharing(true)
mate("Luis"); rx("Luis", 10)
ns.db.settings.share = false; C.Stop()
local k, f = C.Decode(STUB.sent[#STUB.sent].msg)
assert(k == "rx" and f.p == -1, "rx -1 before the transport stops")
assert(X.Of("Luis") == nil, "others forgotten")
