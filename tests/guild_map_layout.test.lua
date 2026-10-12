-- map layout: pins on the map viewed (zone or continent), bundles of 4+, stale ones gone, never me
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(30)
local GM, C = ns.GuildMap, ns.Comm
local function hb(name, z, x, y) STUB.Receive("LVLM2", C.Encode("hb", { l = 20, z = z, x = x, y = y, c = "MAGE" }), "GUILD", name .. "-Testrealm") end
hb("Mario", 1429, 10, 20); hb("Ana", 1429, 50, 50); hb("Luis", 1429, 90, 80)
local pins = GM.Layout(1429, 1000, 700, 18)
assert(#pins == 3, "three pins: " .. #pins)
local mario
for _, p in ipairs(pins) do if p.names[1] == "Mario" then mario = p end end
assert(mario and math.abs(mario.x - 100) < 0.01 and math.abs(mario.y - 140) < 0.01 and mario.mapId == 1429, "where Mario is")
-- four within one pin: a bundle
STUB.guildMembers.Pepe = true; ns.Roster.InvalidateGuildRoster()
hb("Mario", 1429, 50.1, 50.1); hb("Luis", 1429, 50.2, 50); hb("Pepe", 1429, 49.9, 50.1)
pins = GM.Layout(1429, 1000, 700, 18)
assert(#pins == 1 and #pins[1].names == 4, "one bundle of four")
hb("Pepe", 1429, 10, 10)
pins = GM.Layout(1429, 1000, 700, 18)
assert(#pins == 4, "three close: no bundle")
-- a continent: zone 1429 sits in continent 1415 at (0.2 + x/4, 0.3 + y/4)
CreateVector2D = CreateVector2D or function(x, y) return { x = x, y = y, GetXY = function(self) return self.x, self.y end } end
C_Map.GetWorldPosFromMapPos = function(mapId, pos) if mapId ~= 1429 then return nil end; return 0, CreateVector2D(1000 + pos.x * 100, 2000 + pos.y * 100) end
C_Map.GetMapPosFromWorldPos = function(cont, world, override)
	if override ~= 1415 then return nil end
	return 1415, CreateVector2D(0.2 + (world.x - 1000) / 400, 0.3 + (world.y - 2000) / 400)
end
pins = GM.Layout(1415, 1000, 700, 18)
assert(#pins == 4, "on the continent too: " .. #pins)
local first
for _, p in ipairs(pins) do if p.names[1] == "Pepe" then first = p end end
assert(first and math.abs(first.x - (0.2 + 0.1 / 4) * 1000) < 0.5, "converted")
assert(#GM.Layout(1416, 1000, 700, 18) == 0, "another continent: nothing")
C_Map.GetWorldPosFromMapPos = function() error("boom") end
assert(#GM.Layout(1415, 1000, 700, 18) == 0, "a failing conversion: nothing, no error")
-- stale positions go
STUB.Advance(301)
hb("Ana", 1429, 50, 50)
pins = GM.Layout(1429, 1000, 700, 18)
assert(#pins == 1 and pins[1].names[1] == "Ana", "only the fresh one")
-- never me
for _, p in ipairs(pins) do for _, n in ipairs(p.names) do assert(n ~= ns.Me(), "never me") end end
