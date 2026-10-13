STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
ns.char.groupsView = "catalog"   -- these checks are about the catalogue cards (the Groups section opens on Groups)
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local DP, B, C, L = ns.DungeonPanel, ns.Board, ns.Comm, ns.L
local function kinds(rows) local out = {}; for _, r in ipairs(rows) do out[#out + 1] = r.header and ("#" .. r.header) or r.kind end; return table.concat(out, ",") end

-- what the panel shows for the Deadmines (17-26)
STUB.Receive("LVLM2", C.Encode("hb", { l = 21, z = 1412, c = "MAGE" }), "GUILD", "Mario-Testrealm")
STUB.Receive("LVLM2", C.Encode("hb", { l = 19, z = 1412, c = "PRIEST", g = 0 }), "GUILD", "Ana-Testrealm")
STUB.Receive("LVLM2", C.Encode("hb", { l = 50, z = 1412 }), "GUILD", "Luis-Testrealm")
STUB.Receive("LVLM2", C.Encode("lfg", { d = 5, r = "H", id = "lfg00001", m = 20, n = "rápido" }), "GUILD", "Mario-Testrealm")
STUB.Fire("CHAT_MSG_CHANNEL", "LFM DM need tank", "Pepe-Testrealm", "", "2. Trade", "", "", 0, 2, "Trade")
ns.Meetups.AddSample("Ana", 5, 90, { Mario = "D" })
local rows = DP.Rows(5)
assert(kinds(rows) == "#groups,ad,contact,#chat,chat,#meet,meet,slot,slot,slot,slot,slot,#mates,mate,mate", "sections (a run with its five slots): " .. kinds(rows))
local mates = {}
for _, r in ipairs(rows) do if r.kind == "mate" then mates[#mates + 1] = r.name end end
table.sort(mates)
assert(table.concat(mates, ",") == "Ana,Mario", "guildmates of its levels (not Luis, 50): " .. table.concat(mates, ","))

-- a click on a card opens the panel next to the book; right-click keeps the quick menu
B.Toggle(); B.ShowTab("lfg")
local card
for _, c in ipairs(B.cards) do if c.dungeonId == 5 then card = c end end
card.scripts.OnClick(card, "LeftButton")
assert(DP.frame and DP.frame:IsShown() and DP.id == 5, "the panel for the Deadmines")
assert(DP.frame.title.text:find(ns.Dungeons.Name(5), 1, true), "its name")
local shownMenu
local real = B.OpenDungeonMenu
B.OpenDungeonMenu = function(id) shownMenu = id end
card.scripts.OnClick(card, "RightButton")
B.OpenDungeonMenu = real
assert(shownMenu == 5, "right-click: the quick menu")

-- its buttons do the actions (from the click)
local function rowOf(kind) for _, r in ipairs(DP.lines) do if r:IsShown() and r.entry and r.entry.kind == kind then return r end end end
local ad = rowOf("ad")
assert(ad and ad.buttons[1]:IsShown(), "join buttons on Mario's group")
ad.buttons[1].scripts.OnClick(ad.buttons[1])   -- join as tank
assert(ns.LFG.myJoins["lfg00001"] == "T", "joined as tank")
DP.Refresh()
ad = rowOf("ad")
local leave
for _, b in ipairs(ad.buttons) do if b:IsShown() and b.text == L.DP_LEAVE then leave = b end end
assert(leave, "now: leave")
local chat = rowOf("chat")
chat.buttons[1].scripts.OnClick(chat.buttons[1])
assert(STUB.lastTell == "Pepe-Testrealm", "whisper the chat poster")
local mate = rowOf("mate")
local invited
C_PartyInfo = { InviteUnit = function(n) invited = n end }
mate.buttons[1].scripts.OnClick(mate.buttons[1])
assert(invited == mate.entry.name, "invite a guildmate of this level")
-- the footer: look for a group here, set up a meetup here
local here
ns.On("LM_LFG_HERE", function(id) here = id end)
DP.lfgButton.scripts.OnClick(DP.lfgButton)
assert(here == 5, "look for a group here")
-- it follows changes and closes with the board
STUB.Receive("LVLM2", C.Encode("lfgx", { id = "lfg00001" }), "GUILD", "Mario-Testrealm")
assert(not kinds(DP.Rows(5)):find("ad", 1, true), "the withdrawn ad is gone")
B.frame:Hide(); B.frame.scripts.OnHide = B.frame.scripts.OnHide
DP.Close()
assert(not DP.frame:IsShown(), "closes")
