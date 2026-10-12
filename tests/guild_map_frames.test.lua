-- map frames: same size on screen at any zoom, bundles with a count, a click routes, fresh positions when it opens
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(30)
local GM, C = ns.GuildMap, ns.Comm
local function hb(name, x, y) STUB.Receive("LVLM2", C.Encode("hb", { l = 20, z = 1412, x = x, y = y, c = "MAGE" }), "GUILD", name .. "-Testrealm") end
STUB.worldMapId = 1412
hb("Mario", 40, 50)
WorldMapFrame.ScrollContainer = { GetCanvasScale = function() return 2 end }
local n = #STUB.sent
WorldMapFrame:Show(); WorldMapFrame:OnMapChanged()
local shown = {}
for _, p in ipairs(GM.pins) do if p:IsShown() then shown[#shown + 1] = p end end
assert(#shown == 1 and shown[1].mate == "Mario", "Mario")
assert(math.abs(shown[1].scale - 0.5) < 1e-9 and shown[1].point[4] == 800, "scaled down by the canvas zoom, offsets in its own units")
-- a click: the route to him
local routed
ns.Help.WaypointTo = function(mapId, x, y, label) routed = label end
shown[1].scripts.OnClick(shown[1], "LeftButton")
assert(routed == "Mario", "a click routes to him")
-- opening the map asked for fresh positions, once in 30 s
local asks = 0
for i = n + 1, #STUB.sent do if (C.Decode(STUB.sent[i].msg)) == "mpq" then asks = asks + 1 end end
assert(asks == 1, "asked once: " .. asks)
WorldMapFrame:Hide(); WorldMapFrame:Show(); WorldMapFrame:OnMapChanged()
asks = 0
for i = n + 1, #STUB.sent do if (C.Decode(STUB.sent[i].msg)) == "mpq" then asks = asks + 1 end end
assert(asks == 1, "not again within 30 s")
-- a bundle shows its count
STUB.guildMembers.Pepe = true; ns.Roster.InvalidateGuildRoster()
WorldMapFrame.ScrollContainer = nil
hb("Ana", 40.2, 50); hb("Luis", 40, 50.2); hb("Pepe", 40.1, 50.1)
GM.Refresh()
shown = {}
for _, p in ipairs(GM.pins) do if p:IsShown() then shown[#shown + 1] = p end end
assert(#shown == 1 and shown[1].count:IsShown() and shown[1].count.text == "4", "one bundle of four")
