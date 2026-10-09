-- The cap notice can be turned off.
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
ns.db.settings.restedNotices = false
STUB.player.level = 20; STUB.player.rested = 1600
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(2)
STUB.Fire("UPDATE_EXHAUSTION")
for _, line in ipairs(STUB.printed) do assert(not line:find(string.format(ns.L.RESTED_MAX, ns.Rested.CAP), 1, true), "no max notice with the option off") end
