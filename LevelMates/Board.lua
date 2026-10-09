-- Board.lua: the guildmates window. Reads ns.Roster; every action on a mate runs from a click.
local _, ns = ...
local B = {}
ns.Board = B
local L, R = ns.L, ns.Roster
local ROWS, ROW_H, HELP_ROWS = 20, 16, 3

local function ClassColor(class)
	local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
	if c then return c.r, c.g, c.b end
	return 1, 1, 1
end

local function Build()
	local f = CreateFrame("Frame", "LevelMatesBoard", UIParent, "BasicFrameTemplateWithInset")
	B.frame = f
	f:SetSize(420, 82 + (ROWS + HELP_ROWS) * ROW_H)   -- room for the last mate row above the help rows
	f:SetMovable(true); f:EnableMouse(true); f:SetClampedToScreen(true); f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", f.StartMoving)
	f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing(); local p, _, rp, x, y = self:GetPoint(); ns.char.board = { p, rp, x, y } end)
	local saved = ns.char.board
	if saved then f:SetPoint(saved[1], UIParent, saved[2], saved[3], saved[4]) else f:SetPoint("CENTER") end
	if f.TitleText then f.TitleText:SetText(L.BOARD_TITLE) end
	tinsert(UISpecialFrames, "LevelMatesBoard")
	f:Hide()

	local function Col(parent, w, justify) local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); fs:SetWidth(w); fs:SetJustifyH(justify or "LEFT"); fs:SetWordWrap(false); return fs end
	local head = { Col(f, 120), Col(f, 30, "CENTER"), Col(f, 150), Col(f, 50, "CENTER"), Col(f, 50, "RIGHT") }
	head[1]:SetPoint("TOPLEFT", 12, -30)
	for i = 2, 5 do head[i]:SetPoint("LEFT", head[i - 1], "RIGHT", 4, 0) end
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
	local near = CreateFrame("CheckButton", nil, f)
	near:SetSize(22, 22); near:SetPoint("BOTTOMRIGHT", -140, 8)
	near:SetChecked(ns.char.boardNear == true)
	near:SetScript("OnClick", function(self) ns.char.boardNear = self:GetChecked() and true or false; B.Refresh() end)
	local nearLabel = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	nearLabel:SetPoint("LEFT", near, "RIGHT", 2, 0); nearLabel:SetText(L.FILTER_NEAR)
	B.nearCheck = near

	B.rows = {}
	for i = 1, ROWS do
		local btn = CreateFrame("Button", nil, f)
		btn:SetSize(400, ROW_H)
		btn:SetPoint("TOPLEFT", 12, -30 - i * ROW_H)
		btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
		local r = { button = btn, name = Col(btn, 120), level = Col(btn, 30, "CENTER"), zone = Col(btn, 150), group = Col(btn, 50, "CENTER"), xph = Col(btn, 50, "RIGHT") }
		r.name:SetPoint("LEFT", 0, 0); r.level:SetPoint("LEFT", r.name, "RIGHT", 4, 0); r.zone:SetPoint("LEFT", r.level, "RIGHT", 4, 0); r.group:SetPoint("LEFT", r.zone, "RIGHT", 4, 0); r.xph:SetPoint("LEFT", r.group, "RIGHT", 4, 0)
		btn:SetScript("OnClick", function(self, mouse)
			local name = self.mate
			if not name then return end
			if mouse == "RightButton" then B.OpenMenu(name) else ns.Fire("LM_ROW_CLICK", name) end
		end)
		B.rows[i] = r
	end
	f.empty = Col(f, 380, "CENTER"); f.empty:SetPoint("TOP", 0, -70)

	local help = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
	help:SetSize(120, 22); help:SetPoint("BOTTOMLEFT", 12, 8); help:SetText(L.BTN_HELP)
	help:SetScript("OnClick", function() ns.Fire("LM_HELP_BUTTON") end)
	B.helpButton = help

	-- active help requests, above the help button; "On my way" whispers only from its click
	B.helpRows = {}
	for i = 1, HELP_ROWS do
		local text = Col(f, 300)
		text:SetPoint("BOTTOMLEFT", 12, 34 + (i - 1) * ROW_H)
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
		if not ns.char.boardNear or math.abs((m.level or 0) - mine) <= NEAR_RANGE then out[#out + 1] = name end
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
	for i = 1, ROWS do
		local r, name = B.rows[i], list[i]
		r.button.mate = name
		if name then
			local m = R.mates[name]
			r.name:SetText(name); r.name:SetTextColor(ClassColor(m.class))
			r.level:SetText(m.level)
			local info = m.mapId and C_Map.GetMapInfo(m.mapId)
			r.zone:SetText(info and info.name or "")
			r.group:SetText(m.inGroup and (m.hasSlot and L.GROUP_FREE or L.GROUP_FULL) or L.SOLO)
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
