-- Skin.lua: LevelMates' own look, warm browns and gold as the game's windows, built with the game's BackdropTemplate
-- (flat fill + the tooltip border), the way ElvUI, Baganator's themes and others do it. Every window, button and tab
-- of the addon is made here; the "classic" style option gives back the game's own templates.
local _, ns = ...
local SK = {}
ns.Skin = SK
local unpack = unpack or table.unpack

SK.FLAT, SK.EDGE = "Interface\\Buttons\\WHITE8X8", "Interface\\Tooltips\\UI-Tooltip-Border"
-- the game's own tiled backgrounds (its frames use them most): stone for the window, marble for the inner panel
SK.ROCK, SK.MARBLE = "Interface\\FrameGeneral\\UI-Background-Rock", "Interface\\FrameGeneral\\UI-Background-Marble"
SK.C = {
	frame = { 1, 0.80, 0.58, 1 }, frameBorder = { 0.86, 0.67, 0.32, 1 },
	panel = { 0.30, 0.21, 0.12, 0.96 }, panelBorder = { 0.58, 0.44, 0.22, 1 },
	button = { 0.42, 0.29, 0.13, 1 }, buttonBorder = { 0.86, 0.67, 0.32, 1 },
	tab = { 0.30, 0.21, 0.11, 1 }, tabActive = { 0.58, 0.42, 0.17, 1 },
	row = { 1, 0.85, 0.55, 0.07 }, header = { 1, 0.82, 0.25, 0.14 }, hover = { 1, 0.85, 0.45, 0.16 },
	bar = { 0.08, 0.05, 0.02, 0.55 }, barLine = { 0.86, 0.67, 0.32, 0.7 },
	box = { 0.17, 0.115, 0.06, 0.88 }, boxBorder = { 0.62, 0.46, 0.22, 1 }, strip = { 0.10, 0.065, 0.03, 0.55 },
	line = { 0.21, 0.145, 0.08, 0.92 }, lineBorder = { 0.46, 0.33, 0.15, 1 },
	card = { 0.86, 0.67, 0.32, 1 }, cardDim = { 0.40, 0.33, 0.24, 1 }, band = { 0.10, 0.06, 0.02, 0.62 },
}

function SK.On() return not (ns.db and ns.db.settings.style == "classic") end

-- Background and border on a frame made with BackdropTemplate.
-- With `bgFile` the background is that texture, tiled and tinted by `bg`.
function SK.Backdrop(f, bg, border, edge, bgFile)
	f:SetBackdrop({ bgFile = bgFile or SK.FLAT, tile = bgFile ~= nil, tileSize = 256, edgeFile = SK.EDGE, edgeSize = edge or 14, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
	f:SetBackdropColor(unpack(bg))
	f:SetBackdropBorderColor(unpack(border))
end

-- A window: a title, a close button and an inner panel (f.Inset) like the game's own frames.
function SK.Window(name, parent)
	if not SK.On() then return CreateFrame("Frame", name, parent or UIParent, "BasicFrameTemplateWithInset") end
	local f = CreateFrame("Frame", name, parent or UIParent, "BackdropTemplate")
	SK.Backdrop(f, SK.C.frame, SK.C.frameBorder, 16, SK.ROCK)
	-- a darker title bar with a gold line under it
	local bar = f:CreateTexture(nil, "BACKGROUND", nil, 2)
	bar:SetColorTexture(unpack(SK.C.bar)); bar:SetPoint("TOPLEFT", 4, -4); bar:SetPoint("TOPRIGHT", -4, -4); bar:SetHeight(20)
	local barLine = f:CreateTexture(nil, "BORDER")
	barLine:SetColorTexture(unpack(SK.C.barLine)); barLine:SetPoint("TOPLEFT", bar, "BOTTOMLEFT"); barLine:SetPoint("TOPRIGHT", bar, "BOTTOMRIGHT"); barLine:SetHeight(1)
	f.TitleBar = bar
	f.TitleText = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	f.TitleText:SetPoint("TOP", 0, -8)
	local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT", -2, -2)
	close:SetScript("OnClick", function() f:Hide() end)
	f.CloseButton = close
	-- the inner panel is drawn with textures on the window itself: a child frame would cover the window's own texts
	local inset = f:CreateTexture(nil, "BACKGROUND", nil, 1)
	inset:SetPoint("TOPLEFT", 8, -26); inset:SetPoint("BOTTOMRIGHT", -8, 28)
	inset:SetColorTexture(unpack(SK.C.panel))
	-- the game's marble over it, faint: texture without darkening the brown
	local grain = f:CreateTexture(nil, "BACKGROUND", nil, 2)
	grain:SetAllPoints(inset); grain:SetTexture(SK.MARBLE, "REPEAT", "REPEAT"); grain:SetHorizTile(true); grain:SetVertTile(true); grain:SetAlpha(0.22)
	f.InsetGrain = grain
	local function line(p1, p2, w, h)
		local t = f:CreateTexture(nil, "BORDER")
		t:SetColorTexture(unpack(SK.C.panelBorder)); t:SetPoint(p1, inset, p1); t:SetPoint(p2, inset, p2)
		if w then t:SetWidth(w) else t:SetHeight(h) end
	end
	line("TOPLEFT", "TOPRIGHT", nil, 1); line("BOTTOMLEFT", "BOTTOMRIGHT", nil, 1); line("TOPLEFT", "BOTTOMLEFT", 1); line("TOPRIGHT", "BOTTOMRIGHT", 1)
	f.Inset = inset
	return f
end

-- A box drawn with textures on `f` (a child frame would cover f's own texts): a fill and a 1-pixel border.
-- Returns the fill; anchor it with SetPoint and the border follows.
function SK.Box(f, bg, border, sub)
	local fill = f:CreateTexture(nil, "BACKGROUND", nil, sub or 3)
	fill:SetColorTexture(unpack(bg))
	if border then
		local function line(p1, p2, w, h)
			local t = f:CreateTexture(nil, "BACKGROUND", nil, (sub or 3) + 1)
			t:SetColorTexture(unpack(border)); t:SetPoint(p1, fill, p1); t:SetPoint(p2, fill, p2)
			if w then t:SetWidth(w) else t:SetHeight(h) end
		end
		line("TOPLEFT", "TOPRIGHT", nil, 1); line("BOTTOMLEFT", "BOTTOMRIGHT", nil, 1); line("TOPLEFT", "BOTTOMLEFT", 1); line("TOPRIGHT", "BOTTOMRIGHT", 1)
	end
	return fill
end

-- The character sheet's own art (Forever's): stripes for alternate rows, a plaque for section headers.
function SK.Stripe(b)
	if not SK.On() then return nil end
	local t = b:CreateTexture(nil, "BACKGROUND", nil, 1)
	t:SetAtlas("UI-Character-Info-Line-Bounce"); t:SetAllPoints(); t:Hide()
	return t
end
function SK.Plaque(b)
	if not SK.On() then return nil end
	local t = b:CreateTexture(nil, "BACKGROUND", nil, 2)
	t:SetAtlas("UI-Character-Info-Title"); t:SetPoint("TOPLEFT", 18, 1);   -- after the row's icon
	 t:SetPoint("BOTTOMRIGHT", 0, -1); t:Hide()
	return t
end

-- A list row as a small box (a Button made with BackdropTemplate): a fill and a thin border.
function SK.Row(b)
	b:SetBackdrop({ bgFile = SK.FLAT, edgeFile = SK.FLAT, edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } })
	b:SetBackdropColor(unpack(SK.C.line)); b:SetBackdropBorderColor(unpack(SK.C.lineBorder))
end

-- A button: brown with a gold border and the game's gold text; brighter under the mouse.
function SK.Button(parent, name)
	if not SK.On() then return CreateFrame("Button", name, parent, "UIPanelButtonTemplate") end
	local b = CreateFrame("Button", name, parent, "BackdropTemplate")
	SK.Backdrop(b, SK.C.button, SK.C.buttonBorder, 12)
	local fs = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	fs:SetPoint("CENTER", 0, 0)
	b:SetFontString(fs)
	b:SetNormalFontObject("GameFontNormal"); b:SetHighlightFontObject("GameFontHighlight"); b:SetDisabledFontObject("GameFontDisable")
	local hl = b:CreateTexture(nil, "HIGHLIGHT")
	hl:SetPoint("TOPLEFT", 3, -3); hl:SetPoint("BOTTOMRIGHT", -3, 3); hl:SetColorTexture(unpack(SK.C.hover))
	b:SetHighlightTexture(hl)
	return b
end

-- A tab: a flat button; the selected one is lighter, with white text.
function SK.Tab(parent, name)
	if not SK.On() then return CreateFrame("Button", name, parent, "PanelTabButtonTemplate") end
	local b = SK.Button(parent, name)
	b.skinTab = true
	b:SetDisabledFontObject("GameFontHighlight")   -- the selected tab is disabled: white text, not grey
	SK.Backdrop(b, SK.C.tab, SK.C.buttonBorder, 12)
	return b
end
function SK.SelectTab(b, selected)
	b:SetBackdropColor(unpack(selected and SK.C.tabActive or SK.C.tab))
	b:SetEnabled(not selected)
end
