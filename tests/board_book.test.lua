STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local B, C, L = ns.Board, ns.Comm, ns.L
B.Toggle()
assert(B.tab == "home" and B.heading.text == "Test Guild", "opens on Home, the guild's name as heading")
local function shown() local out = {}; for _, r in ipairs(B.rows) do if r.button:IsShown() then out[#out + 1] = r end end; return out end
local rows = shown()
assert(rows[1].button.homeEntry.header == "guild" and rows[2].button.homeEntry.kind == "level" and rows[2].barFill:IsShown(), "the guild, its level bar")
local invite
for _, r in ipairs(rows) do if r.button.homeEntry.kind == "invite" then invite = r end end
assert(invite and invite.xph.text == L.HOME_COPY, "alone: the invite")
invite.button.scripts.OnClick(invite.button, "LeftButton")
assert(ns.DiscordCopy.frame:IsShown() and ns.DiscordCopy.box.text == ns.Home.InviteText(), "copy box with the invite")
-- a help request: "On my way" from Home
STUB.Receive("LVLM2", C.Encode("hb", { l = 21, z = 1412, c = "MAGE" }), "GUILD", "Ana-Testrealm")
STUB.Receive("LVLM2", C.Encode("help", { t = "Ogro", z = 1412, x = 40, y = 50, id = "h0000001" }), "GUILD", "Ana-Testrealm")
B.Refresh()
local help
for _, r in ipairs(shown()) do if r.button.homeEntry.kind == "help" then help = r end end
assert(help and help.xph.text == L.HOME_GO, "Voy")
help.button.scripts.OnClick(help.button, "LeftButton")
assert(STUB.lastChat and STUB.lastChat.chatType == "WHISPER" and STUB.lastChat.target == "Ana", "whispers the asker, from the click")
-- a guildmate near: Invite opens the mate menu
local mate
for _, r in ipairs(shown()) do if r.button.homeEntry.kind == "mate" then mate = r end end
assert(mate and mate.name.text == "Ana" and mate.xph.text == L.HOME_INVITE, "Ana near my level")
mate.button.scripts.OnClick(mate.button, "LeftButton")
assert(B.lastMenuFor == "Ana", "her menu")
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

-- every Home row has its icon
B.ShowTab("home")
for _, r in ipairs(B.rows) do
	local e = r.button:IsShown() and r.button.homeEntry
	if e and not e.header then assert(r.icon:IsShown(), "an icon on " .. tostring(e.kind)) end
end

-- bars grow when their value changes on the same page; the final width is set at once
B.ShowTab("home")
local bar = B.rows[2].barFill
local w0 = bar:GetWidth()
ns.Points.AddSample("Luis", { t = 60 })
STUB.Advance(0.6)   -- changes redraw the open page at most twice a second
assert(bar:GetWidth() ~= w0, "the new width at once")
