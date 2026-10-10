-- Dungeons.lua: the dungeons the group finder knows, with their card art: the fourteen of the Forever dungeon journal.
-- To add one, append a row here and add its DUNGEON_* name to both locale files (tests/policy.test.mjs checks that).
-- Ids 1-6 travel in messages (lfg, dun goals): never renumber them.
local _, ns = ...
local D = {}
ns.Dungeons = D

-- Card art: only the game's own loading screens (classic ones by path, Forever's new ones by file id), cropped to
-- the card. Nothing is copied from anyone; the textures already ship with the game.
-- Forever's ids (community listfile, camelot160/main): 7963775 loadscreen_camelot_dalaran, 7963777 _excavation,
-- 7963781 _oldironforge (Hall of Thanes), 7963782 _ruinsoflordaeron.
local LS = "Interface\\Glues\\LoadingScreens\\"
local WIDE, TALL = { 0.02, 0.98, 0.25, 0.82 }, { 0.02, 0.98, 0.24, 0.82 }
local NEW = { 0, 1, 0.12, 0.88 }
-- Both Monastery wings are one instance in game, named without the wing (as ForeverDungeonJournal notes too).
local SM = { "Scarlet Monastery", "Monasterio Escarlata" }

D.list = {
	{ id = 1,  key = "DUNGEON_HALL_OF_THANES",      min = 13, max = 20, art = 7963781, coords = NEW },
	{ id = 2,  key = "DUNGEON_RAGEFIRE_CHASM",      min = 13, max = 18, art = LS .. "LoadScreenRagefireChasm", coords = WIDE },
	{ id = 3,  key = "DUNGEON_RUINS_OF_LORDAERON",  min = 15, max = 22, art = 7963782, coords = NEW },
	{ id = 4,  key = "DUNGEON_WAILING_CAVERNS",     min = 15, max = 24, art = LS .. "LoadScreenWailingCaverns", coords = WIDE },
	{ id = 5,  key = "DUNGEON_DEADMINES",           min = 17, max = 26, art = LS .. "LoadScreenDeadmines", coords = WIDE },
	{ id = 6,  key = "DUNGEON_SHADOWFANG_KEEP",     min = 20, max = 30, art = LS .. "LoadScreenShadowFangKeep", coords = TALL },
	{ id = 7,  key = "DUNGEON_BLACKFATHOM_DEEPS",   min = 24, max = 32, art = LS .. "LoadScreenBlackFathomDeeps", coords = WIDE },
	{ id = 8,  key = "DUNGEON_STOCKADE",            min = 24, max = 32, art = 131870, coords = TALL },
	{ id = 9,  key = "DUNGEON_EXCAVATION_WETLANDS", min = 26, max = 33, art = 7963777, coords = NEW },
	{ id = 10, key = "DUNGEON_DALARAN",             min = 28, max = 33, art = 7963775, coords = NEW },
	{ id = 11, key = "DUNGEON_GNOMEREGAN",          min = 29, max = 38, art = LS .. "LoadScreenGnomeregan", coords = TALL },
	{ id = 12, key = "DUNGEON_RAZORFEN_KRAUL",      min = 29, max = 38, art = 131865, coords = TALL },
	{ id = 13, key = "DUNGEON_SM_GRAVEYARD",        min = 30, max = 38, art = LS .. "LoadScreenScarletMonastery2", coords = TALL, instance = SM },
	{ id = 14, key = "DUNGEON_SM_LIBRARY",          min = 33, max = 41, art = LS .. "LoadScreenScarletMonastery2", coords = TALL, instance = SM },
}

local byId = {}
for _, d in ipairs(D.list) do byId[d.id] = d end

function D.Get(id) return byId[id] end
function D.Name(id) local d = byId[id]; return d and ns.L[d.key] or ("#" .. tostring(id)) end
function D.Fits(id, level) local d = byId[id]; return d ~= nil and type(level) == "number" and level >= d.min and level <= d.max end

-- Whether the instance name the game reports (GetInstanceInfo) is this dungeon: its own name or one of its
-- in-game instance names (the Monastery wings share one).
function D.Matches(id, instanceName)
	local d = byId[id]
	if not d or not instanceName then return false end
	if instanceName == D.Name(id) then return true end
	for _, n in ipairs(d.instance or {}) do if n == instanceName then return true end end
	return false
end

-- By level range, for the cards.
function D.Sorted()
	local out = {}
	for _, d in ipairs(D.list) do out[#out + 1] = d end
	table.sort(out, function(a, b)
		if a.min ~= b.min then return a.min < b.min end
		if a.max ~= b.max then return a.max < b.max end
		return a.id < b.id
	end)
	return out
end

-- The card's texture (path or file id) and crop; nil when there is none to show.
function D.Art(id)
	local d = byId[id]
	if not d then return nil end
	return d.art, d.coords
end
