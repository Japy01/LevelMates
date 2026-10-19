-- The guild chat's history (asked 2026-10-18, as Guild Armory shows it): at login the lines the game itself keeps
-- for the guild and officer streams are read through C_Club (newest 200, placeholders and destroyed ones out),
-- older ones are asked for the way the game's own window does, live lines merge without duplicates, and the
-- window only appends new lines instead of rewriting and jumping to the bottom
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
local GC, L = ns.GuildChat, ns.L
local function id(epochSecs, pos) return { epoch = epochSecs * 1e6, position = pos or 0 } end   -- a float: the game's Lua has doubles, the test runtime 32-bit integers
local now = time()
STUB.clubStreams = { { streamId = 11, name = "Guild", streamType = 1 }, { streamId = 12, name = "Officer", streamType = 2 }, { streamId = 13, name = "Discord", streamType = 3 } }
STUB.clubMessages = {
	[11] = { { messageId = id(now - 3600), content = "ayer tarde", author = { name = "Mario-Testrealm", classID = 8 } },
		{ messageId = id(now - 1800), content = UNKNOWN, author = { name = "Ana-Testrealm" } },   -- not loaded by the game: a placeholder
		{ messageId = id(now - 1700), content = "|cffffffff Unknown entity |r", author = { name = "Ana-Testrealm" } },   -- the same placeholder, coloured and padded as the game may hand it
		{ messageId = id(now - 1650), content = "Entidad desconocida", author = { name = "Ana-Testrealm" } },   -- and in Spanish, whatever the globals say
		{ messageId = id(now - 900), content = "borrada", destroyed = true, author = { name = "Ana-Testrealm" } },
		{ messageId = id(now - 600), content = "hola a todos", author = { name = "Pepe-Testrealm", classID = 3 } } },
	[12] = { { messageId = id(now - 1200), content = "reunión", author = { name = "Ana-Testrealm", classID = 5 } } },
	[13] = { { messageId = id(now - 100), content = "x", author = { name = "" } } },
}
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(10)
local lines = GC.Lines()
assert(#lines == 3, "the game's history, placeholders and destroyed lines out: " .. #lines)
assert(lines[1].text == "ayer tarde" and lines[1].name == "Mario" and lines[1].kind == "guild" and lines[1].at == now - 3600, "oldest first, from the game's clock")
assert(lines[2].kind == "officer" and lines[2].text == "reunión" and lines[3].text == "hola a todos", "guild and officer lines in time order")
assert(STUB.clubRequested and STUB.clubRequested[11] and STUB.clubRequested[11].count >= 100, "older lines asked for, the way the game's window does")
assert(STUB.clubFocused and STUB.clubFocused[11], "the stream focused first (the game loads nothing otherwise)")
-- a live line: appended; the same line in the game's history later: no duplicate
STUB.Fire("CHAT_MSG_GUILD", "en vivo", "Luis-Testrealm", "", "", "", "", 0, 0, "", 0, 1, "Player-1-LUIS")
assert(#GC.Lines() == 4 and GC.Lines()[4].text == "en vivo", "live line appended")
table.insert(STUB.clubMessages[11], { messageId = id(time()), content = "en vivo", author = { name = "Luis-Testrealm", classID = 1 } })
STUB.Fire("CLUB_MESSAGE_HISTORY_RECEIVED", 1, 11)
assert(#GC.Lines() == 4, "no duplicate: " .. #GC.Lines())
-- older lines arriving later go in at the front, in order
table.insert(STUB.clubMessages[11], 1, { messageId = id(now - 7200), content = "anteayer", author = { name = "Mario-Testrealm", classID = 8 } })
STUB.Fire("CLUB_MESSAGE_HISTORY_RECEIVED", 1, 11)
assert(#GC.Lines() == 5 and GC.Lines()[1].text == "anteayer", "older lines first")
-- the window appends: a new line is one AddMessage, no Clear, and the view stays where it was unless at the bottom
GC.Open()
local before = #GC.msg.messages
local clears = GC.msg.clears or 0
STUB.Fire("CHAT_MSG_GUILD", "otra", "Luis-Testrealm", "", "", "", "", 0, 0, "", 0, 2, "Player-1-LUIS")
assert(#GC.msg.messages == before + 1 and (GC.msg.clears or 0) == clears, "appended, not rewritten")
GC.msg.atBottom = false; GC.msg.scrolledToBottom = nil
STUB.Fire("CHAT_MSG_GUILD", "y otra", "Luis-Testrealm", "", "", "", "", 0, 0, "", 0, 3, "Player-1-LUIS")
assert(not GC.msg.scrolledToBottom, "reading the history: not dragged down")
-- the lines are kept for the next session
assert(ns.db.chat and ns.db.chat[ns.GuildKey()] and #ns.db.chat[ns.GuildKey()] >= 5, "saved")
print("ok")
