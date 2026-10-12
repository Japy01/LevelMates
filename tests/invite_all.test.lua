-- invite all: online ones only, once each, never me; one summary line
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local C, B = ns.Comm, ns.Board
STUB.guildMembers["Mario Rossi"] = true; ns.Roster.InvalidateGuildRoster()
STUB.Receive("LVLM2", C.Encode("hb", { l = 20, z = 1421 }), "GUILD", "Mario Rossi-Testrealm")
local invited = {}
C_PartyInfo = C_PartyInfo or {}
C_PartyInfo.InviteUnit = function(n) invited[#invited + 1] = n end
local before = #STUB.printed
local a, off = B.InviteAll({ "Mario Rossi", "Ana", ns.Me(), "Mario Rossi" })
assert(a == 1 and off == 1 and invited[1] == "Mario Rossi" and #invited == 1, "online only, once, never me")
assert(#STUB.printed == before + 1 and STUB.printed[#STUB.printed]:find("Ana", 1, true), "one summary line, naming who was not online")
