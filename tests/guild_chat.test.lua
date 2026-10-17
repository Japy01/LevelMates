-- the guild chat window: the guild and officer lines heard this session (a Discord line shows its sender only: the
-- text is hidden from addons), newest at the bottom; a box to write to the guild from Enter; a Chat button on the book
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local GC, B, L = ns.GuildChat, ns.Board, ns.L
local SECRET = setmetatable({}, {})
issecretvalue = function(v) return v == SECRET end
STUB.Fire("CHAT_MSG_GUILD", "hola a todos", "Mario-Testrealm", "", "", "", "", 0, 0, "", 0, 1, "Player-1-MARIO")
STUB.Fire("CHAT_MSG_OFFICER", "reunión mañana", "Ana-Testrealm", "", "", "", "", 0, 0, "", 0, 2, "Player-1-ANA")
STUB.Fire("CHAT_MSG_GUILD", SECRET, "Luis-Testrealm", "", "", "", "", 0, 0, "", 0, 3, "Player-1-LUIS")
STUB.Fire("CHAT_MSG_GUILD_DISCORD", SECRET, "Pepe", "", "", "", "", 0, 0, "", 0, 4, "")
local lines = GC.Lines()
assert(#lines == 3 and lines[1].name == "Mario" and lines[1].text == "hola a todos" and lines[1].kind == "guild", "the guild line kept: " .. #lines)
assert(lines[2].kind == "officer" and lines[2].text == "reunión mañana", "the officer line")
assert(lines[3].kind == "discord" and lines[3].name == "Pepe" and lines[3].text == nil, "a Discord line: the sender only")
-- the window: /lm chat opens it (the book has the chat on Home; no button, asked 2026-10-17); the lines newest at the bottom
B.Toggle()
SlashCmdList["LEVELMATES"]("chat")
assert(GC.frame and GC.frame:IsShown(), "the window")
local shown = {}
for _, r in ipairs(GC.rows) do if r:IsShown() then shown[#shown + 1] = r.text.text end end
assert(#shown == 3 and shown[1]:find("Mario", 1, true) and shown[1]:find("hola a todos", 1, true) and shown[3]:find("Pepe", 1, true) and shown[3]:find(L.GC_DISCORD, 1, true), "lines drawn: " .. table.concat(shown, " | "))
assert(shown[2]:find(L.GC_OFFICER, 1, true), "officer lines marked")
-- writing: Enter sends to the guild, the box empties; nothing while a chat lockdown holds, the text stays
STUB.lastChat = nil
GC.input:SetText("buenas")
GC.input.scripts.OnEnterPressed(GC.input)
assert(STUB.lastChat and STUB.lastChat.chatType == "GUILD" and STUB.lastChat.msg == "buenas" and GC.input.text == "", "sent to the guild")
InChatMessagingLockdown = function() return true end
STUB.lastChat = nil
GC.input:SetText("otra")
GC.input.scripts.OnEnterPressed(GC.input)
assert(STUB.lastChat == nil and GC.input.text == "otra", "lockdown: not sent, the text kept")
InChatMessagingLockdown = function() return false end
-- the cap: never more than GC.MAX lines
for i = 1, GC.MAX + 20 do STUB.Fire("CHAT_MSG_GUILD", "l" .. i, "Mario-Testrealm", "", "", "", "", 0, 0, "", 0, 10 + i, "Player-1-MARIO") end
assert(#GC.Lines() == GC.MAX and GC.Lines()[GC.MAX].text == "l" .. (GC.MAX + 20), "capped, newest kept")
-- /lm chat toggles it
SlashCmdList["LEVELMATES"]("chat")
assert(not GC.frame:IsShown(), "closed by the command")
