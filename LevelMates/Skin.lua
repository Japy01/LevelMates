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
-- The guild banner in my faction's colours: red for the Horde, blue for the Alliance.
function SK.Banner()
	local faction = UnitFactionGroup and UnitFactionGroup("player")
	return faction == "Horde" and "Interface\\Icons\\INV_BannerPVP_01" or "Interface\\Icons\\INV_BannerPVP_02"
end
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
-- Near-black brown for white, the same hue darkened for colours: the spellbook's own text is that dark.
-- How dark the ink is: /lm tinta 1 (lightest) to 5 (darkest); 4 by default.
SK.INK_LEVELS = { 0.32, 0.26, 0.21, 0.16, 0.11 }
function SK.InkLevel() local n = ns.db and ns.db.settings.ink or 4; return SK.INK_LEVELS[n] and n or 4 end
function SK.Ink(r, g, b)
	local k = SK.INK_LEVELS[SK.InkLevel()]
	return (r or 1) * k, (g or 1) * k * 0.8, (b or 1) * k * 0.55
end
-- Colour codes inside a text (item links, quality colours) in ink too: a white or grey item would vanish on paper.
function SK.InkText(s)
	if type(s) ~= "string" then return s end
	return (s:gsub("|c(%x%x)(%x%x)(%x%x)(%x%x)", function(a, r, g, b)
		local ir, ig, ib = SK.Ink(tonumber(r, 16) / 255, tonumber(g, 16) / 255, tonumber(b, 16) / 255)
		return string.format("|c%s%02x%02x%02x", a, math.floor(ir * 255 + 0.5), math.floor(ig * 255 + 0.5), math.floor(ib * 255 + 0.5))
	end))
end
-- A font string written on the page: no shadow (it blurs on paper), and listed for the ink pass.
SK.inkList = {}
function SK.InkFont(fs)
	if not fs or fs.inked then return fs end
	fs.inked = true
	if fs.SetShadowColor then fs:SetShadowColor(0, 0, 0, 0) end
	SK.inkList[#SK.inkList + 1] = fs
	SK.InkOne(fs)
	return fs
end
-- After a page is drawn: whatever colour each text was given turns into ink, once (what is already ink is left be;
-- the game's own text objects do not take overridden methods, so this pass is how it is done).
local function near(a, b) return math.abs(a - b) < 0.004 end
function SK.InkOne(fs)
	local r, g, b = fs:GetTextColor()
	r, g, b = r or 1, g or 1, b or 1
	local done, level = fs.lmInk, SK.InkLevel()
	local already = done and near(done[1], r) and near(done[2], g) and near(done[3], b)
	if not already or fs.lmLevel ~= level then
		if not already then fs.lmBase = { r, g, b } end   -- a fresh colour from the page: that is the base
		local base = fs.lmBase
		local ir, ig, ib = SK.Ink(base[1], base[2], base[3])
		fs:SetTextColor(ir, ig, ib)
		fs.lmInk, fs.lmLevel = { ir, ig, ib }, level
	end
	local t = fs:GetText()
	if type(t) == "string" and t:find("|c", 1, true) and (t ~= fs.lmInkText or fs.lmTextLevel ~= level) then
		if t ~= fs.lmInkText then fs.lmBaseText = t end
		local inked = SK.InkText(fs.lmBaseText)
		fs:SetText(inked)
		fs.lmInkText, fs.lmTextLevel = inked, level
	end
end
function SK.InkPass() for _, fs in ipairs(SK.inkList) do SK.InkOne(fs) end end

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
				if gf.TopTileStreaks then gf.TopTileStreaks:Hide() end   -- the attic's band would cover the page's first lines
			end
			gf.TitleText = gf.TitleContainer and gf.TitleContainer.TitleText or gf.TitleText
			gf.gameFrame = true
			if portrait then SK.Page(gf, true) else SK.SmallPage(gf) end
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
	f.TitleText.lmKeep = true   -- on the dark frame, above the page
	if portrait then SK.Page(f, true) else SK.SmallPage(f) end
	return f
end

-- A small window gets the page too, and its writing in ink each time it shows (and after its own refreshes).
function SK.SmallPage(f)
	-- the whole inside, right under the title: these windows write from the top and keep their buttons at the foot
	local page = SK.Page(f)
	page:ClearAllPoints(); page:SetPoint("TOPLEFT", 4, -22); page:SetPoint("BOTTOMRIGHT", -4, 4)
	f:HookScript("OnShow", function() SK.InkWindow(f); if C_Timer then C_Timer.After(0, function() SK.InkWindow(f) end) end end)
end
-- Everything written on a window's page, in ink: its texts and those of its rows and boxes. The game's red buttons,
-- the close button, the title band and the typing boxes keep their own colours.
function SK.InkWindow(f)
	local function walk(o)
		if o.lmKeep or o == f.CloseButton or o == f.TitleContainer then return end
		for _, r in ipairs({ o:GetRegions() }) do
			if r.GetObjectType and r:GetObjectType() == "FontString" and not r.lmKeep and r ~= f.TitleText then
				if not r.lmInkListed then r.lmInkListed = true; SK.InkFont(r) end
				SK.InkOne(r)
			end
		end
		for _, c in ipairs({ o:GetChildren() }) do
			if not (c.GetObjectType and c:GetObjectType() == "EditBox") then walk(c) end   -- typed text stays light on its dark box
		end
	end
	walk(f)
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
function SK.Button(parent, name) local b = CreateFrame("Button", name, parent, "UIPanelButtonTemplate"); b.lmKeep = true; return b end

-- A main tab: a square icon (as the spellbook's), its name in a tooltip, lit when selected.
-- A section button in the top band: the section's icon and its name, on a dark plate with a thin gold edge; the chosen
-- one lit (bright edge, white name, a soft glow). As wide as its name.
function SK.Tab(parent, name, icon, label)
	local b = CreateFrame("Button", name, parent, "BackdropTemplate")
	b.skinTab, b.label = true, label
	b:SetHeight(30)
	if b.SetBackdrop then
		b:SetBackdrop({ bgFile = "Interface/Tooltips/UI-Tooltip-Background", edgeFile = "Interface/Tooltips/UI-Tooltip-Border", edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
		b:SetBackdropColor(0.10, 0.07, 0.03, 0.9)
	end
	b.icon = b:CreateTexture(nil, "ARTWORK"); b.icon:SetSize(22, 22); b.icon:SetPoint("LEFT", 5, 0)
	b.icon:SetTexture(icon); b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	b.text = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	b.text:SetPoint("LEFT", b.icon, "RIGHT", 6, 0); b.text:SetText(label or "")
	b.text.lmKeep = true   -- on the dark band: never inked
	local w = b.text.GetStringWidth and b.text:GetStringWidth() or 0
	if not w or w <= 0 then w = #tostring(label or "") * 7 end
	b:SetWidth(math.floor(5 + 22 + 6 + w + 12))
	b.glow = b:CreateTexture(nil, "BACKGROUND", nil, 1); b.glow:SetTexture("Interface/Buttons/CheckButtonHilight"); b.glow:SetBlendMode("ADD")
	b.glow:SetPoint("TOPLEFT", 3, -3); b.glow:SetPoint("BOTTOMRIGHT", -3, 3); b.glow:SetAlpha(0.5); b.glow:Hide()
	b:SetHighlightTexture("Interface/Buttons/ButtonHilight-Square", "ADD")
	b:SetScript("OnEnter", function(self)
		if not GameTooltip then return end
		GameTooltip:SetOwner(self, "ANCHOR_BOTTOM"); GameTooltip:AddLine(self.label, 1, 1, 1); GameTooltip:Show()
	end)
	b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
	return b
end
function SK.SelectTab(b, selected)
	b.selected = selected and true or false
	b.glow:SetShown(selected)
	if b.SetBackdropBorderColor then
		if selected then b:SetBackdropBorderColor(1, 0.82, 0, 1) else b:SetBackdropBorderColor(0.55, 0.42, 0.2, 0.9) end
	end
	if selected then b.text:SetTextColor(1, 1, 1) else b.text:SetTextColor(1, 0.82, 0) end
	local v = selected and 1 or 0.8
	b.icon:SetVertexColor(v, v, v)
	b:SetEnabled(not selected)
end
