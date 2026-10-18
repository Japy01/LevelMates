-- Recruitment, asked 2026-10-18: the reminder's interval is chosen on the tab (5 to 60 min; it is also the wait
-- between posts) and a post can be forced while the wait holds: the button says "Publicar igualmente"
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
-- a post: the wait holds, the button offers to post anyway, and a click does
STUB.lastChat = nil
B.recruitPost.scripts.OnClick(B.recruitPost)
assert(STUB.lastChat and STUB.lastChat.target == 2, "posted")
assert(RC.Wait() > 0 and B.recruitPost.text == L.RECRUIT_POST_ANYWAY, "during the wait the button says so: " .. tostring(B.recruitPost.text))
assert(RC.Prepare(1, 2) == nil, "the plain way still waits")
STUB.lastChat = nil
B.recruitPost.scripts.OnClick(B.recruitPost)
assert(STUB.lastChat and STUB.lastChat.target == 2, "posted anyway from the click")
STUB.Advance(1801); B.Refresh()
assert(RC.Wait() == 0 and B.recruitPost.text == L.RECRUIT_POST, "after the interval: the plain button")
-- the reminder follows the interval
ns.char.recruitRemind = true
RC.Tick()
assert(RC.prompt and RC.prompt:IsShown(), "offered once the interval passed")
print("ok")
