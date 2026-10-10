-- Board.lua: the guildmates window. Reads ns.Roster; every action on a mate runs from a click.
local _, ns = ...
local B = {}
ns.Board = B
local L, R = ns.L, ns.Roster
local ROWS, ROW_H, HELP_ROWS, MIN_ROWS = 20, 20, 3, 8
B.ROWS, B.ROW_H, B.MIN_ROWS = ROWS, ROW_H, MIN_ROWS
B.tab = "mates"
local unpack = unpack or table.unpack   -- the client has unpack; table.unpack covers other Lua versions

-- Layout: one place for the widths so the columns always fit inside the window.
B.COLS = { 150, 50, 180, 70, 70 }   -- name, level, zone, group, xp/h
B.GAP, B.MARGIN, B.WIDTH = 4, 12, 600
B.JCOLS = { 100, 1, 315, 1, 103 }   -- journal: when, -, entry, -, zone (same total as B.COLS)
B.GCOLS = { 100, 1, 284, 70, 65 }   -- goals: by, -, goal, progress, until (same total as B.COLS)
B.WCOLS = { 100, 1, 344, 1, 74 }   -- wishes: who, -, item, -, since (same total as B.COLS)
B.CCOLS = { 150, 1, 239, 60, 70 }   -- professions: who, -, profession, rank, online or last seen (same total as B.COLS)
B.CARD_COLS, B.CARD_GAP, B.CARD_H, B.ART_H = 4, 6, 100, 50   -- dungeon cards (room for two-line names)
-- Tabs, in order; each key's label is L[TAB_LABELS[key]].
B.TAB_KEYS = { "mates", "lfg", "journal", "goals", "wishes", "crafts" }
local TAB_LABELS = { mates = "TAB_MATES", lfg = "TAB_LFG", journal = "TAB_JOURNAL", goals = "TAB_GOALS", wishes = "TAB_WISHES", crafts = "TAB_CRAFTS" }
B.TAB_LABELS = TAB_LABELS
local HEAD_KEY = { mates = "MATES", lfg = "LFG", journal = "JOURNAL", goals = "GOALS", wishes = "WISHES", crafts = "CRAFTS" }
local function KnownTab(key) for _, k in ipairs(B.TAB_KEYS) do if k == key then return key end end; return "mates" end
B.TOP = 84                                  -- y of the column headers: heading, subtitle and divider sit above
B.BOTTOM = 26                               -- height of the strip under the inset, where the buttons live
B.CHROME = B.TOP + ROW_H + B.BOTTOM + 10       -- window height without the mate and help rows (recomputed from the inset in Build)
local ROW_W = B.COLS[1] + B.COLS[2] + B.COLS[3] + B.COLS[4] + B.COLS[5] + 4 * B.GAP

-- Colour coding: group state and how close a mate is to my level.
B.GROUP_COLORS = { open = { 0.35, 0.9, 0.35 }, full = { 0.95, 0.35, 0.35 }, solo = { 0.7, 0.7, 0.7 } }
B.LEVEL_COLORS = { near = { 0.4, 1, 0.4 }, far = { 0.75, 0.75, 0.75 } }

-- Class icon: Forever draws them from atlases ("classicon-<class>", as its character screen does); the older
-- circles sheet with CLASS_ICON_TCOORDS is the fallback when the client has no such atlas.
local function SetClassIcon(tex, class)
	if not class then tex:Hide(); return end
	local atlas = "classicon-" .. class:lower()
	if C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(atlas) then
		tex:SetAtlas(atlas); tex:Show(); return
	end
	local coords = CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[class]
	if coords then
		tex:SetTexture("Interface/TargetingFrame/UI-Classes-Circles")
		tex:SetTexCoord(unpack(coords)); tex:Show()
	else
		tex:Hide()
	end
end

local function ClassColor(class)
	local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
	if c then return c.r, c.g, c.b end
	return 1, 1, 1
end

local function Build()
	-- The journal-style frame (gold border, dark inset) when the client has it; the basic frame otherwise.
	local f
	if ButtonFrameTemplate_HidePortrait then
		local ok, frame = pcall(CreateFrame, "Frame", "LevelMatesBoard", UIParent, "ButtonFrameTemplate")
		if ok and frame then
			f = frame
			ButtonFrameTemplate_HidePortrait(f)
			if ButtonFrameTemplate_HideAttic then ButtonFrameTemplate_HideAttic(f) end   -- the template reserves an empty 60px band above the inset
		end
	end
	f = f or CreateFrame("Frame", "LevelMatesBoard", UIParent, "BasicFrameTemplateWithInset")
	B.frame = f
	-- Lay the content out from the inset's real anchors, so it sits inside the dark recess whatever the template does.
	local insetTop, insetBottom = 24, 26
	if f.Inset and f.Inset.GetPoint then
		local _, _, _, _, y1 = f.Inset:GetPoint(1)
		local _, _, _, _, y2 = f.Inset:GetPoint(2)
		if type(y1) == "number" and y1 < 0 then insetTop = -y1 end
		if type(y2) == "number" and y2 > 0 then insetBottom = y2 end
	end
	B.TOP, B.BOTTOM = insetTop + 60, insetBottom
	B.CHROME = B.TOP + ROW_H + B.BOTTOM + 10
	f:SetSize(B.WIDTH, B.CHROME + (ROWS + HELP_ROWS) * ROW_H)   -- room for the last mate row above the help rows
	f:SetMovable(true); f:EnableMouse(true); f:SetClampedToScreen(true); f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", f.StartMoving)
	f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing(); local p, _, rp, x, y = self:GetPoint(); ns.char.board = { p, rp, x, y } end)
	local saved = ns.char.board
	if saved then f:SetPoint(saved[1], UIParent, saved[2], saved[3], saved[4]) else f:SetPoint("CENTER") end
	B.SetTitle(B.TitleString())
	tinsert(UISpecialFrames, "LevelMatesBoard")
	f:Hide()

	-- Heading, subtitle, divider and the name search, in the style of the dungeon journal.
	B.heading = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	B.heading:SetPoint("TOPLEFT", B.MARGIN, -(insetTop + 10)); B.heading:SetText(L.BOARD_HEADING); B.heading:SetJustifyH("LEFT")
	B.restedText = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")   -- my rested XP, next to the heading
	B.restedText:SetPoint("LEFT", B.heading, "RIGHT", 12, 0); B.restedText:SetTextColor(0.6, 0.8, 1)
	B.subtitle = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	B.subtitle:SetPoint("TOPLEFT", B.MARGIN, -(insetTop + 34)); B.subtitle:SetText(L.BOARD_SUBTITLE); B.subtitle:SetJustifyH("LEFT"); B.subtitle:SetTextColor(0.7, 0.7, 0.7)
	local divider = f:CreateTexture(nil, "ARTWORK")
	divider:SetColorTexture(1, 0.82, 0, 0.35); divider:SetHeight(1)
	divider:SetPoint("TOPLEFT", B.MARGIN, -(B.TOP - 8)); divider:SetPoint("TOPRIGHT", -B.MARGIN, -(B.TOP - 8))
	local search = CreateFrame("EditBox", nil, f, "SearchBoxTemplate")
	search:SetSize(150, 20); search:SetPoint("TOPRIGHT", -B.MARGIN - 6, -(insetTop + 12))
	if search.Instructions then search.Instructions:SetText(L.SEARCH_HINT) end
	search:SetScript("OnTextChanged", function(self) B.search = self:GetText() or ""; B.Refresh() end)
	-- "Discord": the current tab as text to paste in Discord (every tab).
	local discord = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
	discord:SetSize(80, 20); discord:SetPoint("RIGHT", search, "LEFT", -12, 0); discord:SetText(L.BTN_DISCORD)
	discord:SetScript("OnClick", function() ns.Fire("LM_DISCORD_COPY", B.tab) end)
	B.discordButton = discord
	B.searchBox = search

	local function Col(parent, w, justify, font) local fs = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlight"); fs:SetWidth(w); fs:SetJustifyH(justify or "LEFT"); fs:SetWordWrap(false); return fs end
	local HN = "GameFontNormal"
	local head = { Col(f, B.COLS[1], nil, HN), Col(f, B.COLS[2], "CENTER", HN), Col(f, B.COLS[3], nil, HN), Col(f, B.COLS[4], "CENTER", HN), Col(f, B.COLS[5], "RIGHT", HN) }
	head[1]:SetPoint("TOPLEFT", B.MARGIN, -B.TOP)
	for i = 2, 5 do head[i]:SetPoint("LEFT", head[i - 1], "RIGHT", B.GAP, 0) end
	head[1]:SetText(L.COL_NAME); head[2]:SetText(L.COL_LEVEL); head[3]:SetText(L.COL_ZONE); head[4]:SetText(L.COL_GROUP); head[5]:SetText(L.COL_XPH)
	for i = 1, 5 do head[i]:SetTextColor(1, 0.82, 0) end
	B.headText = head

	-- Level and Zone headers sort when clicked; the active one is drawn white.
	B.headers = {}
	local function Header(key, fs)
		local b = CreateFrame("Button", nil, f)
		b:SetPoint("TOPLEFT", fs, "TOPLEFT", -2, 2); b:SetPoint("BOTTOMRIGHT", fs, "BOTTOMRIGHT", 2, -2)
		b:SetScript("OnClick", function() B.SetSort(key) end)
		B.headers[key] = b
	end
	Header("level", head[2]); Header("zone", head[3])

	-- "Near my level (±5)" filter, bottom right.
	local near = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")   -- the template draws the box; a bare CheckButton is invisible
	near:SetSize(22, 22); near:SetPoint("BOTTOMRIGHT", -150, 2)
	near:SetChecked(ns.char.boardNear == true)
	near:SetScript("OnClick", function(self) ns.char.boardNear = self:GetChecked() and true or false; B.Refresh() end)
	local nearLabel = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	nearLabel:SetPoint("LEFT", near, "RIGHT", 2, 0); nearLabel:SetText(L.FILTER_NEAR)
	B.nearLabel = nearLabel
	B.nearCheck = near

	-- "Looking for a partner" (guildmates tab), in the header under the search box.
	local pal = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
	pal:SetSize(20, 20); pal:SetPoint("TOPRIGHT", -(B.MARGIN + 130), -(insetTop + 30))   -- ends above the divider
	B.subtitle:SetWidth(B.WIDTH - (B.MARGIN + 130) - 20 - 4 - B.MARGIN); B.subtitle:SetWordWrap(false)   -- stops before the box
	pal:SetScript("OnClick", function(self)
		if not ns.Partner.SetOn(self:GetChecked() and true or false) then self:SetChecked(ns.Partner.IsOn()) end
		B.Refresh()
	end)
	local palLabel = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	palLabel:SetPoint("LEFT", pal, "RIGHT", 2, 0); palLabel:SetText(L.FILTER_PAL)
	B.palCheck, B.palLabel = pal, palLabel

	B.rows = {}
	for i = 1, ROWS do
		local btn = CreateFrame("Button", nil, f)
		btn:SetSize(ROW_W, ROW_H)
		btn:SetPoint("TOPLEFT", B.MARGIN, -B.TOP - i * ROW_H)
		btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
		local bg = btn:CreateTexture(nil, "BACKGROUND")   -- zebra striping
		bg:SetAllPoints(btn); bg:SetColorTexture(1, 1, 1, i % 2 == 0 and 0.06 or 0)
		btn:SetHighlightTexture("Interface/QuestFrame/UI-QuestLogTitleHighlight", "ADD")
		local icon = btn:CreateTexture(nil, "ARTWORK")   -- class icon, left of the name
		icon:SetSize(ROW_H - 4, ROW_H - 4); icon:SetPoint("LEFT", 0, 0)
		local r = { bg = bg, icon = icon, button = btn, name = Col(btn, B.COLS[1] - (ROW_H - 4) - 4), level = Col(btn, B.COLS[2], "CENTER"), zone = Col(btn, B.COLS[3]), group = Col(btn, B.COLS[4], "CENTER"), xph = Col(btn, B.COLS[5], "RIGHT") }
		r.name:SetPoint("LEFT", icon, "RIGHT", 4, 0); r.level:SetPoint("LEFT", r.name, "RIGHT", B.GAP, 0); r.zone:SetPoint("LEFT", r.level, "RIGHT", B.GAP, 0); r.group:SetPoint("LEFT", r.zone, "RIGHT", B.GAP, 0); r.xph:SetPoint("LEFT", r.group, "RIGHT", B.GAP, 0)
		btn:SetScript("OnClick", function(self, mouse)
			if B.tab == "crafts" then
				if mouse == "RightButton" and self.craftName and not self.craftMine then B.OpenCraftMenu(self.craftName) end
				return
			end
			if B.tab == "wishes" then
				if mouse == "RightButton" and self.wishMine then B.OpenWishMenu(self.wishId) end
				return
			end
			if B.tab == "goals" then
				if mouse == "RightButton" then
					if self.goalId then B.OpenGoalMenu(self.goalId) elseif self.personalMine then B.OpenMyGoalMenu() end
				end
				return
			end
			local name = self.mate
			if not name then return end
			if mouse == "RightButton" then B.OpenMenu(name) else ns.Fire("LM_ROW_CLICK", name) end
		end)
		btn:SetScript("OnEnter", function(self)
			if not GameTooltip then return end
			if B.tab == "lfg" and self.adId then   -- Dungeons tab: the whole note
				local a = ns.LFG.ads[self.adId]
				if a and a.n then GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:AddLine(a.n, 1, 1, 1, true); GameTooltip:Show() end
			elseif B.tab == "goals" and self.goalId then   -- goals: who is missing a level goal
				local g = ns.Goals.Get(self.goalId)
				if g and g.ty == "lvl" then
					local _, _, missing = ns.Goals.Progress(g)
					if #missing > 0 then
						GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
						GameTooltip:AddLine(string.format(L.GOAL_MISSING, table.concat(missing, ", ")), 1, 1, 1, true)
						GameTooltip:Show()
					end
				end
			elseif B.tab == "wishes" and self.wishId then   -- wishes: the item card
				GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:SetHyperlink("item:" .. self.wishId); GameTooltip:Show()
			elseif B.tab == "journal" and self.entry and self.entry.link then   -- journal: the item card
				GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:SetHyperlink(self.entry.link); GameTooltip:Show()
			elseif B.tab == "mates" and self.mate then   -- partner match and shared rested XP
				local lines = {}
				if ns.Partner and ns.Partner.Matches(self.mate) then lines[#lines + 1] = { L.PAL_TOOLTIP, 0.4, 1, 0.4 } end
				local rx = ns.Rested and ns.Rested.Of(self.mate)
				if rx then lines[#lines + 1] = { string.format(L.RESTED_THEIRS, rx), 0.6, 0.8, 1 } end
				if #lines > 0 then
					GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
					for _, l in ipairs(lines) do GameTooltip:AddLine(l[1], l[2], l[3], l[4]) end
					GameTooltip:Show()
				end
			end
		end)
		btn:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
		B.rows[i] = r
	end
	f.empty = Col(f, B.WIDTH - 40, "CENTER"); f.empty:SetPoint("TOP", 0, -(B.TOP + 40))

	-- Dungeons tab: a card per dungeon (art, name, levels, how many are looking), as the dungeon journal's home.
	B.CARD_W = math.floor((B.WIDTH - 2 * B.MARGIN - (B.CARD_COLS - 1) * B.CARD_GAP) / B.CARD_COLS)
	B.cards = {}
	for i = 1, #ns.Dungeons.list do
		local c = CreateFrame("Button", nil, f)
		c:SetSize(B.CARD_W, B.CARD_H); c:RegisterForClicks("AnyUp")
		c:SetHighlightTexture("Interface/QuestFrame/UI-QuestLogTitleHighlight", "ADD")
		c.bg = c:CreateTexture(nil, "BACKGROUND"); c.bg:SetAllPoints()
		c.art = c:CreateTexture(nil, "ARTWORK"); c.art:SetPoint("TOPLEFT", 3, -3); c.art:SetPoint("TOPRIGHT", -3, -3); c.art:SetHeight(B.ART_H)
		c.name = c:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		c.name:SetPoint("TOPLEFT", 5, -(B.ART_H + 6)); c.name:SetWidth(B.CARD_W - 10); c.name:SetHeight(26); c.name:SetJustifyH("LEFT"); c.name:SetJustifyV("TOP"); c.name:SetWordWrap(true)   -- "Scarlet Monastery: Graveyard" needs two lines
		c.levels = c:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); c.levels:SetPoint("BOTTOMLEFT", 5, 5)
		c.count = c:CreateFontString(nil, "OVERLAY", "GameFontGreenSmall"); c.count:SetPoint("BOTTOMRIGHT", -5, 5)
		c:SetScript("OnClick", function(self) B.OpenDungeonMenu(self.dungeonId) end)
		c:SetScript("OnEnter", function(self) B.DungeonTooltip(self) end)
		c:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
		c:Hide()
		B.cards[i] = c
	end

	local help = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
	help:SetSize(120, 20); help:SetPoint("BOTTOMLEFT", 12, 3); help:SetText(L.BTN_HELP)
	help:SetScript("OnClick", function() ns.Fire("LM_HELP_BUTTON") end)
	B.helpButton = help

	-- Dungeons tab: its own action button in the same spot as "Ask for help".
	local lfg = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
	lfg:SetSize(140, 20); lfg:SetPoint("BOTTOMLEFT", 12, 3); lfg:SetText(L.BTN_LFG)
	lfg:SetScript("OnClick", function() ns.Fire("LM_LFG_BUTTON") end)
	B.lfgButton = lfg
	-- Tabs: WoW's classic tabs hanging under the window (as the Dungeon Journal's), so the bottom bar keeps the buttons.
	B.tabs = {}
	local tabList, prevTab = {}, nil
	for i, key in ipairs(B.TAB_KEYS) do
		local b = CreateFrame("Button", "LevelMatesBoardTab" .. i, f, "PanelTabButtonTemplate")
		b:SetID(i); b:SetText(L[TAB_LABELS[key]])
		if prevTab then b:SetPoint("LEFT", prevTab, "RIGHT", -16, 0) else b:SetPoint("TOPLEFT", f, "BOTTOMLEFT", 11, 2) end
		if PanelTemplates_TabResize then PanelTemplates_TabResize(b, 0) end
		b:SetScript("OnClick", function() B.SetTab(key) end)
		B.tabs[key], tabList[i], prevTab = b, b, b
	end
	f.Tabs = tabList   -- the template's parentArray, set here so the order is ours
	if PanelTemplates_SetNumTabs then PanelTemplates_SetNumTabs(f, #tabList) end
	B.tab = KnownTab(ns.char.boardTab)

	-- Journal tab: clear (bottom left), type filter (bottom right), pager in the help-rows area.
	local clear = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
	clear:SetSize(120, 20); clear:SetPoint("BOTTOMLEFT", 12, 3); clear:SetText(L.BTN_J_CLEAR)
	clear:SetScript("OnClick", function() ns.Fire("LM_JOURNAL_CLEAR") end)
	B.journalClear = clear
	local filter = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
	filter:SetSize(140, 20); filter:SetPoint("BOTTOMRIGHT", -12, 3)
	filter:SetScript("OnClick", function(self)
		MenuUtil.CreateContextMenu(self, function(_, root)
			for _, kind in ipairs(ns.Journal.FILTERS) do
				root:CreateButton(ns.Journal.FilterName(kind), function() B.journalFilter = kind; B.journalPage = 1; B.Refresh() end)
			end
		end)
	end)
	B.journalFilterButton = filter
	local prev = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
	prev:SetSize(110, 20); prev:SetPoint("BOTTOM", -160, B.BOTTOM + 8); prev:SetText(L.BTN_J_PREV)
	prev:SetScript("OnClick", function() B.TurnPage(-1) end)
	local nextb = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
	nextb:SetSize(110, 20); nextb:SetPoint("BOTTOM", 160, B.BOTTOM + 8); nextb:SetText(L.BTN_J_NEXT)
	nextb:SetScript("OnClick", function() B.TurnPage(1) end)
	local pageText = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	pageText:SetPoint("BOTTOM", 0, B.BOTTOM + 12)
	B.journalPrev, B.journalNext, B.journalPageText = prev, nextb, pageText

	-- Goals tab: "New goal" for officers (bottom left).
	local goalNew = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
	goalNew:SetSize(120, 20); goalNew:SetPoint("BOTTOMLEFT", 12, 3); goalNew:SetText(L.BTN_GOAL_NEW)
	goalNew:SetScript("OnClick", function() ns.Fire("LM_GOAL_NEW") end)
	B.goalNew = goalNew
	local myGoal = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
	myGoal:SetSize(120, 20); myGoal:SetPoint("BOTTOMRIGHT", -12, 3); myGoal:SetText(L.BTN_MYGOAL)
	myGoal:SetScript("OnClick", function() ns.Fire("LM_MYGOAL") end)
	B.myGoal = myGoal

	-- Wishes tab: "Add wish" (bottom left).
	local wishAdd = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
	wishAdd:SetSize(120, 20); wishAdd:SetPoint("BOTTOMLEFT", 12, 3); wishAdd:SetText(L.BTN_WISH_ADD)
	wishAdd:SetScript("OnClick", function() ns.Fire("LM_WISH_ADD") end)
	B.wishAdd = wishAdd

	-- active help requests, above the help button; "On my way" whispers only from its click
	B.helpRows = {}
	for i = 1, HELP_ROWS do
		local text = Col(f, B.WIDTH - 110)
		text:SetPoint("BOTTOMLEFT", 12, B.BOTTOM + 8 + (i - 1) * ROW_H)
		local btn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
		btn:SetSize(60, ROW_H); btn:SetPoint("LEFT", text, "RIGHT", 4, 0); btn:SetText(L.BTN_COMING)
		btn:SetScript("OnClick", function(self) if self.helpId then ns.Help.Coming(self.helpId) end end)
		B.helpRows[i] = { text = text, button = btn }
	end
end

local function RefreshHelp()
	local H = ns.Help
	local ids = H and H.List() or {}
	for i = 1, HELP_ROWS do
		local row, id = B.helpRows[i], ids[i]
		local h = id and H.active[id]
		row.button.helpId = id
		if h then
			local info = h.mapId and C_Map.GetMapInfo(h.mapId)
			row.text:SetText(string.format("%s: %s (%s)", h.name, h.text, info and info.name or tostring(h.mapId)))
			row.text:Show(); row.button:Show()
		else
			row.text:SetText(""); row.text:Hide(); row.button:Hide()
		end
	end
	B.helpButton:SetText(H and H.mine and L.BTN_HELP_CANCEL or L.BTN_HELP)
end

local NEAR_RANGE = 5
-- "LevelMates - <guild> (3)": the addon, the guild it is showing, and how many mates are online.
function B.TitleString()
	local guild = GetGuildInfo and GetGuildInfo("player")
	local base = (guild and guild ~= "") and (L.BOARD_TITLE .. " - " .. guild) or L.BOARD_TITLE
	return string.format("%s (%d)", base, #R.List())
end

function B.SetTitle(text)
	local fs = B.frame.TitleContainer and B.frame.TitleContainer.TitleText or B.frame.TitleText
	if fs then fs:SetText(text) end
end
local function ZoneName(m) local info = m.mapId and C_Map.GetMapInfo(m.mapId); return info and info.name or "" end

function B.SetSort(mode)
	if B.tab ~= "mates" then return end
	local s = ns.char.boardSort or { mode = "level", desc = true }
	if s.mode == mode then s.desc = not s.desc else s = { mode = mode, desc = mode == "level" } end   -- level starts high-to-low, zone a-to-z
	ns.char.boardSort = s
	B.Refresh()
end

-- Mates in display order: optional ±5 level filter, then the chosen sort (ties: level high to low, then name).
local function Visible()
	local sort = ns.char.boardSort or { mode = "level", desc = true }
	local mine = UnitLevel("player")
	local out = {}
	for _, name in ipairs(R.List()) do
		local m = R.mates[name]
		local nearOk = not ns.char.boardNear or math.abs((m.level or 0) - mine) <= NEAR_RANGE
		local searchOk = (B.search or "") == "" or name:lower():find(B.search:lower(), 1, true) ~= nil   -- plain text, not a pattern
		if nearOk and searchOk then out[#out + 1] = name end
	end
	local function tie(a, b) local A, B2 = R.mates[a], R.mates[b]; if A.level ~= B2.level then return A.level > B2.level end; return a < b end
	table.sort(out, function(a, b)
		local A, B2 = R.mates[a], R.mates[b]
		if sort.mode == "zone" then
			local za, zb = ZoneName(A), ZoneName(B2)
			if za ~= zb then if sort.desc then return za > zb end; return za < zb end
			return tie(a, b)
		end
		if A.level ~= B2.level then if sort.desc then return A.level > B2.level end; return A.level < B2.level end
		return a < b
	end)
	-- Partner matches go to the top: same zone first, then level high to low, then name; the rest keeps its order.
	if ns.Partner and ns.Partner.IsOn() then
		local myMap = C_Map.GetBestMapForUnit("player")
		local top, rest = {}, {}
		for _, name in ipairs(out) do if ns.Partner.Matches(name) then top[#top + 1] = name else rest[#rest + 1] = name end end
		table.sort(top, function(a, b)
			local A, B2 = R.mates[a], R.mates[b]
			local za, zb = A.mapId == myMap, B2.mapId == myMap
			if za ~= zb then return za end
			if A.level ~= B2.level then return A.level > B2.level end
			return a < b
		end)
		for _, name in ipairs(rest) do top[#top + 1] = name end
		out = top
	end
	return out
end

-- Header texts and colours for the active tab; only the guildmates tab sorts.
local function SetHeaders()
	local lfg = B.tab == "lfg"
	if lfg then for i = 1, 5 do B.headText[i]:SetText("") end; return end   -- the grid has no columns
	if B.tab == "crafts" then
		B.headText[1]:SetText(L.COL_WHO); B.headText[2]:SetText(""); B.headText[3]:SetText(L.COL_PROFESSION)
		B.headText[4]:SetText(L.COL_RANK); B.headText[5]:SetText(L.COL_SEEN)
		for i = 1, 5 do B.headText[i]:SetTextColor(1, 0.82, 0) end
		return
	end
	if B.tab == "wishes" then
		B.headText[1]:SetText(L.COL_WHO); B.headText[2]:SetText(""); B.headText[3]:SetText(L.COL_ITEM)
		B.headText[4]:SetText(""); B.headText[5]:SetText(L.COL_SINCE)
		for i = 1, 5 do B.headText[i]:SetTextColor(1, 0.82, 0) end
		return
	end
	if B.tab == "goals" then
		B.headText[1]:SetText(L.COL_BY); B.headText[2]:SetText(""); B.headText[3]:SetText(L.COL_GOAL)
		B.headText[4]:SetText(L.COL_PROGRESS); B.headText[5]:SetText(L.COL_UNTIL)
		for i = 1, 5 do B.headText[i]:SetTextColor(1, 0.82, 0) end
		return
	end
	if B.tab == "journal" then
		B.headText[1]:SetText(L.COL_WHEN); B.headText[2]:SetText(""); B.headText[3]:SetText(L.COL_ENTRY)
		B.headText[4]:SetText(""); B.headText[5]:SetText(L.COL_ZONE)
		for i = 1, 5 do B.headText[i]:SetTextColor(1, 0.82, 0) end
		return
	end
	local sort = ns.char.boardSort or { mode = "level", desc = true }
	B.headText[1]:SetText(lfg and L.COL_PLAYER or L.COL_NAME)
	B.headText[5]:SetText(lfg and L.COL_NOTE or L.COL_XPH)
	B.headText[4]:SetText(lfg and L.COL_ROLES or L.COL_GROUP)
	local sorted = not lfg
	for key, fs in pairs({ level = B.headText[2], zone = B.headText[3] }) do
		if sorted and key == sort.mode then fs:SetTextColor(1, 1, 1) else fs:SetTextColor(1, 0.82, 0) end
	end
	-- the sorted header carries its direction: v = high to low / z to a, ^ = low to high / a to z
	B.headText[2]:SetText(L.COL_LEVEL .. (sorted and sort.mode == "level" and (sort.desc and " v" or " ^") or ""))
	B.headText[3]:SetText((lfg and L.COL_DUNGEON or L.COL_ZONE) .. (sorted and sort.mode == "zone" and (sort.desc and " v" or " ^") or ""))
end

local function ClearRow(r) r.icon:Hide(); r.name:SetText(""); r.level:SetText(""); r.zone:SetText(""); r.group:SetText(""); r.xph:SetText(""); r.button:Hide() end

B.PAL_TINT = { 0.2, 0.8, 0.3, 0.15 }
-- Row background: the partner tint for a match, otherwise the zebra stripe.
local function RowBg(r, i, tint)
	if tint then r.bg:SetColorTexture(unpack(B.PAL_TINT)) else r.bg:SetColorTexture(1, 1, 1, i % 2 == 0 and 0.06 or 0) end
end

local function FillMates(list)
	local mine = UnitLevel("player")
	for i = 1, ROWS do
		local r, name = B.rows[i], list[i]
		r.button.mate, r.button.adId = name, nil
		if name then
			local m = R.mates[name]
			r.name:SetText(name); r.name:SetTextColor(ClassColor(m.class))
			SetClassIcon(r.icon, m.class)
			r.level:SetText(m.level)
			r.level:SetTextColor(unpack(math.abs((m.level or 0) - mine) <= NEAR_RANGE and B.LEVEL_COLORS.near or B.LEVEL_COLORS.far))
			local info = m.mapId and C_Map.GetMapInfo(m.mapId)
			r.zone:SetText(info and info.name or ""); r.zone:SetTextColor(1, 1, 1)
			local state = m.inGroup and (m.hasSlot and "open" or "full") or "solo"
			r.group:SetText(state == "open" and L.GROUP_FREE or state == "full" and L.GROUP_FULL or L.SOLO)
			r.group:SetTextColor(unpack(B.GROUP_COLORS[state]))
			r.xph:SetText(m.xph and m.xph > 0 and tostring(m.xph) or "")
			r.button:Show()
			RowBg(r, i, ns.Partner and ns.Partner.Matches(name))
		else
			r.button.mate = nil
			ClearRow(r)
		end
	end
end

-- Column widths for the active tab (the row and header font strings are chained left to right).
local function SetColumns(widths)
	for i, w in ipairs(widths) do B.headText[i]:SetWidth(w) end
	for _, r in ipairs(B.rows) do
		r.name:SetWidth(widths[1] - (ROW_H - 4) - 4); r.level:SetWidth(widths[2]); r.zone:SetWidth(widths[3])
		r.group:SetWidth(widths[4]); r.xph:SetWidth(widths[5])
	end
end

local function FillJournal(list)
	for i = 1, ROWS do
		local r, e = B.rows[i], list[i]
		r.button.mate, r.button.adId, r.button.entry = nil, nil, e
		if e then
			r.icon:Hide()
			r.name:SetText(ns.Journal.When(e)); r.name:SetTextColor(0.7, 0.7, 0.7)
			r.level:SetText("")
			r.zone:SetText(ns.Journal.Text(e)); r.zone:SetTextColor(unpack(ns.Journal.Color(e)))
			r.group:SetText("")
			r.xph:SetText(e.zone or ""); r.xph:SetTextColor(0.7, 0.7, 0.7)
			r.button:Show()
			RowBg(r, i, false)
		else
			ClearRow(r)
		end
	end
end

local function FillGoals(list)
	for i = 1, ROWS do
		local r, g = B.rows[i], list[i]
		r.button.mate, r.button.adId, r.button.entry = nil, nil, nil
		r.button.goalId = g and not g.name and g.id or nil
		r.button.personalMine = g and g.mine or nil
		if g and g.name then   -- personal goal
			local P = ns.Personal
			r.icon:Hide()
			r.name:SetText(g.name); r.name:SetTextColor(1, 1, 1)
			r.level:SetText("")
			r.zone:SetText(P.Text(g)); r.zone:SetTextColor(0.6, 0.8, 1)
			r.group:SetText(P.ProgressText(g)); r.group:SetTextColor(unpack(P.IsDone(g) and B.GROUP_COLORS.open or { 1, 1, 1 }))
			r.xph:SetText(ns.Goals.UntilText(g)); r.xph:SetTextColor(0.7, 0.7, 0.7)
			r.button:Show()
			RowBg(r, i, false)
		elseif g then
			r.icon:Hide()
			r.name:SetText(g.by or ""); r.name:SetTextColor(0.7, 0.7, 0.7)
			r.level:SetText("")
			r.zone:SetText(ns.Goals.Text(g)); r.zone:SetTextColor(1, 0.82, 0)
			r.group:SetText(ns.Goals.ProgressText(g)); r.group:SetTextColor(unpack(ns.Goals.IsDone(g) and B.GROUP_COLORS.open or { 1, 1, 1 }))
			r.xph:SetText(ns.Goals.UntilText(g)); r.xph:SetTextColor(0.7, 0.7, 0.7)
			r.button:Show()
			RowBg(r, i, false)
		else
			ClearRow(r)
		end
	end
end

function B.OpenGoalMenu(id)
	if not ns.Goals.CanDelete(id) then return end
	B.lastGoalMenu = id
	local g = ns.Goals.Get(id)
	MenuUtil.CreateContextMenu(B.frame, function(_, root)
		root:CreateTitle(ns.Goals.Text(g))
		root:CreateButton(L.GOAL_DELETE, function() ns.Goals.Delete(id) end)
	end)
end

local function FillCrafts(list)
	for i = 1, ROWS do
		local r, c = B.rows[i], list[i]
		r.button.mate, r.button.adId, r.button.entry, r.button.goalId, r.button.personalMine = nil, nil, nil, nil, nil
		r.button.craftName, r.button.craftMine = c and c.name or nil, c and c.mine or nil
		if c then
			local m = R.mates[c.name]
			r.icon:Hide()
			r.name:SetText(c.name); r.name:SetTextColor(ClassColor(m and m.class))
			r.level:SetText("")
			r.zone:SetText(ns.Professions.Name(c.id)); r.zone:SetTextColor(1, 0.82, 0)
			r.group:SetText(tostring(c.rank)); r.group:SetTextColor(1, 1, 1)
			local online = c.mine or m ~= nil
			r.xph:SetText(online and L.ONLINE or date("%d/%m", c.t)); r.xph:SetTextColor(unpack(online and B.GROUP_COLORS.open or { 0.7, 0.7, 0.7 }))
			r.button:Show()
			RowBg(r, i, false)
		else
			ClearRow(r)
		end
	end
end

function B.OpenCraftMenu(name)
	MenuUtil.CreateContextMenu(B.frame, function(_, root)
		root:CreateTitle(name)
		root:CreateButton(L.MENU_WHISPER, function() B.Whisper(name) end)
		if R.mates[name] then root:CreateButton(L.MENU_INVITE, function() B.Invite(name) end) end
	end)
end

local function CraftsVisible()
	local out, q = {}, (B.search or ""):lower()
	for _, c in ipairs(ns.Professions.List()) do
		if q == "" or c.name:lower():find(q, 1, true) or ns.Professions.Name(c.id):lower():find(q, 1, true) then out[#out + 1] = c end
	end
	return out
end

local function FillWishes(list)
	for i = 1, ROWS do
		local r, w = B.rows[i], list[i]
		r.button.mate, r.button.adId, r.button.entry, r.button.goalId, r.button.personalMine = nil, nil, nil, nil, nil
		r.button.wishId, r.button.wishMine = w and w.id or nil, w and w.mine or nil
		if w then
			r.icon:Hide()
			r.name:SetText(w.name); r.name:SetTextColor(unpack(w.mine and { 1, 1, 1 } or { 0.7, 0.7, 0.7 }))
			r.level:SetText("")
			r.zone:SetText(ns.Wishlist.Link(w.id) or string.format(L.WISH_UNKNOWN, w.id)); r.zone:SetTextColor(1, 1, 1)
			r.group:SetText("")
			r.xph:SetText(date("%d/%m", w.t)); r.xph:SetTextColor(0.7, 0.7, 0.7)
			r.button:Show()
			RowBg(r, i, false)
		else
			ClearRow(r)
		end
	end
end

function B.OpenWishMenu(id)
	if not ns.Wishlist.Has(id) then return end
	MenuUtil.CreateContextMenu(B.frame, function(_, root)
		root:CreateButton(L.WISH_REMOVE, function() ns.Wishlist.Remove(id) end)
	end)
end

-- Dungeons tab: the ads for a dungeon (mine first), the visible cards, and filling them.
function B.AdsFor(id)
	local out, LFG = {}, ns.LFG
	if LFG.mine and LFG.mine.d == id then out[1] = { name = (UnitName("player")), r = LFG.mine.r, n = LFG.mine.n, mine = true, joined = LFG.mine.joined, id = LFG.mine.id } end
	for _, adId in ipairs(LFG.List()) do
		local a = LFG.ads[adId]
		if a.d == id and not (LFG.mine and adId == LFG.mine.id) then out[#out + 1] = a end
	end
	return out
end

local function GridVisible()
	local out, q = {}, (B.search or ""):lower()
	for _, d in ipairs(ns.Dungeons.Sorted()) do
		local match = q == "" or ns.Dungeons.Name(d.id):lower():find(q, 1, true) ~= nil
		if not match then for _, a in ipairs(B.AdsFor(d.id)) do if a.name:lower():find(q, 1, true) then match = true end end end
		if match then out[#out + 1] = d.id end
	end
	return out
end

local function FillGrid(list)
	for i = 1, ROWS do ClearRow(B.rows[i]) end
	local mine = UnitLevel("player")
	for i, c in ipairs(B.cards) do
		local id = list[i]
		if id then
			local d, ads = ns.Dungeons.Get(id), B.AdsFor(id)
			local col, row = (i - 1) % B.CARD_COLS, math.floor((i - 1) / B.CARD_COLS)
			c:ClearAllPoints()
			c:SetPoint("TOPLEFT", B.frame, "TOPLEFT", B.MARGIN + col * (B.CARD_W + B.CARD_GAP), -(B.TOP + row * (B.CARD_H + B.CARD_GAP)))
			c.dungeonId, c.fits = id, ns.Dungeons.Fits(id, mine)
			local tex, coords = ns.Dungeons.Art(id)
			if tex then c.art:SetTexture(tex); c.art:SetTexCoord(unpack(coords)); c.art:SetAlpha(c.fits and 1 or 0.45); c.art:Show() else c.art:Hide() end
			c.bg:SetColorTexture(unpack(c.fits and { 0.35, 0.27, 0.05, 0.9 } or { 0.08, 0.08, 0.08, 0.9 }))
			c.name:SetText(ns.Dungeons.Name(id)); c.name:SetTextColor(unpack(c.fits and { 1, 0.82, 0 } or { 0.75, 0.75, 0.75 }))
			c.levels:SetText(string.format("%d-%d", d.min, d.max))
			c.count:SetText(#ads == 0 and "" or #ads == 1 and L.LFG_SEARCHING_ONE or string.format(L.LFG_SEARCHING, #ads))
			c:Show()
		else
			c:Hide()
		end
	end
end

function B.DungeonTooltip(card)
	if not GameTooltip then return end
	local d = ns.Dungeons.Get(card.dungeonId)
	GameTooltip:SetOwner(card, "ANCHOR_RIGHT")
	GameTooltip:AddLine(string.format("%s (%d-%d)", ns.Dungeons.Name(d.id), d.min, d.max), 1, 0.82, 0)
	for _, a in ipairs(B.AdsFor(d.id)) do
		GameTooltip:AddLine(a.name .. " · " .. ns.LFG.RolesShort(a.r) .. (a.n and (": " .. a.n) or ""), 1, 1, 1, true)
		local who = {}
		for name, role in pairs(a.joined or {}) do who[#who + 1] = name .. " (" .. L["ROLE_" .. role] .. ")" end
		if #who > 0 then table.sort(who); GameTooltip:AddLine("   " .. string.format(L.LFJ_JOINED, table.concat(who, ", ")), 0.4, 1, 0.4, true) end
	end
	GameTooltip:Show()
end

-- A card's click: whisper or invite who is looking, withdraw mine, or look for a group there.
function B.OpenDungeonMenu(id)
	B.lastDungeonMenu = id
	MenuUtil.CreateContextMenu(B.frame, function(_, root)
		root:CreateTitle(ns.Dungeons.Name(id))
		for _, a in ipairs(B.AdsFor(id)) do
			if a.mine then
				local who = {}
				for name, role in pairs(a.joined or {}) do who[#who + 1] = { name = name, role = role } end
				table.sort(who, function(x, y) return x.name < y.name end)
				for _, w in ipairs(who) do root:CreateButton(string.format(L.LFJ_INVITE, w.name, L["ROLE_" .. w.role]), function() B.Invite(w.name) end) end
				root:CreateButton(L.LFG_CANCEL_MINE, function() ns.LFG.Cancel() end)
			else
				if ns.LFG.myJoins[a.id] then
					root:CreateButton(string.format(L.LFJ_LEAVE, a.name), function() ns.LFG.Leave(a.id) end)
				else
					for _, role in ipairs({ "T", "H", "D" }) do
						root:CreateButton(string.format(L.LFJ_JOIN, a.name, L["ROLE_" .. role]), function() ns.LFG.Join(a.id, role) end)
					end
				end
				root:CreateButton(string.format(L.LFG_WHISPER, a.name), function() B.Whisper(a.name) end)
				root:CreateButton(string.format(L.LFG_INVITE, a.name), function() B.Invite(a.name) end)
			end
		end
		root:CreateButton(L.LFG_HERE, function() ns.Fire("LM_LFG_HERE", id) end)
	end)
end

function B.OpenMyGoalMenu()
	if not ns.Personal.Mine() then return end
	MenuUtil.CreateContextMenu(B.frame, function(_, root)
		root:CreateButton(L.MYGOAL_REMOVE, function() ns.Personal.Clear() end)
	end)
end

-- Pages of ROWS for the long tabs (journal, goals, wishes); the pager sits in the help-rows area.
local PAGE_KEY = { journal = "journalPage", goals = "goalPage", wishes = "wishPage", crafts = "craftPage" }
local function Page(all)
	local key = PAGE_KEY[B.tab]
	local pages = math.max(1, math.ceil(#all / ROWS))
	B[key] = math.min(math.max(1, B[key] or 1), pages)
	local list = {}
	for i = (B[key] - 1) * ROWS + 1, math.min(#all, B[key] * ROWS) do list[#list + 1] = all[i] end
	B.journalPageText:SetText(string.format(L.J_PAGE, B[key], pages))
	B.journalPrev:SetEnabled(B[key] > 1); B.journalNext:SetEnabled(B[key] < pages)
	return list, pages
end
function B.TurnPage(step)
	local key = PAGE_KEY[B.tab]
	if key then B[key] = (B[key] or 1) + step; B.Refresh() end
end

local function RefreshTabs()
	local lfg, journal, goals, wishes, crafts = B.tab == "lfg", B.tab == "journal", B.tab == "goals", B.tab == "wishes", B.tab == "crafts"
	local mates = B.tab == "mates"
	local index = 1
	for i, key in ipairs(B.TAB_KEYS) do if key == B.tab then index = i end end
	if PanelTemplates_SetTab then PanelTemplates_SetTab(B.frame, index)
	else for i, key in ipairs(B.TAB_KEYS) do B.tabs[key]:SetEnabled(i ~= index) end end
	B.helpButton:SetShown(mates); B.nearCheck:SetShown(mates); B.nearLabel:SetShown(mates)
	B.palCheck:SetShown(mates); B.palLabel:SetShown(mates)
	B.palCheck:SetChecked(ns.Partner and ns.Partner.IsOn() or false)
	B.lfgButton:SetShown(lfg)
	B.lfgButton:SetText(ns.LFG.mine and L.BTN_LFG_CANCEL or L.BTN_LFG)
	B.journalClear:SetShown(journal); B.journalFilterButton:SetShown(journal)
	B.journalPrev:SetShown(journal); B.journalNext:SetShown(journal); B.journalPageText:SetShown(journal)
	B.goalNew:SetShown(goals and R.IAmOfficer())
	B.myGoal:SetShown(goals)
	B.wishAdd:SetShown(wishes)
end

function B.Refresh()
	if not B.frame or not B.frame:IsShown() then return end
	local lfg, journal, goals, wishes, crafts = B.tab == "lfg", B.tab == "journal", B.tab == "goals", B.tab == "wishes", B.tab == "crafts"
	local list, pages
	if journal then
		list = Page(ns.Journal.List(B.journalFilter or "all", B.search))
		B.journalFilterButton:SetText(ns.Journal.FilterName(B.journalFilter or "all"))
	elseif crafts then
		list, pages = Page(CraftsVisible())
	elseif wishes then
		list, pages = Page(ns.Wishlist.List())
	elseif goals then
		local all = ns.Goals.List()
		for _, p in ipairs(ns.Personal.List()) do all[#all + 1] = p end
		list, pages = Page(all)
	else
		list = lfg and GridVisible() or Visible()
	end
	SetColumns(journal and B.JCOLS or goals and B.GCOLS or wishes and B.WCOLS or crafts and B.CCOLS or B.COLS)
	SetHeaders()
	local hk = HEAD_KEY[B.tab] or "MATES"
	B.heading:SetText(L["HEAD_" .. hk])
	B.subtitle:SetText(journal and ns.Journal.PaceText() or L["SUB_" .. hk])
	if B.searchBox and B.searchBox.Instructions then B.searchBox.Instructions:SetText(L["SEARCH_" .. hk]) end
	local rows = math.max(MIN_ROWS, math.min(ROWS, #list))
	if lfg then rows = math.max(MIN_ROWS, math.ceil(math.ceil(#list / B.CARD_COLS) * (B.CARD_H + B.CARD_GAP) / ROW_H)) end
	B.frame:SetHeight(B.CHROME + (rows + HELP_ROWS) * ROW_H)
	B.SetTitle(B.TitleString())
	local rested = ns.Rested and ns.Rested.Mine()
	B.restedText:SetText(rested and string.format(L.RESTED_MINE, rested) or "")
	if journal then FillJournal(list) elseif crafts then FillCrafts(list) elseif wishes then FillWishes(list) elseif goals then FillGoals(list) elseif lfg then FillGrid(list) else FillMates(list) end
	if not lfg then for _, c in ipairs(B.cards) do c:Hide() end end
	local emptyText = ""
	if #list == 0 then
		if journal then emptyText = ns.Journal.Count() == 0 and L.J_EMPTY or L.EMPTY_FILTERED
		elseif goals then emptyText = L.GOAL_EMPTY
		elseif crafts then emptyText = #ns.Professions.List() > 0 and L.EMPTY_FILTERED or L.CRAFTS_EMPTY
		elseif wishes then emptyText = L.WISH_EMPTY
		elseif not IsInGuild() then emptyText = L.NOT_IN_GUILD
		elseif lfg then emptyText = L.EMPTY_FILTERED   -- every dungeon has a card: empty only when the search hides them all
		elseif #R.List() > 0 then emptyText = L.EMPTY_FILTERED
		else emptyText = L.EMPTY end
	end
	B.frame.empty:SetText(emptyText)
	RefreshTabs()
	if (goals or wishes or crafts) and pages > 1 then   -- the pager only when there is more than one page
		B.journalPrev:Show(); B.journalNext:Show(); B.journalPageText:Show()
	end
	if journal or goals or wishes or crafts then
		for _, hr in ipairs(B.helpRows) do hr.text:Hide(); hr.button:Hide() end   -- the pager uses this area
	else
		RefreshHelp()
	end
end

function B.SetTab(key)
	key = KnownTab(key)
	ns.char.boardTab, B.tab, B.search = key, key, ""
	if B.searchBox then B.searchBox:SetText("") end
	B.Refresh()
end

-- Open the board on a given tab (slash command, minimap, binding).
function B.ShowTab(key)
	if not B.frame then Build() end
	B.tab = KnownTab(key)
	ns.char.boardTab = B.tab
	B.frame:Show()
	B.Refresh()
end

function B.Toggle()
	if not B.frame then Build() end
	B.frame:SetShown(not B.frame:IsShown())
	B.Refresh()
end

-- Actions below run only from click handlers (menu entries / row clicks): Forever drops them otherwise.
function B.Invite(name) C_PartyInfo.InviteUnit(name) end
function B.Whisper(name) ChatFrameUtil.SendTell(name) end
function B.OpenMenu(name)
	B.lastMenuFor = name
	local m = R.mates[name]
	MenuUtil.CreateContextMenu(B.frame, function(_, root)
		root:CreateTitle(name)
		root:CreateButton(L.MENU_INVITE, function() B.Invite(name) end)
		root:CreateButton(L.MENU_WHISPER, function() B.Whisper(name) end)
		if m and m.x and m.y and m.mapId then root:CreateButton(L.MENU_WAYPOINT, function() ns.Help.WaypointTo(m.mapId, m.x, m.y) end) end
	end)
end

ns.On("LM_ROSTER_CHANGED", B.Refresh)
ns.On("LM_HELP_CHANGED", B.Refresh)
ns.On("LM_TOGGLE_BOARD", B.Toggle)
ns.On("LM_LOADED", function()
	if AddonCompartmentFrame and ns.db.settings.minimap then
		AddonCompartmentFrame:RegisterAddon({ text = L.BOARD_TITLE, icon = "Interface\\AddOns\\LevelMates\\Media\\icon", func = B.Toggle })
	end
end)

-- Called by Bindings.xml (the assignable key).
function LevelMates_ToggleBoard() B.Toggle() end
BINDING_NAME_LEVELMATES_TOGGLE = L.BINDING_TOGGLE

-- The title carries the guild name: refresh when the player's guild changes.
local guildFrame = CreateFrame("Frame")
guildFrame:RegisterEvent("PLAYER_GUILD_UPDATE")
guildFrame:SetScript("OnEvent", function() B.Refresh() end)

ns.On("LM_LFG_CHANGED", B.Refresh)
ns.Slash("lfg", function() B.ShowTab("lfg") end)
ns.Slash("grupo", function() B.ShowTab("lfg") end)

ns.On("LM_PARTNER_CHANGED", B.Refresh)

ns.On("LM_RESTED_CHANGED", B.Refresh)

ns.On("LM_JOURNAL_CHANGED", B.Refresh)
ns.Slash("diario", function() B.ShowTab("journal") end)
ns.Slash("journal", function() B.ShowTab("journal") end)

ns.On("LM_GOALS_CHANGED", B.Refresh)
ns.Slash("metas", function() B.ShowTab("goals") end)
ns.Slash("goals", function() B.ShowTab("goals") end)

ns.On("LM_WISHES_CHANGED", B.Refresh)
ns.Slash("deseos", function() B.ShowTab("wishes") end)
ns.Slash("wishlist", function() B.ShowTab("wishes") end)

ns.On("LM_PROFESSIONS_CHANGED", B.Refresh)
ns.Slash("oficios", function() B.ShowTab("crafts") end)
ns.Slash("professions", function() B.ShowTab("crafts") end)
