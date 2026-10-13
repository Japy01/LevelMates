-- the limits (2 runs each, 10 in the guild) count real runs, not /lm sim samples
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(30)
local M = ns.Meetups
for i = 1, 12 do M.AddSample("Sim" .. i, (i % 14) + 1, 60 + i, {}) end
assert(M.Create{ d = 5, at = M.Now() + 60, role = "T" }, "samples do not fill the guild's ten")
assert(M.Create{ d = 6, at = M.Now() + 90, role = "T" }, "my second")
assert(not M.Create{ d = 7, at = M.Now() + 120, role = "T" }, "my third: refused, two each")
