-- pills in the title: mates online (click → Mates), Discord when linked, how many still run 0.3
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
local B, C, R = ns.Board, ns.Comm, ns.Roster
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
STUB.Receive("LVLM2", C.Encode("hb", { l = 30, z = 1421, c = "MAGE" }), "GUILD", "Mario-Testrealm")
STUB.Receive("LVLM2", C.Encode("hb", { l = 12, z = 1412 }), "GUILD", "Ana-Testrealm")
B.Toggle(); B.ShowTab("journal")
local p = B.pills
assert(p.online:IsShown() and p.online.text.text:find("|t 2 ", 1, true), "online pill: " .. tostring(p.online.text.text))
assert(not p.discord:IsShown(), "no Discord pill without a linked channel")
assert(not p.legacy:IsShown(), "no old-version pill")
p.online.scripts.OnClick(p.online)
assert(B.tab == "mates", "the online pill opens Mates")
C_Discord = { IsEnabled = function() return true end, IsGuildChannelLinked = function() return true end, IsUserOAuthed = function() return true end }
R.legacy["Pepe"] = GetTime()
B.Refresh()
assert(p.discord:IsShown(), "Discord pill when linked")
assert(p.legacy:IsShown() and p.legacy.text.text:find(": 1", 1, true), "old-version pill counts 1")
C_Discord = nil
