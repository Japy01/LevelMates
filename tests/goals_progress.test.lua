STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
ns.db.settings.shareFeed = false   -- the wall (fe) has its own test
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local C, G, R, J, L = ns.Comm, ns.Goals, ns.Roster, ns.Journal, ns.L
local function mate(name) STUB.Receive("LVLM", C.Encode("hb", { l = 20, z = 1421 }), "GUILD", name .. "-Testrealm") end
local function lastKind() return (C.Decode(STUB.sent[#STUB.sent].msg)) end
local function find(pred) for _, g in ipairs(G.List()) do if pred(g) then return g end end end
STUB.guildMembers = { Tester = true, Mario = true }
R.InvalidateGuildRoster()
STUB.iAmOfficer = true
mate("Mario")

-- dungeon together: done when my journal records it with a guildmate
assert(G.Create("dun", 2, nil, 7))
local dun = find(function(g) return g.ty == "dun" end)
J.Add("dungeon", { name = ns.Dungeons.Name(2), mates = {} })
assert(not G.IsDone(dun), "alone does not count")
J.Add("dungeon", { name = ns.Dungeons.Name(3), mates = { "Mario" } })
assert(not G.IsDone(dun), "another dungeon does not count")
local printed = #STUB.printed
J.Add("dungeon", { name = ns.Dungeons.Name(2), mates = { "Mario" } })
assert(G.IsDone(dun) and dun.doneBy == "Tester" and lastKind() == "gd", "done with a guildmate; the guild is told")
assert(#STUB.printed == printed + 1 and STUB.printed[#STUB.printed]:find(G.Text(dun), 1, true), "reached, announced once")
J.Add("dungeon", { name = ns.Dungeons.Name(2), mates = { "Mario" } })
assert(#STUB.printed == printed + 1, "not announced twice")

-- done by someone else
assert(G.Create("dun", 4, nil, 7))
local dun2 = find(function(g) return g.ty == "dun" and g.a == 4 end)
STUB.Receive("LVLM", C.Encode("gd", { id = dun2.id }), "GUILD", "Stranger-Testrealm")
assert(not dun2.doneBy, "a stranger cannot complete it")
STUB.Receive("LVLM", C.Encode("gd", { id = dun2.id }), "GUILD", "Mario-Testrealm")
assert(G.IsDone(dun2) and dun2.doneBy == "Mario" and G.ProgressText(dun2) == string.format(L.GOAL_DONE_BY, "Mario"), "done by Mario")

-- counter: my part from the journal plus everyone else's
assert(G.Create("cnt", 5, "qst", 7))
local cnt = find(function(g) return g.ty == "cnt" end)
J.Add("quest", { id = 1, name = "a" }); J.Add("quest", { id = 2, name = "b" })
assert(G.MyContribution(cnt) == 2, "my part from the journal")
STUB.Receive("LVLM", C.Encode("gc", { id = cnt.id, n = 2 }), "GUILD", "Mario-Testrealm")
assert(select(1, G.Progress(cnt)) == 4 and G.ProgressText(cnt) == "4/5", "sum of everyone")
STUB.Receive("LVLM", C.Encode("gc", { id = cnt.id, n = 2 }), "GUILD", "Tester-Testrealm")
assert(select(1, G.Progress(cnt)) == 4, "my own echo never counts twice")

-- my part goes out after a heartbeat, at most once a minute
local function gcs(from) local out = {}; for i = from, #STUB.sent do local k, f = C.Decode(STUB.sent[i].msg); if k == "gc" then out[#out + 1] = f.n end end; return table.concat(out, ",") end
local n = #STUB.sent + 1
STUB.Advance(100)
assert(gcs(n) == "2", "sent with a heartbeat: " .. gcs(n))
printed = #STUB.printed
J.Add("quest", { id = 3, name = "c" })
assert(G.IsDone(cnt) and #STUB.printed == printed + 1, "reached at 5, announced")
n = #STUB.sent + 1
STUB.Advance(100)
assert(gcs(n) == "3", "the new part goes out: " .. gcs(n))
STUB.Receive("LVLM", C.Encode("gc", { id = cnt.id, n = 3 }), "GUILD", "Mario-Testrealm")
assert(#STUB.printed == printed + 1, "a reached goal is not announced again")

-- a newcomer gets my contributions and my completed dungeon
n = #STUB.sent
STUB.iAmOfficer = false
STUB.Receive("LVLM", C.Encode("ping", {}), "GUILD", "Nuevo-Testrealm")
STUB.Advance(6)
local kinds = {}
for i = n + 1, #STUB.sent do kinds[#kinds + 1] = (C.Decode(STUB.sent[i].msg)) end
local s = table.concat(kinds, ",")
assert(s:find("gc", 1, true) and s:find("gd", 1, true), "contributions and my completion re-sent: " .. s)
