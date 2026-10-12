-- project 5 final review fixes
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
-- (4) a snapshot from an earlier session: Ana was 59
ns.db.history = { ["Test Guild"] = { log = {}, snap = { Ana = { level = 59, rank = 4 }, Tester = { level = 20, rank = 4 }, Mario = { level = 30, rank = 4 }, Luis = { level = 40, rank = 4 } }, race = { Ana = { level = 59 } } } }
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(30)
local GN, GH, GB, C, B, F, L = ns.GuildNotes, ns.GuildHistory, ns.GuildBank, ns.Comm, ns.Board, ns.Feed, ns.L
STUB.guildRoles = { Luis = 2 }; ns.Roster.InvalidateGuildRoster()
STUB.memberInfo = { Ana = { level = 60, classID = 2 }, Mario = { level = 30 }, Luis = { level = 40 }, Tester = { level = 20 } }
STUB.guildTotal = 4
local function scan() ns.Roster.InvalidateGuildRoster(); ns.Members.Invalidate(); STUB.Fire("GUILD_ROSTER_UPDATE"); STUB.Advance(3) end
scan()
local ana
for _, r in ipairs(GH.Race()) do if r.name == "Ana" then ana = r end end
assert(ana and ana.before and not ana.first, "4: reached 60 while I was away: not live")
-- (1) a note under someone else's id, and a tombstone squat
STUB.Receive("LVLM2", C.Encode("gn", STUB.Rec{ id = ns.NameKey("Ana"), f = "Mario", n = "trampa" }), "GUILD", "Mario-Testrealm")
assert(GN.Note("Ana") == nil and GN.Note("Mario") == nil, "1: an id that is not the note's subject: refused")
STUB.Receive("LVLM2", C.Encode("x", STUB.Rec{ t = "gn", id = ns.NameKey("Ana") }), "GUILD", "Mario-Testrealm")
STUB.Receive("LVLM2", C.Encode("gn", STUB.Rec{ id = ns.NameKey("Ana"), f = "Ana", n = "Sanadora" }), "GUILD", "Ana-Testrealm")
assert(GN.Note("Ana") == "Sanadora", "1: Mario's tombstone did not block Ana")
-- (2) a faked writer: live refused, catch-up accepted
STUB.Receive("LVLM2", C.Encode("gmo", STUB.Rec{ id = "motd", n = "falso", o = "Luis" }), "GUILD", "Mario-Testrealm")
assert(GN.Motd() == nil, "2: Mario claiming to be Luis, live: refused")
STUB.Receive("LVLM2", C.Encode("gmo", STUB.Rec{ id = "motd", n = "de Luis", o = "Luis" }), "WHISPER", "Mario-Testrealm")
assert(GN.Motd() == "de Luis", "2: handed over at login: accepted")
-- (5) a departure shows on the wall
STUB.guildMembers.Pepe = true; STUB.memberInfo.Pepe = { level = 15 }; STUB.guildTotal = 5; scan()
STUB.guildMembers.Pepe = nil; STUB.guildTotal = 4; scan()
local left = false
for _, e in ipairs(F.List()) do if e.who == "Pepe" and e.k == "leave" then left = true end end
assert(left, "5: the departure on the wall")
-- (10) level-ups from 10 on go to the history
STUB.memberInfo.Mario.level = 31; scan()
assert(GH.List()[1].k == "level" and GH.List()[1].who == "Mario", "10: a level-up in the history")
-- (6) names with the realm are shown without it
STUB.guildMembers["Zoe-Testrealm"] = true; STUB.guildTotal = 5; scan()
local zoe = false
for _, m in ipairs(ns.Members.List()) do if m.name == "Zoe" then zoe = true end end
assert(zoe, "6: Zoe-Testrealm listed as Zoe")
STUB.guildMembers["Zoe-Testrealm"] = nil; STUB.guildTotal = 4; scan()
-- (7) a reader who cannot see a tab does not wipe it
STUB.bank = { money = 100, tabs = { { name = "General", slots = { [1] = { id = 858, n = 1 } } }, { name = "Oficiales", slots = { [1] = { id = 999, n = 2 } } } } }
STUB.Fire("GUILDBANKFRAME_OPENED"); STUB.Advance(3); STUB.Fire("GUILDBANKFRAME_CLOSED"); STUB.Advance(2)
STUB.bank.tabs[2].view = false
STUB.Fire("GUILDBANKFRAME_OPENED"); STUB.Advance(3); STUB.Fire("GUILDBANKFRAME_CLOSED"); STUB.Advance(2)
local kept = false
for _, t in ipairs(GB.Snapshot().tabs) do if t.name == "Oficiales" and t.items[999] == 2 then kept = true end end
assert(kept, "7: the tab I cannot see is kept")
-- (8) a full bank fits
local tabs = {}
for t = 1, 8 do local items = {}; for s = 1, 98 do items[100000 + t * 1000 + s] = 200 end; tabs[t] = { name = "Pestaña " .. t, items = items } end
assert(C.Validate("gbk", { id = "bank", v = 1, e = 2, t = 1, m = 1, p = GB.Encode(tabs) }), "8: eight full tabs fit")
-- (9) the bank's line is shown
B.Toggle(); B.ShowTab("bank")
assert(B.subtitle:IsShown() and B.subtitle.text:find(ns.Me(), 1, true), "9: who saw the bank, shown")
