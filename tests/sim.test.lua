-- /lm sim: local-only fake guildmates for testing alone. Goes through the real decode path; sends nothing.
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local R = ns.Roster
STUB.player.realm = "Classic Beta PvP"   -- realm names have spaces; sender names carry the realm without them
STUB.ambiguateKeepsRealm = true          -- Forever's Ambiguate left "Mario-ClassicBetaPvP" untouched (screenshot)
STUB.player.mapId = 1421
STUB.quests = { 1098 }
local sentBefore = #STUB.sent
SlashCmdList["LEVELMATES"]("sim")
assert(#R.List() == 3, "three fake mates: " .. #R.List())
assert(#STUB.sent == sentBefore, "simulation sends nothing")
assert(R.mates.Mario and R.mates.Mario.mapId == 1421 and R.mates.Mario.hasSlot, "Mario on my map with a free slot")
assert(R.mates.Mario.quests[1098], "Mario shares one of my quests")
assert(R.mates.Ana.mapId ~= 1421, "Ana on another map")
-- a fake help request from Mario on my map: notice and waypoint, nothing sent
local wp
C_Map.SetUserWaypoint = function(p) wp = p end
C_Map.CanSetUserWaypointOnMap = function() return true end
UiMapPoint = { CreateFromCoordinates = function(m, x, y) return { uiMapID = m, x = x, y = y } end }
SlashCmdList["LEVELMATES"]("sim help")
assert(ns.Help.List()[1] and wp and wp.uiMapID == 1421, "fake help request shows up with a waypoint")
assert(#STUB.sent == sentBefore, "still nothing sent")
-- clear removes only the fakes
SlashCmdList["LEVELMATES"]("sim off")
assert(#R.List() == 0 and #ns.Help.List() == 0, "fakes removed")
