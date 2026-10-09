-- Logging in with full rested XP says so.
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.player.level = 20; STUB.player.rested = 1600
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(2)
local found = false
for _, line in ipairs(STUB.printed) do if line:find(string.format(ns.L.RESTED_MAX, ns.Rested.CAP), 1, true) then found = true end end
assert(found, "max notice at login")
