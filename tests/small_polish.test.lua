-- Small polish from the 2026-10-18 audit: /lm help lists the commands (asking for help is /lm ayuda <texto>); an
-- unknown command says so and lists them; Members shows the rank's name and "today"; the screen copy of notices is
-- off by default; secondary windows clamp to the screen and remember where they were dragged; the addon
-- compartment entry exists whatever the minimap option says; Tab moves between a form's boxes
LevelMatesDB = { settings = { minimap = false } }
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(30)
local B, L, R, GC = ns.Board, ns.L, ns.Roster, ns.GuildChat
-- the compartment entry, minimap button or not
assert(STUB.compartment and STUB.compartment.text == L.BOARD_TITLE, "the addon compartment entry")
-- /lm help: the list
STUB.printed = {}
SlashCmdList["LEVELMATES"]("help")
local said = table.concat(STUB.printed, "\n")
assert(said:find(L.CMD_TITLE, 1, true) and said:find("/lm chat", 1, true) and #STUB.printed >= #L.CMD_LIST, "the command list: " .. said:sub(1, 200))
assert(not ns.Help.mine, "no help request made")
STUB.printed = {}
SlashCmdList["LEVELMATES"]("nada")
said = table.concat(STUB.printed, "\n")
assert(said:find(string.format(L.CMD_UNKNOWN, "nada"), 1, true) and said:find("/lm chat", 1, true), "unknown: said, and the list")
-- Members: the rank's name and "today"
STUB.guildMembers = { Tester = true, Luis = true, Ana = true }
STUB.guildRoles = { Luis = 2 }
STUB.memberInfo = { Tester = { level = 20 }, Luis = { level = 40, rank = 1, rankName = "Oficial", presence = 3, lastOnlineHour = 3 }, Ana = { level = 25, rankName = "Miembro", presence = 3, lastOnlineDay = 4 } }
R.InvalidateGuildRoster(); ns.Members.Invalidate()
B.Toggle(); B.ShowTab("members")
local function row(name) for _, r in ipairs(B.rows) do if r.button:IsShown() and r.button.memberEntry and r.button.memberEntry.name == name then return r end end end
assert(row("Luis") and row("Luis").group.text == "Oficial", "the rank's name: " .. tostring(row("Luis") and row("Luis").group.text))
assert(row("Luis").xph.text == L.MEMBER_TODAY, "seen today: " .. tostring(row("Luis").xph.text))
assert(row("Ana").xph.text == string.format(L.MEMBER_DAYS, 4), "days away")
-- windows remember where they were dragged, and never leave the screen
GC.Open()
assert(GC.frame.clamped, "clamped")
GC.frame.GetPoint = function() return "TOPLEFT", UIParent, "TOPLEFT", 100, -50 end
GC.frame.scripts.OnDragStop(GC.frame)
assert(ns.db.windows and ns.db.windows.chat and ns.db.windows.chat[3] == 100 and ns.db.windows.chat[4] == -50, "the chat window's place saved")
GC.frame:Hide()
-- Tab between a form's boxes
local a, b = CreateFrame("EditBox"), CreateFrame("EditBox")
ns.TabOrder({ a, b })
a:SetFocus(); a.scripts.OnTabPressed(a)
assert(b:HasFocus() and not a:HasFocus(), "Tab: the next box")
b.scripts.OnTabPressed(b)
assert(a:HasFocus(), "and round")
local GV = ns.GroupsView
assert(GV.form and GV.form.name.scripts.OnTabPressed and GV.form.note.scripts.OnTabPressed, "the group form chains its boxes")
print("ok")
