-- the guild leader or an officer turns the Discord bot tag on for the whole guild (a record, like LevelMates' MOTD);
-- each player can still opt out
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(30)
local GN, C, DC, A = ns.GuildNotes, ns.Comm, ns.Discord, ns.Activities
STUB.guildRoles = { Luis = 2 }; ns.Roster.InvalidateGuildRoster()
local run = { id = "a1b2c3d4", d = 5, at = 29333333, by = "Mario", role = "T", size = 5, caps = A.Caps(5), joined = {} }
local function tagged() return DC.Line("new", run):find("[LM1", 1, true) ~= nil end

assert(not tagged() and not GN.GuildTag(), "off: neither the guild nor me")
-- a non-officer cannot turn it on, nor can their record
assert(not GN.SetGuildTag(true), "not an officer: refused")
STUB.Receive("LVLM2", C.Encode("gst", STUB.Rec{ id = "guild", dt = 1 }), "GUILD", "Mario-Testrealm")
assert(not GN.GuildTag() and not tagged(), "Mario's record: refused")
-- an officer's record turns it on for me
STUB.Receive("LVLM2", C.Encode("gst", STUB.Rec{ id = "guild", dt = 1 }), "GUILD", "Luis-Testrealm")
assert(GN.GuildTag() and tagged(), "Luis (officer): on for the guild, so my lines carry the tag")
-- I can opt out
ns.db.settings.discordTagOff = true
assert(not tagged(), "opted out")
ns.db.settings.discordTagOff = false
-- an officer turns it off
STUB.Receive("LVLM2", C.Encode("gst", STUB.Rec{ id = "guild", dt = 0 }), "GUILD", "Luis-Testrealm")
assert(not GN.GuildTag() and not tagged(), "off again")
-- my own switch still works without the guild's
ns.db.settings.discordTag = true
assert(tagged(), "my own switch")
ns.db.settings.discordTag = false
-- me as an officer: I can set it, and it goes out
STUB.guildRoles = { Luis = 2, Tester = 1 }; ns.Roster.InvalidateGuildRoster()
local n = #STUB.sent
assert(GN.SetGuildTag(true), "the leader turns it on")
assert(GN.GuildTag() and tagged(), "on")
local sent = false
for i = n + 1, #STUB.sent do if C.Decode(STUB.sent[i].msg) == "gst" then sent = true end end
assert(sent, "shared with the guild")

-- like Guild Armory: a group made with the tag carries it, so every join and leave of that group goes tagged,
-- whatever the joiner's own switch
GN.SetGuildTag(false)
ns.db.settings.discordTag = false
local tagRun = { id = "b1b2c3d4", d = 5, at = 29333333, by = "Mario", role = "T", size = 5, caps = A.Caps(5), joined = {}, dc = true, dcTag = true }
assert(DC.Line("join", tagRun, "Tester", "H"):find("[LM1", 1, true), "the group's tag wins")
local plain = { id = "c1b2c3d4", d = 5, at = 29333333, by = "Mario", role = "T", size = 5, caps = A.Caps(5), joined = {}, dc = true }
assert(not DC.Line("join", plain, "Tester", "H"):find("[LM1", 1, true), "a group without it: as my switch says")
-- it travels: a received ad and run marked dc=2 carry the tag
STUB.Receive("LVLM2", C.Encode("hb", { l = 30, z = 1412, c = "MAGE" }), "GUILD", "Mario-Testrealm")
STUB.Receive("LVLM2", C.Encode("lfg", { d = 5, lr = "T", id = "mario009", m = 20, dc = 2 }), "GUILD", "Mario-Testrealm")
assert(ns.LFG.ads.mario009 and ns.LFG.ads.mario009.dcTag, "a Now group with the tag")
STUB.Receive("LVLM2", C.Encode("qd", STUB.Rec{ id = "mrun0009", d = 5, at = ns.Meetups.Now() + 60, r = "T", dc = 2 }), "GUILD", "Mario-Testrealm")
local got
for _, m in ipairs(ns.Meetups.List()) do if m.id == "mrun0009" then got = m end end
assert(got and got.dc and got.dcTag, "a run with the tag")
-- mine: made with the tag when it is on (the guild's or mine), and says so
ns.db.settings.discordTag = true
STUB.Advance(31)
assert(ns.LFG.Post{ d = 6, role = "T", discord = true }, "posted")
local f
for i = #STUB.sent, 1, -1 do local k, ff = C.Decode(STUB.sent[i].msg); if k == "lfg" then f = ff; break end end
assert(f.dc == 2, "my group travels with the tag: " .. tostring(f.dc))
ns.db.settings.discordTag = false
