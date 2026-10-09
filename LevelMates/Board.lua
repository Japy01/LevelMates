-- Board.lua: the guildmates window. Reads ns.Roster; every action on a mate runs from a click.
local _, ns = ...
local B = {}
ns.Board = B
local L, R = ns.L, ns.Roster
local ROWS, ROW_H, HELP_ROWS, MIN_ROWS = 20, 20, 3, 8
B.ROWS, B.ROW_H, B.MIN_ROWS = ROWS, ROW_H, MIN_ROWS
local unpack = unpack or table.unpack   -- the client has unpack; table.unpack covers other Lua versions

-- Layout: one place for the widths so the columns always fit inside the window.
B.COLS = { 150, 50, 180, 70, 70 }   -- name, level, zone, group, xp/h
B.GAP, B.MARGIN, B.WIDTH = 4, 12, 560
B.TOP = 84                                  -- y of the column headers: heading, subtitle and divider sit above
B.BOTTOM = 26                               -- height of the strip under the inset, where the buttons live
B.CHROME = B.TOP + ROW_H + B.BOTTOM + 10       -- window height without the mate and help rows (recomputed from the inset in Build)
local ROW_W = B.COLS[1] + B.COLS[2] + B.COLS[3] + B.COLS[4] + B.COLS[5] + 4 * B.GAP

-- Colour coding: group state and how close a mate is to my level.
B.GROUP_COLORS = { open = { 0.35, 0.9, 0.35 }, full = { 0.95, 0.35, 0.35 }, solo = { 0.7, 0.7, 0.7 } }
B.LEVEL_COLORS = { near = { 0.4, 1, 0.4 }, far = { 0.75, 0.75, 0.75 } }

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
	B.subtitle = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	B.subtitle:SetPoint("TOPLEFT", B.MARGIN, -(insetTop + 34)); B.subtitle:SetText(L.BOARD_SUBTITLE); B.subtitle:SetJustifyH("LEFT"); B.subtitle:SetTextColor(0.7, 0.7, 0.7)
	local divider = f:CreateTexture(nil, "ARTWORK")
	divider:SetColorTexture(1, 0.82, 0, 0.35); divider:SetHeight(1)
	divider:SetPoint("TOPLEFT", B.MARGIN, -(B.TOP - 8)); divider:SetPoint("TOPRIGHT", -B.MARGIN, -(B.TOP - 8))
	local search = CreateFrame("EditBox", nil, f, "SearchBoxTemplate")
	search:SetSize(150, 20); search:SetPoint("TOPRIGHT", -B.MARGIN - 6, -(insetTop + 12))
	if search.Instructions then search.Instructions:SetText(L.SEARCH_HINT) end
	search:SetScript("OnTextChanged", function(self) B.search = self:GetText() or ""; B.Refresh() end)
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
	B.nearCheck = near

	B.rows = {}
	for i = 1, ROWS do
		local btn = CreateFrame("Button", nil, f)
		btn:SetSize(ROW_W, ROW_H)
		btn:SetPoint("TOPLEFT", B.MARGIN, -B.TOP - i * ROW_H)
		btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
		local bg = btn:CreateTexture(nil, "BACKGROUND")   -- zebra striping
		bg:SetAllPoints(btn); bg:SetColorTexture(1, 1, 1, i % 2 == 0 and 0.06 or 0)
		btn:SetHighlightTexture("Interface/QuestFrame/UI-QuestLogTitleHighlight", "ADD")
		local r = { bg = bg, button = btn, name = Col(btn, B.COLS[1]), level = Col(btn, B.COLS[2], "CENTER"), zone = Col(btn, B.COLS[3]), group = Col(btn, B.COLS[4], "CENTER"), xph = Col(btn, B.COLS[5], "RIGHT") }
		r.name:SetPoint("LEFT", 0, 0); r.level:SetPoint("LEFT", r.name, "RIGHT", B.GAP, 0); r.zone:SetPoint("LEFT", r.level, "RIGHT", B.GAP, 0); r.group:SetPoint("LEFT", r.zone, "RIGHT", B.GAP, 0); r.xph:SetPoint("LEFT", r.group, "RIGHT", B.GAP, 0)
		btn:SetScript("OnClick", function(self, mouse)
			local name = self.mate
			if not name then return end
			if mouse == "RightButton" then B.OpenMenu(name) else ns.Fire("LM_ROW_CLICK", name) end
		end)
		B.rows[i] = r
	end
	f.empty = Col(f, B.WIDTH - 40, "CENTER"); f.empty:SetPoint("TOP", 0, -(B.TOP + 40))

	local help = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
	help:SetSize(120, 20); help:SetPoint("BOTTOMLEFT", 12, 3); help:SetText(L.BTN_HELP)
	help:SetScript("OnClick", function() ns.Fire("LM_HELP_BUTTON") end)
	B.helpButton = help

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
	return out
end

function B.Refresh()
	if not B.frame or not B.frame:IsShown() then return end
	local list = Visible()
	local sort = ns.char.boardSort or { mode = "level", desc = true }
	for key, fs in pairs({ level = B.headText[2], zone = B.headText[3] }) do
		if key == sort.mode then fs:SetTextColor(1, 1, 1) else fs:SetTextColor(1, 0.82, 0) end
	end
	-- the sorted header carries its direction: v = high to low / z to a, ^ = low to high / a to z
	B.headText[2]:SetText(L.COL_LEVEL .. (sort.mode == "level" and (sort.desc and " v" or " ^") or ""))
	B.headText[3]:SetText(L.COL_ZONE .. (sort.mode == "zone" and (sort.desc and " v" or " ^") or ""))
	B.frame:SetHeight(B.CHROME + (math.max(MIN_ROWS, math.min(ROWS, #list)) + HELP_ROWS) * ROW_H)
	B.SetTitle(B.TitleString())
	local mine = UnitLevel("player")
	for i = 1, ROWS do
		local r, name = B.rows[i], list[i]
		r.button.mate = name
		if name then
			local m = R.mates[name]
			r.name:SetText(name); r.name:SetTextColor(ClassColor(m.class))
			r.level:SetText(m.level)
			r.level:SetTextColor(unpack(math.abs((m.level or 0) - mine) <= NEAR_RANGE and B.LEVEL_COLORS.near or B.LEVEL_COLORS.far))
			local info = m.mapId and C_Map.GetMapInfo(m.mapId)
			r.zone:SetText(info and info.name or "")
			local state = m.inGroup and (m.hasSlot and "open" or "full") or "solo"
			r.group:SetText(state == "open" and L.GROUP_FREE or state == "full" and L.GROUP_FULL or L.SOLO)
			r.group:SetTextColor(unpack(B.GROUP_COLORS[state]))
			r.xph:SetText(m.xph and m.xph > 0 and tostring(m.xph) or "")
			r.button:Show()
		else
			r.name:SetText(""); r.level:SetText(""); r.zone:SetText(""); r.group:SetText(""); r.xph:SetText("")
			r.button:Hide()
		end
	end
	local emptyText = ""
	if #list == 0 then
		if not IsInGuild() then emptyText = L.NOT_IN_GUILD elseif #R.List() > 0 then emptyText = L.EMPTY_FILTERED else emptyText = L.EMPTY end
	end
	B.frame.empty:SetText(emptyText)
	RefreshHelp()
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
