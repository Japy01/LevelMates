STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local L, R = ns.L, ns.Roster
local function said(text) for _, p in ipairs(STUB.printed) do if p:find(text, 1, true) then return p end end end
SlashCmdList["LEVELMATES"]("sim")
local sent = #STUB.sent
SlashCmdList["LEVELMATES"]("sim nivel")
assert(R.mates.Mario.level == 31, "Mario goes up one level")
local line = said(string.format(L.LEVELUP_NOTICE, "Mario", 31))
assert(line and line:find("|Haddon:LevelMates:cheer:Mario:31|h", 1, true), "the level-up line with [Congratulate]")
assert(#STUB.sent == sent, "nothing sent")
SlashCmdList["LEVELMATES"]("sim nivel")
assert(R.mates.Mario.level == 32, "again")
