STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local C, P, L = ns.Comm, ns.Partner, ns.L
STUB.player.level = 20
local function mate(name, level, z) STUB.Receive("LVLM2", C.Encode("hb", { l = level, z = z or 1421 }), "GUILD", name .. "-Testrealm") end
local function pal(name, p) STUB.Receive("LVLM2", C.Encode("pal", { p = p }), "GUILD", name .. "-Testrealm") end
local function lastKind() return (C.Decode(STUB.sent[#STUB.sent].msg)) end
assert(ns.db.settings.palNotices == true, "notices on by default")
assert(P.IsOn() == false, "off by default")
mate("Mario", 23); mate("Ana", 24); mate("Luis", 17)

-- a click turns it on and tells the guild, on a kind of its own
assert(P.SetOn(true) == true and P.IsOn() and ns.char.lookingPartner == true, "on")
local k, f = C.Decode(STUB.sent[#STUB.sent].msg)
assert(k == "pal" and f.p == 1, "pal p=1 sent")
for i = 1, #STUB.sent do
	local kk, ff = C.Decode(STUB.sent[i].msg)
	if kk == "hb" then assert(ff.p == nil, "the flag never rides on hb (older versions would drop the hb)") end
end

-- matching: both marked and within 3 levels; one notice per person
local printed = #STUB.printed
pal("Mario", 1)
assert(P.Marked("Mario") and P.Matches("Mario"), "Mario 23 vs 20: match")
assert(#STUB.printed == printed + 1 and STUB.printed[#STUB.printed]:find("Mario", 1, true) and STUB.printed[#STUB.printed]:find("23", 1, true), "notice with name and level")
pal("Mario", 1)
assert(#STUB.printed == printed + 1, "notice once per person")
pal("Ana", 1)
assert(P.Marked("Ana") and not P.Matches("Ana"), "Ana 24 vs 20: 4 levels, no match")
assert(#STUB.printed == printed + 1, "no notice for a non-match")
assert(not P.Matches("Luis"), "Luis not marked")
pal("Stranger", 1)
assert(not P.Marked("Stranger"), "unknown to the roster: ignored")

-- my level changes: Ana comes in range and is announced then
STUB.player.level = 21
ns.Fire("LM_ROSTER_CHANGED")
assert(P.Matches("Ana") and #STUB.printed == printed + 2, "Ana now matches and is announced once")

-- my box off: no matches, marks stay known; toggling back does not repeat notices
P.SetOn(false)
k, f = C.Decode(STUB.sent[#STUB.sent].msg)
assert(k == "pal" and f.p == 0 and not P.Matches("Mario") and P.Marked("Mario"), "off: p=0 sent, no matches")
P.SetOn(true)
assert(#STUB.printed == printed + 2, "toggling does not repeat notices")

-- notices off
ns.db.settings.palNotices = false
mate("Rosa", 21); pal("Rosa", 1)
assert(P.Matches("Rosa") and #STUB.printed == printed + 2, "notices off: silent")
ns.db.settings.palNotices = true

-- marks go away with bye and with p=0
STUB.Receive("LVLM2", C.Encode("bye", {}), "GUILD", "Mario-Testrealm")
assert(not P.Marked("Mario"), "bye clears the mark")
pal("Ana", 0)
assert(not P.Marked("Ana"), "p=0 clears")

-- a newcomer gets my mark right after my heartbeat
local n = #STUB.sent
STUB.Receive("LVLM2", C.Encode("ping", {}), "GUILD", "Nuevo-Testrealm")
STUB.Advance(6)
local order = {}
for i = n + 1, #STUB.sent do local kk = C.Decode(STUB.sent[i].msg); if kk == "hb" or kk == "pal" then order[#order + 1] = kk end end
assert(order[1] == "hb" and order[2] == "pal", "hb then pal: " .. table.concat(order, ","))

-- grouping with someone who was looking turns mine off; with someone who was not, it stays
STUB.partyMembers = { Rosa = true }
STUB.Fire("GROUP_ROSTER_UPDATE")
assert(not P.IsOn() and ns.char.lookingPartner == false, "found: off")
assert(lastKind() == "pal" and STUB.printed[#STUB.printed]:find("Rosa", 1, true), "p=0 sent and the user is told")
P.SetOn(true)
STUB.partyMembers = { Luis = true }
STUB.Fire("GROUP_ROSTER_UPDATE")
assert(P.IsOn(), "Luis was not looking: stays on")
STUB.partyMembers = {}

-- inside an instance nothing goes out
STUB.inInstance = true
n = #STUB.sent
P.SetOn(false); P.SetOn(true)
assert(#STUB.sent == n, "nothing sent inside an instance")
STUB.inInstance = false

-- sharing off: p=0 goes out first, my choice is kept, their marks are forgotten
ns.db.settings.share = false; C.Stop()
k, f = C.Decode(STUB.sent[#STUB.sent].msg)
assert(k == "pal" and f.p == 0, "p=0 before the transport stops")
assert(P.IsOn() and not P.Marked("Rosa"), "my choice kept, their marks forgotten")
-- turning it on without sharing is refused
P.SetOn(false)
assert(P.SetOn(true) == false and not P.IsOn() and STUB.printed[#STUB.printed]:find(L.HELP_NEEDS_SHARE, 1, true), "needs sharing")
