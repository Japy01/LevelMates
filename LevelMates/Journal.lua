-- Journal.lua: a local, per-character record of the leveling journey. Never sends anything.
-- Spec 2026-10-09-levelmates-journal-design.
local _, ns = ...
local J = {}
ns.Journal = J
local L, R = ns.L, ns.Roster
J.KINDS = { "level", "quest", "dungeon", "group", "item", "skill", "death" }
J.FILTERS = { "all", "level", "quest", "dungeon", "group", "item", "skill", "death" }
J.MAX = 1000
local COLORS = {
	level = { 1, 0.82, 0 }, quest = { 1, 1, 1 }, dungeon = { 0.6, 0.8, 1 }, group = { 0.4, 1, 0.4 },
	item = { 1, 1, 1 }, skill = { 1, 0.7, 0.3 }, death = { 1, 0.4, 0.4 },
}

local function entries()
	ns.char.journal = ns.char.journal or {}
	return ns.char.journal
end

function J.Add(kind, data)
	local e = { k = kind, t = time(), zone = GetRealZoneText() }
	for key, value in pairs(data or {}) do e[key] = value end
	local list = entries()
	list[#list + 1] = e
	while #list > J.MAX do table.remove(list, 1) end   -- oldest first: drop from the front
	ns.Fire("LM_JOURNAL_CHANGED")
	return e
end

function J.Count() return #entries() end

function J.Clear() wipe(entries()); ns.Fire("LM_JOURNAL_CHANGED") end

function J.RemoveWhere(fn)
	local list = entries()
	for i = #list, 1, -1 do if fn(list[i]) then table.remove(list, i) end end
	ns.Fire("LM_JOURNAL_CHANGED")
end

function J.Duration(sec)
	if sec < 60 then return L.J_DUR_LT end
	local h, m = math.floor(sec / 3600), math.floor(sec % 3600 / 60)
	if h > 0 then return string.format(L.J_DUR_HM, h, m) end
	return string.format(L.J_DUR_M, m)
end

function J.Text(e)
	if e.k == "level" then
		return string.format(L.J_LEVEL, e.level) .. (e.took and string.format(L.J_TOOK, J.Duration(e.took), e.level - 1) or "")
	elseif e.k == "quest" then return string.format(L.J_QUEST, e.name)
	elseif e.k == "dungeon" then
		return string.format(L.J_DUNGEON, e.name) .. ((e.mates and #e.mates > 0) and string.format(L.J_WITH, table.concat(e.mates, ", ")) or "")
	elseif e.k == "group" then return string.format(L.J_GROUP, e.name)
	elseif e.k == "item" then return string.format(L.J_ITEM, e.link)
	elseif e.k == "skill" then
		if e.learned then return string.format(L.J_SKILL_NEW, e.name) end
		return string.format(L.J_SKILL_UP, e.name, e.rank)
	elseif e.k == "death" then return string.format(L.J_DEATH, e.level)
	end
	return ""
end

function J.Color(e) return COLORS[e.k] or { 1, 1, 1 } end
function J.When(e) return date("%d/%m %H:%M", e.t) end
function J.FilterName(kind) return L["J_FILTER_" .. string.upper(kind)] end

-- Newest first; filter by kind ("all" for every kind) and by plain text in the entry or its zone.
function J.List(filter, search)
	local out, q = {}, (search or ""):lower()
	local list = entries()
	for i = #list, 1, -1 do
		local e = list[i]
		if (filter == nil or filter == "all" or e.k == filter)
			and (q == "" or (J.Text(e) .. " " .. (e.zone or "")):lower():find(q, 1, true)) then
			out[#out + 1] = e
		end
	end
	return out
end

-- Recorders: level, quest, death.
local function lastLevelEntry()
	local list = entries()
	for i = #list, 1, -1 do if list[i].k == "level" then return list[i] end end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LEVEL_UP"); ev:RegisterEvent("QUEST_TURNED_IN"); ev:RegisterEvent("PLAYER_DEAD")
ev:SetScript("OnEvent", function(_, event, a1)
	if event == "PLAYER_LEVEL_UP" then
		local prev = lastLevelEntry()
		J.Add("level", { level = a1, took = prev and (time() - prev.t) or nil })
	elseif event == "QUEST_TURNED_IN" then
		J.Add("quest", { id = a1, name = C_QuestLog.GetTitleForQuestID(a1) or ("#" .. tostring(a1)) })
	elseif event == "PLAYER_DEAD" then
		J.Add("death", { level = UnitLevel("player") })
	end
end)

ns.On("LM_LOADED", function() entries() end)
