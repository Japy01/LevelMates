-- runs: five slots, the leader's line-up, a waiting list, add and remove by hand
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(30)
local M, C = ns.Meetups, ns.Comm
for _, n in ipairs({ "Mario", "Ana", "Luis" }) do STUB.Receive("LVLM2", C.Encode("hb", { l = 20, z = 1421, c = "MAGE" }), "GUILD", n .. "-Testrealm") end
assert(M.Create(5, M.Now() + 60, "", "T", false), "created as tank")
local m = M.List(5)[1]
local s = M.Slots(m)
assert(s.T[1] == "Tester" and #s.D == 0 and not M.Free(m, "T") and M.Free(m, "D"), "the leader holds the tank slot")
local function join(id, who, role) STUB.Receive("LVLM2", C.Encode("qj", STUB.Rec{ id = id .. "." .. ns.NameKey(who), r = role }), "GUILD", who .. "-Testrealm") end
join(m.id, "Mario", "H"); join(m.id, "Ana", "H")
STUB.Advance(1)
m = M.List(5)[1]; s = M.Slots(m)
assert(s.H[1] == "Mario" and s.waiting[1] == "Ana" and s.confirmed, "first come; the second waits")
local qm; for i = #STUB.sent, 1, -1 do local k, f = C.Decode(STUB.sent[i].msg); if k == "qm" then qm = f.m; break end end
assert(qm and qm:find("H=Mario", 1, true) and qm:find("T=Tester", 1, true), "line-up published: " .. tostring(qm))
assert(M.AddMember(m.id, "Luis", "D") and M.Slots(M.List(5)[1]).D[1] == "Luis", "added by hand")
assert(not M.AddMember(m.id, "Ana", "T"), "a full role refused")
assert(M.RemoveMember(m.id, "Luis") and #M.Slots(M.List(5)[1]).D == 0, "removed")
-- someone else's line-up for my run is ignored
STUB.Receive("LVLM2", C.Encode("qm", STUB.Rec{ id = m.id, m = "T=Ana" }), "GUILD", "Ana-Testrealm")
assert(M.Slots(M.List(5)[1]).T[1] == "Tester", "only the leader's line-up counts")
-- a leaver frees the slot; the waiting one moves up
STUB.Receive("LVLM2", C.Encode("x", STUB.Rec{ t = "qj", id = m.id .. "." .. ns.NameKey("Mario") }), "GUILD", "Mario-Testrealm")
STUB.Advance(1)
s = M.Slots(M.List(5)[1])
assert(s.H[1] == "Ana" and #s.waiting == 0, "Mario left; Ana moves up")
-- joining a full role is refused here too
local mm = M.List(5)[1]
STUB.Receive("LVLM2", C.Encode("qd", STUB.Rec{ id = "mar00001", d = 4, at = M.Now() + 30, r = "H" }), "GUILD", "Mario-Testrealm")
assert(not M.Join("mar00001", "H") and M.Join("mar00001", "D"), "only a free role")
-- a run from before (no role): the leader's class guess, unconfirmed
STUB.Receive("LVLM2", C.Encode("qd", STUB.Rec{ id = "old00001", d = 6, at = M.Now() + 40 }), "GUILD", "Ana-Testrealm")
s = M.Slots(M.List(6)[1])
assert(s.D[1] == "Ana" and not s.confirmed, "old run: guessed leader role, not confirmed")
-- a surname in the line-up
STUB.Receive("LVLM2", C.Encode("hb", { l = 20, z = 1421, c = "MAGE" }), "GUILD", "Pepe Grillo-Testrealm")
STUB.guildMembers["Pepe Grillo"] = true; ns.Roster.InvalidateGuildRoster()
join(mm.id, "Pepe Grillo", "D"); STUB.Advance(1)
assert(M.Slots(M.List(5)[1]).D[1] == "Pepe Grillo", "the full name, surname included")
