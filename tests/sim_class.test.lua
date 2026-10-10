STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local n = #STUB.sent
SlashCmdList.LEVELMATES("sim clase")
assert(#ns.Builds.List() >= 2 and ns.Builds.Of("Mario") and #ns.Macros.Guild() == 1 and #ns.ChatAds.For(5) == 1, "samples for the Class tab and a chat ad")
for i = n + 1, #STUB.sent do local k = ns.Comm.Decode(STUB.sent[i].msg); assert(k ~= "tb" and k ~= "mc", "nothing sent") end
SlashCmdList.LEVELMATES("sim off")
assert(not ns.Builds.Of("Mario") and #ns.Macros.Guild() == 0 and #ns.ChatAds.For(5) == 0, "cleared")
