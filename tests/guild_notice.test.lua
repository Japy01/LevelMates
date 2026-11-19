STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local C, B, GN, R, L = ns.Comm, ns.Board, ns.GuildNotice, ns.Roster, ns.L
assert(GN, "the module")
local guild = {}
local realSend = SendChatMessage
function SendChatMessage(msg, kind, lang, target) if kind == "GUILD" then guild[#guild + 1] = msg end; return realSend(msg, kind, lang, target) end
local function last(kind) for i = #STUB.sent, 1, -1 do local k, f = C.Decode(STUB.sent[i].msg); if k == kind then return f end end end
STUB.guildMembers = { Tester = true, Jefa = true, Mario = true }
STUB.guildRoles = { Jefa = 2 }
R.InvalidateGuildRoster()
local ROUND = 30 + GN.JITTER + 1   -- one turn of the ticker and the longest random wait
local function pause(minutes) GN.SetOn(false); STUB.Advance(minutes * 60); GN.SetOn(true) end   -- time passes, nothing sent

-- what the other officers hear
assert(C.Validate("gi", { t = 100 }) and not C.Validate("gi", {}), "format")

-- the text: the guild info's lines that say something, without codes, at most five messages of 255 bytes
STUB.guildInfo = "Bienvenidos a Test Guild.\n\n  Banda los jueves a las 21:00.  \n|cffff0000Discord|r: pregunta|nCuarta línea"
local l = GN.Lines()
assert(#l == 4 and l[1] == "Bienvenidos a Test Guild." and l[2] == "Banda los jueves a las 21:00." and l[3] == "Discord: pregunta" and l[4] == "Cuarta línea", "lines: " .. table.concat(l, " / "))
STUB.guildInfo = "1\n2\n3\n4\n5\n6\n7"
assert(#GN.Lines() == 5 and GN.Lines()[5] == "5", "at most five messages")
-- a long paragraph (the info holds up to 500 letters): in messages broken between words, nothing lost
STUB.guildInfo = string.rep("palabra ", 60)
l = GN.Lines()
assert(#l == 2 and #l[1] <= 255 and #l[2] <= 255 and l[1]:sub(-7) == "palabra" and l[2]:sub(1, 7) == "palabra", "two messages: " .. #l)
assert(l[1] .. " " .. l[2] == strtrim(STUB.guildInfo), "every word kept")
STUB.guildInfo = string.rep("á", 200)
assert(#GN.Lines()[1] <= 255 and GN.Lines()[1]:sub(-2) == "á" and #GN.Lines() == 2, "no space: cut at 255 bytes, never inside a letter")
STUB.guildInfo = " \n \n"
assert(#GN.Lines() == 0, "nothing to say")
STUB.guildInfo = nil
assert(#GN.Lines() == 0, "no info at all")

-- off by default, and never from a member
STUB.guildInfo = "Bienvenidos.\nBanda los jueves."
STUB.Advance(GN.SETTLE + 3 * ROUND)
assert(#guild == 0 and not GN.On(), "off by default")
GN.SetOn(true)
assert(GN.On(), "on")
STUB.player.guild = "Otra Hermandad"
assert(not GN.On(), "turned on in one guild: off in another")
STUB.player.guild = "Test Guild"
STUB.Advance(3 * ROUND)
assert(#guild == 0, "a member never sends it")

-- an officer who turned it on: the lines go out by themselves, and every officer hears when
STUB.iAmOfficer = true
STUB.Advance(ROUND)
assert(#guild == 2 and guild[1] == "Bienvenidos." and guild[2] == "Banda los jueves.", "sent: " .. #guild)
assert(last("gi") and GN.Last().by == "Tester", "shared")
-- once per interval (60 minutes unless chosen)
assert(GN.Every() == 60, "an hour by default")
STUB.Advance(50 * 60)
assert(#guild == 2, "not before the interval")
STUB.Advance(10 * 60 + 2 * ROUND)
assert(#guild == 4, "again after an hour: " .. #guild)

-- another officer sent it: the wait starts from theirs; a member's word does not count
STUB.Advance(55 * 60)
STUB.Receive("LVLM2", C.Encode("gi", { t = GetServerTime() }), "GUILD", "Jefa-Testrealm")
STUB.Receive("LVLM2", C.Encode("gi", { t = GetServerTime() + 30 }), "GUILD", "Mario-Testrealm")
assert(GN.Last().by == "Jefa", "Jefa's, not Mario's")
STUB.Advance(30 * 60)
assert(#guild == 4, "Jefa just sent it")

-- two officers due at once: each waits a random moment first, and the later one hears the other and stays quiet
pause(31)
GN.Tick()
STUB.Receive("LVLM2", C.Encode("gi", { t = GetServerTime() }), "GUILD", "Jefa-Testrealm")
STUB.Advance(GN.JITTER + 1)
assert(#guild == 4, "Jefa sent it in the meantime: not twice")

-- in combat or in an instance the game holds chat: not sent, not counted, tried again once out
pause(61)
STUB.inCombat = true
STUB.Advance(2 * ROUND)
assert(#guild == 4 and GN.Last().by == "Jefa", "in combat: nothing sent, nothing counted")
STUB.inCombat = false; STUB.inInstance = true
STUB.Advance(2 * ROUND)
assert(#guild == 4, "in an instance: nothing either")
STUB.inInstance = false
STUB.Advance(ROUND)
assert(#guild == 6 and GN.Last().by == "Tester", "sent once out: " .. #guild)

-- no guild info: nothing
STUB.guildInfo = ""
pause(61)
STUB.Advance(2 * ROUND)
assert(#guild == 6, "no info: nothing")

-- just after entering the world it waits: the other officers' last time may be on its way
STUB.guildInfo = "Hola."
pause(61)
STUB.Fire("PLAYER_ENTERING_WORLD", false, true)   -- a reload
STUB.Advance(ROUND)
assert(#guild == 6, "not in the first two minutes")
STUB.Advance(GN.SETTLE)
assert(#guild == 7 and guild[7] == "Hola.", "then it goes")

-- a longer interval, chosen by the officer
ns.char.guildNoticeEvery = 120
assert(GN.Every() == 120 and GN.Wait() > 60 * 60, "two hours")
ns.char.guildNoticeEvery = 7
assert(GN.Every() == 60, "only the offered choices")
ns.char.guildNoticeEvery = nil

-- what to say: the guild info (by default), the game's message of the day, or both (the message of the day first)
assert(GN.What() == "info", "the info by default")
ns.char.guildNoticeWhat = "nonsense"
assert(GN.What() == "info", "only the offered choices")
STUB.Fire("GUILD_MOTD", "Hoy banda a las 21:00")
ns.char.guildNoticeWhat = "motd"
assert(table.concat(GN.Lines(), "/") == "Hoy banda a las 21:00", "the message of the day: " .. table.concat(GN.Lines(), "/"))
ns.char.guildNoticeWhat = "both"
assert(table.concat(GN.Lines(), "/") == "Hoy banda a las 21:00/Hola.", "both, the message of the day first")
-- the game hands it only at login or when it changes (asking for it is a blocked action on Forever): kept per guild
assert(ns.db.guildNotice[ns.GuildKey()].motd == "Hoy banda a las 21:00", "kept in the saved data, for after a /reload")
STUB.player.guild = "Otra Hermandad"
ns.char.guildNoticeWhat = "motd"
assert(#GN.Lines() == 0, "another guild's message is not this one's")
STUB.player.guild = "Test Guild"
-- it may come before the game says which guild this is: kept until it does
STUB.player.guild = nil
STUB.Fire("GUILD_MOTD", "Llegó pronto")
STUB.player.guild = "Test Guild"
assert(table.concat(GN.Lines(), "/") == "Llegó pronto", "the early message of the day: " .. table.concat(GN.Lines(), "/"))
STUB.Fire("GUILD_MOTD", "Hoy banda a las 21:00")
-- it goes out like the info did
pause(61)
STUB.Advance(ROUND)
assert(#guild == 8 and guild[8] == "Hoy banda a las 21:00", "the message of the day said: " .. tostring(guild[#guild]))
-- an empty message of the day: nothing for "motd", only the info for "both"
STUB.Fire("GUILD_MOTD", "")
assert(#GN.Lines() == 0, "no message of the day: nothing")
ns.char.guildNoticeWhat = "both"
assert(table.concat(GN.Lines(), "/") == "Hola.", "both without one: the info")

-- my own text: written in the tab, kept per guild, cleaned like the rest
ns.char.guildNoticeWhat = "text"
assert(#GN.Lines() == 0, "nothing written yet")
GN.SetText("  Banda el jueves a las 21:00, |cffff0000apuntaos|r en el Discord  ")
assert(table.concat(GN.Lines(), "/") == "Banda el jueves a las 21:00, apuntaos en el Discord", "my text: " .. table.concat(GN.Lines(), "/"))
STUB.player.guild = "Otra Hermandad"
assert(#GN.Lines() == 0, "another guild's text is not this one's")
STUB.player.guild = "Test Guild"
pause(61)
STUB.Advance(ROUND)
assert(#guild == 9 and guild[9] == "Banda el jueves a las 21:00, apuntaos en el Discord", "my text said")
ns.char.guildNoticeWhat = "motd"

-- in the Recruit tab (officers only): turn it on or off, how often, when it last went
B.Toggle()
B.ShowTab("recruit")
B.Refresh(); STUB.Advance(0.6)
assert(B.noticeCheck:IsShown() and B.noticeCheck:GetChecked() == true, "the switch, on")
assert(B.noticeEvery.text == string.format(L.RECRUIT_EVERY, 60), "how often: " .. tostring(B.noticeEvery.text))
assert(B.noticeWhat.text == L.NOTICE_WHAT_motd and B.noticeStatus.text == L.NOTICE_EMPTY, "what, and nothing to say: " .. tostring(B.noticeStatus.text))
ns.char.guildNoticeWhat = nil
B.Refresh(); STUB.Advance(0.6)
assert(B.noticeWhat.text == L.NOTICE_WHAT_info and not B.noticeText:IsShown(), "the info, no box: " .. tostring(B.noticeWhat.text))
ns.char.guildNoticeWhat = "text"
B.Refresh(); STUB.Advance(0.6)
assert(B.noticeText:IsShown() and B.noticeText:GetText() == "Banda el jueves a las 21:00, apuntaos en el Discord", "my text, in its box")
B.noticeText:SetText("Hoy quedada en Ventormenta"); B.noticeText.scripts.OnEnterPressed(B.noticeText)
assert(table.concat(GN.Lines(), "/") == "Hoy quedada en Ventormenta", "written from the tab")
ns.char.guildNoticeWhat = nil
B.Refresh(); STUB.Advance(0.6)
assert(B.noticeStatus.text:find("Tester", 1, true), "who sent it last: " .. tostring(B.noticeStatus.text))
B.noticeCheck:SetChecked(false); B.noticeCheck.scripts.OnClick(B.noticeCheck)
assert(not GN.On(), "turned off from the tab")
STUB.Advance(3 * 60 * 60)
assert(#guild == 9, "off: nothing more")

print("ok guild_notice")

-- Another officer can relay the original author and interval at a fresh client's login.
STUB.guildMembers.Marisol = true; STUB.guildRoles.Marisol = 2; R.InvalidateGuildRoster()
local at = GetServerTime()
STUB.Receive("LVLM2", C.Encode("gin", { t = at, by = "Marisol", m = 120 }), "GUILD", "Jefa-Testrealm")
assert(GN.Last().by == "Marisol" and GN.Wait() == 120 * 60)
