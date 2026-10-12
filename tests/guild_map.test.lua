STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local C, GM, B, R, L = ns.Comm, ns.GuildMap, ns.Board, ns.Roster, ns.L
STUB.guildMembers = { Tester = true, Mario = true, Ana = true, Luis = true }
R.InvalidateGuildRoster()
STUB.Receive("LVLM2", C.Encode("hb", { l = 30, z = 1412, c = "MAGE", x = 40, y = 50 }), "GUILD", "Mario-Testrealm")
STUB.Receive("LVLM2", C.Encode("hb", { l = 20, z = 1412 }), "GUILD", "Ana-Testrealm")             -- no position shared
STUB.Receive("LVLM2", C.Encode("hb", { l = 25, z = 1421, x = 10, y = 10 }), "GUILD", "Luis-Testrealm")
assert(ns.db.settings.mapPins == true, "on by default")

-- pins: guildmates sharing their position, on the map shown
WorldMapFrame:Show(); WorldMapFrame:OnMapChanged()
local shown = {}
for _, p in ipairs(GM.pins) do if p:IsShown() then shown[#shown + 1] = p end end
assert(#shown == 1 and shown[1].mate == "Mario", "Mario only")
local pt = shown[1].point
assert(pt[1] == "CENTER" and pt[3] == "TOPLEFT" and pt[4] == 400 and pt[5] == -350, "at his position")
shown[1].scripts.OnEnter(shown[1])
assert(GameTooltip.lines[1]:find("Mario", 1, true) and GameTooltip.lines[1]:find("30", 1, true), "name and level on hover")
STUB.worldMapId = 1421; WorldMapFrame:OnMapChanged()
shown = {}
for _, p in ipairs(GM.pins) do if p:IsShown() then shown[#shown + 1] = p end end
assert(#shown == 1 and shown[1].mate == "Luis", "another map, another guildmate")
ns.db.settings.mapPins = false; GM.Refresh()
for _, p in ipairs(GM.pins) do assert(not p:IsShown(), "option off: no pins") end
ns.db.settings.mapPins = true

-- the busiest zone on the Guildmates tab
local n, mapId = GM.Busiest()
assert(n == 3 and mapId == 1412, "Mario, Ana and me in 1412: " .. tostring(n))
B.ShowTab("mates")
assert(B.restedText.text:find(string.format(L.ZONE_BUSY, 3, "Map 1412"), 1, true), "shown by the heading: " .. tostring(B.restedText.text))
B.ShowTab("goals")
assert(not B.restedText.text:find(string.format(L.ZONE_BUSY, 3, "Map 1412"), 1, true), "only on Guildmates")
