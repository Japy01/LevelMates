-- the level-up banner: "Level 24!", how long it took, XP per hour, the place in the guild; ~8 s, a click closes it
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(30)
local DG, L = ns.Ding, ns.L
STUB.memberInfo = { Ana = { level = 40 }, Mario = { level = 30 }, Luis = { level = 10 }, Tester = { level = 23 } }
STUB.guildTotal = 4
ns.Roster.InvalidateGuildRoster(); ns.Members.Invalidate(); STUB.Fire("GUILD_ROSTER_UPDATE"); STUB.Advance(3)
assert(DG.Rank(24) == 3, "two above 24: third. Got " .. tostring(DG.Rank(24)))

STUB.lastChat = nil
STUB.Advance(600)
STUB.player.level = 24
STUB.Fire("PLAYER_LEVEL_UP", 24)
assert(DG.frame:IsShown() and DG.frame.title.text == string.format(L.DING_TITLE, 24), "the banner: " .. tostring(DG.frame.title.text))
assert(DG.frame.took.text ~= "" and DG.frame.rank.text:find("3", 1, true), "how long it took and the place")
assert(STUB.lastChat == nil, "nothing to chat (the heartbeat with the new level is the addon's own, not the banner's)")
STUB.Advance(4)
-- a second level: replaces the first, its own 8 s
STUB.player.level = 25
STUB.Fire("PLAYER_LEVEL_UP", 25)
assert(DG.frame.title.text == string.format(L.DING_TITLE, 25), "the newest")
STUB.Advance(5)
assert(DG.frame:IsShown(), "the first one's timer does not hide the second")
STUB.Advance(4)
assert(not DG.frame:IsShown(), "gone after about 8 s")
-- a click closes it
STUB.player.level = 26
STUB.Fire("PLAYER_LEVEL_UP", 26)
DG.frame.scripts.OnClick(DG.frame)
assert(not DG.frame:IsShown(), "a click closes it")
-- in combat it still shows
STUB.inCombat = true
STUB.player.level = 27
STUB.Fire("PLAYER_LEVEL_UP", 27)
assert(DG.frame:IsShown(), "in combat too")
STUB.inCombat = false
STUB.Advance(9)
-- quiet mode: none
ns.Settings.SetQuiet(true)
STUB.player.level = 28
STUB.Fire("PLAYER_LEVEL_UP", 28)
assert(not DG.frame:IsShown(), "quiet: no banner")
ns.Settings.SetQuiet(false)
