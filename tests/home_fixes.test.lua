-- Home, after the 2026-10-18 screenshot: the chat panel wraps long lines (a scrolling message frame, as the
-- window), names of guildmates without the addon get their class colour from the roster, a Discord line reads
-- as a sentence, and a group card's title never runs under its button
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(30)
local B, DB, L, R, GC, W = ns.Board, ns.Dashboard, ns.L, ns.Roster, ns.GuildChat, ns.Widgets
RAID_CLASS_COLORS.HUNTER = { r = 0.67, g = 0.83, b = 0.45 }
STUB.guildMembers = { Tester = true, Pepe = true }
STUB.memberInfo = { Tester = { level = 20 }, Pepe = { level = 33, presence = 1, classID = 3 } }
R.InvalidateGuildRoster()
assert(R.ClassOf("Pepe") == "HUNTER", "a guildmate without the addon: the roster's class: " .. tostring(R.ClassOf("Pepe")))
STUB.Fire("CHAT_MSG_GUILD", "una línea muy larga que en el panel de inicio antes se cortaba con puntos suspensivos y ahora se parte en dos", "Pepe-Testrealm", "", "", "", "", 0, 0, "", 0, 1, "Player-1-PEPE")
STUB.Fire("CHAT_MSG_GUILD_DISCORD", "x", "Santo", "", "", "", "", 0, 0, "", 0, 2, "")
local lines = GC.Lines()
assert(GC.LineText(lines[1]):find("|cff", 1, true) and GC.LineText(lines[1]):find("Pepe", 1, true), "Pepe's name in his class colour: " .. GC.LineText(lines[1]))
assert(GC.LineText(lines[2]):find("Santo", 1, true) and GC.LineText(lines[2]):find("Discord", 1, true) and not GC.LineText(lines[2]):find(L.DT_PROTECTED, 1, true), "a Discord line as a sentence: " .. GC.LineText(lines[2]))
B.Toggle(); B.ShowTab("home")
assert(DB.chatMsg and DB.chatMsg.kind == "ScrollingMessageFrame" and DB.chatMsg.wordWrap ~= false, "Home's chat on a scrolling message frame")
assert(#DB.chatMsg.messages == 2 and DB.chatMsg.messages[1].text:find("se parte en dos", 1, true), "the whole line kept")
assert(DB.chatMsg.hyperlinks and DB.chatMsg.wheel, "links and the wheel")
-- a group card: the title stops where the button starts
local c = W.GroupCard(DB.frame, true, true)
c:Set({ id = "g1", src = "now", name = "Excavación: Los Humedales", by = "Tester-Testrealm", mine = true, size = 5, caps = { T = 1, H = 1, D = 3 }, slots = {} })
local p = c.text.point
assert(p and p[1] == "RIGHT" and p[2] == c.buttons[1] and p[3] == "LEFT", "the title ends before the button")
print("ok")
