STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local C, RA, R, L = ns.Comm, ns.Rares, ns.Roster, ns.L
local function last(kind) for i = #STUB.sent, 1, -1 do local k, f = C.Decode(STUB.sent[i].msg); if k == kind then return f end end end
local function count(kind, from) local n = 0; for i = (from or 0) + 1, #STUB.sent do if (C.Decode(STUB.sent[i].msg)) == kind then n = n + 1 end end; return n end
STUB.guildMembers = { Tester = true, Mario = true }
R.InvalidateGuildRoster()
STUB.Receive("LVLM", C.Encode("hb", { l = 20, z = 1412 }), "GUILD", "Mario-Testrealm")
assert(ns.db.settings.rareNotices == true, "on by default")
ns.db.settings.sharePos = true   -- sightings carry my position: they need position sharing on
assert(C.Validate("rr", { n = "Mangaleta", z = 1412, x = 42.5, y = 61 }) and C.Validate("rr", { n = "Mangaleta", z = 1412 }) == false, "rr format")

-- I target a live rare: the guild hears it once in 15 minutes
STUB.player.mapId = 1412; STUB.pos = { 0.425, 0.61 }
STUB.units.target = { name = "Mangaleta", class = "rare" }
STUB.Fire("PLAYER_TARGET_CHANGED")
local f = last("rr")
assert(f and f.n == "Mangaleta" and f.z == 1412 and f.x == 42.5 and f.y == 61, "sighting sent")
local n = #STUB.sent
STUB.Fire("PLAYER_TARGET_CHANGED"); STUB.units.mouseover = STUB.units.target; STUB.Fire("UPDATE_MOUSEOVER_UNIT")
assert(count("rr", n) == 0, "not again soon")
STUB.Advance(RA.THROTTLE + 1)
STUB.Fire("PLAYER_TARGET_CHANGED")
assert(count("rr", n) == 1, "again after 15 minutes")
-- not rares, dead rares, players: nothing
n = #STUB.sent
STUB.units.target = { name = "Lobo", class = "normal" }; STUB.Fire("PLAYER_TARGET_CHANGED")
STUB.units.target = { name = "Muerto", class = "rareelite", dead = true }; STUB.Fire("PLAYER_TARGET_CHANGED")
STUB.units.target = { name = "Pepe", class = "rare", player = true }; STUB.Fire("PLAYER_TARGET_CHANGED")
assert(count("rr", n) == 0, "only live, non-player rares")
-- protected values: nothing
issecretvalue = function(v) return v == "Secreto" end
STUB.units.target = { name = "Secreto", class = "rare" }; STUB.Fire("PLAYER_TARGET_CHANGED")
assert(count("rr", n) == 0, "protected names are not sent")
issecretvalue = nil

-- a guildmate's sighting: told in the same map, with a [Waypoint] link
STUB.Receive("LVLM", C.Encode("hb", { l = 20, z = 1412 }), "GUILD", "Mario-Testrealm")   -- back in the roster after the 15 minutes above
STUB.Receive("LVLM", C.Encode("rr", { n = "Rey Mosh", z = 1412, x = 30, y = 40 }), "GUILD", "Mario-Testrealm")
local line = STUB.printed[#STUB.printed]
assert(line:find(string.format(L.RARE_SEEN, "Mario", "Rey Mosh", "Map 1412"), 1, true) and line:find("|Haddon:LevelMates:way:1412:30.0:40.0|h", 1, true), "notice with the link")
assert(UIErrorsFrame.messages[#UIErrorsFrame.messages] == string.format(L.RARE_SEEN, "Mario", "Rey Mosh", "Map 1412"), "on screen")
local printed = #STUB.printed
STUB.Receive("LVLM", C.Encode("rr", { n = "Rey Mosh", z = 1412, x = 30, y = 40 }), "GUILD", "Mario-Testrealm")
STUB.Receive("LVLM", C.Encode("rr", { n = "Otro", z = 1421, x = 30, y = 40 }), "GUILD", "Mario-Testrealm")
STUB.Receive("LVLM", C.Encode("rr", { n = "Extraño", z = 1412, x = 30, y = 40 }), "GUILD", "Nadie-Testrealm")
assert(#STUB.printed == printed, "no repeats, other maps or strangers")
-- the link sets the waypoint
local wp
C_Map.CanSetUserWaypointOnMap = function() return true end
C_Map.SetUserWaypoint = function(p) wp = p end
UiMapPoint = { CreateFromCoordinates = function(m, x, y) return { m = m, x = x, y = y } end }
STUB.ClickLink("addon:LevelMates:way:1412:30.0:40.0")
assert(wp and wp.m == 1412 and math.abs(wp.x - 0.30) < 1e-9 and math.abs(wp.y - 0.40) < 1e-9, "waypoint set")
-- option off
ns.db.settings.rareNotices = false
STUB.Advance(400)
STUB.Receive("LVLM", C.Encode("hb", { l = 20, z = 1412 }), "GUILD", "Mario-Testrealm")
STUB.Receive("LVLM", C.Encode("rr", { n = "Rey Mosh", z = 1412, x = 30, y = 40 }), "GUILD", "Mario-Testrealm")
assert(#STUB.printed == printed, "option off")
