STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local B, C, L = ns.Board, ns.Comm, ns.L
B.Toggle()
assert(B.tab == "home" and B.heading.text == "Test Guild", "opens on Home, the guild's name as heading")
local DB = ns.Dashboard
assert(DB.frame:IsShown() and DB.stats[1].value.text == "1", "the dashboard, the guild's level")
assert(DB.invite:IsShown(), "alone: the invite")
DB.invite.scripts.OnClick(DB.invite, "LeftButton")
assert(ns.DiscordCopy.frame:IsShown() and ns.DiscordCopy.box.text == ns.Home.InviteText(), "copy box with the invite")
-- a help request: "On my way" from Home
STUB.Receive("LVLM2", C.Encode("hb", { l = 21, z = 1412, c = "MAGE" }), "GUILD", "Ana-Testrealm")
STUB.Receive("LVLM2", C.Encode("help", { t = "Ogro", z = 1412, x = 40, y = 50, id = "h0000001" }), "GUILD", "Ana-Testrealm")
B.Refresh()
local help = DB.now.items[1]
assert(help:IsShown() and help.action.text == L.HOME_GO, "Voy")
help.action.scripts.OnClick(help.action, "LeftButton")
assert(STUB.lastChat and STUB.lastChat.chatType == "WHISPER" and STUB.lastChat.target == "Ana", "whispers the asker, from the click")
-- who is where: a click opens Guildmates
DB.where.items[1].scripts.OnClick(DB.where.items[1], "LeftButton")
assert(B.tab == "mates", "to Guildmates")
B.ShowTab("home")
-- Copy for Discord on Home
local text = ns.DiscordCopy.Text("home")
assert(text:find(string.format(L.HOME_LEVEL, 1), 1, true), "guild level in the copy")

-- inviting says so at once (the server may take a moment)
C_PartyInfo = { InviteUnit = function() end }
STUB.printed = {}
-- with the book open, what a click did goes to its foot: count it with chat
local told = {}
do local fb = ns.Board.Feedback; ns.Board.Feedback = function(t) told[#told + 1] = t; fb(t) end end
local function lastSaid() return told[#told] or STUB.printed[#STUB.printed] end
B.Invite("Gigasamba Caramba")
assert(lastSaid():find(string.format(L.INVITE_SENT, "Gigasamba Caramba"), 1, true), "told at once")

-- bars grow when their value changes on the same page; the final width is set at once
local bar = B.frame:CreateTexture()
B.Grow(bar, 40)
B.Grow(bar, 120)
assert(bar:GetWidth() == 120, "the new width at once")
