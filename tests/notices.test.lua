STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local C, L, V = ns.Comm, ns.L, ns.Version
assert(ns.db.settings.screenNotices == true and ns.db.settings.levelNotices == true and ns.db.settings.shareProfessions == true, "defaults on")
ns.Notice("Hola %s", "Ana")
assert(STUB.printed[#STUB.printed]:find("Hola Ana", 1, true) and UIErrorsFrame.messages[#UIErrorsFrame.messages] == "Hola Ana", "chat and screen")
ns.Notice("%s", "|cff1eff00|Hitem:1::::|h[Boots]|h|r")
assert(UIErrorsFrame.messages[#UIErrorsFrame.messages] == "[Boots]", "no link codes on screen: " .. UIErrorsFrame.messages[#UIErrorsFrame.messages])
ns.db.settings.screenNotices = false
local n = #UIErrorsFrame.messages
ns.Notice("Adios")
assert(#UIErrorsFrame.messages == n and STUB.printed[#STUB.printed]:find("Adios", 1, true), "option off: chat only")
ns.db.settings.screenNotices = true

-- an ad for my level reaches the screen
STUB.player.level = 15
STUB.Receive("LVLM", C.Encode("hb", { l = 16, z = 1421 }), "GUILD", "Mario-Testrealm")
STUB.Receive("LVLM", C.Encode("lfg", { d = 2, r = "T", id = "ad000001", m = 20 }), "GUILD", "Mario-Testrealm")
assert(UIErrorsFrame.messages[#UIErrorsFrame.messages]:find("Mario", 1, true), "LFG notice on screen")

-- versions
assert(V.Newer("0.2.0", "0.1.9") and V.Newer("1.0", "0.9.9") and V.Newer("v0.1.1", "0.1.0"), "newer")
assert(not V.Newer("0.1.0", "0.1.0") and not V.Newer("0.1.0", "0.2") and not V.Newer("dev", "0.1.0") and not V.Newer("0.2.0", "dev"), "not newer")
ns.VERSION = "0.1.0"
STUB.Receive("LVLM", C.Encode("hb", { l = 16, z = 1421, v = "0.1.0" }), "GUILD", "Mario-Testrealm")
local said = 0
local function count() said = 0; for _, p in ipairs(STUB.printed) do if p:find(string.format(L.VERSION_NEW, "0.2.0"), 1, true) then said = said + 1 end end; return said end
assert(count() == 0, "same version: nothing")
STUB.Receive("LVLM", C.Encode("hb", { l = 16, z = 1421, v = "0.2.0" }), "GUILD", "Mario-Testrealm")
STUB.Receive("LVLM", C.Encode("hb", { l = 16, z = 1421, v = "0.2.0" }), "GUILD", "Mario-Testrealm")
assert(count() == 1, "newer: told once")
