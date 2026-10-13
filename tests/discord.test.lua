-- Discord: runs announced in the guild's linked channel, from clicks only; held when blocked, sent from a click
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(30)
local DC, M, C = ns.Discord, ns.Meetups, ns.Comm
local posted = {}
SendChatMessage = function(text, chatType) posted[#posted + 1] = { text = text, type = chatType } end
C_Discord = { IsEnabled = function() return true end, IsGuildChannelLinked = function() return true end, IsUserOAuthed = function() return false end }
assert(select(2, DC.Available()) == "DISCORD_NO_USER", "not linked: why")
C_Discord.IsGuildChannelLinked = function() return false end
assert(select(2, DC.Available()) == "DISCORD_NO_GUILD", "guild not linked: why")
C_Discord.IsGuildChannelLinked = function() return true end
C_Discord.IsUserOAuthed = function() error("secret") end
assert(DC.Available(), "an error is unknown, not no: allowed (the send itself tells)")
-- Forever: the restricted checks answer nothing to an addon. Unknown is allowed; only an explicit false refuses
C_Discord.IsGuildChannelLinked = function() end
C_Discord.IsUserOAuthed = function() end
local ok, why = DC.Available()
assert(ok and why == "DISCORD_UNSURE", "no answer: allowed, with a note: " .. tostring(why))
C_Discord.IsEnabled = function() return false end
assert(not DC.Available(), "Discord off in the client: no")
C_Discord.IsEnabled = function() return true end
C_Discord.IsGuildChannelLinked = function() return true end
C_Discord.IsUserOAuthed = function() return true end
assert(DC.Available(), "available")
-- Forever's restriction flag reads true outside combat: it must not stop us
STUB.reportsRestricted = true
assert(M.Create(5, M.Now() + 60, "traed | pociones % y más cosas de las que hacen falta", "T", true), "created with Discord")
local p = posted[1]
assert(#posted == 1 and p.type == "GUILD_DISCORD" and #p.text <= 236 and not p.text:find("|", 1, true), "one clean line: " .. tostring(p and p.text))
assert(p.text:find(ns.Dungeons.Name(5), 1, true) and p.text:find(ns.Me(), 1, true), "names the dungeon and the leader")
-- a run without the mark posts nothing; a join of a marked run posts the joiner's line from the joiner's client
M.Create(6, M.Now() + 90, "", "D", false)
assert(#posted == 1, "no mark, no line")
STUB.Receive("LVLM2", C.Encode("hb", { l = 20, z = 1421, c = "MAGE" }), "GUILD", "Mario-Testrealm")
STUB.Receive("LVLM2", C.Encode("qd", STUB.Rec{ id = "mar00001", d = 4, at = M.Now() + 30, r = "H", dc = 1 }), "GUILD", "Mario-Testrealm")
assert(#posted == 1, "receiving a run posts nothing")
assert(M.Join("mar00001", "D") and #posted == 2 and posted[2].text:find(ns.Me(), 1, true), "my join, my line")
-- in combat inside an instance: held (the latest per run), never on its own, sent from the click
local id = M.List(5)[1].id
STUB.inInstance, STUB.inCombat = true, true
M.Cancel(id)
assert(DC.Held(id) and #posted == 2, "held")
STUB.Advance(120); assert(#posted == 2, "no automatic retry")
STUB.inInstance, STUB.inCombat = false, false
DC.SendHeld(id)
assert(#posted == 3 and not DC.Held(id), "sent from the click")
-- blocked during our send: marked unsent, the button back, no retry for 30 s
SendChatMessage = function(text, chatType) posted[#posted + 1] = { text = text, type = chatType }; STUB.Fire("ADDON_ACTION_BLOCKED", "LevelMates", "SendChatMessage") end
M.Leave("mar00001")
assert(DC.Held("mar00001"), "blocked: held")
local n = #posted
M.Join("mar00001", "D")
assert(#posted == n and DC.Held("mar00001"), "within 30 s: held, not tried")
-- a surname and accents stay whole; long notes are cut, the line under 236
local line = DC.Line("new", { id = "z", d = 5, at = M.Now() + 60, by = "Gigasamba Caramba", role = "T", n = string.rep("á", 40) })
assert(#line <= 236 and line:find("Gigasamba Caramba", 1, true), "surname kept, under the limit")
