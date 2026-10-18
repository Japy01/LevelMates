-- The guild list is read from the game once per change (audit 2026-10-17): the counts and lists the book draws
-- many times a refresh share one read until GUILD_ROSTER_UPDATE (or a club member event) says it changed
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(30)
local R = ns.Roster
local reads = 0
local old = C_Club.GetClubMembers
C_Club.GetClubMembers = function(...) reads = reads + 1; return old(...) end
R.InvalidateGuildRoster()
R.OnlineCount(); R.OnlineCount(); R.OnlineWithout(); R.GuildMembers()
assert(reads == 1, "one read for many askers: " .. reads)
STUB.Fire("GUILD_ROSTER_UPDATE")
R.OnlineCount()
assert(reads == 2, "the game said it changed: read again: " .. reads)
STUB.Fire("CLUB_MEMBER_PRESENCE_UPDATED")
R.OnlineCount()
assert(reads == 3, "someone came or went: read again: " .. reads)
-- a stale list is never kept for long anyway
STUB.Advance(120)
R.OnlineCount()
assert(reads == 4, "after a while, read again: " .. reads)
print("ok")
