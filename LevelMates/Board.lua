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
B.COLS = { 150, 50, 260, 70, 70 }   -- name, level, zone, group, xp/h
B.GAP, B.MARGIN, B.WIDTH = 4, 24, 900   -- the margin keeps the text inside the page's drawn edge
B.JCOLS = { 100, 1, 395, 1, 103 }   -- journal: when, -, entry, -, zone (same total as B.COLS)
B.GCOLS = { 100, 1, 364, 70, 65 }   -- goals: by, -, goal, progress, until (same total as B.COLS)
B.WCOLS = { 100, 1, 320, 105, 74 }   -- wishes and gifts: who, -, item, wants/gives, since (same total as B.COLS)
B.CCOLS = { 150, 1, 289, 60, 100 }   -- professions: who, -, progress bar, rank, online or last seen (same total as B.COLS)
B.BAR_W = 160
B.FCOLS = { 110, 1, 393, 1, 95 }   -- wall: who, -, what, -, when (same total as B.COLS)
B.KCOLS = { 150, 1, 339, 50, 60 }   -- class: who or macro, -, points or macro text, level, action (same total as B.COLS)
B.HCOLS = { 170, 1, 279, 80, 70 }   -- home: who or what, -, details, numbers, action (same total as B.COLS)
B.ICOLS = { 150, 50, 160, 110, 130 }   -- inactive members: name, level, rank, away, joined (same total as B.COLS)   -- class: who or macro, -, points or macro text, level, action (same total as B.COLS)
B.CARD_COLS, B.CARD_GAP, B.CARD_H, B.ART_H = 5, 8, 104, 50   -- dungeon cards (room for two-line names)
-- Tabs, in order; each key's label is L[TAB_LABELS[key]].
B.TAB_KEYS = { "home", "mates", "lfg", "guild", "journal" }   -- the five main tabs
B.GUILD_KEYS = { "feed", "goals", "wishes", "crafts", "class", "members", "bank", "recruit" }   -- the Guild tab's sub-sections
B.CONTENT_KEYS = { "home", "mates", "lfg", "journal", "feed", "goals", "wishes", "crafts", "class", "members", "bank", "recruit" }   -- what a page shows
local TAB_LABELS = { home = "TAB_HOME", guild = "TAB_GUILD", mates = "TAB_MATES", lfg = "TAB_LFG", journal = "TAB_JOURNAL", goals = "TAB_GOALS", wishes = "TAB_WISHES", crafts = "TAB_CRAFTS", class = "TAB_CLASS", feed = "TAB_FEED", recruit = "TAB_RECRUIT", members = "TAB_MEMBERS", bank = "TAB_BANK" }
B.TAB_LABELS = TAB_LABELS
local HEAD_KEY = { home = "HOME", mates = "MATES", lfg = "LFG", journal = "JOURNAL", goals = "GOALS", wishes = "WISHES", crafts = "CRAFTS", class = "CLASS", feed = "FEED", recruit = "RECRUIT", members = "MEMBERS", bank = "BANK" }
local TAB_ICON = { home = "Interface\\Icons\\INV_Misc_Book_09", mates = "Interface\\Icons\\Spell_Holy_PrayerOfFortitude",
	lfg = "Interface\\Icons\\INV_Misc_Key_03", guild = "banner", journal = "Interface\\Icons\\INV_Misc_Note_01" }
local function KnownTab(key) for _, k in ipairs(B.CONTENT_KEYS) do if k == key then return key end end; return "home" end
-- The main tab a page belongs to: the Guild tab's sub-sections belong to "guild".
function B.MainOf(key) for _, k in ipairs(B.GUILD_KEYS) do if k == key then return "guild" end end; return key end
-- "guild" opens its last sub-section (the wall at first).
local function Resolve(key) if key == "guild" then return ns.char.guildSub or "feed" end; return key end
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

local function MyClass() return select(2, UnitClass("player")) end

local function ClassColor(class)
	local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
	if c then return c.r, c.g, c.b end
	return 1, 1, 1
end

local function Build()
	-- The guild book: the game's own frame with its round portrait, the top band for the icon tabs, a parchment page.
	local f = ns.Skin.Window("LevelMatesBoard", UIParent, true)
	B.frame = f
	-- Lay the content out from the inset's real anchors, so it sits inside the dark recess whatever the template does.
	local insetTop, insetBottom = 24, 26
	if f.Inset and f.Inset.GetPoint then
		local _, _, _, _, y1 = f.Inset:GetPoint(1)
		local _, _, _, _, y2 = f.Inset:GetPoint(2)
		if type(y1) == "number" and y1 < 0 then insetTop = -y1 end
		if type(y2) == "number" and y2 > 0 then insetBottom = y2 end
	end
	if f.page then insetTop = insetTop + 55 end   -- the page's drawn top edge (its curl): the writing starts below it
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
	if _G.Fancy24Font then B.heading:SetFontObject("Fancy24Font") end   -- the game's decorative letters, as the spellbook's titles
	local divider = f:CreateTexture(nil, "ARTWORK")
	divider:SetAtlas(ns.Skin.DIVIDER); divider:SetHeight(10)
	divider:SetPoint("TOPLEFT", B.MARGIN - 4, -(B.TOP - 12)); divider:SetPoint("TOPRIGHT", -B.MARGIN - 40, -(B.TOP - 12))
	B.divider = divider
	local strip = f:CreateTexture(nil, "BORDER")   -- a faint band behind the column names
	strip:SetColorTexture(unpack(ns.Skin.C.strip))
	strip:SetPoint("TOPLEFT", f, "TOPLEFT", B.MARGIN - 4, -(B.TOP - 2)); strip:SetPoint("BOTTOMRIGHT", f, "TOPRIGHT", -(B.MARGIN - 4), -(B.TOP + ROW_H - 4))
	B.colStrip = strip
	local search = CreateFrame("EditBox", nil, f, "SearchBoxTemplate")
	search:SetSize(170, 20); search:SetPoint("TOPRIGHT", f, "TOPRIGHT", -30, -30)   -- in the top band, as the spellbook's
	if search.Instructions then search.Instructions:SetText(L.SEARCH_HINT) end
	search:SetScript("OnTextChanged", function(self) B.search = self:GetText() or ""; B.Refresh() end)
	-- "Discord": the current tab as text to paste in Discord (every tab).
	local discord = ns.Skin.Button(f)
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
	B.SUB_NARROW = B.WIDTH - (B.MARGIN + 130) - 20 - 4 - B.MARGIN
	B.subtitle:SetWidth(B.SUB_NARROW); B.subtitle:SetWordWrap(false)   -- stops before the box
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
		local hl = btn:CreateTexture(nil, "HIGHLIGHT"); hl:SetAllPoints(); hl:SetColorTexture(0.45, 0.28, 0.08, 0.16)   -- a soft brown shade: a white glow washes the page out
		btn:SetHighlightTexture(hl)
		local icon = btn:CreateTexture(nil, "ARTWORK")   -- class icon, left of the name
		icon:SetSize(ROW_H - 4, ROW_H - 4); icon:SetPoint("LEFT", 0, 0)
		local r = { bg = bg, icon = icon, button = btn, stripe = ns.Skin.Stripe(btn), plaque = ns.Skin.Plaque(btn), name = Col(btn, B.COLS[1] - (ROW_H - 4) - 4), level = Col(btn, B.COLS[2], "CENTER"), zone = Col(btn, B.COLS[3]), group = Col(btn, B.COLS[4], "CENTER"), xph = Col(btn, B.COLS[5], "RIGHT") }
		-- Professions tab: a rank bar in the third column
		-- progress bars: the game's own status bar texture (as health and mana), dark gold on a brown groove
		r.barBg = btn:CreateTexture(nil, "ARTWORK"); r.barBg:SetColorTexture(0.24, 0.14, 0.05, 0.45); r.barBg:SetSize(B.BAR_W, 10); r.barBg:Hide()
		r.barFill = btn:CreateTexture(nil, "OVERLAY"); r.barFill:SetTexture("Interface/TargetingFrame/UI-StatusBar"); r.barFill:SetVertexColor(0.80, 0.55, 0.12); r.barFill:SetHeight(8); r.barFill:Hide()
		r.name:SetPoint("LEFT", icon, "RIGHT", 4, 0); r.level:SetPoint("LEFT", r.name, "RIGHT", B.GAP, 0); r.zone:SetPoint("LEFT", r.level, "RIGHT", B.GAP, 0); r.group:SetPoint("LEFT", r.zone, "RIGHT", B.GAP, 0); r.xph:SetPoint("LEFT", r.group, "RIGHT", B.GAP, 0)
		btn:SetScript("OnClick", function(self, mouse)
			if B.tab == "home" then
				if self.homeEntry and not self.homeEntry.header then B.HomeAction(self.homeEntry) end
				return
			end
			if B.tab == "feed" then return end
			if B.tab == "lfg" then   -- the run calendar, or a suggestion of Together
				if self.meet then B.OpenMeetMenu(self.meet) elseif self.togetherEntry then B.OpenTogetherMenu(self.togetherEntry)
				elseif self.questEntry then B.OpenQuestMenu(self.questEntry) end
				return
			end
			if B.tab == "class" then
				if self.classEntry and not self.classEntry.header then B.OpenClassMenu(self.classEntry) end
				return
			end
			if B.tab == "members" then
				if self.memberEntry then B.OpenMemberMenu(self.memberEntry) end
				return
			end
			if B.tab == "bank" then return end
			if B.tab == "crafts" then
				if self.recipesHeader then B.recipesOf = nil; B.Refresh()   -- back to the professions
				elseif self.crafter then B.OpenCraftMenu(self.crafter.name, self.entryItem)
				elseif mouse == "RightButton" and self.craftName and not self.craftMine then B.OpenCraftMenu(self.craftName) end
				return
			end
			if B.tab == "wishes" then
				if mouse == "RightButton" and self.wishId then B.OpenWishMenu(self.wishId, self.wishKind, self.wishMine, self.wishName) end
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
			if B.tab == "lfg" and self.questEntry then   -- a quest post: their objectives, mine, who else looks
				local p = self.questEntry
				GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
				GameTooltip:AddLine(p.t, 1, 0.82, 0)
				if p.ob then GameTooltip:AddLine(string.format(L.QH_THEIRS, p.by, p.ob), 1, 1, 1, true) end
				local mine = ns.QuestProgress and ns.QuestProgress.Objectives and ns.QuestProgress.Objectives(p.q)
				if mine then GameTooltip:AddLine(string.format(L.QH_MINE, mine), 0.6, 0.8, 1, true) end
				if #p.joined > 0 then GameTooltip:AddLine(string.format(L.QH_ALSO, table.concat(p.joined, ", ")), 0.8, 0.8, 0.8, true) end
				GameTooltip:Show()
			elseif B.tab == "lfg" and self.adId then   -- Dungeons tab: the whole note
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
			elseif B.tab == "class" and self.classEntry and not self.classEntry.header then   -- class: the whole macro, or the build
				local e = self.classEntry
				GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
				if e.kind == "ask" then
					GameTooltip:AddLine(e.q.by, 1, 0.82, 0)
					GameTooltip:AddLine(e.q.x, 1, 1, 1, true)
				elseif e.kind == "build" then
					GameTooltip:AddLine(e.e.name .. " · " .. string.format(L.LEVEL_N, e.e.l), 1, 0.82, 0)
					GameTooltip:AddLine(ns.Builds.PointsText(e.e), 1, 1, 1, true)
					if not e.e.b then GameTooltip:AddLine(L.CLASS_NO_CODE, 0.7, 0.7, 0.7, true) end
				else
					GameTooltip:AddLine(e.m.name, 1, 0.82, 0)
					for line in (e.m.body .. "\n"):gmatch("(.-)\n") do GameTooltip:AddLine(line, 1, 1, 1) end
				end
				GameTooltip:Show()
			elseif B.tab == "feed" and self.feedItem then   -- wall: the item card
				GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:SetHyperlink("item:" .. self.feedItem); GameTooltip:Show()
			elseif B.tab == "journal" and self.entry and self.entry.link then   -- journal: the item card
				GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:SetHyperlink(self.entry.link); GameTooltip:Show()
			elseif B.tab == "mates" and self.mate then   -- partner match and shared rested XP
				local lines = {}
				if ns.Partner and ns.Partner.Matches(self.mate) then lines[#lines + 1] = { L.PAL_TOOLTIP, 0.4, 1, 0.4 } end
				local alts = ns.Alts and ns.Alts.Of(self.mate) or {}
				if #alts > 0 then lines[#lines + 1] = { string.format(L.CARD_ALTS, table.concat(alts, ", ")), 0.8, 0.8, 0.8 } end
				local rx = ns.Rested and ns.Rested.Of(self.mate)
				if rx then lines[#lines + 1] = { string.format(L.RESTED_THEIRS, rx), 0.6, 0.8, 1 } end
				local shared = ns.QuestProgress and ns.QuestProgress.Shared(self.mate) or {}
				if #shared > 0 then
					lines[#lines + 1] = { L.QUEST_SHARED, 1, 0.82, 0 }
					for _, q in ipairs(shared) do lines[#lines + 1] = { q.title .. ": " .. (q.o:gsub(",", ", ")), 1, 1, 1 } end
				end
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
		local c = CreateFrame("Button", nil, f, ns.Skin.On() and "BackdropTemplate" or nil)
		c:SetSize(B.CARD_W, B.CARD_H); c:RegisterForClicks("AnyUp")
		c:SetHighlightTexture("Interface/QuestFrame/UI-QuestLogTitleHighlight", "ADD")
		c.bg = c:CreateTexture(nil, "BACKGROUND"); c.bg:SetAllPoints()
		c.art = c:CreateTexture(nil, "ARTWORK"); c.art:SetPoint("TOPLEFT", 3, -3); c.art:SetPoint("TOPRIGHT", -3, -3); c.art:SetHeight(B.ART_H)
		c.name = c:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		c.name:SetPoint("TOPLEFT", 5, -(B.ART_H + 6)); c.name:SetWidth(B.CARD_W - 10); c.name:SetHeight(26); c.name:SetJustifyH("LEFT"); c.name:SetJustifyV("TOP"); c.name:SetWordWrap(true)   -- "Scarlet Monastery: Graveyard" needs two lines
		c.levels = c:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); c.levels:SetPoint("BOTTOMLEFT", 5, 5)
		c.count = c:CreateFontString(nil, "OVERLAY", "GameFontGreenSmall"); c.count:SetPoint("BOTTOMRIGHT", -5, 5)
		c.badge = c:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); c.badge:SetPoint("TOPLEFT", c.art, "TOPLEFT", 3, -3)
		if ns.Skin.On() then   -- the picture fills the card; name, levels and who is looking sit on dark bands over it
			c.skin = true
			ns.Skin.Backdrop(c, { 0, 0, 0, 1 }, ns.Skin.C.card, 12)
			c.bg:Hide()
			c.art:ClearAllPoints(); c.art:SetPoint("TOPLEFT", 4, -4); c.art:SetPoint("BOTTOMRIGHT", -4, 4)
			c.top = c:CreateTexture(nil, "ARTWORK", nil, 1); c.top:SetColorTexture(unpack(ns.Skin.C.band))
			c.top:SetPoint("TOPLEFT", 4, -4); c.top:SetPoint("TOPRIGHT", -4, -4); c.top:SetHeight(32)
			c.bottom = c:CreateTexture(nil, "ARTWORK", nil, 1); c.bottom:SetColorTexture(unpack(ns.Skin.C.band))
			c.bottom:SetPoint("BOTTOMLEFT", 4, 4); c.bottom:SetPoint("BOTTOMRIGHT", -4, 4); c.bottom:SetHeight(18)
			c.name:SetFontObject("GameFontNormal"); c.name:ClearAllPoints(); c.name:SetPoint("TOPLEFT", 8, -6); c.name:SetWidth(B.CARD_W - 16); c.name:SetHeight(28)
			c.levels:ClearAllPoints(); c.levels:SetPoint("BOTTOMLEFT", 8, 7)
			c.count:ClearAllPoints(); c.count:SetPoint("BOTTOMRIGHT", -8, 7)
			c.badge:ClearAllPoints(); c.badge:SetPoint("TOPRIGHT", -8, -38)
		end
		-- a click opens the dungeon's panel next to the book; right-click, the quick menu
		c:SetScript("OnClick", function(self, mouse) if mouse == "RightButton" then B.OpenDungeonMenu(self.dungeonId) else ns.DungeonPanel.Open(self.dungeonId) end end)
		c:SetScript("OnEnter", function(self) B.DungeonTooltip(self) end)
		c:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
		c:Hide()
		B.cards[i] = c
	end

	local help = ns.Skin.Button(f)
	help:SetSize(120, 20); help:SetPoint("BOTTOMLEFT", 12, 3); help:SetText(L.BTN_HELP)
	help:SetScript("OnClick", function() ns.Fire("LM_HELP_BUTTON") end)
	B.helpButton = help

	-- Dungeons tab: its own action button in the same spot as "Ask for help".
	local lfg = ns.Skin.Button(f)
	lfg:SetSize(140, 20); lfg:SetPoint("BOTTOMLEFT", 12, 3); lfg:SetText(L.BTN_LFG)
	lfg:SetScript("OnClick", function() ns.Fire("LM_LFG_BUTTON") end)
	B.lfgButton = lfg
	-- Tabs: WoW's classic tabs hanging under the window (as the Dungeon Journal's), so the bottom bar keeps the buttons.
	B.tabs = {}
	local tabList, prevTab = {}, nil
	for i, key in ipairs(B.TAB_KEYS) do
		local b = ns.Skin.Tab(f, "LevelMatesBoardTab" .. i, TAB_ICON[key] == "banner" and ns.Skin.Banner() or TAB_ICON[key], L[TAB_LABELS[key]])
		b:SetID(i)
		-- in the top band, right of the portrait, as the spellbook's
		if prevTab then b:SetPoint("LEFT", prevTab, "RIGHT", 10, 0) else b:SetPoint("TOPLEFT", f, "TOPLEFT", f.gameFrame and 66 or 16, -24) end
		b:SetScript("OnClick", function() B.SetTab(key) end)
		B.tabs[key], tabList[i], prevTab = b, b, b
	end
	f.Tabs = tabList   -- the template's parentArray, set here so the order is ours
	-- the Guild tab's sub-sections: a row of buttons on the subtitle's line
	B.subs = {}
	local prevSub
	for _, key in ipairs(B.GUILD_KEYS) do
		local b = ns.Skin.Button(f)
		b:SetSize(76, 20); b:SetText(L[TAB_LABELS[key]])   -- eight of them on one line
		if prevSub then b:SetPoint("LEFT", prevSub, "RIGHT", 4, 0) else b:SetPoint("TOPLEFT", f, "TOPLEFT", B.MARGIN, -(insetTop + 36)) end
		b:SetScript("OnClick", function() B.SetTab(key) end)
		B.subs[key], prevSub = b, b
	end
	if PanelTemplates_SetNumTabs then PanelTemplates_SetNumTabs(f, #tabList) end
	B.tab = KnownTab(ns.char.boardTab)

	-- Journal tab: clear (bottom left), type filter (bottom right), pager in the help-rows area.
	local clear = ns.Skin.Button(f)
	clear:SetSize(120, 20); clear:SetPoint("BOTTOMLEFT", 12, 3); clear:SetText(L.BTN_J_CLEAR)
	clear:SetScript("OnClick", function() ns.Fire("LM_JOURNAL_CLEAR") end)
	B.journalClear = clear
	local filter = ns.Skin.Button(f)
	filter:SetSize(140, 20); filter:SetPoint("BOTTOMRIGHT", -12, 3)
	filter:SetScript("OnClick", function(self)
		MenuUtil.CreateContextMenu(self, function(_, root)
			for _, kind in ipairs(ns.Journal.FILTERS) do
				root:CreateButton(ns.Journal.FilterName(kind), function() B.journalFilter = kind; B.journalPage = 1; B.Refresh() end)
			end
		end)
	end)
	B.journalFilterButton = filter
	-- Journal tab: "Achievements" (bottom right, left of the filter) swaps the journal for my achievements
	local ach = ns.Skin.Button(f)
	ach:SetSize(120, 20); ach:SetPoint("RIGHT", filter, "LEFT", -8, 0)
	ach:SetScript("OnClick", function() B.journalView = B.journalView ~= "ach" and "ach" or nil; B.journalPage = 1; B.Refresh() end)
	B.journalAchButton = ach
	local prev = ns.Skin.Button(f)
	prev:SetSize(110, 20); prev:SetPoint("BOTTOM", -160, B.BOTTOM + 8); prev:SetText(L.BTN_J_PREV)
	prev:SetScript("OnClick", function() B.TurnPage(-1) end)
	local nextb = ns.Skin.Button(f)
	nextb:SetSize(110, 20); nextb:SetPoint("BOTTOM", 160, B.BOTTOM + 8); nextb:SetText(L.BTN_J_NEXT)
	nextb:SetScript("OnClick", function() B.TurnPage(1) end)
	local pageText = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	pageText:SetPoint("BOTTOM", 0, B.BOTTOM + 12)
	B.journalPrev, B.journalNext, B.journalPageText = prev, nextb, pageText

	-- Goals tab: "New goal" for officers (bottom left).
	local goalNew = ns.Skin.Button(f)
	goalNew:SetSize(120, 20); goalNew:SetPoint("BOTTOMLEFT", 12, 3); goalNew:SetText(L.BTN_GOAL_NEW)
	goalNew:SetScript("OnClick", function() ns.Fire("LM_GOAL_NEW") end)
	B.goalNew = goalNew
	local myGoal = ns.Skin.Button(f)
	myGoal:SetSize(120, 20); myGoal:SetPoint("BOTTOMRIGHT", -12, 3); myGoal:SetText(L.BTN_MYGOAL)
	myGoal:SetScript("OnClick", function() ns.Fire("LM_MYGOAL") end)
	B.myGoal = myGoal

	-- Wishes tab: "Add wish" (bottom left).
	local wishAdd = ns.Skin.Button(f)
	wishAdd:SetSize(120, 20); wishAdd:SetPoint("BOTTOMLEFT", 12, 3); wishAdd:SetText(L.BTN_WISH_ADD)
	wishAdd:SetScript("OnClick", function() ns.Fire("LM_WISH_ADD") end)
	B.wishAdd = wishAdd
	local giftAdd = ns.Skin.Button(f)
	giftAdd:SetSize(120, 20); giftAdd:SetPoint("BOTTOMRIGHT", -12, 3); giftAdd:SetText(L.BTN_GIFT_ADD)
	giftAdd:SetScript("OnClick", function() ns.Fire("LM_GIFT_ADD") end)
	B.giftAdd = giftAdd

	-- Dungeons tab: "Calendar" (bottom right) swaps the cards for the next 7 days of meetups.
	local calendar = ns.Skin.Button(f)
	calendar:SetSize(120, 20); calendar:SetPoint("BOTTOMRIGHT", -12, 3); calendar:SetText(L.BTN_CALENDAR)
	calendar:SetScript("OnClick", function() B.lfgCalendar = not B.lfgCalendar; B.lfgTogether, B.lfgQuests = false, false; B.Refresh() end)
	B.lfgCalendarButton = calendar
	-- "Together": groups the addon suggests from who is online (left of Calendar)
	local together = ns.Skin.Button(f)
	together:SetSize(120, 20); together:SetPoint("RIGHT", calendar, "LEFT", -6, 0); together:SetText(L.BTN_TOGETHER)
	together:SetScript("OnClick", function() B.lfgTogether = not B.lfgTogether; B.lfgCalendar, B.lfgQuests = false, false; B.Refresh() end)
	B.togetherButton = together
	-- "Quests": the guild quest board (left of Together); its filter and "Search for a quest" take the bottom left
	local quests = ns.Skin.Button(f)
	quests:SetSize(120, 20); quests:SetPoint("RIGHT", together, "LEFT", -6, 0); quests:SetText(L.BTN_QUESTS)
	quests:SetScript("OnClick", function() B.lfgQuests = not B.lfgQuests; B.lfgCalendar, B.lfgTogether = false, false; B.Refresh() end)
	B.questsButton = quests
	B.questFilter = "all"
	local FILTERS = { "all", "zone", "level", "group" }
	local filterB = ns.Skin.Button(f)
	filterB:SetSize(140, 20); filterB:SetPoint("BOTTOMLEFT", 12, 3)
	filterB:SetScript("OnClick", function()
		for i, k in ipairs(FILTERS) do if k == B.questFilter then B.questFilter = FILTERS[i % #FILTERS + 1]; break end end
		B.Refresh()
	end)
	B.questFilterButton = filterB
	local postB = ns.Skin.Button(f)
	postB:SetSize(130, 20); postB:SetPoint("LEFT", filterB, "RIGHT", 6, 0); postB:SetText(L.QH_POST_BUTTON)
	postB:SetScript("OnClick", function(self)
		MenuUtil.CreateContextMenu(self, function(_, root)
			root:CreateTitle(L.QH_POST_BUTTON)
			for _, q in ipairs(ns.Questhub.MyQuests()) do
				root:CreateButton(q.title, function() ns.Questhub.Toggle(q.id); B.Refresh() end)
			end
		end)
	end)
	B.questPostButton = postB
	-- Members: the view (List / History / Alts / Race) and, in the list, the filter (bottom left)
	B.membersView, B.memberFilter = "list", "all"
	local VIEWS, MFILTERS = { "list", "history", "alts", "race" }, { "all", "online", "officers", "nonote" }
	local viewB = ns.Skin.Button(f)
	viewB:SetSize(130, 20); viewB:SetPoint("BOTTOMLEFT", 12, 3)
	viewB:SetScript("OnClick", function()
		for i, k in ipairs(VIEWS) do if k == B.membersView then B.membersView = VIEWS[i % #VIEWS + 1]; break end end
		B.memberPage = 1; B.Refresh()
	end)
	B.memberViewButton = viewB
	local mfB = ns.Skin.Button(f)
	mfB:SetSize(130, 20); mfB:SetPoint("LEFT", viewB, "RIGHT", 6, 0)
	mfB:SetScript("OnClick", function()
		for i, k in ipairs(MFILTERS) do if k == B.memberFilter then B.memberFilter = MFILTERS[i % #MFILTERS + 1]; break end end
		B.memberPage = 1; B.Refresh()
	end)
	B.memberFilterButton = mfB
	-- "My role: Tank Healer Damage" (bottom left of the Groups tab)
	local roleLine = CreateFrame("Frame", nil, f)
	roleLine:SetSize(260, 20); roleLine:SetPoint("BOTTOMLEFT", 12, 3)
	roleLine.label = roleLine:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	roleLine.label:SetPoint("LEFT", 0, 0); roleLine.label:SetText(L.RUN_MY_ROLE)
	B.roleButtons = {}
	for i, role in ipairs({ "T", "H", "D" }) do
		local b = ns.Skin.Button(roleLine)
		b:SetSize(62, 20); b:SetPoint("LEFT", 64 + (i - 1) * 64, 0); b:SetText(L["ROLE_" .. role])
		b:SetScript("OnClick", function() ns.Roles.Set(role); B.Refresh() end)
		B.roleButtons[role] = b
	end
	B.roleLine = roleLine

	-- Wall: "Cemetery" (bottom right) shows only deaths; a second click shows everything again.
	local cemetery = ns.Skin.Button(f)
	cemetery:SetSize(120, 20); cemetery:SetPoint("BOTTOMRIGHT", -12, 3); cemetery:SetText(L.BTN_CEMETERY)
	cemetery:SetScript("OnClick", function() B.feedDeaths = not B.feedDeaths; B.feedPage = 1; B.Refresh() end)
	B.feedCemetery = cemetery

	-- Class tab: "Share macro" (bottom left) lists my macros; a click shares or withdraws one.
	local classShare = ns.Skin.Button(f)
	classShare:SetSize(140, 20); classShare:SetPoint("BOTTOMLEFT", 12, 3); classShare:SetText(L.BTN_SHARE_MACRO)
	classShare:SetScript("OnClick", function(self) B.OpenShareMacroMenu(self) end)
	B.classShare = classShare
	local classAsk = ns.Skin.Button(f)
	classAsk:SetSize(160, 20); classAsk:SetPoint("BOTTOMRIGHT", -12, 3); classAsk:SetText(L.BTN_ASK)
	classAsk:SetScript("OnClick", function() ns.Ask.OpenBox() end)
	B.classAsk = classAsk

	-- Recruit tab (officers): three templates, which one, the channel, a preview, the status and Publish.
	local rp = CreateFrame("Frame", nil, f)
	rp:SetPoint("TOPLEFT", B.MARGIN, -B.TOP); rp:SetSize(B.WIDTH - 2 * B.MARGIN, 300); rp:Hide()
	B.recruitPanel, B.recruitEdit, B.recruitUse, B.recruitChannel, B.recruitLabels = rp, {}, {}, {}, {}
	for i = 1, 3 do
		local use = CreateFrame("CheckButton", nil, rp, "UICheckButtonTemplate")
		use:SetSize(22, 22); use:SetPoint("TOPLEFT", 0, -(i - 1) * 34)
		use:SetScript("OnClick", function() ns.char.recruitTemplate = i; B.Refresh() end)
		local edit = CreateFrame("EditBox", nil, rp, "InputBoxTemplate")
		edit:SetSize(B.WIDTH - 2 * B.MARGIN - 40, 22); edit:SetPoint("LEFT", use, "RIGHT", 10, 0); edit:SetAutoFocus(false); edit:SetMaxLetters(200)
		local function save(self) ns.Recruit.SetTemplate(i, self:GetText()); self:ClearFocus() end
		edit:SetScript("OnEnterPressed", save); edit:SetScript("OnEditFocusLost", save)
		B.recruitUse[i], B.recruitEdit[i] = use, edit
	end
	for k, ch in ipairs({ 2, 1 }) do
		local cb = CreateFrame("CheckButton", nil, rp, "UICheckButtonTemplate")
		cb:SetSize(22, 22); cb:SetPoint("TOPLEFT", (k - 1) * 220, -110)
		cb:SetScript("OnClick", function() ns.char.recruitChannel = ch; B.Refresh() end)
		local label = rp:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		label:SetPoint("LEFT", cb, "RIGHT", 2, 0); label:SetText(L["RECRUIT_CHANNEL_" .. ch])
		table.insert(B.recruitLabels, label)
		B.recruitChannel[ch] = cb
	end
	local preview = rp:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	preview:SetPoint("TOPLEFT", 4, -146); preview:SetWidth(B.WIDTH - 2 * B.MARGIN - 8); preview:SetJustifyH("LEFT"); preview:SetTextColor(1, 0.75, 0.75)
	B.recruitPreview = preview
	local status = rp:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	status:SetPoint("TOPLEFT", 4, -200); status:SetJustifyH("LEFT"); status:SetTextColor(0.7, 0.7, 0.7)
	B.recruitStatus = status
	local post = ns.Skin.Button(rp)
	post:SetSize(140, 24); post:SetPoint("TOPLEFT", 0, -226); post:SetText(L.RECRUIT_POST)
	post:SetScript("OnClick", function()   -- the only place recruitment reaches a public channel: a click
		for i = 1, 3 do ns.Recruit.SetTemplate(i, B.recruitEdit[i]:GetText()) end   -- what is typed, even without Enter
		local text, ch = ns.Recruit.Prepare(ns.char.recruitTemplate or 1, ns.char.recruitChannel or 2)
		if text then SendChatMessage(text, "CHANNEL", nil, ch); ns.Recruit.Posted() end
	end)
	B.recruitPost = post
	local remind = CreateFrame("CheckButton", nil, rp, "UICheckButtonTemplate")
	remind:SetSize(22, 22); remind:SetPoint("LEFT", post, "RIGHT", 20, 0)
	remind:SetScript("OnClick", function(self) ns.char.recruitRemind = self:GetChecked() and true or false end)
	local remindLabel = rp:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	table.insert(B.recruitLabels, remindLabel)
	remindLabel:SetPoint("LEFT", remind, "RIGHT", 2, 0); remindLabel:SetText(L.RECRUIT_REMIND)
	B.recruitRemind = remind
	-- Recruit tab: "Inactive" (bottom left) swaps the templates for members who have not logged in; 14 or 30 days.
	local view = ns.Skin.Button(f)
	view:SetSize(120, 20); view:SetPoint("BOTTOMLEFT", 12, 3); view:SetText(L.BTN_INACTIVE)
	view:SetScript("OnClick", function() B.recruitView = B.recruitView ~= "inactive" and "inactive" or nil; B.recruitPage = 1; if B.recruitView then ns.Inactive.Scan() end; B.Refresh() end)
	B.recruitViewButton = view
	local days = ns.Skin.Button(f)
	days:SetSize(120, 20); days:SetPoint("BOTTOMRIGHT", -12, 3)
	days:SetScript("OnClick", function() ns.char.inactiveDays = (ns.char.inactiveDays or 14) == 14 and 30 or 14; B.recruitPage = 1; B.Refresh() end)
	B.recruitDaysButton = days

	-- active help requests, above the help button; "On my way" whispers only from its click
	B.helpRows = {}
	for i = 1, HELP_ROWS do
		local text = Col(f, B.WIDTH - 110)
		text:SetPoint("BOTTOMLEFT", 12, B.BOTTOM + 8 + (i - 1) * ROW_H)
		local btn = ns.Skin.Button(f)
		btn:SetSize(60, ROW_H); btn:SetPoint("LEFT", text, "RIGHT", 4, 0); btn:SetText(L.BTN_COMING)
		btn:SetScript("OnClick", function(self) if self.helpId then ns.Help.Coming(self.helpId) end end)
		B.helpRows[i] = { text = text, button = btn }
	end
	-- dark ink for every text written on the parchment
	local Ink = ns.Skin.InkFont
	Ink(B.heading); Ink(B.restedText); Ink(B.subtitle); Ink(f.empty); Ink(B.journalPageText); Ink(B.palLabel)   -- not nearLabel: it sits on the dark bar under the page
	for _, label in ipairs(B.recruitLabels) do Ink(label) end
	for _, fs in ipairs(B.headText) do Ink(fs) end
	for _, r in ipairs(B.rows) do Ink(r.name); Ink(r.level); Ink(r.zone); Ink(r.group); Ink(r.xph) end
	for _, hr in ipairs(B.helpRows) do Ink(hr.text) end
	Ink(B.recruitPreview); Ink(B.recruitStatus)
	B.heading:SetTextColor(1, 0.82, 0); B.restedText:SetTextColor(0.6, 0.8, 1); B.subtitle:SetTextColor(0.8, 0.8, 0.8)
	ns.Skin.InkPass()
end

-- `skip`: rows at the foot left to the pager (a long Mates list); the requests go in the ones above.
local function RefreshHelp(skip)
	skip = skip or 0
	local H = ns.Help
	local ids = H and H.List() or {}
	for i = 1, HELP_ROWS do
		local row, id = B.helpRows[i], i > skip and ids[i - skip] or nil
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
	if B.tab == "home" then for i = 1, 5 do B.headText[i]:SetText("") end; return end
	if B.tab == "recruit" then
		if B.recruitView == "inactive" then
			B.headText[1]:SetText(L.COL_NAME); B.headText[2]:SetText(L.COL_LEVEL); B.headText[3]:SetText(L.COL_RANK_GUILD)
			B.headText[4]:SetText(L.COL_AWAY); B.headText[5]:SetText(L.COL_JOINED)
			for i = 1, 5 do B.headText[i]:SetTextColor(1, 0.82, 0) end
		else
			for i = 1, 5 do B.headText[i]:SetText("") end
		end
		return
	end
	if B.tab == "class" then
		B.headText[1]:SetText(""); B.headText[2]:SetText(""); B.headText[3]:SetText(""); B.headText[4]:SetText(L.COL_LEVEL); B.headText[5]:SetText("")
		for i = 1, 5 do B.headText[i]:SetTextColor(1, 0.82, 0) end
		return
	end
	if B.tab == "feed" then
		B.headText[1]:SetText(L.COL_WHO); B.headText[2]:SetText(""); B.headText[3]:SetText(L.COL_WHAT)
		B.headText[4]:SetText(""); B.headText[5]:SetText(L.COL_WHEN)
		for i = 1, 5 do B.headText[i]:SetTextColor(1, 0.82, 0) end
		return
	end
	if B.tab == "crafts" then
		B.headText[1]:SetText(L.COL_WHO); B.headText[2]:SetText(""); B.headText[3]:SetText(L.COL_PROFESSION)
		B.headText[4]:SetText(L.COL_RANK); B.headText[5]:SetText(L.COL_SEEN)
		B.headText[3]:SetText(L.COL_PROGRESS)
		for i = 1, 5 do B.headText[i]:SetTextColor(1, 0.82, 0) end
		return
	end
	if B.tab == "wishes" then
		B.headText[1]:SetText(L.COL_WHO); B.headText[2]:SetText(""); B.headText[3]:SetText(L.COL_ITEM)
		B.headText[4]:SetText(L.COL_KIND); B.headText[5]:SetText(L.COL_SINCE)
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
	if tint then r.bg:SetColorTexture(unpack(B.PAL_TINT))
	elseif ns.Skin.On() then r.bg:SetColorTexture(0, 0, 0, 0); if r.stripe then r.stripe:Show() end   -- a thin line under each row, as the spellbook's lists
	else r.bg:SetColorTexture(1, 1, 1, i % 2 == 0 and 0.06 or 0) end
end

-- A section header row: in this style the character sheet's plaque with the text centred in white.
local function SectionHeader(r)
	if r.plaque then
		r.bg:SetColorTexture(0, 0, 0, 0); r.stripe:Hide(); r.plaque:Show()   -- a soft band, the section's name and count
		r.name:SetWidth(ROW_W - (ROW_H - 4) - 4); r.name:SetTextColor(1, 0.82, 0)
		r.button.tall = true
	else
		r.bg:SetColorTexture(1, 0.82, 0, 0.08)
	end
end

-- Bars grow smoothly (half a second) when their value changes on the page being looked at; the final width is set
-- at once, the frames in between draw the growth.
local growing, animator = {}, nil
local function GrowStep()
	local now, any = GetTime(), false
	for tex, a in pairs(growing) do
		local p = (now - a[3]) / 0.5
		if p >= 1 then tex:SetWidth(a[2]); growing[tex] = nil
		else tex:SetWidth(a[1] + (a[2] - a[1]) * (1 - (1 - p) * (1 - p))); any = true end
	end
	if not any then animator:SetScript("OnUpdate", nil) end
end
function B.Grow(tex, width)
	local from = tex.lmW
	tex:SetWidth(width); tex.lmW = width
	if from and math.abs(from - width) > 1 then
		animator = animator or CreateFrame("Frame")
		growing[tex] = { from, width, GetTime() }
		animator:SetScript("OnUpdate", GrowStep)
	end
end
-- A new page: its bars start where they are, no growth from the previous page's values.
local function ResetBars() for _, r in ipairs(B.rows or {}) do r.barFill.lmW = nil; growing[r.barFill] = nil end end

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
-- Each tab's column widths, stretched to the page: the same proportions however wide the book is.
local function SetColumns(widths)
	local sum = 0
	for _, w in ipairs(widths) do sum = sum + w end
	local k = (B.WIDTH - 2 * B.MARGIN - (#widths - 1) * B.GAP) / sum
	local scaled = {}
	for i, w in ipairs(widths) do scaled[i] = math.floor(w * k) end
	widths = scaled
	for i, w in ipairs(widths) do B.headText[i]:SetWidth(w) end
	for _, r in ipairs(B.rows) do
		r.name:SetWidth(widths[1] - (ROW_H - 4) - 4); r.level:SetWidth(widths[2]); r.zone:SetWidth(widths[3])
		r.name:SetJustifyH("LEFT"); r.button.tall = nil; if r.plaque then r.plaque:Hide() end   -- a section header (plaque) is set again by its fill
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
			r.name:SetText(g.name); if g.mine then r.name:SetTextColor(ClassColor(MyClass())) else r.name:SetTextColor(1, 1, 1) end
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
		root:CreateButton(L.GOAL_DELETE, function() ns.Confirm(L.CONFIRM_GOAL, function() ns.Goals.Delete(id) end) end)
	end)
end

local function FillFeed(list)
	for i = 1, ROWS do
		local r, e = B.rows[i], list[i]
		r.button.mate, r.button.adId, r.button.entry, r.button.goalId, r.button.personalMine = nil, nil, nil, nil, nil
		r.button.feedItem = e and e.k == "itm" and e.a or nil
		if e then
			local m = R.mates[e.who]
			r.icon:Hide()
			r.name:SetText(ns.Feed.Who(e))
			if e.k == "gol" then r.name:SetTextColor(1, 0.82, 0)
			elseif e.who == ns.Me() then r.name:SetTextColor(ClassColor(MyClass()))
			else r.name:SetTextColor(ClassColor(m and m.class)) end
			r.level:SetText("")
			r.zone:SetText(ns.Feed.Text(e)); r.zone:SetTextColor(1, 1, 1)
			r.group:SetText("")
			r.xph:SetText(ns.Feed.Ago(e)); r.xph:SetTextColor(0.7, 0.7, 0.7)
			r.button:Show()
			RowBg(r, i, false)
		else
			ClearRow(r)
		end
	end
end

local function FillCrafts(list)
	for i = 1, ROWS do
		local r, c = B.rows[i], list[i]
		r.button.mate, r.button.adId, r.button.entry, r.button.goalId, r.button.personalMine = nil, nil, nil, nil, nil
		r.button.craftItem, r.button.crafter, r.button.recipeItem, r.button.recipesHeader = c and c.craftItem, c and c.crafter, c and c.recipeItem, c and c.recipesHeader
		r.button.entryItem = c and c.item
		r.button.craftHeader = c and c.header or nil
		r.button.craftName, r.button.craftMine = c and not c.header and c.name or nil, c and c.mine or nil
		r.barBg:Hide(); r.barFill:Hide()
		if c and (c.craftItem or c.recipesHeader) then   -- "who crafts [item]", or someone's recipes of a profession
			r.icon:Hide()
			r.name:SetText(c.craftItem and string.format(L.RC_WHO, ns.Recipes.Link(c.craftItem)) or c.recipesHeader); r.name:SetTextColor(1, 0.82, 0)
			r.level:SetText(""); r.zone:SetText(""); r.group:SetText(""); r.xph:SetText(c.recipesHeader and L.RC_BACK or "")
			r.button:Show()
			SectionHeader(r)
		elseif c and c.crafter then   -- someone who crafts it: profession and rank, online or when last seen
			local w = c.crafter
			r.icon:Hide()
			r.name:SetText("   " .. w.name); r.name:SetTextColor(1, 1, 1)
			r.level:SetText(""); r.zone:SetText(ns.Professions.Name(w.line) .. " " .. w.r .. "/" .. w.m); r.zone:SetTextColor(0.8, 0.8, 0.8)
			r.group:SetText("")
			if w.online then r.xph:SetText(L.ONLINE); r.xph:SetTextColor(unpack(B.GROUP_COLORS.open))
			else r.xph:SetText(string.format(L.FEED_AGO, ns.Journal.Duration(math.max(0, GetServerTime() - (w.t or 0))))); r.xph:SetTextColor(0.7, 0.7, 0.7) end
			r.button:Show()
			RowBg(r, i, false)
		elseif c and c.recipeItem then   -- one of their recipes
			r.icon:Hide()
			r.name:SetText("   " .. ns.Recipes.Link(c.recipeItem)); r.name:SetTextColor(1, 1, 1)
			r.level:SetText(""); r.zone:SetText(""); r.group:SetText(""); r.xph:SetText("")
			r.button:Show()
			RowBg(r, i, false)
		elseif c and c.header then   -- the profession: icon, name and how many have it
			r.icon:SetTexture(ns.Professions.Icon(c.header)); r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92); r.icon:Show()
			r.name:SetText(ns.Professions.Name(c.header) .. " (" .. c.count .. ")"); r.name:SetTextColor(1, 0.82, 0)
			r.level:SetText(""); r.zone:SetText(""); r.group:SetText(""); r.xph:SetText("")
			r.button:Show()
			SectionHeader(r)
		elseif c then
			local m = R.mates[c.name]
			r.icon:Hide()
			r.name:SetText("   " .. c.name); r.name:SetTextColor(ClassColor(c.mine and MyClass() or m and m.class))
			r.level:SetText("")
			r.zone:SetText("")
			r.barBg:ClearAllPoints(); r.barBg:SetPoint("LEFT", r.zone, "LEFT", 0, 0); r.barBg:Show()
			r.barFill:ClearAllPoints(); r.barFill:SetPoint("LEFT", r.zone, "LEFT", 0, 0)
			B.Grow(r.barFill, math.max(1, B.BAR_W * math.min(1, c.rank / (c.max or c.rank)))); r.barFill:Show()
			r.group:SetText(c.max and (c.rank .. "/" .. c.max) or tostring(c.rank)); r.group:SetTextColor(1, 1, 1)
			if c.mine then r.xph:SetText("")
			elseif m then r.xph:SetText(L.ONLINE); r.xph:SetTextColor(unpack(B.GROUP_COLORS.open))
			else r.xph:SetText(string.format(L.FEED_AGO, ns.Journal.Duration(math.max(0, time() - c.t)))); r.xph:SetTextColor(0.7, 0.7, 0.7) end
			local hint = ns.Professions.TrainHint(c.rank, c.max)   -- at the top of a rank: who to visit
			if hint then local was = r.xph:GetText() or ""; r.xph:SetText((was ~= "" and (was .. " · ") or "") .. hint); r.xph:SetTextColor(1, 0.6, 0.2) end
			r.button:Show()
			RowBg(r, i, false)
		else
			ClearRow(r)
		end
	end
end

-- item: when the row is "who crafts [item]", the menu offers to ask for it.
function B.OpenCraftMenu(name, item)
	MenuUtil.CreateContextMenu(B.frame, function(_, root)
		root:CreateTitle(name)
		if item and name ~= ns.Me() then root:CreateButton(string.format(L.RC_ASK_MENU, ns.Recipes.Link(item)), function() ns.Recipes.Ask(name, item) end) end
		root:CreateButton(L.RC_THEIR_RECIPES, function() B.recipesOf = name; B.craftPage = 1; B.Refresh() end)
		if name ~= ns.Me() then
			root:CreateButton(L.MENU_WHISPER, function() B.Whisper(name) end)
			if R.mates[name] then root:CreateButton(L.MENU_INVITE, function() B.Invite(name) end) end
		end
	end)
end

-- The Crafts tab: someone's recipes (after "Their recipes"); otherwise who crafts what the search names, then the
-- professions as always.
local function CraftsVisible()
	local out = {}
	if B.recipesOf then
		for line, e in pairs(ns.Recipes.Of(B.recipesOf)) do
			out[#out + 1] = { recipesHeader = string.format(L.RC_THEIRS, B.recipesOf, ns.Professions.Name(line)), line = line }
			for _, item in ipairs(e.items or {}) do out[#out + 1] = { recipeItem = item } end
		end
		if #out == 0 then out[1] = { recipesHeader = string.format(L.RC_NONE, B.recipesOf) } end
		return out
	end
	if B.search and B.search ~= "" then
		for _, item in ipairs(ns.Recipes.Find(B.search)) do
			out[#out + 1] = { craftItem = item }
			for _, w in ipairs(ns.Recipes.WhoCrafts(item)) do out[#out + 1] = { crafter = w, item = item } end
		end
	end
	for _, row in ipairs(ns.Professions.Groups(B.search)) do out[#out + 1] = row end
	return out
end

local function FillWishes(list)
	for i = 1, ROWS do
		local r, w = B.rows[i], list[i]
		r.button.mate, r.button.adId, r.button.entry, r.button.goalId, r.button.personalMine = nil, nil, nil, nil, nil
		r.button.wishId, r.button.wishMine, r.button.wishKind, r.button.wishName = w and w.id or nil, w and w.mine or nil, w and w.kind or nil, w and w.name or nil
		if w then
			r.icon:Hide()
			r.name:SetText(w.name); if w.mine then r.name:SetTextColor(ClassColor(MyClass())) else r.name:SetTextColor(0.7, 0.7, 0.7) end
			r.level:SetText("")
			local item = ns.Wishlist.Link(w.id) or string.format(L.WISH_UNKNOWN, w.id)
			if w.reservedBy then item = item .. "  " .. string.format(L.GIFT_RESERVED_BY, w.reservedBy) end
			r.zone:SetText(item); r.zone:SetTextColor(1, 1, 1)
			r.group:SetText(w.kind == "give" and (w.price and ns.Gifts.Money(w.price) or L.GIVES) or L.WANTS)
			r.group:SetTextColor(unpack(w.kind == "give" and { 1, 0.82, 0 } or { 0.4, 1, 0.4 }))
			r.xph:SetText(date("%d/%m", w.t)); r.xph:SetTextColor(0.7, 0.7, 0.7)
			r.button:Show()
			RowBg(r, i, false)
		else
			ClearRow(r)
		end
	end
end

function B.OpenWishMenu(id, kind, mine, name)
	if kind == "give" then
		if mine then
			MenuUtil.CreateContextMenu(B.frame, function(_, root) root:CreateButton(L.GIFT_REMOVE, function() ns.Confirm(L.CONFIRM_OFFER, function() ns.Gifts.Remove(id) end) end) end)
		else
			local row
			for _, g in ipairs(ns.Gifts.List()) do if g.name == name and g.id == id then row = g end end
			if row and not row.reservedBy and R.mates[name] then   -- the giver confirms: online only
				MenuUtil.CreateContextMenu(B.frame, function(_, root) root:CreateButton(row.price and L.GIFT_BUY or L.GIFT_RESERVE, function() ns.Gifts.Reserve(name, id) end) end)
			end
		end
		return
	end
	if not mine or not ns.Wishlist.Has(id) then return end
	MenuUtil.CreateContextMenu(B.frame, function(_, root)
		root:CreateButton(L.WISH_REMOVE, function() ns.Confirm(L.CONFIRM_WISH, function() ns.Wishlist.Remove(id) end) end)
	end)
end

-- Dungeons tab: the ads for a dungeon (mine first), the visible cards, and filling them.
function B.AdsFor(id)
	local out, LFG = {}, ns.LFG
	if LFG.mine and LFG.mine.d == id then out[1] = { name = ns.Me(), r = LFG.mine.r, n = LFG.mine.n, mine = true, joined = LFG.mine.joined, id = LFG.mine.id } end
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
		if not match then for _, a in ipairs(ns.ChatAds.For(d.id)) do if a.name:lower():find(q, 1, true) then match = true end end end
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
			if tex and c.skin then   -- a taller picture: the same scene, more of it, so it is not stretched
				local mid = (coords[3] + coords[4]) / 2
				c.art:SetTexture(tex); c.art:SetTexCoord(coords[1], coords[2], math.max(0, mid - 0.31), math.min(1, mid + 0.31)); c.art:SetAlpha(c.fits and 1 or 0.55); c.art:Show()
			elseif tex then c.art:SetTexture(tex); c.art:SetTexCoord(unpack(coords)); c.art:SetAlpha(c.fits and 1 or 0.45); c.art:Show() else c.art:Hide() end
			if c.skin then c:SetBackdropBorderColor(unpack(c.fits and ns.Skin.C.card or ns.Skin.C.cardDim))
			else c.bg:SetColorTexture(unpack(c.fits and { 0.35, 0.27, 0.05, 0.9 } or { 0.08, 0.08, 0.08, 0.9 })) end
			c.name:SetText(ns.Dungeons.Name(id)); c.name:SetTextColor(unpack(c.fits and { 1, 0.82, 0 } or { 0.75, 0.75, 0.75 }))
			c.levels:SetText(string.format(c.skin and L.CARD_LEVELS or "%d-%d", d.min, d.max))
			local count, chat = #ads == 0 and "" or #ads == 1 and L.LFG_SEARCHING_ONE or string.format(L.LFG_SEARCHING, #ads), #ns.ChatAds.For(id)
			if chat > 0 then count = count .. (count ~= "" and " · " or "") .. string.format(L.CHAT_ADS, chat) end
			c.count:SetText(count)
			local meet = ns.Meetups.List(id)[1]
			if meet then
				c.badge:SetText(ns.Meetups.When(meet) .. " · " .. ns.Meetups.Count(meet) .. "/5"); c.badge:Show()
			else
				c.badge:SetText(""); c.badge:Hide()
			end
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
	for _, a in ipairs(ns.ChatAds.For(d.id)) do
		GameTooltip:AddLine(string.format(L.CHAT_AD_LINE, a.name, a.text, ns.Journal.Duration(math.max(0, math.floor(GetTime() - a.t)))), 0.8, 0.8, 0.8, true)
	end
	for _, m in ipairs(ns.Meetups.List(d.id)) do
		local who = {}
		for name, role in pairs(m.joined or {}) do who[#who + 1] = name .. " (" .. L["ROLE_" .. role] .. ")" end
		table.sort(who)
		GameTooltip:AddLine(string.format(L.MEET_LINE, ns.Meetups.When(m), m.by) .. (m.n and (": " .. m.n) or ""), 0.6, 0.8, 1, true)
		if #who > 0 then GameTooltip:AddLine("   " .. string.format(L.LFJ_JOINED, table.concat(who, ", ")), 0.4, 1, 0.4, true) end
	end
	GameTooltip:Show()
end

-- Journal tab, achievements view: earned ones with their date, the rest with their progress.
local function FillAch(list)
	local AC = ns.Achievements
	for i = 1, ROWS do
		local r, a = B.rows[i], list[i]
		r.button.mate, r.button.adId, r.button.entry, r.button.ach = nil, nil, nil, a
		if a then
			local has = AC.Has(a.id)
			r.icon:SetTexture(AC.Icon(a.id)); r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92); r.icon:SetDesaturated(not has); r.icon:Show()
			r.name:SetText(AC.Name(a.id)); r.name:SetTextColor(unpack(has and { 1, 0.82, 0 } or { 0.7, 0.7, 0.7 }))
			r.level:SetText("")
			r.zone:SetText(AC.Desc(a.id)); r.zone:SetTextColor(1, 1, 1)
			if a.cat == "ch" then r.group:SetText(has and "1/1" or "0/1") else r.group:SetText(AC.Progress(a.id) .. "/" .. a.n) end
			r.group:SetTextColor(1, 1, 1)
			r.xph:SetText(has and date("%d/%m/%y", AC.When(a.id)) or ""); r.xph:SetTextColor(0.4, 1, 0.4)
			r.button:Show()
			RowBg(r, i, false)
		else
			ClearRow(r)
		end
	end
end

-- Home: the guild, what is happening now, what is for me, this week.
local HOME_ICON = { level = "banner", challenge = "Interface/Icons/INV_Misc_Map_01", help = "Interface/Icons/Spell_Holy_Heal", lfg = "Interface/Icons/INV_Misc_Key_03",
	meet = "Interface/Icons/INV_Misc_PocketWatch_01", gift = "Interface/Icons/INV_Misc_Bag_10", trainer = "Interface/Icons/INV_Misc_Book_09", rank = "Interface/Icons/INV_Misc_Coin_01", invite = "Interface/Icons/INV_Letter_15" }
local HOME_COLOR = { guild = { 1, 0.82, 0 }, now = { 0.4, 1, 0.4 }, foryou = { 1, 0.82, 0 }, week = { 0.6, 0.8, 1 } }
local function FillHome(list)
	for i = 1, ROWS do
		local r, e = B.rows[i], list[i]
		r.button.mate, r.button.adId, r.button.homeEntry = nil, nil, e
		r.barBg:Hide(); r.barFill:Hide()
		if e and e.header then
			r.icon:Hide()
			r.name:SetText(L["HOME_" .. e.header:upper()] .. (e.count and ("  •  " .. e.count) or ""))
			SectionHeader(r)
			r.name:SetTextColor(unpack(HOME_COLOR[e.header] or { 1, 0.82, 0 }))
			r.level:SetText(""); r.zone:SetText(""); r.group:SetText(""); r.xph:SetText("")
			r.button:Show()
		elseif e then
			local m = e.name and R.mates[e.name]
			local ic = HOME_ICON[e.kind]   -- each kind of row with its own icon (the mate row shows its class below)
			if ic then r.icon:SetTexture(ic == "banner" and ns.Skin.Banner() or ic); r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92); r.icon:Show() else r.icon:Hide() end
			r.level:SetText(""); r.zone:SetTextColor(1, 1, 1); r.group:SetTextColor(1, 1, 1); r.xph:SetTextColor(0.4, 1, 0.4)
			r.name:SetTextColor(1, 1, 1)
			local action = ""
			if e.kind == "level" or e.kind == "challenge" then   -- a bar across the details column
				local have, goal = e.kind == "level" and e.into or e.have, e.kind == "level" and e.need or e.goal
				r.name:SetText(e.kind == "level" and string.format(L.HOME_LEVEL, e.level) or e.text); r.name:SetTextColor(1, 0.82, 0)
				r.zone:SetText("")
				r.barBg:ClearAllPoints(); r.barBg:SetPoint("LEFT", r.zone, "LEFT", 0, 0); r.barBg:Show()
				r.barFill:ClearAllPoints(); r.barFill:SetPoint("LEFT", r.zone, "LEFT", 0, 0)
				B.Grow(r.barFill, math.max(1, B.BAR_W * math.min(1, have / math.max(1, goal)))); r.barFill:Show()
				r.group:SetText(have .. "/" .. goal)
				if e.kind == "challenge" and e.done then action = L.HOME_DONE end
			elseif e.kind == "motd" then
				r.icon:SetTexture("Interface/Icons/INV_Letter_15"); r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92); r.icon:Show()
				r.name:SetText(e.by); r.name:SetTextColor(1, 0.82, 0)
				r.zone:SetText(e.text); r.zone:SetTextColor(1, 1, 1)
			elseif e.kind == "help" then
				local info = e.zone and C_Map.GetMapInfo(e.zone)
				r.name:SetText(e.name); r.name:SetTextColor(ClassColor(m and m.class))
				r.zone:SetText(e.text .. (info and ("  ·  " .. info.name) or "")); r.zone:SetTextColor(1, 0.5, 0.4)
				action = L.HOME_GO
			elseif e.kind == "lfg" then
				r.name:SetText(e.name); r.name:SetTextColor(ClassColor(m and m.class))
				r.zone:SetText(ns.Dungeons.Name(e.dungeon) .. "  ·  " .. ns.LFG.RolesShort(e.roles))
				action = L.HOME_JOIN
			elseif e.kind == "meet" then
				r.name:SetText(e.meet.by)
				r.zone:SetText(ns.Dungeons.Name(e.meet.d) .. "  ·  " .. ns.Meetups.When(e.meet))
				action = L.HOME_SEE
			elseif e.kind == "mate" then
				SetClassIcon(r.icon, m and m.class)
				if not r.icon:IsShown() then r.icon:SetTexture("Interface/Icons/Spell_Holy_PrayerOfFortitude"); r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92); r.icon:Show() end   -- class not known yet
				r.name:SetText(e.name); r.name:SetTextColor(ClassColor(m and m.class))
				local info = m and m.mapId and C_Map.GetMapInfo(m.mapId)
				r.zone:SetText(string.format(L.LEVEL_N, m and m.level or 0) .. (info and ("  ·  " .. info.name) or ""))
				action = L.HOME_INVITE
			elseif e.kind == "gift" then
				r.name:SetText(e.name); r.name:SetTextColor(ClassColor(m and m.class))
				r.zone:SetText((ns.Wishlist.Link(e.id) or string.format(L.WISH_UNKNOWN, e.id)) .. "  ·  " .. (e.price and ns.Gifts.Money(e.price) or L.GIVES))
				action = e.price and L.HOME_BUY or L.HOME_RESERVE
			elseif e.kind == "trainer" then
				r.icon:SetTexture("Interface\\Icons\\INV_Misc_Book_09"); r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92); r.icon:Show()
				r.name:SetText(string.format(L.HOME_TRAINER, e.n)); r.zone:SetText(e.names)
			elseif e.kind == "rank" then
				r.name:SetText(L["HOME_RANK_" .. e.cat]); r.name:SetTextColor(0.6, 0.8, 1)
				local parts = {}
				for k, t in ipairs(e.top) do parts[#parts + 1] = k .. ". " .. t.name .. " (" .. t.n .. ")" end
				r.zone:SetText(table.concat(parts, "   "))
			elseif e.kind == "invite" then
				r.name:SetText(L.HOME_ALONE_TITLE); r.name:SetTextColor(1, 0.82, 0)
				r.zone:SetText(L.HOME_ALONE)
				action = L.HOME_COPY
			end
			r.xph:SetText(action)
			r.button:Show()
			RowBg(r, i, false)
		else
			ClearRow(r)
		end
	end
end

-- A Home row's click does its thing (each one only from this click).
function B.HomeAction(e)
	if e.kind == "help" then ns.Help.Coming(e.id)
	elseif e.kind == "lfg" then ns.DungeonPanel.Open(e.dungeon)
	elseif e.kind == "meet" then B.OpenMeetMenu(e.meet)
	elseif e.kind == "mate" then B.OpenMenu(e.name)
	elseif e.kind == "gift" then B.OpenWishMenu(e.id, "give", false, e.name)
	elseif e.kind == "invite" then ns.DiscordCopy.OpenText(ns.Home.InviteText())
	elseif e.kind == "level" or e.kind == "challenge" or e.kind == "rank" then B.SetTab("feed")
	end
end

-- Recruit tab, inactive view.
local function FillInactive(list)
	for i = 1, ROWS do
		local r, e = B.rows[i], list[i]
		r.button.mate, r.button.adId = nil, nil
		if e then
			r.icon:Hide()
			r.name:SetText(e.name); r.name:SetTextColor(1, 1, 1)
			r.level:SetText(tostring(e.level)); r.level:SetTextColor(0.75, 0.75, 0.75)
			r.zone:SetText(e.rank); r.zone:SetTextColor(0.75, 0.75, 0.75)
			r.group:SetText(ns.Inactive.AwayText(e)); r.group:SetTextColor(1, 0.5, 0.4)
			r.xph:SetText(ns.Inactive.JoinedText(e)); r.xph:SetTextColor(0.7, 0.7, 0.7)
			r.button:Show()
			RowBg(r, i, false)
		else
			ClearRow(r)
		end
	end
end

-- Dungeons tab, calendar view: the next 7 days of meetups, a header per day.
B.CAL_DAYS = 7
local function CalendarVisible()
	local out, lastDay, now = {}, nil, ns.Meetups.Now()
	for _, m in ipairs(ns.Meetups.List()) do
		if m.at >= now and m.at <= now + B.CAL_DAYS * 1440 then   -- not the ones already started
			local t = date("*t", m.at * 60)
			local day = t.year * 10000 + t.month * 100 + t.day
			if day ~= lastDay then out[#out + 1] = { header = day, t = t }; lastDay = day end
			out[#out + 1] = { meet = m }
		end
	end
	return out
end

local function FillCalendar(list)
	for i = 1, ROWS do
		local r, c = B.rows[i], list[i]
		r.button.mate, r.button.adId = nil, nil
		r.button.meet, r.button.meetHeader = c and c.meet, c and c.header
		if c and c.header then
			r.icon:Hide()
			r.name:SetText(string.format("%s %02d/%02d", L["DAY_" .. c.t.wday], c.t.day, c.t.month)); r.name:SetTextColor(1, 0.82, 0)
			r.level:SetText(""); r.zone:SetText(""); r.group:SetText(""); r.xph:SetText("")
			r.button:Show()
			SectionHeader(r)
		elseif c then
			local m, n = c.meet, 1
			for _ in pairs(c.meet.joined or {}) do n = n + 1 end
			local t = date("*t", m.at * 60)
			r.icon:Hide()
			r.name:SetText(string.format("   %02d:%02d", t.hour, t.min)); r.name:SetTextColor(1, 1, 1)
			r.level:SetText("")
			r.zone:SetText(ns.Dungeons.Name(m.d) .. " · " .. m.by .. (m.n and (": " .. m.n) or "")); r.zone:SetTextColor(0.6, 0.8, 1)
			r.group:SetText(tostring(n)); r.group:SetTextColor(1, 1, 1)
			local role = ns.Meetups.MyRole(m.id)
			r.xph:SetText(m.by == ns.Me() and L.CAL_MINE or role and L["ROLE_" .. role] or ""); r.xph:SetTextColor(0.4, 1, 0.4)
			r.button:Show()
			RowBg(r, i, false)
		else
			ClearRow(r)
		end
	end
end

-- Groups tab, Together view: each suggestion as a header (the dungeon) and its rows (role, name, level, "?" when guessed).
local function TogetherVisible()
	local out = {}
	for _, s in ipairs(ns.Together.Suggest()) do
		out[#out + 1] = { header = true, s = s }
		for _, row in ipairs(s.rows) do out[#out + 1] = { s = s, row = row } end
	end
	local gq = ns.Together.GroupQuests()
	if #gq > 0 then
		out[#out + 1] = { header = true, questsHeader = true }
		for _, q in ipairs(gq) do out[#out + 1] = { quest = q } end
	end
	return out
end
local function FillTogether(list)
	for i = 1, ROWS do
		local r, c = B.rows[i], list[i]
		r.button.mate, r.button.adId, r.button.meet = nil, nil, nil
		r.button.togetherEntry = c
		if c and c.questsHeader then
			r.icon:Hide()
			r.name:SetText(L.TOGETHER_QUESTS); r.name:SetTextColor(1, 0.82, 0)
			r.level:SetText(""); r.zone:SetText(""); r.group:SetText(""); r.xph:SetText("")
			r.button:Show()
			SectionHeader(r)
		elseif c and c.quest then
			r.icon:Hide()
			r.name:SetText("   " .. c.quest.title); r.name:SetTextColor(1, 1, 1)
			r.level:SetText(""); r.zone:SetText(table.concat(c.quest.with, ", ")); r.zone:SetTextColor(0.6, 0.8, 1); r.group:SetText(""); r.xph:SetText(L.TOGETHER_CLICK)
			r.button:Show()
			RowBg(r, i, false)
		elseif c and c.header then
			local d = ns.Dungeons.Get(c.s.d)
			r.icon:Hide()
			r.name:SetText(ns.Dungeons.Name(c.s.d)); r.name:SetTextColor(1, 0.82, 0)
			r.level:SetText(string.format("%d-%d", d.min, d.max)); r.zone:SetText(string.format(L.TOGETHER_FILLED, c.s.filled)); r.group:SetText(""); r.xph:SetText(L.TOGETHER_CLICK)
			r.button:Show()
			SectionHeader(r)
		elseif c then
			r.icon:Hide()
			r.name:SetText("   " .. L["ROLE_" .. c.row.role] .. (c.row.guessed and " ?" or "")); r.name:SetTextColor(1, 1, 1)
			r.level:SetText(tostring(c.row.level)); r.zone:SetText(c.row.name); r.zone:SetTextColor(1, 1, 1); r.group:SetText(""); r.xph:SetText("")
			r.button:Show()
			RowBg(r, i, false)
		else
			ClearRow(r)
		end
	end
end
-- 15 minutes from t (a date table), up to the next quarter hour: day offset (0 today, 1 tomorrow), hour, minute.
function B.SoonSlot(t)
	local total = math.ceil((t.hour * 60 + t.min + 15) / 15) * 15
	return math.floor(total / 1440), math.floor(total % 1440 / 60), total % 60
end
-- A suggestion's click: make it a run (the dialog, in 15 minutes) or invite everyone in it.
function B.OpenTogetherMenu(e)
	if e.questsHeader then return end
	if e.quest then   -- a group quest in common: post it, or invite who has it
		MenuUtil.CreateContextMenu(B.frame, function(_, root)
			root:CreateTitle(e.quest.title)
			root:CreateButton(L.QH_POST, function() ns.Questhub.Post(e.quest.q) end)
			root:CreateButton(L.DP_INVITE_ALL, function() B.InviteAll(e.quest.with) end)
		end)
		return
	end
	local s = e.s
	local names = {}
	for _, row in ipairs(s.rows) do names[#names + 1] = row.name end
	MenuUtil.CreateContextMenu(B.frame, function(_, root)
		root:CreateTitle(ns.Dungeons.Name(s.d))
		root:CreateButton(L.TOGETHER_RUN, function() ns.MeetDialog.OpenAt(s.d, B.SoonSlot(date("*t"))) end)
		root:CreateButton(L.DP_INVITE_ALL, function() B.InviteAll(names) end)
	end)
end

-- Groups tab, Quests view: the guild's quest posts.
local function QuestsVisible() return ns.Questhub.List(B.questFilter) end
local function FillQuests(list)
	local myLevel = UnitLevel("player")
	for i = 1, ROWS do
		local r, p = B.rows[i], list[i]
		r.button.mate, r.button.adId, r.button.meet, r.button.togetherEntry = nil, nil, nil, nil
		r.button.questEntry = p
		if p then
			r.icon:Hide()
			r.name:SetText(p.t); if p.g == 1 then r.name:SetTextColor(1, 0.82, 0.4) else r.name:SetTextColor(1, 1, 1) end   -- group quests in gold
			r.level:SetText(p.l and p.l > 0 and tostring(p.l) or "")
			if p.l and math.abs(p.l - myLevel) <= ns.Questhub.RANGE then r.level:SetTextColor(0.4, 1, 0.4) else r.level:SetTextColor(1, 1, 1) end
			r.zone:SetText(p.z or ""); r.zone:SetTextColor(0.8, 0.8, 0.8)
			r.group:SetText(p.by .. (#p.joined > 0 and (" +" .. #p.joined) or "")); r.group:SetTextColor(1, 1, 1)
			r.xph:SetText(ns.Journal.Duration(math.max(0, GetServerTime() - p.at))); r.xph:SetTextColor(0.7, 0.7, 0.7)
			r.button:Show()
			RowBg(r, i, false)
		else
			ClearRow(r)
		end
	end
end
-- A post's click: me too / not me, whisper, invite; mine: invite all, withdraw.
function B.OpenQuestMenu(p)
	MenuUtil.CreateContextMenu(B.frame, function(_, root)
		root:CreateTitle(p.t)
		if p.by == ns.Me() then
			root:CreateButton(L.DP_INVITE_ALL, function() B.InviteAll(p.joined) end)
			root:CreateButton(L.QH_WITHDRAW, function() ns.Confirm(L.CONFIRM_QUEST, function() ns.Questhub.Withdraw(p.q); B.Refresh() end) end)
		else
			if ns.Questhub.IJoined(p.id) then root:CreateButton(L.QH_NOT_ME, function() ns.Questhub.NotMe(p.id); B.Refresh() end)
			else root:CreateButton(L.QH_ME_TOO, function() ns.Questhub.MeToo(p.id); B.Refresh() end) end
			root:CreateButton(L.DP_WHISPER, function() B.Whisper(p.by) end)
			root:CreateButton(L.DP_INVITE, function() B.Invite(p.by) end)
		end
	end)
end

-- Guild > Members: the list, the history, the alts tree or the race, as the view button says.
local function MembersVisible()
	if B.membersView == "history" then
		local out = {}
		for _, e in ipairs(ns.GuildHistory.List()) do out[#out + 1] = { history = e } end
		return out
	elseif B.membersView == "alts" then
		local out = {}
		for _, e in ipairs(ns.Members.Alts()) do out[#out + 1] = { alt = e } end
		return out
	elseif B.membersView == "race" then
		local out = {}
		for _, e in ipairs(ns.Members.RaceRows()) do out[#out + 1] = { race = e } end
		return out
	end
	local out = {}
	for _, e in ipairs(ns.Members.List(B.memberFilter, B.search)) do out[#out + 1] = { member = e } end
	return out
end
local function FillMembers(list)
	for i = 1, ROWS do
		local r, c = B.rows[i], list[i]
		r.button.mate, r.button.adId = nil, nil
		r.button.memberEntry, r.button.historyEntry, r.button.altEntry, r.button.raceEntry = c and c.member, c and c.history, c and c.alt, c and c.race
		r.icon:Hide(); r.barBg:Hide(); r.barFill:Hide()
		r.level:SetText(""); r.zone:SetText(""); r.group:SetText(""); r.xph:SetText("")
		r.zone:SetTextColor(1, 1, 1); r.group:SetTextColor(0.8, 0.8, 0.8); r.xph:SetTextColor(0.7, 0.7, 0.7)
		if c and c.member then
			local m = c.member
			r.name:SetText(((m.role == 1 or m.role == 2) and "* " or "") .. m.name); r.name:SetTextColor(ClassColor(R.mates[m.name] and R.mates[m.name].class))
			r.level:SetText(tostring(m.level))
			r.zone:SetText(m.note or ""); r.zone:SetTextColor(0.85, 0.85, 0.6)
			r.group:SetText(L["GUILD_RANK_N"] and string.format(L.GUILD_RANK_N, m.rank) or tostring(m.rank))
			if m.online then r.xph:SetText(L.ONLINE); r.xph:SetTextColor(unpack(B.GROUP_COLORS.open))
			elseif m.days then r.xph:SetText(string.format(L.MEMBER_DAYS, m.days)) end
			r.button:Show(); RowBg(r, i, false)
		elseif c and c.history then
			local e = c.history
			r.name:SetText(e.who); r.name:SetTextColor(1, 1, 1)
			r.zone:SetText(L["HIST_" .. e.k:upper()] and string.format(L["HIST_" .. e.k:upper()], e.a or "") or e.k)
			r.xph:SetText(string.format(L.FEED_AGO, ns.Journal.Duration(math.max(0, time() - e.t))))
			r.button:Show(); RowBg(r, i, false)
		elseif c and c.alt then
			local e = c.alt
			if e.main then r.name:SetText(e.main); r.name:SetTextColor(1, 0.82, 0); r.zone:SetText(e.proven and L.ALTS_PROVEN or L.ALTS_SAID)
			else r.name:SetText("   " .. e.alt); r.name:SetTextColor(1, 1, 1) end
			r.button:Show(); RowBg(r, i, false)
		elseif c and c.race then
			local e = c.race
			r.name:SetText(e.name); r.name:SetTextColor(1, 1, 1)
			r.level:SetText(tostring(e.level))
			r.zone:SetText(e.first and L.RACE_FIRST_TAG or e.firstClass and L.RACE_CLASS_TAG or e.before and L.RACE_BEFORE_TAG or "")
			r.zone:SetTextColor(1, 0.82, 0)
			r.button:Show(); RowBg(r, i, false)
		else
			ClearRow(r)
		end
	end
end
-- A member's click: whisper, invite, their card, write a note (mine, or anyone's for those allowed).
function B.OpenMemberMenu(m)
	MenuUtil.CreateContextMenu(B.frame, function(_, root)
		root:CreateTitle(m.name)
		if m.name ~= ns.Me() then
			root:CreateButton(L.MENU_WHISPER, function() B.Whisper(m.name) end)
			root:CreateButton(L.MENU_INVITE, function() B.Invite(m.name) end)
		end
		if R.mates[m.name] or m.name == ns.Me() then root:CreateButton(L.MEMBER_CARD, function() ns.Fire("LM_ROW_CLICK", m.name) end) end
		if ns.GuildNotes.CanWrite(m.name) then root:CreateButton(L.NOTE_WRITE, function() B.AskNote(m.name) end) end
	end)
end
-- The note's box (a click from the menu).
function B.AskNote(name)
	StaticPopupDialogs["LEVELMATES_NOTE"] = StaticPopupDialogs["LEVELMATES_NOTE"] or {
		text = L.NOTE_PROMPT, button1 = OKAY, button2 = CANCEL, hasEditBox = true, maxLetters = 120, timeout = 0, whileDead = true, hideOnEscape = true,
		OnAccept = function(self, data) local eb = self.GetEditBox and self:GetEditBox() or self.EditBox; ns.GuildNotes.SetNote(data, eb and eb:GetText()) end,
		EditBoxOnEnterPressed = function(self) local dialog = self:GetParent(); ns.GuildNotes.SetNote(dialog.data, self:GetText()); dialog:Hide() end,
	}
	StaticPopup_Show("LEVELMATES_NOTE", name, nil, name)
end

-- Guild > Bank: one row per item, with its tab.
local function BankVisible()
	local out = {}
	for _, e in ipairs(ns.GuildBank.Rows(B.search)) do out[#out + 1] = { bank = e } end
	return out
end
local function FillBank(list)
	for i = 1, ROWS do
		local r, c = B.rows[i], list[i]
		r.button.mate, r.button.adId = nil, nil
		r.button.bankEntry = c and c.bank
		r.icon:Hide(); r.barBg:Hide(); r.barFill:Hide()
		if c then
			r.name:SetText(ns.Recipes.Link(c.bank.id)); r.name:SetTextColor(1, 1, 1)
			r.level:SetText(""); r.zone:SetText(c.bank.tab); r.zone:SetTextColor(0.8, 0.8, 0.8)
			r.group:SetText("x" .. c.bank.n); r.group:SetTextColor(1, 1, 1); r.xph:SetText("")
			r.button:Show(); RowBg(r, i, false)
		else
			ClearRow(r)
		end
	end
end

-- A meetup's click in the calendar: join with a role, leave, or cancel mine.
function B.OpenMeetMenu(m)
	local when = ns.Meetups.When(m)
	MenuUtil.CreateContextMenu(B.frame, function(_, root)
		root:CreateTitle(ns.Dungeons.Name(m.d) .. " · " .. when)
		if m.by == ns.Me() then
			root:CreateButton(string.format(L.MEET_CANCEL, when), function() ns.Confirm(L.CONFIRM_RUN, function() ns.Meetups.Cancel(m.id) end) end)
		elseif ns.Meetups.MyRole(m.id) then
			root:CreateButton(string.format(L.MEET_LEAVE, when), function() ns.Meetups.Leave(m.id) end)
		else
			for _, role in ipairs({ "T", "H", "D" }) do
				root:CreateButton(string.format(L.MEET_JOIN, when, L["ROLE_" .. role]), function() ns.Meetups.Join(m.id, role) end)
			end
		end
	end)
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
		for _, m in ipairs(ns.Meetups.List(id)) do
			local when = ns.Meetups.When(m)
			if m.by == ns.Me() then
				root:CreateButton(string.format(L.MEET_CANCEL, when), function() ns.Confirm(L.CONFIRM_RUN, function() ns.Meetups.Cancel(m.id) end) end)
			elseif ns.Meetups.MyRole(m.id) then
				root:CreateButton(string.format(L.MEET_LEAVE, when), function() ns.Meetups.Leave(m.id) end)
			else
				for _, role in ipairs({ "T", "H", "D" }) do
					root:CreateButton(string.format(L.MEET_JOIN, when, L["ROLE_" .. role]), function() ns.Meetups.Join(m.id, role) end)
				end
			end
		end
		for _, a in ipairs(ns.ChatAds.For(id)) do root:CreateButton(string.format(L.CHAT_AD_WHISPER, a.name), function() B.Whisper(a.full) end) end
		root:CreateButton(L.MEET_HERE, function() ns.Fire("LM_MEET_HERE", id) end)
		root:CreateButton(L.LFG_HERE, function() ns.Fire("LM_LFG_HERE", id) end)
	end)
end

function B.OpenMyGoalMenu()
	if not ns.Personal.Mine() then return end
	MenuUtil.CreateContextMenu(B.frame, function(_, root)
		root:CreateButton(L.MYGOAL_REMOVE, function() ns.Personal.Clear() end)
	end)
end

-- Class tab: three sections (builds of my class, the macro library, guildmates' macros), each under a header.
local function ClassVisible()
	local q, out = (B.search or ""):lower(), {}
	local function section(key, items)
		out[#out + 1] = { header = key, count = #items }
		for _, it in ipairs(items) do out[#out + 1] = it end
	end
	local builds = {}
	for _, e in ipairs(ns.Builds.List(B.search)) do builds[#builds + 1] = { kind = "build", e = e } end
	section("builds", builds)
	local lib = {}
	for _, m in ipairs(ns.Macros.Library(MyClass())) do
		if q == "" or m.name:lower():find(q, 1, true) then lib[#lib + 1] = { kind = "lib", m = m } end
	end
	section("library", lib)
	local guild = {}
	for _, m in ipairs(ns.Macros.Guild(B.search)) do guild[#guild + 1] = { kind = "guild", m = m } end
	section("guild", guild)
	local asks = {}
	for _, q in ipairs(ns.Ask.List(B.search)) do asks[#asks + 1] = { kind = "ask", q = q } end
	section("ask", asks)
	return out
end

local function OneLine(body) return (tostring(body or ""):gsub("\n", "  ·  ")) end

local CLASS_ICONS = { library = "Interface\\Icons\\INV_Misc_Book_09", guild = "Interface\\Icons\\INV_Misc_Note_01", ask = "Interface\\Icons\\INV_Misc_QuestionMark" }

local function FillClass(list)
	for i = 1, ROWS do
		local r, c = B.rows[i], list[i]
		r.button.mate, r.button.adId, r.button.entry, r.button.goalId, r.button.personalMine = nil, nil, nil, nil, nil
		r.button.classEntry = c
		if c and c.header then
			if c.header == "builds" then SetClassIcon(r.icon, MyClass())
			else r.icon:SetTexture(CLASS_ICONS[c.header]); r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92); r.icon:Show() end
			-- the header spans the row (SetColumns gives the name column back on the next redraw)
			local label = L["CLASS_SECTION_" .. c.header:upper()] .. " (" .. c.count .. ")"
			if c.count == 0 then label = label .. "  |cffb3b3b3" .. L["CLASS_EMPTY_" .. c.header:upper()] .. "|r" end
			r.name:SetWidth(ROW_W - (ROW_H - 4) - 4); r.name:SetText(label); r.name:SetTextColor(1, 0.82, 0)
			r.level:SetText(""); r.zone:SetText("")
			r.group:SetText(""); r.xph:SetText("")
			r.button:Show()
			SectionHeader(r)
		elseif c and c.kind == "ask" then
			local q = c.q
			local m = R.mates[q.by]
			SetClassIcon(r.icon, q.mine and MyClass() or m and m.class)
			r.name:SetText(q.by); if q.mine then r.name:SetTextColor(ClassColor(MyClass())) else r.name:SetTextColor(1, 1, 1) end
			r.level:SetText("")
			r.zone:SetText(q.x); r.zone:SetTextColor(1, 1, 1)
			r.group:SetText("")
			r.xph:SetText(ns.Journal.Duration(math.max(0, time() - q.t))); r.xph:SetTextColor(0.7, 0.7, 0.7)
			r.button:Show()
			RowBg(r, i, false)
		elseif c and c.kind == "build" then
			local e = c.e
			SetClassIcon(r.icon, e.c)
			r.name:SetText(e.name); r.name:SetTextColor(ClassColor(e.c))
			r.level:SetText("")
			r.zone:SetText(ns.Builds.PointsText(e)); r.zone:SetTextColor(1, 1, 1)
			r.group:SetText(tostring(e.l)); r.group:SetTextColor(1, 1, 1)
			r.xph:SetText(e.b and L.CLASS_VIEW or ""); r.xph:SetTextColor(0.4, 1, 0.4)
			r.button:Show()
			RowBg(r, i, false)
		elseif c then
			local m = c.m
			r.icon:SetTexture(m.icon or "Interface\\Icons\\INV_Misc_QuestionMark"); r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92); r.icon:Show()
			r.name:SetText(m.name); r.name:SetTextColor(0.6, 0.8, 1)
			r.level:SetText("")
			r.zone:SetText(c.kind == "guild" and (m.by .. ": " .. OneLine(m.body)) or OneLine(m.body)); r.zone:SetTextColor(0.85, 0.85, 0.85)
			r.group:SetText("")
			r.xph:SetText(L.CLASS_CREATE); r.xph:SetTextColor(0.4, 1, 0.4)
			r.button:Show()
			RowBg(r, i, false)
		else
			ClearRow(r)
		end
	end
end

-- A row's click: view a build, create a macro, whisper its owner.
function B.OpenClassMenu(c)
	MenuUtil.CreateContextMenu(B.frame, function(_, root)
		if c.kind == "ask" then
			root:CreateTitle(c.q.by)
			if not c.q.mine then root:CreateButton(string.format(L.ASK_ANSWER_TO, c.q.by), function() B.Whisper(c.q.by) end) end
		elseif c.kind == "build" then
			local e = c.e
			root:CreateTitle(e.name)
			if e.b then root:CreateButton(L.CLASS_VIEW_BUILD, function() ns.Builds.Open(e) end) end
			if not e.mine then root:CreateButton(string.format(L.LFG_WHISPER, e.name), function() B.Whisper(e.name) end) end
		else
			local m = c.m
			root:CreateTitle(m.name)
			if c.kind == "guild" and ns.Macros.Risky(m.body) then root:CreateTitle(L.MACRO_RUN_WARN) end
			root:CreateButton(L.CLASS_CREATE_MACRO, function() ns.Macros.Create(m.name, m.body) end)
			if c.kind == "guild" then root:CreateButton(string.format(L.LFG_WHISPER, m.by), function() B.Whisper(m.by) end) end
		end
	end)
end

-- "Share macro": my macros; a shared one is marked, and its click withdraws it.
function B.OpenShareMacroMenu(owner)
	MenuUtil.CreateContextMenu(owner or B.frame, function(_, root)
		local mine = ns.Macros.Mine()
		root:CreateTitle(#mine == 0 and L.CLASS_NO_MACROS or L.BTN_SHARE_MACRO)
		for _, m in ipairs(mine) do
			if m.shared then root:CreateButton(string.format(L.CLASS_SHARED_MARK, m.name), function() ns.Macros.Unshare(m.name); B.Refresh() end)
			else root:CreateButton(m.name, function() ns.Macros.Share(m.name); B.Refresh() end) end
		end
	end)
end

-- Pages of ROWS for the long tabs (journal, goals, wishes, a long Mates list…); the pager sits in the help-rows area.
local PAGE_KEY = { journal = "journalPage", goals = "goalPage", wishes = "wishPage", crafts = "craftPage", class = "classPage", recruit = "recruitPage", home = "homePage", feed = "feedPage", mates = "matePage", members = "memberPage", bank = "bankPage" }
local function PageKey() if B.tab == "lfg" then return B.lfgCalendar and "calendarPage" or B.lfgTogether and "togetherPage" or B.lfgQuests and "questsPage" or nil end; return PAGE_KEY[B.tab] end
local function Page(all)
	local key = PageKey()
	local pages = math.max(1, math.ceil(#all / ROWS))
	B[key] = math.min(math.max(1, B[key] or 1), pages)
	local list = {}
	for i = (B[key] - 1) * ROWS + 1, math.min(#all, B[key] * ROWS) do list[#list + 1] = all[i] end
	B.journalPageText:SetText(string.format(L.J_PAGE, B[key], pages))
	B.journalPrev:SetEnabled(B[key] > 1); B.journalNext:SetEnabled(B[key] < pages)
	return list, pages
end
function B.TurnPage(step)
	ResetBars()
	local key = PageKey()
	if key then B[key] = (B[key] or 1) + step; B.Refresh() end
end

local function RefreshRecruit()
	local RC, t = ns.Recruit, ns.Recruit.Templates()
	local use, ch = ns.char.recruitTemplate or 1, ns.char.recruitChannel or 2
	for i = 1, 3 do
		if not B.recruitEdit[i]:HasFocus() then B.recruitEdit[i]:SetText(t[i] or "") end
		B.recruitUse[i]:SetChecked(i == use)
	end
	for c, cb in pairs(B.recruitChannel) do cb:SetChecked(c == ch) end
	B.recruitRemind:SetChecked(ns.char.recruitRemind == true)
	B.recruitPreview:SetText(RC.Expand(t[use] or ""))
	local l, wait = RC.Last(), RC.Wait()
	local status = l and string.format(L.RECRUIT_LAST, ns.Journal.Duration(math.max(0, time() - l.at)), l.by) or L.RECRUIT_NONE
	status = status .. "  ·  " .. (wait > 0 and string.format(L.RECRUIT_WAIT, math.ceil(wait / 60)) or L.RECRUIT_READY)
	B.recruitStatus:SetText(status)
end

local function RefreshTabs()
	if B.tab == "recruit" and not R.IAmOfficer() then B.tab = "feed"; ns.char.boardTab = "feed"; ns.char.guildSub = "feed" end   -- members: the wall, never stuck
	local lfg, journal, goals, wishes, crafts, feed, recruit = B.tab == "lfg", B.tab == "journal", B.tab == "goals", B.tab == "wishes", B.tab == "crafts", B.tab == "feed", B.tab == "recruit"
	local class = B.tab == "class"
	local mates = B.tab == "mates"
	local index, main = 1, B.MainOf(B.tab)
	for i, key in ipairs(B.TAB_KEYS) do if key == main then index = i end end
	for key, b in pairs(B.subs) do
		b:SetShown(main == "guild" and (key ~= "recruit" or R.IAmOfficer()))
		if key == B.tab then b:LockHighlight() else b:UnlockHighlight() end
	end
	if ns.Skin.On() then
		B.frame.selectedTab = index
		for i, key in ipairs(B.TAB_KEYS) do ns.Skin.SelectTab(B.tabs[key], i == index) end
	elseif PanelTemplates_SetTab then PanelTemplates_SetTab(B.frame, index)
	else for i, key in ipairs(B.TAB_KEYS) do B.tabs[key]:SetEnabled(i ~= index) end end
	B.helpButton:SetShown(mates); B.nearCheck:SetShown(mates); B.nearLabel:SetShown(mates)
	B.palCheck:SetShown(mates); B.palLabel:SetShown(mates)
	B.palCheck:SetChecked(ns.Partner and ns.Partner.IsOn() or false)
	B.lfgButton:SetShown(lfg and not B.lfgQuests)   -- the Quests view uses that corner
	B.lfgCalendarButton:SetShown(lfg)
	B.lfgCalendarButton:SetText(B.lfgCalendar and L.BTN_CARDS or L.BTN_CALENDAR)
	B.togetherButton:SetShown(lfg)
	B.togetherButton:SetText(B.lfgTogether and L.BTN_CARDS or L.BTN_TOGETHER)
	B.memberViewButton:SetShown(B.tab == "members"); B.memberViewButton:SetText(L["MEMBERS_VIEW_" .. B.membersView:upper()])
	B.memberFilterButton:SetShown(B.tab == "members" and B.membersView == "list"); B.memberFilterButton:SetText(L["MEMBERS_FILTER_" .. B.memberFilter:upper()])
	B.questsButton:SetShown(lfg)
	B.questsButton:SetText(B.lfgQuests and L.BTN_CARDS or L.BTN_QUESTS)
	B.roleLine:SetShown(lfg and not B.lfgQuests)
	B.questFilterButton:SetShown(lfg and B.lfgQuests); B.questPostButton:SetShown(lfg and B.lfgQuests)
	B.questFilterButton:SetText(L["QH_FILTER_" .. B.questFilter:upper()])
	for role, b in pairs(B.roleButtons) do b:SetEnabled(role ~= ns.Roles.Mine()) end   -- mine is pressed in
	B.lfgButton:SetText(ns.LFG.mine and L.BTN_LFG_CANCEL or L.BTN_LFG)
	B.journalClear:SetShown(journal and B.journalView ~= "ach"); B.journalFilterButton:SetShown(journal and B.journalView ~= "ach")
	B.journalAchButton:SetShown(journal); B.journalAchButton:SetText(B.journalView == "ach" and L.BTN_JOURNAL or L.BTN_ACH)
	B.journalPrev:SetShown(journal); B.journalNext:SetShown(journal); B.journalPageText:SetShown(journal)
	B.goalNew:SetShown(goals and R.IAmOfficer())
	B.myGoal:SetShown(goals)
	B.wishAdd:SetShown(wishes)
	B.classShare:SetShown(class)
	B.classAsk:SetShown(class)
	B.feedCemetery:SetShown(feed)
	B.feedCemetery:SetText(B.feedDeaths and L.BTN_WALL_ALL or L.BTN_CEMETERY)
	B.giftAdd:SetShown(wishes)
	B.recruitViewButton:SetShown(recruit)
	B.recruitViewButton:SetText(B.recruitView == "inactive" and L.BTN_TEMPLATES or L.BTN_INACTIVE)
	B.recruitDaysButton:SetShown(recruit and B.recruitView == "inactive")
	B.recruitDaysButton:SetText(string.format(L.INACTIVE_DAYS, ns.char.inactiveDays or 14))
end

function B.Refresh()
	if not B.frame or not B.frame:IsShown() then return end
	if B.tab == "recruit" and not R.IAmOfficer() then B.tab = "feed"; ns.char.boardTab = "feed"; ns.char.guildSub = "feed" end   -- members: the wall, never stuck
	local lfg, journal, goals, wishes, crafts, feed, recruit = B.tab == "lfg", B.tab == "journal", B.tab == "goals", B.tab == "wishes", B.tab == "crafts", B.tab == "feed", B.tab == "recruit"
	local class, home = B.tab == "class", B.tab == "home"
	local list, pages
	if home then
		list, pages = Page(ns.Home.Rows())
	elseif journal and B.journalView == "ach" then
		list, pages = Page(ns.Achievements.LIST)
	elseif journal then
		list = Page(ns.Journal.List(B.journalFilter or "all", B.search))
		B.journalFilterButton:SetText(ns.Journal.FilterName(B.journalFilter or "all"))
	elseif recruit then
		list = {}
		if B.recruitView == "inactive" then list, pages = Page(ns.Inactive.List(ns.char.inactiveDays or 14, B.search)) end
	elseif feed then
		local all = ns.Feed.List(B.search, B.feedDeaths)
		B.feedDeathCount = #ns.Feed.List(nil, true)   -- the week's deaths, whatever the search
		list, pages = Page(all)
	elseif class then
		list, pages = Page(ClassVisible())
	elseif B.tab == "members" then
		list, pages = Page(MembersVisible())
	elseif B.tab == "bank" then
		list, pages = Page(BankVisible())
	elseif crafts then
		list, pages = Page(CraftsVisible())
	elseif wishes then
		local all = {}
		for _, w in ipairs(ns.Wishlist.List()) do w.kind = "want"; all[#all + 1] = w end
		for _, g in ipairs(ns.Gifts.List()) do g.kind = "give"; all[#all + 1] = g end
		list, pages = Page(all)
	elseif goals then
		local all = ns.Goals.List()
		for _, p in ipairs(ns.Personal.List()) do all[#all + 1] = p end
		list, pages = Page(all)
	else
		if lfg and not B.lfgCalendar and not B.lfgTogether and not B.lfgQuests then list = GridVisible()
		else list, pages = Page(lfg and (B.lfgTogether and TogetherVisible() or B.lfgQuests and QuestsVisible() or CalendarVisible()) or Visible()) end
	end
	SetColumns(journal and B.JCOLS or goals and B.GCOLS or wishes and B.WCOLS or crafts and B.CCOLS or feed and B.FCOLS or class and B.KCOLS or home and B.HCOLS or recruit and B.recruitView == "inactive" and B.ICOLS or B.COLS)
	SetHeaders()
	local hk = HEAD_KEY[B.tab] or "MATES"
	B.heading:SetText(L["HEAD_" .. hk])
	B.subtitle:SetText(journal and ns.Journal.PaceText() or feed and B.feedDeaths and string.format(L.FEED_CEMETERY_SUB, B.feedDeathCount or 0) or L["SUB_" .. hk])
	if lfg and B.lfgCalendar then B.heading:SetText(L.HEAD_CALENDAR); B.subtitle:SetText(L.SUB_CALENDAR) end
	if lfg and B.lfgTogether then B.heading:SetText(L.HEAD_TOGETHER); B.subtitle:SetText(L.SUB_TOGETHER) end
	if lfg and B.lfgQuests then B.heading:SetText(L.HEAD_QUESTS); B.subtitle:SetText(L.SUB_QUESTS) end
	if B.tab == "bank" then   -- whose look at the bank, and when
		local snap = ns.GuildBank.Snapshot()
		B.subtitle:SetText(snap and string.format(L.SUB_BANK_SEEN, snap.by, ns.Journal.Duration(math.max(0, GetServerTime() - snap.t)), ns.Gifts.Money(snap.m)) or L.SUB_BANK)
	end
	if recruit and B.recruitView == "inactive" then B.heading:SetText(L.HEAD_INACTIVE); B.subtitle:SetText(L.SUB_INACTIVE) end
	B.subtitle:SetWidth(B.tab == "mates" and B.SUB_NARROW or B.WIDTH - 2 * B.MARGIN)
	B.subtitle:SetShown((B.MainOf(B.tab) ~= "guild") or B.tab == "bank")   -- the bank says whose look it shows   -- the sub-section buttons sit there
	B.divider:SetShown(B.MainOf(B.tab) ~= "guild")
	if home then B.heading:SetText(GetGuildInfo("player") or L.HEAD_HOME) end   -- the partner box sits there only on Guildmates
	if B.searchBox and B.searchBox.Instructions then B.searchBox.Instructions:SetText(L["SEARCH_" .. hk]) end
	local rows = math.max(MIN_ROWS, math.min(ROWS, #list))
	if lfg and not B.lfgCalendar and not B.lfgTogether and not B.lfgQuests then rows = math.max(MIN_ROWS, math.ceil(math.ceil(#list / B.CARD_COLS) * (B.CARD_H + B.CARD_GAP) / ROW_H)) end
	B.frame:SetHeight(B.CHROME + (rows + HELP_ROWS) * ROW_H)
	B.SetTitle(B.TitleString())
	local rested = ns.Rested and ns.Rested.Mine()
	local top = rested and string.format(L.RESTED_MINE, rested) or ""
	if B.tab == "mates" and ns.GuildMap then
		local n, mapId = ns.GuildMap.Busiest()
		if mapId then
			local info = C_Map.GetMapInfo(mapId)
			top = top .. (top ~= "" and "  ·  " or "") .. string.format(L.ZONE_BUSY, n, info and info.name or tostring(mapId))
		end
	end
	B.restedText:SetText(top)
	if journal and B.journalView == "ach" then FillAch(list) elseif home then FillHome(list) elseif recruit and B.recruitView == "inactive" then FillInactive(list) elseif journal then FillJournal(list) elseif class then FillClass(list) elseif feed then FillFeed(list) elseif crafts then FillCrafts(list) elseif B.tab == "members" then FillMembers(list) elseif B.tab == "bank" then FillBank(list) elseif wishes then FillWishes(list) elseif goals then FillGoals(list) elseif lfg then if B.lfgCalendar then FillCalendar(list) elseif B.lfgTogether then FillTogether(list) elseif B.lfgQuests then FillQuests(list) else FillGrid(list) end else FillMates(list) end
	if not lfg or B.lfgCalendar or B.lfgTogether or B.lfgQuests then for _, c in ipairs(B.cards) do c:Hide() end end
	if not crafts and not home then for _, r in ipairs(B.rows) do r.barBg:Hide(); r.barFill:Hide() end end
	-- rows one under another; a section header (plaque) takes more height, and the window grows with it
	local y, extra = 0, 0
	for _, r in ipairs(B.rows) do
		local h = r.button.tall and r.button:IsShown() and ns.Skin.HEAD_H or ROW_H
		r.button:SetHeight(h); r.button:ClearAllPoints(); r.button:SetPoint("TOPLEFT", B.MARGIN, -B.TOP - ROW_H - y)
		y, extra = y + h, extra + (h - ROW_H)
	end
	if extra > 0 then B.frame:SetHeight(B.CHROME + (rows + HELP_ROWS) * ROW_H + extra) end
	B.recruitPanel:SetShown(recruit and B.recruitView ~= "inactive")
	if recruit and B.recruitView ~= "inactive" then RefreshRecruit() end
	local emptyText = ""
	if #list == 0 then
		if journal then emptyText = ns.Journal.Count() == 0 and L.J_EMPTY or L.EMPTY_FILTERED
		elseif goals then emptyText = L.GOAL_EMPTY
		elseif feed then emptyText = L.FEED_EMPTY
		elseif crafts then emptyText = #ns.Professions.List() > 0 and L.EMPTY_FILTERED or L.CRAFTS_EMPTY
		elseif wishes then emptyText = L.WISH_EMPTY
		elseif not IsInGuild() then emptyText = L.NOT_IN_GUILD
		elseif lfg then emptyText = B.lfgCalendar and L.CAL_EMPTY or B.lfgTogether and L.TOGETHER_EMPTY or B.lfgQuests and L.QH_EMPTY or L.EMPTY_FILTERED   -- every dungeon has a card: empty only when the search hides them all
		elseif #R.List() > 0 then emptyText = L.EMPTY_FILTERED
		else emptyText = L.EMPTY end
	end
	if recruit then emptyText = B.recruitView == "inactive" and #list == 0 and L.INACTIVE_EMPTY or "" end   -- the panel fills this tab
	B.frame.empty:SetText(emptyText)
	RefreshTabs()
	ns.Skin.InkPass()   -- what this page wrote, in ink
	local paged = pages and pages > 1
	if (goals or wishes or crafts or feed or class or recruit or home or B.tab == "mates" or lfg or B.tab == "members" or B.tab == "bank") and paged then   -- the pager only when there is more than one page
		B.journalPrev:Show(); B.journalNext:Show(); B.journalPageText:Show()
	end
	if journal or goals or wishes or crafts or feed or recruit or class or home or B.tab == "members" or B.tab == "bank" then
		for _, hr in ipairs(B.helpRows) do hr.text:Hide(); hr.button:Hide() end   -- the pager uses this area
	else
		RefreshHelp(paged and 1 or 0)   -- a long list: its pager at the foot, the requests above it
	end
end

function B.SetTab(key)
	ResetBars()
	B.recipesOf = nil   -- someone's recipes are a look inside the Crafts tab, not a place to come back to
	key = KnownTab(Resolve(key))
	if B.MainOf(key) == "guild" and (key ~= "recruit" or R.IAmOfficer()) then ns.char.guildSub = key end
	ns.char.boardTab, B.tab, B.search = key, key, ""
	if B.searchBox then B.searchBox:SetText("") end
	B.Refresh()
end

-- Open the board on a given tab (slash command, minimap, binding).
function B.ShowTab(key)
	ResetBars()
	if not B.frame then Build() end
	B.tab = KnownTab(Resolve(key))
	if B.MainOf(B.tab) == "guild" and (B.tab ~= "recruit" or R.IAmOfficer()) then ns.char.guildSub = B.tab end
	ns.char.boardTab = B.tab
	B.frame:Show()
	B.Refresh()
end

function B.Toggle()
	if not B.frame then Build() end
	if not B.frame:IsShown() then B.tab = "home" end   -- the board always opens on Home: "what do I do now"
	B.frame:SetShown(not B.frame:IsShown())
	B.Refresh()
end

-- Actions below run only from click handlers (menu entries / row clicks): Forever drops them otherwise.
function B.Invite(name) C_PartyInfo.InviteUnit(name); ns.Say(L.INVITE_SENT, name) end   -- the server can take a few seconds: say the click worked
-- Called from a click (a run's or a suggestion's "Invite all"): the online ones, once each, never me; one line says
-- who was invited and who was not online.
function B.InviteAll(names)
	local seen, done, off = {}, {}, {}
	for _, name in ipairs(names or {}) do
		if name ~= ns.Me() and not seen[name] then
			seen[name] = true
			if R.mates[name] then C_PartyInfo.InviteUnit(name); done[#done + 1] = name else off[#off + 1] = name end
		end
	end
	ns.Say(L.INVITE_ALL, #done, #done > 0 and table.concat(done, ", ") or "-", #off > 0 and table.concat(off, ", ") or "-")
	return #done, #off
end
function B.Whisper(name) ChatFrameUtil.SendTell(name) end
function B.OpenMenu(name)
	B.lastMenuFor = name
	local m = R.mates[name]
	MenuUtil.CreateContextMenu(B.frame, function(_, root)
		root:CreateTitle(name)
		root:CreateButton(L.MENU_INVITE, function() B.Invite(name) end)
		root:CreateButton(L.MENU_WHISPER, function() B.Whisper(name) end)
		if m and m.x and m.y and m.mapId then root:CreateButton(L.MENU_WAYPOINT, function() ns.Help.WaypointTo(m.mapId, m.x, m.y, name) end) end
	end)
end

ns.On("LM_ROSTER_CHANGED", function() ns.Dirty("board") end)
ns.On("LM_HELP_CHANGED", function() ns.Dirty("board") end)
ns.On("LM_TOGGLE_BOARD", B.Toggle)
-- Changes from the guild redraw the open page at most twice a second; clicks still redraw at once.
ns.OnRedraw("board", function() return B.frame and B.frame:IsShown() end, function() B.Refresh() end)
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

ns.On("LM_LFG_CHANGED", function() ns.Dirty("board") end)
-- Chat ads come in streams: one redraw a second at most, and only while the Dungeons tab shows them.
local chatPending = false
ns.On("LM_CHATADS_CHANGED", function()
	if chatPending or B.tab ~= "lfg" then return end
	chatPending = true
	C_Timer.After(1, function() chatPending = false; if B.tab == "lfg" then B.Refresh() end end)
end)
ns.Slash("lfg", function() B.ShowTab("lfg") end)
ns.Slash("grupo", function() B.ShowTab("lfg") end)

ns.On("LM_PARTNER_CHANGED", function() ns.Dirty("board") end)

ns.On("LM_RESTED_CHANGED", function() ns.Dirty("board") end)

ns.On("LM_JOURNAL_CHANGED", function() ns.Dirty("board") end)
ns.Slash("diario", function() B.ShowTab("journal") end)
ns.Slash("journal", function() B.ShowTab("journal") end)

ns.On("LM_GOALS_CHANGED", function() ns.Dirty("board") end)
ns.Slash("metas", function() B.ShowTab("goals") end)
ns.Slash("goals", function() B.ShowTab("goals") end)

ns.On("LM_WISHES_CHANGED", function() ns.Dirty("board") end)
ns.Slash("deseos", function() B.ShowTab("wishes") end)
ns.Slash("wishlist", function() B.ShowTab("wishes") end)

ns.On("LM_PROFESSIONS_CHANGED", function() ns.Dirty("board") end)
ns.Slash("oficios", function() B.ShowTab("crafts") end)
ns.Slash("professions", function() B.ShowTab("crafts") end)

ns.On("LM_FEED_CHANGED", function() ns.Dirty("board") end)
ns.Slash("muro", function() B.ShowTab("feed") end)
ns.Slash("wall", function() B.ShowTab("feed") end)

ns.On("LM_MEETUPS_CHANGED", function() ns.Dirty("board") end)

ns.On("LM_RECRUIT_CHANGED", function() ns.Dirty("board") end)
ns.Slash("reclutar", function() B.ShowTab("recruit") end)
-- /lm tinta 1-5: how dark the text on the page is, tried live.
local function SetInk(rest)
	local n = tonumber(strtrim(rest or ""))
	if not (n and ns.Skin.INK_LEVELS[n]) then ns.Say(L.INK_HELP, ns.Skin.InkLevel()); return end
	ns.db.settings.ink = n
	ns.Skin.InkPass()
	ns.Say(L.INK_SET, n)
end
ns.Slash("tinta", SetInk); ns.Slash("ink", SetInk)
ns.Slash("recruit", function() B.ShowTab("recruit") end)

ns.On("LM_BUILDS_CHANGED", function() ns.Dirty("board") end)
ns.On("LM_MACROS_CHANGED", function() ns.Dirty("board") end)
ns.On("LM_QUESTIONS_CHANGED", function() ns.Dirty("board") end)
ns.On("LM_POINTS_CHANGED", function() ns.Dirty("board") end)
ns.On("LM_ACHIEVEMENTS_CHANGED", function() ns.Dirty("board") end)
ns.On("LM_ROLES_CHANGED", function() ns.Dirty("board") end)
ns.On("LM_QUESTHUB_CHANGED", function() ns.Dirty("board") end)
for _, e in ipairs({ "LM_GUILDNOTES_CHANGED", "LM_HISTORY_CHANGED", "LM_BANK_CHANGED" }) do ns.On(e, function() ns.Dirty("board") end) end
ns.Slash("clase", function() B.ShowTab("class") end)
ns.Slash("class", function() B.ShowTab("class") end)
