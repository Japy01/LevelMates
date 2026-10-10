STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local RC, L = ns.Recruit, ns.L
STUB.iAmOfficer = true; STUB.channels[2] = 2
RC.Tick()
assert(not (RC.prompt and RC.prompt:IsShown()), "off by default")
ns.char.recruitRemind = true
RC.Tick()
assert(RC.prompt and RC.prompt:IsShown() and STUB.lastChat == nil, "offered, never posted by itself")
assert(UIErrorsFrame.messages[#UIErrorsFrame.messages] == L.RECRUIT_PROMPT, "and said on screen")
RC.promptLater.scripts.OnClick(RC.promptLater)
assert(not RC.prompt:IsShown(), "not now")
RC.Tick()
assert(not RC.prompt:IsShown(), "snoozed")
STUB.Advance(RC.GAP + 1); RC.Tick()
assert(RC.prompt:IsShown(), "offered again 10 minutes later")
RC.promptPost.scripts.OnClick(RC.promptPost)
assert(STUB.lastChat and STUB.lastChat.target == 2 and not RC.prompt:IsShown() and RC.Wait() > 0, "one click posts")
RC.Tick()
assert(not RC.prompt:IsShown(), "not during the wait")
STUB.iAmOfficer = false; STUB.Advance(RC.GAP + 1); RC.Tick()
assert(not RC.prompt:IsShown(), "members are never asked")
