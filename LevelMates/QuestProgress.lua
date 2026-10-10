-- QuestProgress.lua: while grouped with guildmates, my progress on the quests we share goes out (`qo`) when it
-- changes; theirs shows in their tooltip, and a guildmate completing a shared quest is told once.
-- Spec 2026-10-10-levelmates-social-leveling-design (B2).
local _, ns = ...
local Q = {}
ns.QuestProgress = Q
local L, C, R = ns.L, ns.Comm, ns.Roster
local sent, told = {}, {}

-- "6/10,1/1": each objective as have/need (an objective without a count is 0/1 or 1/1).
function Q.Objectives(id)
	local objs = C_QuestLog.GetQuestObjectives and C_QuestLog.GetQuestObjectives(id)
	if not objs or #objs == 0 then return nil end
	local parts = {}
	for _, o in ipairs(objs) do
		local need = (o.numRequired or 0) > 0 and o.numRequired or 1
		local have = o.finished and need or math.min(need, o.numFulfilled or 0)
		parts[#parts + 1] = have .. "/" .. need
	end
	return table.concat(parts, ",")
end

-- My quests, complete ones included (the last "10/10" matters too).
local function myQuests()
	local set = {}
	for i = 1, C_QuestLog.GetNumQuestLogEntries() do
		local info = C_QuestLog.GetInfo(i)
		if info and not info.isHeader and info.questID then set[info.questID] = true end
	end
	return set
end
local function grouped(name) return UnitInParty(name) or UnitInRaid(name) end

function Q.SendChanged()
	if not ns.db.settings.shareQuests then return end   -- quest ids go out only for players who share their quests
	local mine, shared = myQuests(), {}
	for name, m in pairs(R.mates) do
		if grouped(name) then for id in pairs(m.quests or {}) do if mine[id] then shared[id] = true end end end
	end
	for id in pairs(shared) do
		local o = Q.Objectives(id)
		if o and #o <= 60 and o ~= sent[id] and C.Send("qo", { i = id, o = o }) then sent[id] = o end
	end
end

local pending = false
local function soon()
	if pending then return end
	pending = true
	C_Timer.After(2, function() pending = false; Q.SendChanged() end)
end

local function complete(o)
	if not o then return false end
	for have, need in o:gmatch("(%d+)/(%d+)") do if tonumber(have) < tonumber(need) then return false end end
	return true
end

C.OnMessage("qo", function(f, name)
	local m = R.mates[name]
	if not m or not grouped(name) then return end   -- my group's progress only
	m.progress = m.progress or {}
	local before = m.progress[f.i]
	m.progress[f.i] = f.o
	if before and complete(f.o) and not complete(before) and myQuests()[f.i] and not told[name .. ":" .. f.i] and ns.db.settings.matchNotices then
		told[name .. ":" .. f.i] = true
		ns.Notice(L.QUEST_DONE, name, C_QuestLog.GetTitleForQuestID(f.i) or ("#" .. f.i))
	end
end)

-- Rows for a guildmate's tooltip: the shared quests with their progress.
function Q.Shared(name)
	local m, out, mine = R.mates[name], {}, myQuests()
	for id, o in pairs(m and m.progress or {}) do
		if mine[id] then out[#out + 1] = { id = id, o = o, title = C_QuestLog.GetTitleForQuestID(id) or ("#" .. id) } end
	end
	table.sort(out, function(a, b) return a.title < b.title end)
	return out
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("QUEST_LOG_UPDATE"); ev:RegisterEvent("GROUP_ROSTER_UPDATE")
ev:SetScript("OnEvent", function(_, event)
	if event == "GROUP_ROSTER_UPDATE" and not IsInGroup() then wipe(sent) end   -- a new group hears everything again
	soon()
end)
-- A groupmate's quest list (a login, a /reload): what we share goes to them again.
ns.On("LM_MATE_QUESTS", function(name)
	local m = R.mates[name]
	if m and grouped(name) then for id in pairs(m.quests or {}) do sent[id] = nil end end
	soon()
end)
