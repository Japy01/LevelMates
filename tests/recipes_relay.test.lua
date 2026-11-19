STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(30)
local RC, C, R = ns.Recipes, ns.Comm, ns.Roster
STUB.guildMembers = { Tester = true, Ana = true, Mario = true }
R.InvalidateGuildRoster()
STUB.Receive("LVLM2", C.Encode("hb", { l = 30, z = 1412 }), "GUILD", "Mario-Testrealm")
local snapshot = { a = "Ana", p = 171, t = GetServerTime() - 50, i = RC.Encode({858}), r = 120 }
local function deliver()
	STUB.Receive("LVLM2", C.Encode("rcl", snapshot), "WHISPER", "Mario-Testrealm")
end
deliver()
assert(not RC.Of("Ana")[171], "only requested books are accepted")
RC.RequestProfession(171)
deliver()
assert(RC.Of("Ana")[171].items[1] == 858 and RC.Of("Ana")[171].t == snapshot.t)
STUB.Receive("LVLM2", C.Encode("pf", {}), "GUILD", "Ana-Testrealm")
deliver()
assert(not RC.Of("Ana")[171], "a received withdrawal blocks stale relays")
