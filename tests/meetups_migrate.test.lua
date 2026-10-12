-- 0.3.2 saved meetups and joins become records once, without errors or duplicates
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
local M = ns.Meetups
local at = M.Now() + 120
ns.db.meetups = { ["Test Guild"] = {
	ab12cd34 = { id = "ab12cd34", d = 5, at = at, n = "vieja", by = "Mario", joined = { Tester = "H" } },
	simx = { id = "simx", d = 4, at = at, by = "Ana", sim = true },
	rota = "basura",
} }
ns.char.meetJoins = { ab12cd34 = "H" }
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local list = M.List()
assert(#list == 1 and list[1].by == "Mario" and list[1].n == "vieja", "the old meetup is there: " .. #list)
assert(M.MyRole("ab12cd34") == "H", "my old join too")
assert(ns.db.meetups["Test Guild"] == nil and ns.char.meetJoins == nil, "the old tables are gone")
STUB.Fire("PLAYER_ENTERING_WORLD", false, true); STUB.Advance(1)
assert(#M.List() == 1, "no duplicates after a reload")
