-- personal state: sent on change, pending while it cannot go, one resend per burst of hellos, again after a drop
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(30)
local S, C = ns.Sync, ns.Comm
local state = 1
local P = S.Personal("pal", function() return { p = state } end, { enabled = function() return true end })
local function count(kind, from) local n = 0; for i = from + 1, #STUB.sent do if (C.Decode(STUB.sent[i].msg)) == kind then n = n + 1 end end; return n end
local n = #STUB.sent
P.Mark(); STUB.Advance(2)
assert(count("pal", n) == 1, "sent on change")
n = #STUB.sent
for i = 1, 3 do STUB.Receive("LVLM2", C.Encode("hi", { s = "" }), "GUILD", "Mario-Testrealm") end
STUB.Advance(12)
assert(count("pal", n) == 1, "one resend for a burst of hellos: " .. count("pal", n))
n = #STUB.sent
ns.Fire("LM_COMM_DROPPED", "pal")
STUB.Advance(90)
assert(count("pal", n) >= 1, "resent after a drop")
-- inside an instance: refused, pending; out with the first heartbeat outside
STUB.inInstance = true
n = #STUB.sent
state = 0; P.Mark(); STUB.Advance(2)
assert(count("pal", n) == 0 and P.pending, "pending inside")
STUB.inInstance = false; STUB.Advance(90)
assert(count("pal", n) == 1 and not P.pending, "out after leaving")
-- saved pending (a /reload inside keeps it) and "worth" (nothing to say: no resend to newcomers)
local items = {}
local Q = S.Personal("wl", function() return { ids = #items > 0 and table.concat(items, ",") or nil } end,
	{ save = "testPending", worth = function() return #items > 0 end })
STUB.inInstance = true
Q.Mark(); STUB.Advance(1)
assert(ns.char.testPending == true, "pending saved with the character")
STUB.inInstance = false
STUB.Fire("PLAYER_ENTERING_WORLD", false, true); STUB.Advance(3)   -- a /reload outside: announced again
assert(not ns.char.testPending, "the saved pending went out with the announce")
n = #STUB.sent
STUB.Receive("LVLM2", C.Encode("hi", { s = "" }), "GUILD", "Ana-Testrealm"); STUB.Advance(8)
assert(count("wl", n) == 0, "an empty list is not resent to newcomers")
