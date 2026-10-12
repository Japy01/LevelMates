-- Alt+click a quest in the log: post or withdraw it; both logs hooked, one click toggles once
local mapClicks, logClicks = 0, 0
function QuestMapLogTitleButton_OnClick(self, button) mapClicks = mapClicks + 1 end
function QuestLogTitleButton_OnClick(self, button) logClicks = logClicks + 1 end
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(30)
local QH, C = ns.Questhub, ns.Comm
STUB.quests = { 101, 202 }
local alt = true
IsAltKeyDown = function() return alt end
local function posts() local n = 0; for _, s in ipairs(STUB.sent) do if (C.Decode(s.msg)) == "qh" then n = n + 1 end end; return n end
QuestMapLogTitleButton_OnClick({ questID = 101 }, "LeftButton")
assert(mapClicks == 1 and QH.MineFor(101) and posts() == 1, "Alt+click posts")
QuestLogTitleButton_OnClick({ questLogIndex = 1, GetID = function() return 1 end }, "LeftButton")
assert(QH.MineFor(101), "the other log for the same quest within half a second: no second toggle")
STUB.Advance(1)
QuestLogTitleButton_OnClick({ GetID = function() return 1 end }, "LeftButton")
assert(not QH.MineFor(101), "Alt+click again withdraws")
alt = false
QuestMapLogTitleButton_OnClick({ questID = 202 }, "LeftButton")
assert(not QH.MineFor(202), "no Alt: nothing")
