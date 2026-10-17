-- Home, rearranged (asked 2026-10-17): no "My character" panel for now; Now, Groups and Quests on the left; the guild
-- chat in the middle with a box to write; Who is where and the wall on the right
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(30)
local B, DB, L = ns.Board, ns.Dashboard, ns.L
STUB.Fire("CHAT_MSG_GUILD", "hola a todos", "Mario-Testrealm", "", "", "", "", 0, 0, "", 0, 1, "Player-1-MARIO")
B.Toggle(); B.ShowTab("home")
assert(DB.chat and DB.chat:IsShown(), "the chat panel")
assert(not DB.me:IsShown(), "my character hidden for now")
assert(DB.now:IsShown() and DB.runs:IsShown() and DB.quests:IsShown() and DB.where:IsShown() and DB.wall:IsShown(), "the other panels")
local shown = {}
for _, it in ipairs(DB.chat.items) do if it:IsShown() then shown[#shown + 1] = it.text.text end end
assert(#shown == 1 and shown[1]:find("Mario", 1, true) and shown[1]:find("hola a todos", 1, true), "the line in the panel: " .. table.concat(shown, " | "))
-- a new line arrives: drawn
STUB.Fire("CHAT_MSG_GUILD", "buenas", "Ana-Testrealm", "", "", "", "", 0, 0, "", 0, 2, "Player-1-ANA"); STUB.Advance(1)
shown = {}
for _, it in ipairs(DB.chat.items) do if it:IsShown() then shown[#shown + 1] = it.text.text end end
assert(#shown == 2 and shown[2]:find("Ana", 1, true), "the new line at the bottom")
-- writing from Home
STUB.lastChat = nil
DB.chatInput:SetText("yo también")
DB.chatInput.scripts.OnEnterPressed(DB.chatInput)
assert(STUB.lastChat and STUB.lastChat.chatType == "GUILD" and STUB.lastChat.msg == "yo también" and DB.chatInput.text == "", "sent from Home, the box emptied")
-- the chat panel is as tall as the page allows: more rows than the wall
assert(DB.CHAT >= 12, "a good number of rows")
