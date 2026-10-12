-- Widgets.lua: the pieces the book is built from, on parchment and in ink: a panel with a header and a hint when it
-- is empty, a big number with its label, a pill, a chip, a role slot, a button that asks "Are you sure?", and the
-- confirm popup for menus. Only the game's art and fonts. Spec 2026-10-12-levelmates-interface-design (A1).
local _, ns = ...
local W = {}
ns.Widgets = W
local SK, L = ns.Skin, ns.L
local unpack = unpack or table.unpack

local function ink(fs) SK.InkFont(fs); return fs end
local function line(parent, layer)
	local t = parent:CreateTexture(nil, layer or "BORDER")
	t:SetColorTexture(unpack(SK.C.line))
	return t
end

-- A panel: a thin ink frame, a title (as written: Lua's upper() breaks accented letters) on the left, a note on the right, the hint inside when empty.
function W.Panel(parent, title)
	local p = CreateFrame("Frame", nil, parent)
	p.top, p.bottom, p.left, p.right_ = line(p), line(p), line(p), line(p)
	p.top:SetHeight(1); p.top:SetPoint("TOPLEFT", 0, -18); p.top:SetPoint("TOPRIGHT", 0, -18)
	p.bottom:SetHeight(1); p.bottom:SetPoint("BOTTOMLEFT"); p.bottom:SetPoint("BOTTOMRIGHT")
	p.left:SetWidth(1); p.left:SetPoint("TOPLEFT", 0, -18); p.left:SetPoint("BOTTOMLEFT")
	p.right_:SetWidth(1); p.right_:SetPoint("TOPRIGHT", 0, -18); p.right_:SetPoint("BOTTOMRIGHT")
	p.title = ink(p:CreateFontString(nil, "OVERLAY", "GameFontNormal"))
	p.title:SetPoint("TOPLEFT", 2, -2); p.title:SetText(title or "")
	p.right = ink(p:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"))
	p.right:SetPoint("TOPRIGHT", -2, -4)
	p.hint = ink(p:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"))
	p.hint:SetPoint("TOPLEFT", 8, -26); p.hint:SetPoint("RIGHT", -8, 0); p.hint:SetJustifyH("LEFT"); p.hint:SetWordWrap(true)
	p.hint:Hide()
	function p:SetTitle(t) self.title:SetText(t or "") end
	function p:SetNote(t) self.right:SetText(t or "") end
	function p:SetHint(t) self.hint:SetText(t or "") end
	function p:SetEmpty(empty) self.hint:SetShown(empty and true or false) end
	return p
end

-- A big number with its label underneath and a small line under that ("23 · item level · 14/17").
function W.Stat(parent)
	local s = CreateFrame("Frame", nil, parent)
	s:SetSize(150, 54)
	s.value = ink(s:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge"))
	s.value:SetPoint("TOP", 0, -2)
	s.label = ink(s:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"))
	s.label:SetPoint("TOP", s.value, "BOTTOM", 0, -2)
	s.sub = ink(s:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"))
	s.sub:SetPoint("TOP", s.label, "BOTTOM", 0, -1)
	s.frameTop, s.frameBottom = line(s), line(s)
	s.frameTop:SetHeight(1); s.frameTop:SetPoint("TOPLEFT"); s.frameTop:SetPoint("TOPRIGHT")
	s.frameBottom:SetHeight(1); s.frameBottom:SetPoint("BOTTOMLEFT"); s.frameBottom:SetPoint("BOTTOMRIGHT")
	function s:Set(value, label, sub)
		self.value:SetText(tostring(value or "")); self.label:SetText(label or ""); self.sub:SetText(sub or "")
	end
	return s
end

-- A pill: a short label on a soft band, as wide as its text.
function W.Pill(parent)
	local p = CreateFrame("Button", nil, parent)
	p:SetHeight(18)
	p.bg = p:CreateTexture(nil, "BACKGROUND"); p.bg:SetAllPoints(); p.bg:SetColorTexture(unpack(SK.C.section))
	p.text = ink(p:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"))
	p.text:SetPoint("CENTER")
	function p:Set(t)
		self.text:SetText(t or "")
		local w = self.text.GetStringWidth and self.text:GetStringWidth() or 0
		self:SetWidth(math.max(40, (w > 0 and w or #tostring(t or "") * 6) + 16))
	end
	return p
end

-- A chip: a small toggle button that stays marked (sub-tabs, filters, days).
function W.Chip(parent, text)
	local c = SK.Button(parent)
	c:SetSize(70, 20); c:SetText(text or "")
	function c:SetChecked(on) self.checked = on and true or false; self:SetEnabled(not self.checked) end   -- the marked one is pressed in
	return c
end

-- A role slot: the class icon and the name in the class colour; empty, the role in grey.
local CLASS_ICON = "Interface\\TargetingFrame\\UI-Classes-Circles"
function W.Slot(parent)
	local s = CreateFrame("Button", nil, parent)
	s:SetSize(64, 48)
	s.bg = s:CreateTexture(nil, "BACKGROUND"); s.bg:SetAllPoints(); s.bg:SetColorTexture(unpack(SK.C.section))
	s.icon = s:CreateTexture(nil, "ARTWORK"); s.icon:SetSize(24, 24); s.icon:SetPoint("TOP", 0, -4)
	s.name = ink(s:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"))
	s.name:SetPoint("BOTTOM", 0, 4); s.name:SetWidth(60); s.name:SetWordWrap(false)
	function s:Set(role, name, class)
		self.role, self.player = role, name
		if name then
			self.empty = false
			local coords = class and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[class]
			self.icon:SetTexture(CLASS_ICON); if coords then self.icon:SetTexCoord(unpack(coords)) end
			self.icon:Show()
			self.name:SetText(name)
			local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
			if c then self.name:SetTextColor(c.r, c.g, c.b) else self.name:SetTextColor(1, 1, 1) end
		else
			self.empty = true
			self.icon:Hide()
			self.name:SetText(L["ROLE_" .. role] or role); self.name:SetTextColor(0.55, 0.5, 0.42)
		end
	end
	return s
end

-- A button that asks first: the first click turns it into "Are you sure?", a second within 5 s does it.
W.CONFIRM_WAIT = 5
function W.ConfirmButton(parent, text, fn)
	local b = SK.Button(parent)
	b.label, b.fn = text, fn
	b:SetText(text)
	function b:Reset() self.pending = nil; self:SetText(self.label) end
	function b:SetAction(label, action) self.label, self.fn = label, action; self:Reset() end
	b:SetScript("OnClick", function(self)
		if self.pending and GetTime() - self.pending <= W.CONFIRM_WAIT then
			self:Reset()
			if self.fn then self.fn() end
			return
		end
		self.pending = GetTime()
		self:SetText(L.CONFIRM_SURE)
		local stamp = self.pending
		C_Timer.After(W.CONFIRM_WAIT + 0.05, function() if self.pending == stamp then self:Reset() end end)
	end)
	return b
end

-- For menus (they close on a click): the game's yes/no popup.
local pending
function ns.Confirm(text, fn)
	StaticPopupDialogs["LEVELMATES_CONFIRM"] = StaticPopupDialogs["LEVELMATES_CONFIRM"] or {
		text = "%s", button1 = YES or "Yes", button2 = NO or "No", timeout = 0, whileDead = true, hideOnEscape = true,
		OnAccept = function(_, data) local f = data or pending; pending = nil; if f then f() end end,
		OnCancel = function() pending = nil end,
	}
	pending = fn
	StaticPopup_Show("LEVELMATES_CONFIRM", text, nil, fn)
end
