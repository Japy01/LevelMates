STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local C, P, R, L = ns.Comm, ns.Personal, ns.Roster, ns.L
local function mate(name, level) STUB.Receive("LVLM2", C.Encode("hb", { l = level or 20, z = 1421 }), "GUILD", name .. "-Testrealm") end
local function last() return C.Decode(STUB.sent[#STUB.sent].msg) end
local today = math.floor(time() / 86400)
STUB.guildMembers = { Tester = true, Mario = true, Ana = true }
R.InvalidateGuildRoster()
STUB.player.level = 30

assert(C.Validate("gp", { l = 40, e = today + 7 }) and C.Validate("gp", { l = 0, e = today }), "gp format")
assert(C.Validate("gp", { l = 61, e = today }) == false and C.Validate("gp", { l = 40 }) == false, "gp ranges and required fields")

-- mine
assert(P.Set(40, 7) and P.Mine().l == 40 and P.Mine().e == today + 7, "set")
local k, f = last()
assert(k == "gp" and f.l == 40 and f.e == today + 7, "told the guild")
local printed = #STUB.printed
assert(not P.Set(25, 7) and not P.Set(40, 40) and not P.Set(61, 3), "invalid refused")
assert(#STUB.printed == printed + 3 and STUB.printed[#STUB.printed]:find(L.MYGOAL_BAD, 1, true), "says why")
assert(P.Mine().l == 40 and P.List()[1].mine and P.List()[1].name == "Tester", "kept, listed first")
assert(P.ProgressText(P.List()[1]) == "30/40" and not P.IsDone(P.List()[1]), "my progress")

-- others
mate("Mario", 22)
STUB.Receive("LVLM2", C.Encode("gp", { l = 30, e = today + 3 }), "GUILD", "Mario-Testrealm")
STUB.Receive("LVLM2", C.Encode("gp", { l = 30, e = today + 3 }), "GUILD", "Nadie-Testrealm")
local list = P.List()
assert(#list == 2 and list[2].name == "Mario" and P.ProgressText(list[2]) == "22/30" and P.Text(list[2]) == string.format(L.MYGOAL_TEXT, 30), "Mario's goal, not a stranger's")
STUB.Receive("LVLM2", C.Encode("gp", { l = 50, e = today - 5 }), "GUILD", "Mario-Testrealm")
STUB.Receive("LVLM2", C.Encode("gp", { l = 50, e = today + 400 }), "GUILD", "Mario-Testrealm")
assert(P.List()[2].l == 30, "expired or far-off deadlines are ignored")
STUB.Receive("LVLM2", C.Encode("gp", { l = 0, e = today }), "GUILD", "Mario-Testrealm")
assert(#P.List() == 1, "Mario withdrew his")
STUB.Receive("LVLM2", C.Encode("gp", { l = 30, e = today + 3 }), "GUILD", "Mario-Testrealm")
ns.db.personal[GetGuildInfo("player")].Mario.e = today - 3
assert(#P.List() == 1, "others' goals expire too")

-- newcomers get mine
local n = #STUB.sent
STUB.Receive("LVLM2", C.Encode("ping", {}), "GUILD", "Ana-Testrealm"); STUB.Advance(6)
local got = false
for i = n + 1, #STUB.sent do local kk, ff = C.Decode(STUB.sent[i].msg); if kk == "gp" and ff.l == 40 then got = true end end
assert(got, "a newcomer gets my goal")

-- reached: announced once
local function hits()
	local c = 0
	for i = 1, #STUB.printed do if STUB.printed[i]:find(string.format(L.MYGOAL_REACHED, 40), 1, true) then c = c + 1 end end
	return c
end
STUB.player.level = 40
STUB.Fire("PLAYER_LEVEL_UP", 40); STUB.Advance(1)
assert(hits() == 1 and P.IsDone(P.List()[1]), "reached, announced")
STUB.player.level = 41
STUB.Fire("PLAYER_LEVEL_UP", 41); STUB.Advance(1)
assert(hits() == 1, "only once")

-- a refused withdraw goes out after the next heartbeat
STUB.inInstance = true
n = #STUB.sent
assert(P.Clear() and not P.Mine() and #STUB.sent == n, "removed; nothing sent inside")
STUB.inInstance = false
ns.Fire("LM_HB_SENT")
k, f = last()
assert(k == "gp" and f.l == 0, "the withdraw goes out after the heartbeat")

-- my own expires
assert(P.Set(50, 1))
ns.char.goal.e = today - 3
assert(not P.Mine() and #P.List() == 0, "expired")
