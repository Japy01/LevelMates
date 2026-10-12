STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local AC, DP, RP, B, C, L = ns.Achievements, ns.DungeonPanel, ns.Report, ns.Board, ns.Comm, ns.L
local function last(kind) for i = #STUB.sent, 1, -1 do local k, f = C.Decode(STUB.sent[i].msg); if k == kind then return f end end end

-- 1: the level-up event's own level counts (the game still reports the old one during it)
assert(not AC.Has("lvl30"))
STUB.player.level = 29   -- what UnitLevel still says
STUB.Fire("PLAYER_LEVEL_UP", 30)
assert(AC.Has("lvl30"), "level 30 earned at the level-up")

-- 2/3: no global error handler; LevelMates' own errors are caught where they start, the rest go on as before
local before = geterrorhandler()
assert(before == STUB.errorHandler, "the game's handler is left alone")
local reached = false
ns.On("LM_TEST_BOOM", function() error("LevelMates test boom") end)
ns.On("LM_TEST_BOOM", function() reached = true end)
STUB.handled = {}
ns.Fire("LM_TEST_BOOM")
assert(reached, "one failing listener does not stop the others")
assert(#STUB.handled == 1 and STUB.handled[1]:find("test boom", 1, true), "the error still reaches the game's handler")
assert(RP.Text():find("test boom", 1, true), "and is in the report")

-- 4/5: the panel catches the mouse, stays on screen, fits its lines above the footer
B.Toggle(); B.ShowTab("lfg")
DP.Open(5)
assert(DP.frame.mouseEnabled and DP.frame.clamped, "catches the mouse, clamped to the screen")
assert(DP.frame:GetHeight() >= 98 + DP.LINES * DP.LINE_H + 40, "room for every line above the footer")
B.frame.GetRight = function() return 1100 end
UIParent.GetRight = function() return 1229 end
DP.Open(5)
assert(DP.frame.point[1] == "TOPRIGHT" and DP.frame.point[3] == "TOPLEFT", "no room on the right: opens on the left")

-- 6: my own group lists who joined with Invite; others' groups have Whisper and Invite
STUB.Receive("LVLM2", C.Encode("hb", { l = 21, z = 1412 }), "GUILD", "Mario-Testrealm")
STUB.Receive("LVLM2", C.Encode("lfg", { d = 5, r = "H", id = "lfg00001", m = 20 }), "GUILD", "Mario-Testrealm")
local rows = DP.Rows(5)
local contact
for _, r in ipairs(rows) do if r.kind == "contact" then contact = r end end
assert(contact and contact.ad.name == "Mario", "Whisper and Invite for Mario's group")
ns.LFG.Post(5, "T")
STUB.Receive("LVLM2", C.Encode("hb", { l = 40, z = 1412 }), "GUILD", "Ana-Testrealm")
STUB.Receive("LVLM2", C.Encode("lfj", { id = ns.LFG.mine.id, r = "H" }), "GUILD", "Ana-Testrealm")
local joiner
for _, r in ipairs(DP.Rows(5)) do if r.kind == "joiner" then joiner = r end end
assert(joiner and joiner.name == "Ana" and joiner.role == "H", "who joined mine, to invite")

-- minors: achievements list resent after a refused send; report without names
ns.char.achPending = true
local n = #STUB.sent
ns.Fire("LM_HB_SENT")
local resent = false
for i = n + 1, #STUB.sent do if C.Decode(STUB.sent[i].msg) == "ac" then resent = true end end
assert(resent and not ns.char.achPending, "resent with the heartbeat")
assert(not RP.Text():find("Mario", 1, true), "the report counts guildmates, without their names")
