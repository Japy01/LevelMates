-- Recruitment, asked 2026-10-18: the reminder's interval is chosen on the tab (5 to 60 min; it is also the wait
-- between posts) and the shared wait also applies to manual posts
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local B, RC, R, L = ns.Board, ns.Recruit, ns.Roster, ns.L
STUB.guildMembers = { Tester = true, Jefa = true }
STUB.guildRoles = { Jefa = 2 }
R.InvalidateGuildRoster()
STUB.iAmOfficer = true
STUB.channels[2] = 2
assert(RC.Gap() == RC.GAP and RC.GAP == 600, "10 minutes by default")
B.Toggle(); B.ShowTab("recruit")
assert(B.recruitEvery and B.recruitEvery:IsShown() and B.recruitEvery.text == string.format(L.RECRUIT_EVERY, 10), "the interval on the tab: " .. tostring(B.recruitEvery and B.recruitEvery.text))
B.recruitEvery.scripts.OnClick(B.recruitEvery)
assert(STUB.MenuEntry(string.format(L.RECRUIT_EVERY, 30)) and STUB.MenuEntry(string.format(L.RECRUIT_EVERY, 5)), "a menu of intervals")
STUB.MenuEntry(string.format(L.RECRUIT_EVERY, 30)).cb()
assert(ns.char.recruitEvery == 30 and RC.Gap() == 1800 and B.recruitEvery.text == string.format(L.RECRUIT_EVERY, 30), "30 minutes chosen")
-- a post: the wait holds, the board also respects it
STUB.lastChat = nil
B.recruitPost.scripts.OnClick(B.recruitPost)
assert(STUB.lastChat and STUB.lastChat.target == 2, "posted")
assert(RC.Wait() > 0 and B.recruitPost.text == L.RECRUIT_POST)
assert(RC.Prepare(1, 2) == nil, "the plain way still waits")
STUB.lastChat = nil
B.recruitPost.scripts.OnClick(B.recruitPost)
assert(not STUB.lastChat, "a click cannot bypass the cooldown")
STUB.Advance(1801); B.Refresh()
assert(RC.Wait() == 0 and B.recruitPost.text == L.RECRUIT_POST, "after the interval: the plain button")
-- the reminder follows the interval
ns.char.recruitRemind = true
RC.Tick()
assert(RC.prompt and RC.prompt:IsShown(), "offered once the interval passed")
print("ok")
-- Recent history is scoped, preserves the author after a relay and respects the reported interval.
STUB.guildMembers.Marisol = true; STUB.guildRoles.Marisol = 2; R.InvalidateGuildRoster()
local zone = STUB.player.mapId
STUB.Receive("LVLM2", ns.Comm.Encode("rcz", { k = "zone" .. zone, t = GetServerTime(), by = "Marisol", m = 60 }), "GUILD", "Jefa-Testrealm")
assert(RC.Wait(1) == 3600 and RC.Last(1).by == "Marisol")
STUB.player.mapId = zone + 1
assert(RC.Wait(1) == 0 and RC.Wait(2) == 0)
STUB.player.mapId = zone
assert(RC.Wait(1) == 3600)
GetChannelList = function() return 1, "General", false, 7, "任意の名前", false, 9, "Commerce", true end
C_ChatInfo.GetChannelInfoFromIdentifier = function(name)
	if name == "General" then return { zoneChannelID = 0, localID = 1 } end
	if name == "任意の名前" then return { zoneChannelID = 1, localID = 7 } end
	if name == "Commerce" then return { zoneChannelID = 2, localID = 9 } end
end
assert(RC.Channel(1) == 7 and not RC.Channel(2), "use the native type, not the displayed name or slot")
GetChannelList = function() return 9, "Commerce", false end
assert(RC.Channel(2) == 9)
