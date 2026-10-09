-- Dungeons.lua: the dungeons the group finder knows. Starts with the six confirmed in the Forever journal;
-- to add one, append a row here and add its DUNGEON_* name to both locale files (tests/policy.test.mjs checks that).
local _, ns = ...
local D = {}
ns.Dungeons = D

D.list = {
	{ id = 1, key = "DUNGEON_HALL_OF_THANES",      min = 13, max = 20 },
	{ id = 2, key = "DUNGEON_RAGEFIRE_CHASM",      min = 13, max = 18 },
	{ id = 3, key = "DUNGEON_RUINS_OF_LORDAERON",  min = 15, max = 22 },
	{ id = 4, key = "DUNGEON_WAILING_CAVERNS",     min = 15, max = 24 },
	{ id = 5, key = "DUNGEON_DEADMINES",           min = 17, max = 26 },
	{ id = 6, key = "DUNGEON_SHADOWFANG_KEEP",     min = 20, max = 30 },
}

local byId = {}
for _, d in ipairs(D.list) do byId[d.id] = d end

function D.Get(id) return byId[id] end
function D.Name(id) local d = byId[id]; return d and ns.L[d.key] or ("#" .. tostring(id)) end
function D.Fits(id, level) local d = byId[id]; return d ~= nil and type(level) == "number" and level >= d.min and level <= d.max end
