-- Skin.lua: the guild book. The game's own frame with a portrait, icon tabs in its top band, a parchment page from the
-- spellbook (Forever's own art), dark ink for the text, section bands and thin row lines, the spellbook's ribbon and
-- divider. Only the game's art. Spec 2026-10-11-levelmates-libro-design.
local _, ns = ...
local SK = {}
ns.Skin = SK
local unpack = unpack or table.unpack

SK.FLAT, SK.EDGE = "Interface\\Buttons\\WHITE8X8", "Interface\\Tooltips\\UI-Tooltip-Border"
SK.ROCK, SK.MARBLE = "Interface\\FrameGeneral\\UI-Background-Rock", "Interface\\FrameGeneral\\UI-Background-Marble"
SK.PAGE, SK.RIBBON, SK.DIVIDER = "spellbook-Page-Right-C60", "spellbook-background-evergreen-ribbon", "spellbook-divider"
SK.ICON = "Interface\\AddOns\\LevelMates\\Media\\icon"
SK.C = {
	frame = { 0.045, 0.035, 0.025, 0.98 }, frameBorder = { 0.62, 0.47, 0.24, 1 },
	page = { 0.86, 0.76, 0.58, 1 },                            -- parchment, where the page art is missing
	ink = { 0.22, 0.13, 0.05 }, inkSoft = { 0.38, 0.28, 0.16 },
	band = { 0.10, 0.06, 0.02, 0.62 }, section = { 0.30, 0.18, 0.06, 0.16 }, line = { 0.35, 0.22, 0.08, 0.28 },
	strip = { 0.30, 0.18, 0.06, 0.10 },
	card = { 0.86, 0.67, 0.32, 1 }, cardDim = { 0.40, 0.33, 0.24, 1 },
	header = { 0.30, 0.18, 0.06, 0.16 },
}
SK.HEAD_H = 22   -- a section header row

function SK.On() return true end   -- one style: the book (kept as a function for the code paths that ask)

-- Text written on the parchment: the colour a fill asks for, in ink (darker, so it reads on paper).
function SK.Ink(r, g, b) return (r or 1) * 0.36, (g or 1) * 0.30, (b or 1) * 0.22 end
-- Colour codes inside a text (item links, quality colours) in ink too: a white or grey item would vanish on paper.
function SK.InkText(s)
	if type(s) ~= "string" then return s end
	return (s:gsub("|c(%x%x)(%x%x)(%x%x)(%x%x)", function(a, r, g, b)
		local ir, ig, ib = SK.Ink(tonumber(r, 16) / 255, tonumber(g, 16) / 255, tonumber(b, 16) / 255)
		return string.format("|c%s%02x%02x%02x", a, math.floor(ir * 255 + 0.5), math.floor(ig * 255 + 0.5), math.floor(ib * 255 + 0.5))
	end))
end
-- A font string on the page: every colour it is given is turned into ink, and no shadow (it blurs on paper).
function SK.InkFont(fs)
	if not fs or fs.inked then return fs end
	fs.inked = true
	local set = fs.SetTextColor
	fs.SetTextColor = function(self, r, g, b, a)
		local ir, ig, ib = SK.Ink(r or 1, g or 1, b or 1)
		return set(self, ir, ig, ib, a)
	end
	local setText = fs.SetText
	fs.SetText = function(self, t) return setText(self, SK.InkText(t)) end
	if fs.SetShadowColor then fs:SetShadowColor(0, 0, 0, 0) end
	fs:SetTextColor(1, 1, 1)
	return fs
end

-- Whether the client has an atlas (Forever's art differs from Mainline's in places).
function SK.HasAtlas(name)
	if not (C_Texture and C_Texture.GetAtlasInfo) then return true end
	return C_Texture.GetAtlasInfo(name) ~= nil
end

-- Background and border on a frame made with BackdropTemplate.
function SK.Backdrop(f, bg, border, edge, bgFile)
	f:SetBackdrop({ bgFile = bgFile or SK.FLAT, tile = bgFile ~= nil, tileSize = 256, edgeFile = SK.EDGE, edgeSize = edge or 14, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
	f:SetBackdropColor(unpack(bg))
	f:SetBackdropBorderColor(unpack(border))
end

-- The parchment page over a window's inner panel (the inset frame of the game's template, or our own), with the
-- spellbook's ribbon at its top right.
function SK.Page(f, ribbon)
	if f.page then return f.page end
	-- On the window itself, where the inner panel was: the game draws the panel (a child frame) over the window's own
	-- texts, so a page on it would cover the heading. The panel is hidden; it still gives the page its place.
	local page = f:CreateTexture(nil, "BACKGROUND", nil, 7)
	page:SetColorTexture(unpack(SK.C.page))
	if SK.HasAtlas(SK.PAGE) then page:SetAtlas(SK.PAGE) end   -- else the plain parchment colour
	page:SetAllPoints(f.Inset)
	if f.Inset and f.Inset.Hide and f.Inset.CreateTexture then f.Inset:Hide() end
	f.page = page
	if ribbon and SK.HasAtlas(SK.RIBBON) then   -- the ribbon hangs at the page's right edge, clear of the columns
		local r = f:CreateTexture(nil, "ARTWORK")
		r:SetAtlas(SK.RIBBON); r:SetSize(28, 80)
		r:SetPoint("TOPLEFT", page, "TOPRIGHT", -6, 6)
		f.Ribbon = r
	end
	return page
end

-- A window: the game's own frame (as its spellbook and character sheet) with the parchment page; `portrait` keeps the
-- round portrait and the top band (the board), otherwise both are hidden (small windows).
function SK.Window(name, parent, portrait)
	if ButtonFrameTemplate_HidePortrait then
		local ok, gf = pcall(CreateFrame, "Frame", name, parent or UIParent, "ButtonFrameTemplate")
		if ok and gf then
			if portrait then
				if gf.SetPortraitToAsset then gf:SetPortraitToAsset(SK.ICON) end
			else
				ButtonFrameTemplate_HidePortrait(gf)
				if ButtonFrameTemplate_HideAttic then ButtonFrameTemplate_HideAttic(gf) end
			end
			gf.TitleText = gf.TitleContainer and gf.TitleContainer.TitleText or gf.TitleText
			gf.gameFrame = true
			if portrait then SK.Page(gf, true) end
			return gf
		end
	end
	-- the client has no such template: a plain dark window with the same page
	local f = CreateFrame("Frame", name, parent or UIParent, "BackdropTemplate")
	SK.Backdrop(f, SK.C.frame, SK.C.frameBorder, 16)
	f.TitleText = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	f.TitleText:SetPoint("TOP", 0, -8)
	local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT", -2, -2)
	close:SetScript("OnClick", function() f:Hide() end)
	f.CloseButton = close
	local inset = f:CreateTexture(nil, "BACKGROUND", nil, 0)
	inset:SetPoint("TOPLEFT", 8, portrait and -86 or -26); inset:SetPoint("BOTTOMRIGHT", -8, 28)
	inset:SetColorTexture(0, 0, 0, 0)
	f.Inset = inset
	if portrait then SK.Page(f, true) end
	return f
end

-- A row's thin line at its foot (rows on the page are separated by lines, not stripes).
function SK.Stripe(b)
	local t = b:CreateTexture(nil, "BACKGROUND", nil, 1)
	t:SetColorTexture(unpack(SK.C.line)); t:SetHeight(1)
	t:SetPoint("BOTTOMLEFT", 0, 0); t:SetPoint("BOTTOMRIGHT", 0, 0)
	t:Hide()
	return t
end
-- A section header's band across the row (with the section's coloured name and count on it).
function SK.Plaque(b)
	local t = b:CreateTexture(nil, "BACKGROUND", nil, 2)
	t:SetColorTexture(unpack(SK.C.section)); t:SetAllPoints(); t:Hide()
	return t
end

-- Buttons are the game's red ones.
function SK.Button(parent, name) return CreateFrame("Button", name, parent, "UIPanelButtonTemplate") end

-- A main tab: a square icon (as the spellbook's), its name in a tooltip, lit when selected.
function SK.Tab(parent, name, icon, label)
	local b = CreateFrame("Button", name, parent)
	b.skinTab, b.label = true, label
	b:SetSize(36, 36)
	b.icon = b:CreateTexture(nil, "ARTWORK"); b.icon:SetAllPoints(); b.icon:SetTexture(icon); b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	b.frame = b:CreateTexture(nil, "OVERLAY"); b.frame:SetAtlas("spellbook-Tab-Frame-C60"); b.frame:SetPoint("TOPLEFT", -6, 6); b.frame:SetPoint("BOTTOMRIGHT", 6, -6)
	b.glow = b:CreateTexture(nil, "OVERLAY", nil, 1); b.glow:SetTexture("Interface\\Buttons\\CheckButtonHilight"); b.glow:SetBlendMode("ADD"); b.glow:SetAllPoints(); b.glow:Hide()
	b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
	b:SetScript("OnEnter", function(self)
		if not GameTooltip then return end
		GameTooltip:SetOwner(self, "ANCHOR_BOTTOM"); GameTooltip:AddLine(self.label, 1, 1, 1); GameTooltip:Show()
	end)
	b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
	return b
end
function SK.SelectTab(b, selected)
	b.glow:SetShown(selected)
	b.icon:SetDesaturated(not selected)
	b:SetEnabled(not selected)
end
