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
	ns.Fire("LM_JOURNAL_ADDED", e)
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
	if sec >= 86400 then return string.format(L.J_DUR_DH, math.floor(sec / 86400), math.floor(sec % 86400 / 3600)) end
	local h, m = math.floor(sec / 3600), math.floor(sec % 3600 / 60)
	if h > 0 then return string.format(L.J_DUR_HM, h, m) end
	return string.format(L.J_DUR_M, m)
end

-- Pace from the levels with a recorded time: the average of the last five, the fastest, and a rough time to 60.
J.PACE_MAX = 8 * 3600
function J.Pace()
	local times = {}
	-- newest first; a level that spans hours or days offline says nothing about the pace
	for _, e in ipairs(J.List("level", "")) do if e.took and e.took <= J.PACE_MAX and not e.sim then times[#times + 1] = e end end
	if #times < 2 then return nil end
	local n, sum = math.min(5, #times), 0
	for i = 1, n do sum = sum + times[i].took end
	local fastest = times[1]
	for _, e in ipairs(times) do if e.took < fastest.took then fastest = e end end
	local avg, left = sum / n, math.max(0, 60 - UnitLevel("player"))
	return { avg = avg, fastest = fastest.level, fastestTook = fastest.took, toMax = left > 0 and avg * left or nil }
end
function J.PaceText()
	local p = J.Pace()
	if not p then return nil end
	local text = string.format(L.PACE, J.Duration(p.avg), p.fastest, J.Duration(p.fastestTook))
	if p.toMax then text = text .. string.format(L.PACE_TO_MAX, J.Duration(p.toMax)) end
	return text
end

function J.Text(e)
	if e.k == "level" then
		return string.format(L.J_LEVEL, e.level) .. ((e.took and e.from) and string.format(L.J_TOOK, J.Duration(e.took), e.from) or "")
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
		-- time per level only between consecutive recorded levels (levels gained with the addon off break the chain)
		local prev = lastLevelEntry()
		local consecutive = prev and prev.level == a1 - 1
		J.Add("level", { level = a1, from = consecutive and prev.level or nil, took = consecutive and (time() - prev.t) or nil })
	elseif event == "QUEST_TURNED_IN" then
		J.Add("quest", { id = a1, name = C_QuestLog.GetTitleForQuestID(a1) or ("#" .. tostring(a1)) })
	elseif event == "PLAYER_DEAD" then
		J.Add("death", { level = UnitLevel("player") })
	end
end)

ns.On("LM_LOADED", function() entries() end)

-- Recorders: groups with guildmates (once per person per session; a /reload is the same session, so the set is saved
-- and only wiped at a real login).
local function grouped()
	ns.char.journalGrouped = ns.char.journalGrouped or {}
	return ns.char.journalGrouped
end
local function inMyGroup(name) return UnitInParty(name) or UnitInRaid(name) end
local function guildmatesInGroup()
	local out = {}
	for name in pairs(R.mates) do if inMyGroup(name) then out[#out + 1] = name end end
	table.sort(out)
	return out
end

-- Dungeons: once per entry into a party instance; the key survives loading screens and /reload.
local function checkInstance()
	local inside, itype = IsInInstance()
	if inside and itype == "party" then
		local name, _, _, _, _, _, _, id = GetInstanceInfo()
		local key = tostring(id and id ~= 0 and id or name)
		if ns.char.journalInstance ~= key then
			ns.char.journalInstance = key
			J.Add("dungeon", { name = name, mates = guildmatesInGroup() })
		end
	elseif not inside then
		ns.char.journalInstance = nil
	end
end

-- Items: mine only (guid, or the sender name when the guid is empty), uncommon or better.
local COLOR_QUALITY = { ["9d9d9d"] = 0, ["ffffff"] = 1, ["1eff00"] = 2, ["0070dd"] = 3, ["a335ee"] = 4, ["ff8000"] = 5, ["e6cc80"] = 6 }
local function quality(link)
	local q = C_Item and C_Item.GetItemQualityByID and C_Item.GetItemQualityByID(link)
	if q then return q end
	local named = link:match("^|cnIQ(%d):")   -- the client's named quality colours
	if named then return tonumber(named) end
	local hex = link:match("^|c%x%x(%x%x%x%x%x%x)")
	return hex and COLOR_QUALITY[hex:lower()]
end
local function isMine(guid, sender)
	if guid and guid ~= "" then return guid == UnitGUID("player") end
	return sender ~= nil and sender ~= "" and ns.ShortName(sender) == ns.Me()
end

-- Professions: the twelve profession skill IDs (locale-independent).
local PROFESSIONS = { [171] = true, [164] = true, [333] = true, [202] = true, [182] = true, [165] = true,
	[186] = true, [393] = true, [197] = true, [129] = true, [185] = true, [356] = true }
-- The skills window can collapse headers, which removes their lines from the enumeration: look professions up by ID
-- when the client can; otherwise treat lines hidden under a collapsed header as unknown (kept), never as unlearned.
local function readProfessions(before)
	local n = C_SkillInfo and C_SkillInfo.GetNumSkillLines() or 0
	if n == 0 then return nil end   -- not loaded yet
	local out = {}
	if C_SkillInfo.GetSkillLineInfoByID then
		for id in pairs(PROFESSIONS) do
			local s = C_SkillInfo.GetSkillLineInfoByID(id)
			if s and s.name and s.name ~= "" and (s.rank or 0) > 0 then out[id] = { name = s.name, rank = s.rank, max = s.maxRank } end
		end
		return out
	end
	local collapsed = false
	for i = 1, n do
		local s = C_SkillInfo.GetSkillLineInfo(i)
		if s and s.isHeader and s.isCollapsed then collapsed = true end
		if s and not s.isHeader and PROFESSIONS[s.skillID] then out[s.skillID] = { name = s.name, rank = s.rank, max = s.maxRank } end
	end
	if collapsed and before then
		for id, old in pairs(before) do if not out[id] then out[id] = old end end
	end
	return out
end
local function checkSkills()
	local before = ns.char.skills
	local now = readProfessions(before)
	if not now then return end
	ns.char.skills = now
	ns.Fire("LM_SKILLS_CHANGED")
	if not before then return end   -- first readable sight: snapshot only
	for id, s in pairs(now) do
		local old = before[id]
		if not old then
			J.Add("skill", { name = s.name, learned = true, rank = s.rank })
		elseif math.floor(s.rank / 25) > math.floor(old.rank / 25) then
			J.Add("skill", { name = s.name, rank = math.floor(s.rank / 25) * 25 })
		end
	end
end

local ev2 = CreateFrame("Frame")
ev2:RegisterEvent("GROUP_ROSTER_UPDATE"); ev2:RegisterEvent("ZONE_CHANGED_NEW_AREA")
ev2:RegisterEvent("CHAT_MSG_LOOT"); ev2:RegisterEvent("SKILL_LINES_CHANGED")
ev2:SetScript("OnEvent", function(_, event, ...)
	if event == "GROUP_ROSTER_UPDATE" then
		local seen = grouped()
		for _, name in ipairs(guildmatesInGroup()) do
			if not seen[name] then seen[name] = true; J.Add("group", { name = name }) end
		end
	elseif event == "ZONE_CHANGED_NEW_AREA" then
		checkInstance()
	elseif event == "CHAT_MSG_LOOT" then
		local text, sender = ...
		local guid = select(12, ...)
		-- during encounters the client hands out protected values: touching them errors, so skip the line
		if issecretvalue and (issecretvalue(text) or issecretvalue(sender) or issecretvalue(guid)) then return end
		if type(text) ~= "string" or not isMine(guid, sender) then return end
		local link = text:match("|c[^|]-|Hitem:.-|h.-|h|r")   -- "|cffRRGGBB" or a named colour ("|cnIQ3:")
		if link then ns.Fire("LM_MY_LOOT", link) end   -- any item I loot (the wishlist listens)
		local q = link and quality(link)
		if q and q >= 2 then J.Add("item", { link = link, q = q }) end
	elseif event == "SKILL_LINES_CHANGED" then
		checkSkills()
	end
end)
ns.On("LM_WORLD", function(isInitial)
	if isInitial then wipe(grouped()) end   -- a new session: groups can be recorded again
	checkInstance(); checkSkills()
end)

-- "Clear journal" (board button): confirm first.
ns.On("LM_JOURNAL_CLEAR", function()
	StaticPopupDialogs["LEVELMATES_JOURNAL_CLEAR"] = StaticPopupDialogs["LEVELMATES_JOURNAL_CLEAR"] or {
		text = L.J_CLEAR_CONFIRM, button1 = YES or OKAY, button2 = NO or CANCEL,
		timeout = 0, whileDead = true, hideOnEscape = true,
		OnAccept = function() J.Clear() end,
	}
	StaticPopup_Show("LEVELMATES_JOURNAL_CLEAR")
end)
