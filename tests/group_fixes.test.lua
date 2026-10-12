local services, filterUnavailable, broken = { { name = "Blink", rank = "", type = "unavailable", level = 24 } }, false, false
function GetNumTrainerServices() return filterUnavailable and #services or 0 end
function GetTrainerServiceInfo(i) if broken then error("boom") end; local s = services[i]; return s.name, s.type, 1, s.level, s.rank end
function GetTrainerServiceTypeFilter(t) return filterUnavailable end
function SetTrainerServiceTypeFilter(t, on) filterUnavailable = on and true or false end
function IsTradeskillTrainer() return false end
local combat = false
function InCombatLockdown() return combat end
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local C, GX, MC, T, L = ns.Comm, ns.GroupXP, ns.MateCard, ns.Trainer, ns.L
local function count(kind, from) local n = 0; for i = (from or 0) + 1, #STUB.sent do if C.Decode(STUB.sent[i].msg) == kind then n = n + 1 end end; return n end

-- 1: a storm of roster updates with the same guildmates sends once
STUB.Receive("LVLM2", C.Encode("hb", { l = 21, z = 1421, c = "MAGE" }), "GUILD", "Mario-Testrealm")
STUB.Receive("LVLM2", C.Encode("hb", { l = 19, z = 1421, c = "PRIEST" }), "GUILD", "Ana-Testrealm")
STUB.Advance(3)   -- the login timers settle first
STUB.partyMembers = { Mario = true }
local n = #STUB.sent
for _ = 1, 10 do STUB.Fire("GROUP_ROSTER_UPDATE") end
STUB.Advance(3)
for _ = 1, 10 do STUB.Fire("GROUP_ROSTER_UPDATE"); STUB.Advance(0.5) end
STUB.Advance(3)
assert(count("xp", n) == 1, "one send for the same group: " .. count("xp", n))
STUB.partyMembers = { Mario = true, Ana = true }
STUB.Fire("GROUP_ROSTER_UPDATE"); STUB.Advance(3)
assert(count("xp", n) == 2, "a new guildmate in the group gets mine at once")

-- 2: in a dungeon the bars stay (paused), and leaving it sends at once
STUB.Receive("LVLM2", C.Encode("xp", { p = 80, l = 21 }), "GUILD", "Mario-Testrealm")
STUB.inInstance = true
STUB.Fire("PLAYER_ENTERING_WORLD", false, false)
STUB.Advance(400); GX.Refresh()
assert(GX.frame:IsShown() and #GX.Rows() >= 2, "still shown inside")
assert(GX.frame.title.text == L.GROUPXP_PAUSED, "marked as paused")
STUB.inInstance = false
n = #STUB.sent
STUB.Fire("PLAYER_ENTERING_WORLD", false, false); STUB.Advance(3)
STUB.Receive("LVLM2", C.Encode("hb", { l = 21, z = 1421, c = "MAGE" }), "GUILD", "Mario-Testrealm"); STUB.Advance(3)   -- he is back on the board
assert(count("xp", n) == 1, "out again: mine goes at once")
STUB.Receive("LVLM2", C.Encode("xp", { p = 82, l = 21 }), "GUILD", "Mario-Testrealm")
assert(GX.frame:IsShown() and GX.frame.title.text == L.GROUPXP_TITLE, "live again")

-- 3: share buttons stack from the bottom, whatever their number
C_QuestLog.GetLogIndexForQuestID = function() return 1 end
C_QuestLog.IsPushableQuest = function() return true end
STUB.quests = { 101 }
STUB.Receive("LVLM2", C.Encode("q", { i = "1/1", ids = "999" }), "GUILD", "Mario-Testrealm")
MC.Show("Mario")
assert(MC.questButtons[1]:IsShown() and MC.questButtons[1].point[3] == 40, "the only button sits right above the others: " .. tostring(MC.questButtons[1].point[3]))

-- 5: the trainer is read after Blizzard's own show, never in combat, and the filter always comes back
STUB.Fire("TRAINER_SHOW")
assert(#T.Pending() == 0, "not inside the show itself")
STUB.Advance(0.1)
assert(#T.Pending() == 1 and filterUnavailable == false, "read just after, filter restored")
combat = true
services[2] = { name = "Nova", rank = "", type = "unavailable", level = 26 }
STUB.Fire("TRAINER_SHOW"); STUB.Advance(0.1)
assert(#T.Pending() == 1, "not in combat")
combat, broken = false, true
STUB.Fire("TRAINER_SHOW"); STUB.Advance(0.1)
assert(filterUnavailable == false, "an error still puts the filter back")
