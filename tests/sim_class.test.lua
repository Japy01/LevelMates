STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local n = #STUB.sent
SlashCmdList.LEVELMATES("sim clase")
assert(#ns.Builds.List() >= 2 and ns.Builds.Of("Mario") and #ns.Macros.Guild() == 1 and #ns.ChatAds.For(5) == 1, "samples for the Class tab and a chat ad")
for i = n + 1, #STUB.sent do local k = ns.Comm.Decode(STUB.sent[i].msg); assert(k ~= "tb" and k ~= "mc", "nothing sent") end
SlashCmdList.LEVELMATES("sim off")
assert(not ns.Builds.Of("Mario") and #ns.Macros.Guild() == 0 and #ns.ChatAds.For(5) == 0, "cleared")
SlashCmdList.LEVELMATES("sim xp")
assert(ns.GroupXP.frame and ns.GroupXP.frame:IsShown() and #ns.GroupXP.Rows() == 3, "group XP bars with two fake guildmates")
SlashCmdList.LEVELMATES("sim muertes")
assert(#ns.Feed.List(nil, true) == 2, "two deaths on the wall")
SlashCmdList.LEVELMATES("sim off")
assert(not ns.GroupXP.frame:IsShown() and #ns.Feed.List(nil, true) == 0, "cleared")
local n = #STUB.sent
SlashCmdList.LEVELMATES("sim xp"); STUB.Fire("PLAYER_XP_UPDATE", "player"); STUB.Advance(40)
for i = n + 1, #STUB.sent do assert(ns.Comm.Decode(STUB.sent[i].msg) ~= "xp", "the sim sends no XP") end
SlashCmdList.LEVELMATES("sim off")
