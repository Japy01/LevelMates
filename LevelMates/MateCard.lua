-- MateCard.lua: a guildmate's card, opened by a left click on their row: class, level, zone, build, professions,
-- wishes and giveaways, personal goal, their latest on the wall and the meetups they go to, with buttons to whisper,
-- invite, set a waypoint or view the build (each only from its click). Spec 2026-10-10-levelmates-class-tanda-design.
local _, ns = ...
local MC = {}
ns.MateCard = MC
local L, R = ns.L, ns.Roster

local function items(list, name)
	local out = {}
	for _, w in ipairs(list) do if w.name == name then out[#out + 1] = ns.Wishlist.Link(w.id) or ("#" .. w.id) end end
	return out
end

local function grouped(name) return UnitInParty(name) or UnitInRaid(name) end
MC.MAX_QUESTS = 5

-- In a group: my quests (not done, shareable) that they do not have; nil when not grouped or they do not share
-- their quests (the roster only knows quests of players who share them).
function MC.MissingQuests(name)
	local m = R.mates[name]
	if not (m and grouped(name) and m.questsKnown and m.quests) then return nil end
	local out = {}
	for id in pairs(R.MyQuests()) do
		if not m.quests[id] and C_QuestLog.IsPushableQuest and C_QuestLog.IsPushableQuest(id) then
			out[#out + 1] = { id = id, title = C_QuestLog.GetTitleForQuestID(id) or ("#" .. id) }
		end
	end
	table.sort(out, function(a, b) return a.title < b.title end)
	while #out > MC.MAX_QUESTS do table.remove(out) end
	return out
end

-- The card's text, one line per thing known about them.
function MC.Lines(name)
	local m, lines = R.mates[name], {}
	if name == UnitName("player") and ns.Alts then   -- my own card: my characters in this guild
		lines[#lines + 1] = L.CARD_MY_CHARS
		local all = ns.Alts.MyAlts()
		local here = ns.Alts.Chars()[ns.PlayerKey()]
		if here then table.insert(all, 1, here) end
		for _, c in ipairs(all) do
			local class = c.class and (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[c.class] or c.class) or "?"
			local profs = {}
			for _, p in ipairs(c.profs or {}) do profs[#profs + 1] = ns.Professions.Name(p.id) .. " " .. p.rank end
			lines[#lines + 1] = string.format(L.CARD_CHAR, c.name, c.level or 0, class) .. (#profs > 0 and (" · " .. table.concat(profs, ", ")) or "")
		end
		return lines
	end
	if m then
		local class = m.class and (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[m.class] or m.class) or "?"
		local info = m.mapId and C_Map.GetMapInfo(m.mapId)
		local state = m.inGroup and (m.hasSlot and L.GROUP_FREE or L.GROUP_FULL) or L.SOLO
		lines[#lines + 1] = string.format(L.CARD_BASICS, class, m.level or 0, info and info.name or "?", state)
	end
	local achs = ns.Achievements and ns.Achievements.Of(name) or {}
	if #achs > 0 then
		local icons = {}
		for i = math.max(1, #achs - 2), #achs do icons[#icons + 1] = ns.Achievements.Link(achs[i]) end
		lines[#lines + 1] = string.format(L.CARD_ACH, #achs) .. "  " .. table.concat(icons, "  ")
	end
	local alts = ns.Alts and ns.Alts.Of(name) or {}
	if #alts > 0 then lines[#lines + 1] = string.format(L.CARD_ALTS, table.concat(alts, ", ")) end
	local b = ns.Builds.Of(name)
	if b then lines[#lines + 1] = string.format(L.CARD_BUILD, ns.Builds.PointsText(b)) end
	local profs = {}
	for _, c in ipairs(ns.Professions.List()) do if c.name == name then profs[#profs + 1] = ns.Professions.Name(c.id) .. " " .. c.rank end end
	if #profs > 0 then lines[#lines + 1] = string.format(L.CARD_PROFS, table.concat(profs, ", ")) end
	local wants, gives = items(ns.Wishlist.List(), name), items(ns.Gifts.List(), name)
	if #wants > 0 then lines[#lines + 1] = string.format(L.CARD_WANTS, table.concat(wants, " ")) end
	if #gives > 0 then lines[#lines + 1] = string.format(L.CARD_GIVES, table.concat(gives, " ")) end
	for _, p in ipairs(ns.Personal.List()) do
		if p.name == name then lines[#lines + 1] = string.format(L.CARD_GOAL, ns.Personal.Text(p), ns.Personal.ProgressText(p)) end
	end
	for _, e in ipairs(ns.Feed.List()) do
		if e.who == name then lines[#lines + 1] = string.format(L.CARD_WALL, ns.Feed.Text(e), ns.Feed.Ago(e)); break end
	end
	for _, mt in ipairs(ns.Meetups.List()) do
		if mt.by == name or (mt.joined and mt.joined[name]) then
			lines[#lines + 1] = string.format(L.CARD_MEETUP, ns.Dungeons.Name(mt.d), ns.Meetups.When(mt))
		end
	end
	if m and grouped(name) then
		local missing = MC.MissingQuests(name)
		if not missing then lines[#lines + 1] = L.CARD_NO_QUESTS
		elseif #missing > 0 then lines[#lines + 1] = L.CARD_MISSING end
	end
	return lines
end

local function Build()
	local f = ns.Skin.Window("LevelMatesMateCard", UIParent)
	MC.frame = f
	f:SetSize(380, 260); f:SetPoint("CENTER", 220, 0); f:SetFrameStrata("DIALOG")
	f:SetMovable(true); f:EnableMouse(true); f:SetClampedToScreen(true); f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", f.StartMoving); f:SetScript("OnDragStop", f.StopMovingOrSizing)
	tinsert(UISpecialFrames, "LevelMatesMateCard")
	local body = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	body:SetPoint("TOPLEFT", 16, -34); body:SetWidth(348); body:SetJustifyH("LEFT"); body:SetJustifyV("TOP"); body:SetWordWrap(true)
	f.body = body
	local function Btn(text, x, fn)
		local b = ns.Skin.Button(f)
		b:SetSize(84, 22); b:SetPoint("BOTTOMLEFT", x, 12); b:SetText(text)
		b:SetScript("OnClick", fn)
		return b
	end
	MC.whisper = Btn(L.MENU_WHISPER, 12, function() ns.Board.Whisper(MC.name) end)
	MC.invite = Btn(L.MENU_INVITE, 100, function() ns.Board.Invite(MC.name) end)
	MC.waypoint = Btn(L.CARD_WAYPOINT, 188, function()
		local m = R.mates[MC.name]
		if m and m.x and m.y and m.mapId then ns.Help.WaypointTo(m.mapId, m.x, m.y) end
	end)
	MC.build = Btn(L.CLASS_VIEW_BUILD, 276, function() ns.Builds.Open(ns.Builds.Of(MC.name)) end)
	MC.questButtons = {}
	for i = 1, MC.MAX_QUESTS do
		local b = ns.Skin.Button(f)
		b:SetSize(348, 22); b:SetPoint("BOTTOMLEFT", 16, 40 + (MC.MAX_QUESTS - i) * 24)
		b:SetScript("OnClick", function(self)   -- the game's own quest share, offered to the group, from this click only
			local index = self.questId and C_QuestLog.GetLogIndexForQuestID and C_QuestLog.GetLogIndexForQuestID(self.questId)
			if index then QuestLogPushQuest(index) end
		end)
		b:Hide()
		MC.questButtons[i] = b
	end
	f:Hide()
end

function MC.Refresh()
	if not (MC.frame and MC.frame:IsShown() and MC.name) then return end
	local name, m = MC.name, R.mates[MC.name]
	local mine = name == UnitName("player")
	MC.whisper:SetShown(not mine); MC.invite:SetShown(not mine)
	local fs = MC.frame.TitleContainer and MC.frame.TitleContainer.TitleText or MC.frame.TitleText
	if fs then fs:SetText(name) end
	MC.frame.body:SetText(table.concat(MC.Lines(name), "\n"))
	MC.waypoint:SetShown(m and m.x and m.y and m.mapId and true or false)
	local b = ns.Builds.Of(name)
	MC.build:SetShown(b and b.b and true or false)
	local missing = MC.MissingQuests(name) or {}
	for i, qb in ipairs(MC.questButtons) do
		local q = missing[i]
		qb.questId = q and q.id
		if q then
			qb:SetText(string.format(L.CARD_SHARE_QUEST, q.title)); qb:Show()
			qb:ClearAllPoints(); qb:SetPoint("BOTTOMLEFT", 16, 40 + (#missing - i) * 24)   -- stacked right above the action buttons
		else qb:Hide() end
	end
	-- room for the text as written (wrapped lines too), the quest buttons and the action row, no more
	local textH = MC.frame.body.GetStringHeight and MC.frame.body:GetStringHeight() or #MC.Lines(name) * 16
	MC.frame:SetHeight(math.max(160, 34 + textH + 16 + #missing * 24 + 40))
	ns.Skin.InkWindow(MC.frame)
end

function MC.Show(name)
	if not MC.frame then Build() end
	MC.name = name
	MC.frame:Show()
	MC.Refresh()
end

ns.On("LM_ROW_CLICK", MC.Show)
for _, e in ipairs({ "LM_ALTS_CHANGED", "LM_MATE_QUESTS", "LM_ROSTER_CHANGED", "LM_BUILDS_CHANGED", "LM_PROFESSIONS_CHANGED", "LM_WISHES_CHANGED", "LM_FEED_CHANGED", "LM_MEETUPS_CHANGED", "LM_GOALS_CHANGED" }) do ns.On(e, MC.Refresh) end
