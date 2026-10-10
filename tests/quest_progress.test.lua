STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local C, Q, B, R, L = ns.Comm, ns.QuestProgress, ns.Board, ns.Roster, ns.L
local function sentQo(from) local out = {}; for i = (from or 0) + 1, #STUB.sent do local k, f = C.Decode(STUB.sent[i].msg); if k == "qo" then out[#out + 1] = f end end; return out end
STUB.guildMembers = { Tester = true, Mario = true }
R.InvalidateGuildRoster()
assert(C.Validate("qo", { i = 101, o = "6/10,1/1" }) and C.Validate("qo", { i = 101, o = "6 de 10" }) == false, "qo format")

STUB.quests = { 101, 102 }
STUB.objectives[101] = { { numFulfilled = 6, numRequired = 10, finished = false }, { numFulfilled = 0, numRequired = 0, finished = true } }
STUB.objectives[102] = { { numFulfilled = 1, numRequired = 3, finished = false } }
assert(Q.Objectives(101) == "6/10,1/1", "objectives as text")
STUB.Receive("LVLM", C.Encode("hb", { l = 20, z = 1421 }), "GUILD", "Mario-Testrealm")
STUB.Receive("LVLM", C.Encode("q", { i = "1/1", ids = "101,555" }), "GUILD", "Mario-Testrealm")

-- not grouped: nothing
local n = #STUB.sent
Q.SendChanged()
assert(#sentQo(n) == 0, "only while grouped")
-- grouped with Mario: the shared quest only, once per change
STUB.partyMembers.Mario = true
Q.SendChanged()
local qo = sentQo(n)
assert(#qo == 1 and qo[1].i == 101 and qo[1].o == "6/10,1/1", "shared quest progress")
n = #STUB.sent
Q.SendChanged()
assert(#sentQo(n) == 0, "unchanged: nothing")
STUB.objectives[101][1].numFulfilled = 7
STUB.Fire("QUEST_LOG_UPDATE"); STUB.Advance(3)
assert(#sentQo(n) == 1 and sentQo(n)[1].o == "7/10,1/1", "changed: sent after the log settles")

-- Mario's progress: in his tooltip; completion told once
STUB.Receive("LVLM", C.Encode("qo", { i = 101, o = "9/10,1/1" }), "GUILD", "Mario-Testrealm")
local shared = Q.Shared("Mario")
assert(#shared == 1 and shared[1].o == "9/10,1/1" and shared[1].title == "Quest 101", "stored")
STUB.Receive("LVLM", C.Encode("qo", { i = 101, o = "10/10,1/1" }), "GUILD", "Mario-Testrealm")
STUB.Receive("LVLM", C.Encode("qo", { i = 101, o = "10/10,1/1" }), "GUILD", "Mario-Testrealm")
local told = 0
for _, p in ipairs(STUB.printed) do if p:find(string.format(L.QUEST_DONE, "Mario", "Quest 101"), 1, true) then told = told + 1 end end
assert(told == 1, "completed: told once")
STUB.Receive("LVLM", C.Encode("qo", { i = 555, o = "1/1" }), "GUILD", "Mario-Testrealm")
assert(#Q.Shared("Mario") == 1, "a quest I do not have is not shown")
STUB.Receive("LVLM", C.Encode("qo", { i = 102, o = "1/3" }), "GUILD", "Nadie-Testrealm")
B.Toggle()
local row
for i = 1, #B.rows do if B.rows[i].name.text == "Mario" then row = B.rows[i] end end
row.button.scripts.OnEnter(row.button)
local tip = table.concat(GameTooltip.lines, "\n")
assert(tip:find(L.QUEST_SHARED, 1, true) and tip:find("Quest 101: 10/10, 1/1", 1, true), "in Mario's tooltip: " .. tip)
