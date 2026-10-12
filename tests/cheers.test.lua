STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local C, L = ns.Comm, ns.L
local function hb(name, level) STUB.Receive("LVLM2", C.Encode("hb", { l = level, z = 1421 }), "GUILD", name .. "-Testrealm") end
local function lines(text) local n = 0; for _, p in ipairs(STUB.printed) do if p:find(text, 1, true) then n = n + 1 end end; return n end
hb("Mario", 20); hb("Ana", 30)
assert(lines(string.format(L.LEVELUP_NOTICE, "Mario", 20)) == 0 and lines(string.format(L.LEVELUP_NOTICE, "Ana", 30)) == 0, "first sight is not a level-up")
hb("Mario", 20)
assert(lines("Mario") == 0, "same level: nothing")
hb("Mario", 21)
assert(lines(string.format(L.LEVELUP_NOTICE, "Mario", 21)) == 1, "level-up line")
assert(STUB.printed[#STUB.printed]:find("|Haddon:LevelMates:cheer:Mario:21|h", 1, true), "with the [Congratulate] link")
assert(UIErrorsFrame.messages[#UIErrorsFrame.messages] == string.format(L.LEVELUP_NOTICE, "Mario", 21), "and on screen")
STUB.ClickLink("addon:LevelMates:cheer:Mario:21")
assert(STUB.lastChat and STUB.lastChat.chatType == "WHISPER" and STUB.lastChat.target == "Mario" and STUB.lastChat.msg == string.format(L.CHEER_TEXT, 21), "the click whispers")
STUB.lastChat = nil
STUB.ClickLink("addon:OtherAddon:x:y")
assert(STUB.lastChat == nil, "other links are not ours")
ns.db.settings.levelNotices = false
hb("Mario", 22)
assert(lines(string.format(L.LEVELUP_NOTICE, "Mario", 22)) == 0, "option off")
