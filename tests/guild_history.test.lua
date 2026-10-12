-- roster history (joins, leaves, ranks) with guards; the race to 60
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(30)
local GH, F = ns.GuildHistory, ns.Feed
STUB.guildMembers = { Tester = true, Mario = true, Ana = true, Luis = true }
STUB.memberInfo = { Mario = { level = 60, classID = 1 }, Ana = { level = 59, classID = 2 }, Luis = { level = 59, classID = 3 }, Tester = { level = 20 } }
STUB.guildTotal = 4
local function scan() ns.Roster.InvalidateGuildRoster(); STUB.Fire("GUILD_ROSTER_UPDATE"); STUB.Advance(3) end
scan()
assert(#GH.List() == 0, "the first read: a baseline only")
-- join, leave, rank
STUB.guildMembers["Pepe Grillo"] = true; STUB.guildTotal = 5; scan()
assert(GH.List()[1].k == "join" and GH.List()[1].who == "Pepe Grillo", "joined")
local walled = false
for _, e in ipairs(F.List()) do if e.who == "Pepe Grillo" then walled = true end end
assert(walled, "the join on the wall")
STUB.memberInfo.Mario.rank = 3; scan()
assert(GH.List()[1].k == "rankup" and GH.List()[1].who == "Mario", "promoted")
STUB.guildMembers["Pepe Grillo"] = nil; STUB.guildTotal = 4; scan()
assert(GH.List()[1].k == "leave" and GH.List()[1].who == "Pepe Grillo", "left")
-- a partial read: no leaves
STUB.guildMembers.Luis = nil; STUB.guildTotal = 4; scan()
assert(GH.List()[1].k ~= "leave" or GH.List()[1].who ~= "Luis", "partial read: Luis did not leave")
STUB.guildMembers.Luis = true; scan()
-- a mass shrink waits for a second read
for i = 1, 10 do STUB.guildMembers["Alt" .. i] = true end
STUB.guildTotal = 14; scan()
local n = #GH.List()
for i = 1, 10 do STUB.guildMembers["Alt" .. i] = nil end
STUB.guildTotal = 4; scan()
assert(#GH.List() == n, "ten of fourteen gone at once: wait")
scan()
assert(#GH.List() == n + 10, "confirmed: ten leaves")
-- the race: Mario was at 60 already; Ana arrives first; Luis first of his class
STUB.memberInfo.Ana.level = 60; scan()
STUB.memberInfo.Luis.level = 60; scan()
local race = {}
for _, r in ipairs(GH.Race()) do race[r.name] = r end
assert(race.Mario.before and not race.Mario.first, "Mario was there before")
assert(race.Ana.first and race.Ana.firstClass, "Ana first, and first of her class")
assert(race.Luis.firstClass and not race.Luis.first, "Luis first of his class")
assert(GH.Race()[1].level >= GH.Race()[#GH.Race()].level, "ordered by level")
