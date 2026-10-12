-- (3) the first look at a list still loading is not taken as the baseline
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(30)
local GH = ns.GuildHistory
STUB.guildMembers = { Tester = true, Mario = true }
STUB.guildTotal = 6   -- the game says six, two arrived so far
ns.Roster.InvalidateGuildRoster(); STUB.Fire("GUILD_ROSTER_UPDATE"); STUB.Advance(3)
STUB.guildMembers = { Tester = true, Mario = true, Ana = true, Luis = true, Pepe = true, Zoe = true }
ns.Roster.InvalidateGuildRoster(); STUB.Fire("GUILD_ROSTER_UPDATE"); STUB.Advance(3)
assert(#GH.List() == 0, "the full list is the baseline: no joins: " .. #GH.List())
