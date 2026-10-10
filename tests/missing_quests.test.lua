STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local C, MC, L = ns.Comm, ns.MateCard, ns.L
local pushed
C_QuestLog.GetLogIndexForQuestID = function(id) for i, q in ipairs(STUB.quests) do if q == id then return i end end end
function QuestLogPushQuest(i) pushed = STUB.quests[i] end
local pushable = { [101] = true, [102] = true, [103] = false, [104] = true }
C_QuestLog.IsPushableQuest = function(id) return pushable[id] end
STUB.quests = { 101, 102, 103, 104 }
STUB.completed = { [104] = true }
STUB.Receive("LVLM", C.Encode("hb", { l = 20, z = 1421, c = "MAGE" }), "GUILD", "Mario-Testrealm")

-- not grouped: nothing about quests
assert(MC.MissingQuests("Mario") == nil and not table.concat(MC.Lines("Mario"), "\n"):find(L.CARD_NO_QUESTS, 1, true), "only in a group")
STUB.partyMembers = { Mario = true }
assert(table.concat(MC.Lines("Mario"), "\n"):find(L.CARD_NO_QUESTS, 1, true), "grouped, but he does not share his quests")

-- he shares them: mine that he lacks, that can be shared and are not done
STUB.Receive("LVLM", C.Encode("q", { i = "1/1", ids = "102" }), "GUILD", "Mario-Testrealm")
local missing = MC.MissingQuests("Mario")
assert(#missing == 1 and missing[1].id == 101 and missing[1].title == "Quest 101", "only 101: " .. #missing)
MC.Show("Mario")
assert(MC.questButtons[1]:IsShown() and MC.questButtons[1].text:find("Quest 101", 1, true) and not MC.questButtons[2]:IsShown(), "a Share button per quest")
MC.questButtons[1].scripts.OnClick(MC.questButtons[1])
assert(pushed == 101, "the game offers it to the group")
STUB.partyMembers = {}
MC.Refresh()
assert(not MC.questButtons[1]:IsShown(), "gone out of the group")
