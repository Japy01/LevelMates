STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.guildRoles = { Tester = 4, Mario = 4, Ana = 2 }
ns.Roster.InvalidateGuildRoster()
local fields = { id = "announcement", h = "Raid supplies", b = "Bring food", v = GetServerTime(), e = GetServerTime() + 60 }
local message = assert(ns.Comm.Encode("gan", fields))
STUB.Receive("LVLM2", message, "GUILD", "Mario-Testrealm")
assert(not ns.Sync.Get("gan", fields.id))
STUB.Receive("LVLM2", message, "GUILD", "Ana-Testrealm")
assert(ns.Sync.Get("gan", fields.id).d.b == "Bring food")
ns.GuildAnnouncements.List()
local ranks = {
	{ name = "Ana", role = 1, verifiedRank = 0, rankName = "Master" },
	{ name = "Tester", role = 4, verifiedRank = 2, rankName = "Veteran" },
	{ name = "Mario", role = 4, verifiedRank = 3, rankName = "Member" },
}
ns.Roster.GuildMembers = function() return ranks end
local private = { id = ns.NameKey("Ana") .. "1", h = "Veterans", b = "Line one\nLine two", v = GetServerTime(), r = 2, n = "Veteran" }
local wire = assert(ns.Comm.Encode("gar", private))
STUB.Receive("LVLM2", wire, "GUILD", "Ana-Testrealm")
assert(#ns.GuildAnnouncements.List() == 1)
STUB.Receive("LVLM2", wire, "WHISPER", "Ana-Testrealm")
assert(#ns.GuildAnnouncements.List() == 2)
assert(not ns.Sync.Get("gan", private.id))
ranks[2].verifiedRank, ranks[2].rankName = 3, "Member"
assert(#ns.GuildAnnouncements.List() == 1)
STUB.Receive("LVLM2", wire, "WHISPER", "Ana-Testrealm")
assert(#ns.GuildAnnouncements.List() == 1)
ns.Board.ShowTab("announcements")
ranks[2].verifiedRank, ranks[2].rankName = 2, "Veteran"
local retract = { id = private.id, h = "-", b = "-", v = private.v + 1, r = 2, n = "Veteran", x = 1 }
STUB.Receive("LVLM2", assert(ns.Comm.Encode("gar", retract)), "WHISPER", "Mario-Testrealm")
assert(#ns.GuildAnnouncements.List() == 2)
local official = { name = "Luz", role = 2, verifiedRank = 1, rankName = "Officer" }
ranks[#ranks + 1] = official
ns.Roster.InvalidateGuildRoster()
private.id = ns.NameKey("Luz") .. "2"
STUB.Receive("LVLM2", assert(ns.Comm.Encode("gar", private)), "WHISPER", "Luz-Testrealm")
assert(#ns.GuildAnnouncements.List() == 3)
retract.id = private.id
STUB.Receive("LVLM2", assert(ns.Comm.Encode("gar", retract)), "WHISPER", "Ana-Testrealm")
assert(#ns.GuildAnnouncements.List() == 2)
STUB.Receive("LVLM2", assert(ns.Comm.Encode("gar", private)), "WHISPER", "Luz-Testrealm")
assert(#ns.GuildAnnouncements.List() == 2)
local policy = { id = "moderation", r = 2, n = "Veteran", v = GetServerTime(), e = GetServerTime() + 60 }
STUB.Receive("LVLM2", assert(ns.Comm.Encode("gam", policy)), "GUILD", "Luz-Testrealm")
assert(not ns.GuildAnnouncements.CanWithdraw({ o = "Ana", d = { r = 2, n = "Veteran" } }))
STUB.Receive("LVLM2", assert(ns.Comm.Encode("gam", policy)), "GUILD", "Ana-Testrealm")
assert(ns.GuildAnnouncements.CanWithdraw({ o = "Ana", d = { r = 2, n = "Veteran" } }))
