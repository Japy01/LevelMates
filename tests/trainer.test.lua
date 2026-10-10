local services, filterUnavailable = {}, false
function GetNumTrainerServices()
	local n = 0
	for _, s in ipairs(services) do if s.type ~= "unavailable" or filterUnavailable then n = n + 1 end end
	return n
end
function GetTrainerServiceInfo(i)
	local k = 0
	for _, s in ipairs(services) do
		if s.type ~= "unavailable" or filterUnavailable then k = k + 1; if k == i then return s.name, s.type, 1, s.level, s.rank end end
	end
end
function GetTrainerServiceTypeFilter(t) if t == "unavailable" then return filterUnavailable end; return true end
function SetTrainerServiceTypeFilter(t, on) if t == "unavailable" then filterUnavailable = on and true or false end end
local tradeskill = false
function IsTradeskillTrainer() return tradeskill end
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local T, L = ns.Trainer, ns.L
assert(ns.db.settings.trainerNotices == true, "on by default")
STUB.printed = {}

-- before any visit: a reminder on even levels only
STUB.player.level = 21; STUB.Fire("PLAYER_LEVEL_UP", 21)
assert(#STUB.printed == 0 or not STUB.printed[#STUB.printed]:find(string.format(L.TRAINER_EVEN, 21), 1, true), "odd level: nothing")
STUB.player.level = 22; STUB.Fire("PLAYER_LEVEL_UP", 22)
assert(STUB.printed[#STUB.printed]:find(string.format(L.TRAINER_EVEN, 22), 1, true), "even level: visit your trainer")

-- a visit records what cannot be learned yet, even with the "unavailable" filter off, and leaves the filter alone
services = {
	{ name = "Fireball", rank = "Rank 5", type = "available", level = 22 },
	{ name = "Frost Nova", rank = "Rank 2", type = "unavailable", level = 26 },
	{ name = "Fireball", rank = "Rank 6", type = "unavailable", level = 24 },
	{ name = "Blink", rank = "", type = "unavailable", level = 24 },
	{ name = "Polymorph", rank = "Rank 2", type = "used", level = 20 },
}
STUB.Fire("TRAINER_SHOW"); STUB.Advance(0.1)
assert(filterUnavailable == false, "filter restored")
local p = T.Pending()
assert(#p == 3, "three to come: " .. #p)

-- leveling up: the new ones, by name
STUB.printed = {}
STUB.player.level = 23; STUB.Fire("PLAYER_LEVEL_UP", 23)
assert(#STUB.printed == 0, "nothing new at 23")
STUB.player.level = 24; STUB.Fire("PLAYER_LEVEL_UP", 24)
local line = STUB.printed[#STUB.printed]
assert(line:find(string.format(L.TRAINER_NEW, 24, 2, "Fireball (Rank 6), Blink"), 1, true), "two new: " .. tostring(line))
assert(#T.Pending() == 1, "told once")

-- profession trainers do not count; the option stops it
tradeskill = true
services = { { name = "Iron Buckle", type = "unavailable", level = 30 } }
STUB.Fire("TRAINER_SHOW"); STUB.Advance(0.1)
assert(#T.Pending() == 1, "a profession trainer changes nothing")
ns.db.settings.trainerNotices = false
STUB.printed = {}
STUB.player.level = 26; STUB.Fire("PLAYER_LEVEL_UP", 26)
assert(#STUB.printed == 0, "off: silent")
