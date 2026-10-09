-- Match.lua: quest matching between me and guildmates on my map. Notices only; nothing is sent from here.
local _, ns = ...
local M = {}
ns.Match = M
local L, R = ns.L, ns.Roster

function M.ForQuest(questID)
	local myMap = C_Map.GetBestMapForUnit("player")
	local out = { has = {}, needs = {} }
	for name, m in pairs(R.mates) do
		if m.mapId == myMap then
			if m.quests[questID] then
				out.has[#out.has + 1] = name
			elseif next(m.quests) ~= nil and ns.Questie and ns.Questie.CanTake(questID, m.level) == true then
				out.needs[#out.needs + 1] = name   -- shares quests, lacks this one, and could take it (Questie)
			end
		end
	end
	table.sort(out.has); table.sort(out.needs)
	return out
end

-- mates on my map who do not have a quest I can share (for "still needs")
function M.WhoNeeds(questID)
	local myMap = C_Map.GetBestMapForUnit("player")
	local out = {}
	for name, m in pairs(R.mates) do
		if m.mapId == myMap and next(m.quests) ~= nil and not m.quests[questID] then out[#out + 1] = name end
	end
	table.sort(out)
	return out
end

function M.Notice(fmt, ...)
	ns.Say(fmt, ...)
	if ns.db.settings.sound and PlaySound then PlaySound(SOUNDKIT and SOUNDKIT.IG_QUEST_LOG_OPEN or 844) end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("QUEST_ACCEPTED")
ev:SetScript("OnEvent", function(_, _, questID)
	if not ns.db.settings.matchNotices or type(questID) ~= "number" then return end
	local title = C_QuestLog.GetTitleForQuestID(questID) or tostring(questID)
	local m = M.ForQuest(questID)
	for _, name in ipairs(m.has) do M.Notice(L.MATCH_HAS, name, title) end
	for i, name in ipairs(m.needs) do
		if i > 3 then break end   -- a crowded zone must not flood the chat
		M.Notice(L.MATCH_CAN, name, title)
	end
	ns.Fire("LM_MATCH", questID, m.has)
end)

ns.On("LM_MATE_QUESTS", function(name)
	if not ns.db.settings.matchNotices then return end
	local mine = R.MyQuests()
	local mate = R.mates[name]
	local myMap = C_Map.GetBestMapForUnit("player")
	if not mate or mate.mapId ~= myMap then return end
	for id in pairs(mine) do
		if mate.quests[id] then M.Notice(L.MATCH_HAS, name, C_QuestLog.GetTitleForQuestID(id) or tostring(id)); return end
	end
end)
