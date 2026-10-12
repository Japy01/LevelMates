STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local C, PT, L, R = ns.Comm, ns.Points, ns.L, ns.Roster
local function last(kind) for i = #STUB.sent, 1, -1 do local k, f = C.Decode(STUB.sent[i].msg); if k == kind then return f end end end
assert(ns.db.settings.sharePoints == true, "on by default")
assert(C.Validate("pt", { t = 120, w = 2910, l = 1, d = 2, h = 0, q = 7 }) and C.Validate("pt", {}), "pt format")

-- weeks start on Monday
local monday = STUB.daysFromCivil(2026, 10, 12) * 86400
assert(PT.Week(monday) == PT.Week(monday + 6 * 86400 + 86399) and PT.Week(monday) == PT.Week(monday - 1) + 1, "Monday to Sunday")

-- what I do counts
STUB.Fire("PLAYER_LEVEL_UP", 21)
STUB.Fire("QUEST_TURNED_IN", 101)
ns.Journal.Add("dungeon", { name = "Deadmines", mates = { "Mario" } })
ns.Journal.Add("dungeon", { name = "Deadmines", mates = {} })   -- alone: nothing
ns.Fire("LM_HELP_GIVEN", "abc12345"); ns.Fire("LM_HELP_GIVEN", "abc12345")   -- the same request once
ns.Fire("LM_GIFT_GIVEN")
local m = PT.Mine()
assert(m.t == 10 + 1 + 15 + 5 + 5 and m.l == 1 and m.q == 1 and m.d == 1 and m.h == 1, "points: " .. m.t)
STUB.Advance(61)
local f = last("pt")
assert(f and f.t == m.t and f.w == PT.Week(time()) and f.d == 1, "shared")

-- a meetup attended: in its hour, grouped with its creator
STUB.Receive("LVLM2", C.Encode("hb", { l = 24, z = 1421 }), "GUILD", "Mario-Testrealm")
ns.Meetups.AddSample("Mario", 5, 10, {})
local meet = ns.Meetups.List()[1]
ns.Sync.Store("qj")[meet.id .. ".Tester"] = { t = "qj", id = meet.id .. ".Tester", o = "Tester", v = 1, e = GetServerTime() + 86400, d = { r = "T" } }   -- I joined it
STUB.partyMembers = { Mario = true }
STUB.Advance(60 * 12)
local before = PT.Mine().t
STUB.Advance(120)
assert(PT.Mine().t == before, "a meetup counts once")
assert(before == m.t + 10, "meetup attended: " .. before)
STUB.partyMembers = {}

-- guildmates' points, the guild total and level
STUB.Receive("LVLM2", C.Encode("hb", { l = 20, z = 1421 }), "GUILD", "Ana-Testrealm")
STUB.Receive("LVLM2", C.Encode("hb", { l = 24, z = 1421 }), "GUILD", "Mario-Testrealm")   -- back on the board after the meetup wait
local week = PT.Week(time())
STUB.Receive("LVLM2", C.Encode("pt", { t = 300, w = week, l = 4, d = 2, h = 3, q = 20 }), "GUILD", "Mario-Testrealm")
STUB.Receive("LVLM2", C.Encode("pt", { t = 50, w = week - 1, l = 9, d = 9, h = 9, q = 9 }), "GUILD", "Ana-Testrealm")
STUB.Receive("LVLM2", C.Encode("pt", { t = 9999, w = week }), "GUILD", "Nadie-Testrealm")
local total = PT.GuildTotal()
assert(total == PT.Mine().t + 300 + 50, "the guild total: " .. total)
local lvl, into, need = PT.Level(350)
assert(lvl == 3 and into == 50 and need == 300, "level 3 at 350 (100 + 200 before): " .. lvl .. " " .. into .. " " .. need)
assert(PT.Level(0) == 1 and select(3, PT.Level(0)) == 100, "level 1 at 0")

-- rankings: this week only, top 3, nobody with nothing
local rk = PT.Rankings()
assert(rk.l[1].name == "Mario" and rk.l[1].n == 4 and #rk.l == 2, "levels: Mario first, Ana (last week) out")
assert(rk.h[1].name == "Mario", "helps")

-- the weekly challenge: rotates by week, scales with players, done once
local ch = PT.Challenge()
assert(ch.goal >= 1 and ch.text ~= "" and ch.have >= 0, "a challenge")
ns.db.points = ns.db.points or {}
local idx = week % 4 + 1
assert(ch.cat == PT.CHALLENGES[idx].cat, "rotates with the week")
STUB.printed = {}
STUB.Receive("LVLM2", C.Encode("pt", { t = 99999, w = week, l = 999, d = 999, h = 999, q = 9999 }), "GUILD", "Mario-Testrealm")
local said = 0
for _, line in ipairs(STUB.printed) do if line:find(L.CHALLENGE_DONE_SHORT, 1, true) then said = said + 1 end end
assert(said == 1 and PT.Challenge().done, "done, told once")
STUB.Receive("LVLM2", C.Encode("pt", { t = 99999, w = week, l = 999, d = 999, h = 999, q = 9999 }), "GUILD", "Mario-Testrealm")
said = 0
for _, line in ipairs(STUB.printed) do if line:find(L.CHALLENGE_DONE_SHORT, 1, true) then said = said + 1 end end
assert(said == 1, "not again")

-- out of the guild or 30 days unseen: no longer counted
STUB.guildMembers = { Tester = true, Ana = true, Luis = true }; R.InvalidateGuildRoster()
assert(PT.GuildTotal() == PT.Mine().t + 50, "Mario left")
STUB.guildMembers = { Tester = true, Mario = true, Ana = true, Luis = true }; R.InvalidateGuildRoster()
ns.db.points[GetGuildInfo("player")].Ana.at = time() - 31 * 86400
assert(PT.GuildTotal() == PT.Mine().t + 99999, "Ana forgotten")

-- a new week resets my weekly counters, not my total
local t0 = PT.Mine().t
ns.char.pointsByGuild["Test Guild"].w = PT.Week() - 1   -- as if the counters were from last week
local m2 = PT.Mine()
assert(m2.t == t0 and m2.l == 0 and m2.d == 0 and m2.w == PT.Week(), "weekly reset")

-- sharing off: withdrawn, and I stop counting
ns.db.settings.sharePoints = false
PT.SetSharing()
assert(last("pt").t == nil, "withdrawn")
ns.db.settings.sharePoints = true
PT.SetSharing()

-- points belong to the guild: a new one starts from zero
local here = PT.Mine().t
STUB.player.guild = "Other Guild"
assert(PT.Mine().t == 0, "a new guild: from zero")
STUB.player.guild = "Test Guild"
assert(PT.Mine().t == here, "back: my points there")
-- helps: twice a day per asker
local h0 = PT.Mine().h
for i = 1, 4 do ns.Fire("LM_HELP_GIVEN", "x" .. i, "Mario") end
assert(PT.Mine().h == h0 + 2, "twice a day for the same asker: " .. PT.Mine().h - h0)
ns.Fire("LM_HELP_GIVEN", "y1", "Ana")
assert(PT.Mine().h == h0 + 3, "another asker counts")
-- not sharing: nothing goes out when points change
ns.db.settings.sharePoints = false
local n = #STUB.sent
STUB.Fire("QUEST_TURNED_IN", 777); STUB.Advance(70)
for i = n + 1, #STUB.sent do assert(C.Decode(STUB.sent[i].msg) ~= "pt", "nothing sent while not sharing") end
ns.db.settings.sharePoints = true
-- the realm's clock when the client has it
C_DateAndTime = { GetServerTimeLocal = function() return monday + 3600 end }
assert(PT.Week() == PT.Week(monday + 3600), "the week by the realm's clock")
C_DateAndTime = nil
