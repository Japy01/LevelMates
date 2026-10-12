STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local C, G, R, L = ns.Comm, ns.Goals, ns.Roster, ns.L
local function mate(name, level) STUB.Receive("LVLM2", C.Encode("hb", { l = level or 20, z = 1421 }), "GUILD", name .. "-Testrealm") end
local today = math.floor(time() / 86400)

-- #5: an empty guild list (not loaded yet at login) is not cached as "nobody is a guildmate"
STUB.guildMembers = {}
R.InvalidateGuildRoster()
assert(not R.IsGuildmate("Jefa"), "nothing loaded yet")
STUB.guildMembers = { Tester = true, Mario = true, Ana = true, Jefa = true, Otra = true }
STUB.guildRoles = { Jefa = 2, Otra = 2 }
assert(R.IsOfficer("Jefa"), "the list arrives a moment later and is used at once")

local function kindsAfterPing(who)
	local n, out = #STUB.sent, {}
	STUB.Receive("LVLM2", C.Encode("hi", { s = "" }), "GUILD", who .. "-Testrealm")
	STUB.Advance(6)
	for i = n + 1, #STUB.sent do local k, f = C.Decode(STUB.sent[i].msg); out[#out + 1] = { k = k, f = f } end
	return out
end

STUB.iAmOfficer = true
mate("Mario", 25); mate("Jefa", 40); mate("Ana", 30); mate("Otra", 30)
UnitLevel = function() return 30 end

-- #1: sample goals never leave this client
SlashCmdList["LEVELMATES"]("sim metas")
for _, m in ipairs(kindsAfterPing("Nuevo")) do
	assert(not (m.f and m.f.id and tostring(m.f.id):find("^simgo")), "sample goal sent: " .. m.k)
end
STUB.Advance(100); ns.Fire("LM_HB_SENT")
for i = 1, #STUB.sent do local _, f = C.Decode(STUB.sent[i].msg); assert(not (f and f.id and tostring(f.id):find("^simgo")), "sample counter sent") end
SlashCmdList["LEVELMATES"]("sim off")

-- #2: a level goal reached through a guildmate's heartbeat is announced
STUB.Receive("LVLM2", C.Encode("go", { id = "lv30", ty = "lvl", a = 30, s = today, e = today + 3 }), "GUILD", "Jefa-Testrealm")
local printed = #STUB.printed
mate("Mario", 30)
local announced = false
for i = printed + 1, #STUB.printed do if STUB.printed[i]:find(G.Text(G.Get("lv30")), 1, true) then announced = true end end
assert(G.IsDone(G.Get("lv30")) and announced, "reached by Mario's level-up: announced")

-- #4: someone who left the guild no longer blocks "everyone to level X"
STUB.Receive("LVLM2", C.Encode("go", { id = "lv40", ty = "lvl", a = 31, s = today, e = today + 3 }), "GUILD", "Jefa-Testrealm")
ns.db.seen[GetGuildInfo("player")].Viejo = { l = 10, t = time() }
local _, _, missing = G.Progress(G.Get("lv40"))
for _, n in ipairs(missing) do assert(n ~= "Viejo", "an ex-guildmate is not missing") end

-- #3: a deleted goal does not come back from another officer's re-share
STUB.Receive("LVLM2", C.Encode("go", { id = "zz01", ty = "cnt", a = 10, w = "qst", s = today, e = today + 3 }), "GUILD", "Jefa-Testrealm")
assert(G.Delete("zz01") and not G.Get("zz01"), "I delete it")
STUB.Receive("LVLM2", C.Encode("go", { id = "zz01", ty = "cnt", a = 10, w = "qst", s = today, e = today + 3 }), "GUILD", "Otra-Testrealm")
assert(not G.Get("zz01"), "a re-share from an officer who missed the delete is refused")
for _, g in ipairs(G.List()) do assert(g.id ~= "zz01", "not listed") end
local healed = false
for _, m in ipairs(kindsAfterPing("Otra")) do if m.k == "gx" and m.f.id == "zz01" then healed = true end end
assert(healed, "officers repeat the delete to newcomers")
-- and a client that gets the delete from an officer forgets it for good too
STUB.Receive("LVLM2", C.Encode("go", { id = "zz02", ty = "cnt", a = 10, w = "qst", s = today, e = today + 3 }), "GUILD", "Jefa-Testrealm")
STUB.Receive("LVLM2", C.Encode("gx", { id = "zz02" }), "GUILD", "Jefa-Testrealm")
STUB.Receive("LVLM2", C.Encode("go", { id = "zz02", ty = "cnt", a = 10, w = "qst", s = today, e = today + 3 }), "GUILD", "Otra-Testrealm")
assert(not G.Get("zz02"), "received deletes are remembered as well")

-- #7: an invalid value says why
printed = #STUB.printed
assert(G.Create("lvl", 99, nil, 3) == false and #STUB.printed == printed + 1 and STUB.printed[#STUB.printed]:find(L.GOAL_BAD_VALUE, 1, true), "invalid: says why")
