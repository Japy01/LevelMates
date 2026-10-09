STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local C, P, R = ns.Comm, ns.Personal, ns.Roster
STUB.guildMembers = { Tester = true, Mario = true }
R.InvalidateGuildRoster()
STUB.player.level = 30
assert(P.Set(40, 7), "set")

-- removed inside a dungeon: refused, so the withdraw must survive a /reload or a logout (SavedVariables only)
STUB.inInstance = true
assert(P.Clear(), "removed")
local saved = LevelMatesDB.chars[ns.PlayerKey()]
assert(saved.goalPending == true, "the pending withdraw is saved with the character")

-- next session: the first heartbeat sends it, once
STUB.inInstance = false
local n = #STUB.sent
ns.Fire("LM_HB_SENT"); ns.Fire("LM_ANNOUNCED")
local withdraws = 0
for i = n + 1, #STUB.sent do local k, f = C.Decode(STUB.sent[i].msg); if k == "gp" and f.l == 0 then withdraws = withdraws + 1 end end
assert(withdraws == 1 and not saved.goalPending, "the withdraw goes out once and is no longer pending")
