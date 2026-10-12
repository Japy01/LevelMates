STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local C, G, R, L = ns.Comm, ns.Goals, ns.Roster, ns.L
local function mate(name, level) STUB.Receive("LVLM2", C.Encode("hb", { l = level or 20, z = 1421 }), "GUILD", name .. "-Testrealm") end
local function lastKind() return (C.Decode(STUB.sent[#STUB.sent].msg)) end
local function find(pred) for _, g in ipairs(G.List()) do if pred(g) then return g end end end
local today = math.floor(time() / 86400)
STUB.guildMembers = { Tester = true, Mario = true, Ana = true, Luis = true, Jefa = true }
STUB.guildRoles = { Jefa = 2 }
R.InvalidateGuildRoster()
assert(ns.db.settings.goalNotices == true, "notices on by default")
assert(R.IsOfficer("Jefa") and not R.IsOfficer("Mario") and not R.IsOfficer("Nadie"), "officer by community role")

-- creating needs an officer
assert(G.Create("lvl", 30, nil, 7) == false and STUB.printed[#STUB.printed]:find(L.GOAL_NOT_OFFICER, 1, true), "not an officer: refused")
STUB.iAmOfficer = true
assert(R.IAmOfficer(), "me as officer")
assert(G.Create("lvl", 30, nil, 7) == true, "officer creates")
local k, f = C.Decode(STUB.sent[#STUB.sent].msg)
assert(k == "go" and f.ty == "lvl" and f.a == 30 and f.s == today and f.e == today + 7, "go sent")
local mineId = f.id
assert(#G.List() == 1 and G.Get(mineId).by == "Tester", "stored with its creator")
assert(G.Create("lvl", 99, nil, 7) == false and G.Create("dun", 99, nil, 7) == false and G.Create("cnt", 50, "xxx", 7) == false and G.Create("lvl", 30, nil, 40) == false, "invalid goals refused")

-- receiving: only from officers
mate("Mario"); mate("Jefa", 40)
local printed = #STUB.printed
STUB.Receive("LVLM2", C.Encode("go", { id = "m1", ty = "cnt", a = 100, w = "lvl", s = today, e = today + 7 }), "GUILD", "Mario-Testrealm")
assert(#G.List() == 1, "a non-officer's goal is ignored")
STUB.Receive("LVLM2", C.Encode("go", { id = "j1", ty = "dun", a = 5, s = today, e = today + 3 }), "GUILD", "Jefa-Testrealm")
assert(#G.List() == 2 and #STUB.printed == printed + 1 and STUB.printed[#STUB.printed]:find("Jefa", 1, true), "an officer's goal is stored and announced")
STUB.Receive("LVLM2", C.Encode("go", { id = "j9", ty = "dun", a = 99, s = today, e = today + 3 }), "GUILD", "Jefa-Testrealm")
assert(not G.Get("j9"), "an unknown dungeon is refused even from an officer")

-- at most 5 active
for i = 2, 6 do STUB.Receive("LVLM2", C.Encode("go", { id = "j" .. i, ty = "cnt", a = 10, w = "qst", s = today, e = today + 3 }), "GUILD", "Jefa-Testrealm") end
assert(#G.List() == 5, "at most 5 active: " .. #G.List())
assert(G.Create("lvl", 20, nil, 3) == false and STUB.printed[#STUB.printed]:find(L.GOAL_FULL, 1, true), "full: refused")

-- deleting: the creator or an officer
STUB.Receive("LVLM2", C.Encode("gx", { id = "j1" }), "GUILD", "Mario-Testrealm")
assert(G.Get("j1"), "Mario cannot delete Jefa's goal")
STUB.Receive("LVLM2", C.Encode("gx", { id = "j1" }), "GUILD", "Jefa-Testrealm")
assert(not G.Get("j1"), "Jefa can")
assert(G.CanDelete(mineId) and G.Delete(mineId) and not G.Get(mineId) and lastKind() == "gx", "I delete mine and tell the guild")

-- a newcomer gets the goals from officers, not from plain members
local function gosAfterPing(who)
	local n = #STUB.sent
	STUB.Receive("LVLM2", C.Encode("hi", { s = "" }), "GUILD", who .. "-Testrealm")
	STUB.Advance(6)
	local c = 0
	for i = n + 1, #STUB.sent do if (C.Decode(STUB.sent[i].msg)) == "go" then c = c + 1 end end
	return c
end
assert(gosAfterPing("Nuevo") == #G.List(), "an officer re-sends every goal it holds")
STUB.iAmOfficer = false
assert(gosAfterPing("Otro") == 0, "a plain member does not re-send others' goals")
STUB.iAmOfficer = true

-- everyone to level X: me, online mates, and those seen in the last 30 days; who is missing
for _, g in ipairs(G.List()) do G.Delete(g.id) end
STUB.player.level = 20
assert(G.Create("lvl", 25, nil, 7))
local lvl = find(function(g) return g.ty == "lvl" end)
mate("Mario", 26); mate("Ana", 22)
local reached, total, missing = G.Progress(lvl)
assert(reached == 2 and total == 4 and table.concat(missing, ",") == "Ana,Tester", "Mario and Jefa reached, Ana and I missing: " .. reached .. "/" .. total .. " " .. table.concat(missing, ","))
assert(G.ProgressText(lvl) == "2/4" and not G.IsDone(lvl), "progress text")
STUB.Receive("LVLM2", C.Encode("bye", {}), "GUILD", "Ana-Testrealm")
reached, total = G.Progress(lvl)
assert(total == 4, "offline guildmates still count with their last level")
ns.db.seen[GetGuildInfo("player")].Ana.t = time() - 31 * 86400
reached, total, missing = G.Progress(lvl)
assert(total == 3 and table.concat(missing, ",") == "Tester", "forgotten after 30 days")

-- texts
assert(G.Text(lvl) == string.format(L.GOAL_LVL, 25) and G.UntilText(lvl) == date("%d/%m", lvl.e * 86400), "texts")

-- expiry: 2 days after the deadline
lvl.e = today - 3
assert(#G.List() == 0, "expired goals are dropped")
