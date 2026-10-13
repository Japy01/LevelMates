STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local C, B, RC, R, L = ns.Comm, ns.Board, ns.Recruit, ns.Roster, ns.L
local function last(kind) for i = #STUB.sent, 1, -1 do local k, f = C.Decode(STUB.sent[i].msg); if k == kind then return f end end end
local function said(text)
	local fb = ns.Board and ns.Board.feedback   -- with the book open, it shows at its foot
	if fb and fb:IsShown() and fb.text.text and fb.text.text:find(text, 1, true) then return true end
	for i = #STUB.printed, 1, -1 do if STUB.printed[i]:find(text, 1, true) then return true end end; return false end
STUB.guildMembers = { Tester = true, Jefa = true }
STUB.guildRoles = { Jefa = 2 }
R.InvalidateGuildRoster()
STUB.Receive("LVLM2", C.Encode("hb", { l = 40, z = 1421 }), "GUILD", "Jefa-Testrealm")
STUB.iAmOfficer = true
STUB.channels[2] = 2

-- #1: the shared wait runs on the server's clock, in seconds
local server = time()
GetServerTime = function() return server end
local realTime = time
time = function(t) if t then return realTime(t) end; return server - 300 end   -- my PC is 5 minutes behind
STUB.Receive("LVLM2", C.Encode("rc", { t = server - 30 }), "GUILD", "Jefa-Testrealm")
assert(RC.Last() and RC.Last().by == "Jefa" and RC.Last().at == server - 30, "Jefa's post accepted, exact second")
assert(RC.Wait() == RC.GAP - 30, "the wait counted on the server clock: " .. RC.Wait())
time = realTime
GetServerTime = nil
ns.db.recruit[GetGuildInfo("player")].last = nil

-- #2: an older copy of a template never overwrites a newer edit
assert(RC.SetTemplate(1, "Nueva versión"))
local v = last("rt").v
assert(v and v > 0, "edits carry their version")
STUB.Receive("LVLM2", C.Encode("rt", { i = 1, x = "Vieja", v = v - 100 }), "GUILD", "Jefa-Testrealm")
assert(RC.Templates()[1] == "Nueva versión", "older copy ignored")
STUB.Receive("LVLM2", C.Encode("rt", { i = 1, x = "Más nueva", v = v + 100 }), "GUILD", "Jefa-Testrealm")
assert(RC.Templates()[1] == "Más nueva", "newer copy wins")

-- #3: a slot taken by our own hidden channel is not Trade
local hidden
for name in pairs(STUB.channels) do if type(name) == "string" and name:find("^LM") then hidden = name end end
local realGet = GetChannelName
GetChannelName = function(n) if n == 2 then return 2, hidden or "LM00000000" end; return realGet(n) end
STUB.lastChat = nil
B.ShowTab("recruit")
B.recruitPost.scripts.OnClick(B.recruitPost)
assert(STUB.lastChat == nil and said(string.format(L.RECRUIT_NO_CHANNEL, 2)), "refused: that is not Trade")
GetChannelName = realGet

-- #5: no "empty list" text over the panel
assert(B.frame.empty.text == "", "no empty-list text on this tab: " .. tostring(B.frame.empty.text))

-- #6: Post uses what is typed, even without pressing Enter
B.recruitUse[1]:SetChecked(true); B.recruitUse[1].scripts.OnClick(B.recruitUse[1])
B.recruitEdit[1]:SetText("Recién escrito")
B.recruitPost.scripts.OnClick(B.recruitPost)
assert(STUB.lastChat and STUB.lastChat.msg == "Recién escrito", "posted the typed text")

-- #4: the reminder waits for a good moment and a closed prompt stays closed
ns.char.recruitRemind = true
STUB.Advance(RC.GAP + 1)
STUB.inInstance = true; RC.Tick()
assert(not (RC.prompt and RC.prompt:IsShown()), "not inside an instance")
STUB.inInstance = false
InCombatLockdown = function() return true end; RC.Tick()
assert(not (RC.prompt and RC.prompt:IsShown()), "not in combat")
InCombatLockdown = function() return false end
STUB.channels[2] = nil; RC.Tick()
assert(not (RC.prompt and RC.prompt:IsShown()), "not away from Trade")
STUB.channels[2] = 2; RC.Tick()
assert(RC.prompt:IsShown(), "offered in town")
RC.prompt:Hide(); RC.prompt.scripts.OnHide(RC.prompt)   -- closed with its X
RC.Tick()
assert(not RC.prompt:IsShown(), "closing it snoozes it")
