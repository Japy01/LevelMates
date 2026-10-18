-- The chat's look (2026-10-18, "esto se puede mejorar mucho"): the game's chat font with air between lines, a
-- date line where the day changes ("hoy", "ayer", else the date), and in the window chips to read everything or
-- the officers only
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(30)
local GC, L, DB, B = ns.GuildChat, ns.L, ns.Dashboard, ns.Board
local now = time()
-- three days of lines, straight into the list as the game's history would put them
local function id(t) return { epoch = t * 1e6, position = 0 } end
STUB.clubStreams = { { streamId = 11, name = "Guild", streamType = 1 }, { streamId = 12, name = "Officer", streamType = 2 } }
STUB.clubMessages = {
	[11] = { { messageId = id(now - 3 * 86400), content = "antes de ayer", author = { name = "Mario-Testrealm" } },
		{ messageId = id(now - 86400), content = "ayer", author = { name = "Mario-Testrealm" } },
		{ messageId = id(now - 60), content = "hoy", author = { name = "Mario-Testrealm" } } },
	[12] = { { messageId = id(now - 30), content = "solo oficiales", author = { name = "Ana-Testrealm" } } },
}
STUB.Fire("CLUB_MESSAGE_HISTORY_RECEIVED", 1, 11)
assert(#GC.Lines() == 4, "four lines: " .. #GC.Lines())
GC.Open()
assert(GC.msg.fontObject == (ChatFontNormal or "ChatFontNormal") and (GC.msg.spacing or 0) >= 2, "the chat font, with air: " .. tostring(GC.msg.fontObject) .. " / " .. tostring(GC.msg.spacing))
local texts = {}
for _, m in ipairs(GC.msg.messages) do texts[#texts + 1] = m.text end
assert(#texts == 7, "four lines and three date lines: " .. #texts .. "\n" .. table.concat(texts, "\n"))
assert(texts[1]:find(date("%d/%m", now - 3 * 86400), 1, true) and texts[3]:find(L.GC_DAY_YESTERDAY, 1, true) and texts[5]:find(L.GC_DAY_TODAY, 1, true), "the day lines: " .. texts[1] .. " | " .. texts[3] .. " | " .. texts[5])
assert(texts[7]:find("solo oficiales", 1, true) and texts[7]:find(L.GC_OFFICER, 1, true), "the officer line last")
-- a new line today: appended, no new date line
STUB.Fire("CHAT_MSG_GUILD", "otra", "Luis-Testrealm", "", "", "", "", 0, 0, "", 0, 1, "Player-1-LUIS")
assert(#GC.msg.messages == 8, "appended: " .. #GC.msg.messages)
-- the chips: officers only
assert(GC.chipAll and GC.chipOfficer and GC.chipAll.checked, "chips, all marked")
GC.chipOfficer.scripts.OnClick(GC.chipOfficer)
texts = {}
for _, m in ipairs(GC.msg.messages) do texts[#texts + 1] = m.text end
assert(GC.filter == "officer" and #texts == 2 and texts[2]:find("solo oficiales", 1, true), "officer lines only, with their date line: " .. #texts)
GC.chipAll.scripts.OnClick(GC.chipAll)
assert(GC.filter == "all" and #GC.msg.messages == 8, "everything again")
-- Home uses the same frame kind: font and air there too
B.Toggle(); B.ShowTab("home")
assert(DB.chatMsg.fontObject == GC.msg.fontObject and (DB.chatMsg.spacing or 0) >= 2, "Home's chat the same")
print("ok")
