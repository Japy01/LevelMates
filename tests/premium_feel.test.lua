-- Premium feel (audit 2026-10-17): the mouse wheel turns the page; the game's own sounds on open, close and tab;
-- the guild chat window on a scrolling message frame (wraps, wheel, hyperlink tooltips, ink); the hidden channel
-- announced once; Options: ink slider, "reset position", quiet mode refreshes the switches it changes
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(30)
local B, L, S, GC = ns.Board, ns.L, ns.Settings, ns.GuildChat
STUB.sounds = {}
local function played(id) for _, s in ipairs(STUB.sounds) do if s == id then return true end end end

-- sounds: open, tab, close
B.Toggle()
assert(played(SOUNDKIT.IG_SPELLBOOK_OPEN), "the book opens with the spellbook's sound")
B.SetTab("journal")
assert(played(SOUNDKIT.IG_CHARACTER_INFO_TAB), "a tab click")
STUB.sounds = {}
B.frame:Hide()
assert(played(SOUNDKIT.IG_SPELLBOOK_CLOSE), "closed any way: the close sound")
STUB.sounds = {}
B.SetTab("journal")
assert(#STUB.sounds == 0, "the same tab again: quiet")

-- the wheel turns pages: 30 journal entries make two pages
for i = 1, 30 do ns.Journal.Add("quest", { name = "Q" .. i }) end
B.ShowTab("journal")
assert(B.journalPageText.text == string.format(L.J_PAGE, 1, 2), "page 1 of 2: " .. tostring(B.journalPageText.text))
assert(B.frame.wheel, "the frame listens to the wheel")
B.frame.scripts.OnMouseWheel(B.frame, -1)
assert(B.journalPage == 2, "wheel down: next page")
B.frame.scripts.OnMouseWheel(B.frame, 1)
assert(B.journalPage == 1, "wheel up: back")

-- the chat window: a scrolling message frame with the lines in ink, hyperlinks on, the wheel scrolls
STUB.Fire("CHAT_MSG_GUILD", "mira |cffa335ee|Hitem:9001::::::::60:::::::|h[Casco]|h|r", "Mario-Testrealm", "", "", "", "", 0, 0, "", 0, 1, "Player-1-MARIO")
GC.Open()
assert(GC.msg and GC.msg.kind == "ScrollingMessageFrame", "a scrolling message frame")
local lastMsg = GC.msg.messages[#GC.msg.messages]   -- after the date line
assert(#GC.msg.messages == 2 and lastMsg.text:find("Mario", 1, true) and lastMsg.text:find("|Hitem:9001", 1, true), "the line, link kept")
assert(not lastMsg.text:find("|cffa335ee", 1, true), "the link's colour toned for the page")
assert(GC.msg.wheel and GC.msg.hyperlinks and GC.msg.scripts.OnHyperlinkEnter and GC.msg.scripts.OnHyperlinkLeave, "wheel and hyperlink tooltips")
assert(GC.msg.wordWrap ~= false, "lines wrap")
assert(ns.Dashboard.chatMsg.hyperlinks and ns.Dashboard.chatMsg.scripts.OnHyperlinkEnter, "Home's chat panel shows link tooltips too")
GC.frame:Hide()

-- the hidden channel: said once, in chat, when it is first joined
local C = ns.Comm
ns.db.settings.transport = "channel"; ns.db.channelNoticed = nil
STUB.printed = {}
C.Stop(); C.Start()
local said = table.concat(STUB.printed, "\n")
assert(said:find(L.COMM_CHANNEL_NOTICE:sub(1, 20), 1, true), "the channel notice: " .. said)
STUB.printed = {}
C.Stop(); C.Start()
assert(#STUB.printed == 0, "said once")
ns.db.settings.transport = "auto"; C.Stop(); C.Start()

-- Options: the ink slider; reset position; quiet mode tells its switches to redraw
local ink, reset
for _, st in ipairs(S.AllSettings()) do if st.name == L.OPT_INK then ink = st end end
assert(ink and ink.slider and ink.slider.min == 1 and ink.slider.max == 5, "an ink slider 1-5")
ink:SetValue(2)
assert(ns.db.settings.ink == 2 and ns.Skin.InkLevel() == 2, "the slider sets the ink")
ns.char.board = { "TOPLEFT", "TOPLEFT", 10, -10 }
for _, i in ipairs(S.category.layout.inits) do if i.button == L.OPT_RESET_POS then reset = i end end
assert(reset, "a reset position button")
reset.click()
assert(ns.char.board == nil and B.frame.point[1] == "CENTER", "the book back in the middle")
local quiet
for _, st in ipairs(S.AllSettings()) do if st.name == L.OPT_QUIET then quiet = st end end
ns.db.settings.sound = true
quiet:SetValue(true)
assert(ns.db.settings.sound == false and S.byKey.sound.notified == 1, "quiet: the sound switch told to redraw")
quiet:SetValue(false)
assert(ns.db.settings.sound == true and S.byKey.sound.notified == 2, "and back")
print("ok")
