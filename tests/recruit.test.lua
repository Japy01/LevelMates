STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local C, B, RC, R, L = ns.Comm, ns.Board, ns.Recruit, ns.Roster, ns.L
local function last(kind) for i = #STUB.sent, 1, -1 do local k, f = C.Decode(STUB.sent[i].msg); if k == kind then return f end end end
local function said(text) for i = #STUB.printed, 1, -1 do if STUB.printed[i]:find(text, 1, true) then return true end end; return false end
STUB.guildMembers = { Tester = true, Jefa = true, Mario = true }
STUB.guildRoles = { Jefa = 2 }
R.InvalidateGuildRoster()
STUB.Receive("LVLM2", C.Encode("hb", { l = 40, z = 1421 }), "GUILD", "Jefa-Testrealm")
STUB.Receive("LVLM2", C.Encode("hb", { l = 20, z = 1421 }), "GUILD", "Mario-Testrealm")
STUB.player.level = 30; STUB.guildOnline = 7; STUB.channels[2] = 2

assert(C.Validate("rt", { i = 2, x = "hola", v = 100 }) and C.Validate("rt", { i = 4, x = "x", v = 100 }) == false and C.Validate("rc", { t = 100 }), "formats")
assert(RC.Expand("{hermandad} · {conectados} · {nivel}") == "Test Guild · 7 · 30", "placeholders: " .. RC.Expand("{hermandad} · {conectados} · {nivel}"))
STUB.player.guild = "100% Pros"
assert(RC.Expand("{guild}!") == "100% Pros!", "a % in the guild name")
STUB.player.guild = "Test Guild"

-- officers only
B.Toggle()
assert(not B.subs.recruit:IsShown(), "members do not see the tab")
assert(not RC.SetTemplate(2, "x") and RC.Prepare(1, 2) == nil, "members cannot edit or post")
STUB.iAmOfficer = true
B.ShowTab("recruit")
assert(B.subs.recruit:IsShown() and B.recruitPanel:IsShown() and B.heading.text == L.HEAD_RECRUIT, "officers do")
assert(B.recruitEdit[1]:GetText() == L.RECRUIT_DEFAULT, "a default template")
for i = 1, #B.rows do assert(not B.rows[i].button:IsShown(), "no list rows here") end

-- edit, share, pick, preview, post
B.recruitEdit[2]:SetText("Somos {hermandad}"); B.recruitEdit[2].scripts.OnEnterPressed(B.recruitEdit[2])
assert(RC.Templates()[2] == "Somos {hermandad}" and last("rt").i == 2 and last("rt").x == "Somos {hermandad}", "saved and shared")
B.recruitUse[2]:SetChecked(true); B.recruitUse[2].scripts.OnClick(B.recruitUse[2])
assert(B.recruitPreview.text == "Somos Test Guild", "preview")
B.recruitPost.scripts.OnClick(B.recruitPost)
assert(STUB.lastChat and STUB.lastChat.msg == "Somos Test Guild" and STUB.lastChat.chatType == "CHANNEL" and STUB.lastChat.target == 2, "posted to channel 2")
assert(last("rc") and RC.Last().by == "Tester", "the wait starts for everyone")

-- the wait is shared
STUB.lastChat = nil
B.recruitPost.scripts.OnClick(B.recruitPost)
assert(STUB.lastChat == nil and said(string.format(L.RECRUIT_WAIT, 10)), "wait 10 minutes")
STUB.Advance(RC.GAP + 1)
STUB.Receive("LVLM2", C.Encode("rc", { t = time() }), "GUILD", "Jefa-Testrealm")
assert(RC.Last().by == "Jefa" and RC.Wait() > 0, "Jefa just posted")
assert(B.recruitStatus.text:find("Jefa", 1, true), "status shows who")
STUB.Receive("LVLM2", C.Encode("rc", { t = time() }), "GUILD", "Mario-Testrealm")
assert(RC.Last().by == "Jefa", "members' rc ignored")

-- shared templates: officers only
STUB.Receive("LVLM2", C.Encode("rt", { i = 3, x = "Plantilla de Jefa", v = time() }), "GUILD", "Jefa-Testrealm")
STUB.Receive("LVLM2", C.Encode("rt", { i = 3, x = "Spam de Mario", v = time() + 10 }), "GUILD", "Mario-Testrealm")
STUB.Advance(0.6)   -- changes redraw the open page at most twice a second
assert(RC.Templates()[3] == "Plantilla de Jefa" and B.recruitEdit[3]:GetText() == "Plantilla de Jefa", "Jefa's template")

-- not in the channel: refused with the reason
STUB.Advance(RC.GAP + 1)
B.recruitChannel[1]:SetChecked(true); B.recruitChannel[1].scripts.OnClick(B.recruitChannel[1])
B.recruitPost.scripts.OnClick(B.recruitPost)
assert(STUB.lastChat == nil and said(string.format(L.RECRUIT_NO_CHANNEL, 1)), "not in channel 1")

-- members again: no tab
STUB.iAmOfficer = false
B.Refresh()
assert(not B.subs.recruit:IsShown() and B.tab ~= "recruit", "back to a member's tabs")
