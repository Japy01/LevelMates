-- Dungeons.lua: the dungeons the group finder knows, with their card art: the fourteen of the Forever dungeon journal.
-- To add one, append a row here and add its DUNGEON_* name to both locale files (tests/policy.test.mjs checks that).
-- Ids 1-6 travel in messages (lfg, dun goals): never renumber them.
local _, ns = ...
local D = {}
ns.Dungeons = D

-- Card art: the game's own loading screens, cropped as the dungeon journal does. ForeverDungeonJournal's own
-- pictures are used from its folder only while it is loaded; they are never copied here.
local LS = "Interface\\Glues\\LoadingScreens\\"
local FDJ = "Interface\\AddOns\\ForeverDungeonJournal\\Media\\"
local WIDE, TALL = { 0.02, 0.98, 0.25, 0.82 }, { 0.02, 0.98, 0.24, 0.82 }
local NEW, OWN = { 0, 1, 0.12, 0.88 }, { 0.03, 0.97, 0.05, 0.95 }

D.list = {
	{ id = 1,  key = "DUNGEON_HALL_OF_THANES",      min = 13, max = 20, needs = "ForeverDungeonJournal", art = FDJ .. "HallOfThanes", coords = OWN },
	{ id = 2,  key = "DUNGEON_RAGEFIRE_CHASM",      min = 13, max = 18, art = LS .. "LoadScreenRagefireChasm", coords = WIDE },
	{ id = 3,  key = "DUNGEON_RUINS_OF_LORDAERON",  min = 15, max = 22, needs = "ForeverDungeonJournal", art = FDJ .. "RuinsOfLordaeron", coords = OWN },
	{ id = 4,  key = "DUNGEON_WAILING_CAVERNS",     min = 15, max = 24, art = LS .. "LoadScreenWailingCaverns", coords = WIDE },
	{ id = 5,  key = "DUNGEON_DEADMINES",           min = 17, max = 26, art = LS .. "LoadScreenDeadmines", coords = WIDE },
	{ id = 6,  key = "DUNGEON_SHADOWFANG_KEEP",     min = 20, max = 30, art = LS .. "LoadScreenShadowFangKeep", coords = TALL },
	{ id = 7,  key = "DUNGEON_BLACKFATHOM_DEEPS",   min = 24, max = 32, art = LS .. "LoadScreenBlackFathomDeeps", coords = WIDE },
	{ id = 8,  key = "DUNGEON_STOCKADE",            min = 24, max = 32, art = 131870, coords = TALL },
	{ id = 9,  key = "DUNGEON_EXCAVATION_WETLANDS", min = 26, max = 33, art = 7963777, coords = NEW },
	{ id = 10, key = "DUNGEON_DALARAN",             min = 28, max = 33, art = 7963775, coords = NEW },
	{ id = 11, key = "DUNGEON_GNOMEREGAN",          min = 29, max = 38, art = LS .. "LoadScreenGnomeregan", coords = TALL },
	{ id = 12, key = "DUNGEON_RAZORFEN_KRAUL",      min = 29, max = 38, art = 131865, coords = TALL },
	{ id = 13, key = "DUNGEON_SM_GRAVEYARD",        min = 30, max = 38, art = LS .. "LoadScreenScarletMonastery2", coords = TALL },
	{ id = 14, key = "DUNGEON_SM_LIBRARY",          min = 33, max = 41, needs = "ForeverDungeonJournal", art = FDJ .. "ScarletMonasteryLibraryHome", coords = { 0, 1, 0.06, 0.94 },
		fallback = LS .. "LoadScreenScarletMonastery2", fallbackCoords = TALL },
}

local byId = {}
for _, d in ipairs(D.list) do byId[d.id] = d end

function D.Get(id) return byId[id] end
function D.Name(id) local d = byId[id]; return d and ns.L[d.key] or ("#" .. tostring(id)) end
function D.Fits(id, level) local d = byId[id]; return d ~= nil and type(level) == "number" and level >= d.min and level <= d.max end

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
	if d.needs and not (C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded(d.needs)) then return d.fallback, d.fallbackCoords end
	return d.art, d.coords
end
