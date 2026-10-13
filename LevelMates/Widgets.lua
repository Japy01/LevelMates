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

-- A pill: a short label on a soft band, as wide as its text. light: on a dark band (the title), light letters, no ink.
function W.Pill(parent, light)
	local p = CreateFrame("Button", nil, parent)
	p:SetHeight(18)
	p.bg = p:CreateTexture(nil, "BACKGROUND"); p.bg:SetAllPoints(); p.bg:SetColorTexture(unpack(SK.C.section))
	p.text = p:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	if not light then ink(p.text) else p.bg:SetColorTexture(1, 1, 1, 0.08) end
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
			if coords then self.icon:SetTexture(CLASS_ICON); self.icon:SetTexCoord(unpack(coords)); self.icon:Show()
			else self.icon:Hide() end   -- class not known (not online): no icon rather than a wrong one
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

-- A run as a card: "when · dungeon · leader", its five slots (tank, healer, three damage) and, withButtons, what I can
-- do: Invite all and Cancel when it is mine, Leave when I joined, Join (a menu of the free roles) otherwise. Cancel
-- asks first; a redraw of the same run keeps the question. :Set(nil) hides it.
local SLOT_ORDER = { { "T", 1 }, { "H", 1 }, { "D", 1 }, { "D", 2 }, { "D", 3 } }
W.RUNCARD_H = 64
local function short(name) return ns.ShortName and ns.ShortName(name) or name end
local function classOf(name)
	if name == ns.Me() then return select(2, UnitClass("player")) end
	local m = ns.Roster.mates[name]
	return m and m.class
end
local function cardButton(c, i)
	local b = SK.Button(c)
	b:SetSize(110, 18); b:SetPoint("TOPRIGHT", 0, -(i - 1) * 21)
	b:SetScript("OnClick", function(self)
		if self.confirm and not (self.pending and GetTime() - self.pending <= W.CONFIRM_WAIT) then
			self.pending = GetTime(); self:SetText(L.CONFIRM_SURE)
			local stamp = self.pending
			C_Timer.After(W.CONFIRM_WAIT + 0.05, function() if self.pending == stamp then self.pending = nil; self:SetText(self.label or "") end end)
			return
		end
		self.pending = nil; self:SetText(self.label or "")
		if self.fn then self.fn(self) end
		ns.Dirty("board")
	end)
	b:Hide()
	return b
end
local function setButtons(c, specs, key)
	for i, b in ipairs(c.buttons) do
		local s = specs[i]
		if s then
			local same = b.key == key and b.label == s[1]
			b.label, b.fn, b.confirm, b.key = s[1], s[2], s[3], key
			if not (same and b.pending) then b.pending = nil; b:SetText(s[1]) end
			b:Show()
		else b.pending, b.fn = nil, nil; b:Hide() end
	end
end
function W.RunCard(parent, withButtons)
	local c = CreateFrame("Button", nil, parent)
	c:SetHeight(W.RUNCARD_H)
	c.text = ink(c:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"))
	c.text:SetPoint("TOPLEFT"); c.text:SetWidth(5 * 68 - 4); c.text:SetJustifyH("LEFT"); c.text:SetWordWrap(false)
	c.slots = {}
	for k = 1, 5 do
		local s = W.Slot(c)
		s:SetPoint("TOPLEFT", (k - 1) * 68, -16)
		s:SetScript("OnClick", function() if c.meet then ns.Board.OpenMeetMenu(c.meet) end end)
		c.slots[k] = s
	end
	c.buttons = {}
	if withButtons then for i = 1, 3 do c.buttons[i] = cardButton(c, i) end end
	c:SetScript("OnClick", function(self) if self.meet then ns.Board.OpenMeetMenu(self.meet) end end)
	function c:Set(m)
		self.meet = m
		if not m then self:Hide(); return end
		local M = ns.Meetups
		self.text:SetText(M.When(m) .. "  ·  " .. ns.Dungeons.Name(m.d) .. "  ·  " .. short(m.by) .. (m.n and m.n ~= "" and ("  ·  " .. m.n) or ""))
		local slots = M.Slots(m)
		local names = {}
		for k, s in ipairs(self.slots) do
			local role, n = SLOT_ORDER[k][1], SLOT_ORDER[k][2]
			local who = slots[role][n]
			if who then names[#names + 1] = who end
			s:Set(role, who and short(who), who and classOf(who))
		end
		if withButtons then
			local specs
			if m.by == ns.Me() then
				specs = { { L.RUN_INVITE_ALL, function() ns.Board.InviteAll(names) end }, { L.DP_CANCEL, function() M.Cancel(m.id) end, true } }
			elseif M.MyRole(m.id) then
				specs = { { L.RUN_LEAVE, function() M.Leave(m.id) end } }
			else
				specs = { { L.RUN_JOIN, function(b)
					MenuUtil.CreateContextMenu(b, function(_, root)
						for _, role in ipairs({ "T", "H", "D" }) do
							if M.Free(m, role) then root:CreateButton(L["ROLE_" .. role], function() M.Join(m.id, role); ns.Dirty("board") end) end
						end
					end)
				end } }
			end
			setButtons(self, specs, m.id)
		end
		self:Show()
	end
	c:Hide()
	return c
end
