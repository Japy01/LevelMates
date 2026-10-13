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
W.ROLE_ICON = "Interface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES"   -- the game's tank/healer/damage circles
local ROLE_KEY = { T = "TANK", H = "HEALER", D = "DAMAGER" }
local function roleIcon(tex, role, grey)
	if not ROLE_KEY[role] then tex:Hide(); return end   -- "any": no role to show
	tex:SetTexture(W.ROLE_ICON)
	if GetTexCoordsForRoleSmallCircle then
		local ok, l, r, t, b = pcall(GetTexCoordsForRoleSmallCircle, ROLE_KEY[role] or "DAMAGER")
		if ok and l then tex:SetTexCoord(l, r, t, b) end
	end
	tex:SetDesaturated(grey and true or false); tex:SetAlpha(grey and 0.45 or 1)
	tex:Show()
end
local function roleIconPublic(tex, role) roleIcon(tex, role, false) end
W.RoleIcon = roleIconPublic
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
			if coords then self.icon:SetTexture(CLASS_ICON); self.icon:SetTexCoord(unpack(coords)); self.icon:SetDesaturated(false); self.icon:SetAlpha(1); self.icon:Show()
			else roleIcon(self.icon, role, false) end   -- class not known (not online): the role, never a wrong class
			self.name:SetText(name)
			local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
			if c then self.name:SetTextColor(c.r, c.g, c.b) else self.name:SetTextColor(1, 1, 1) end
		else
			self.empty = true
			roleIcon(self.icon, role, true)   -- the role it waits for, greyed
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

-- Helpers for the group card below: short names, a member's class, buttons that can ask "Are you sure?".
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
-- A group as a card (project 9): "Ahora · Minas de la Muerte · Mario · note" or "mar 21:00 · …"; up to five places
-- as slots, more as counters per role ("2/5" with a bar, or "12/40" without roles); and, withButtons, what I can do:
-- Invite all and Withdraw/Cancel on mine, Leave on one I joined, Join otherwise (a menu of the free roles, or straight
-- in as "any"). Withdraw and Cancel ask first; a redraw of the same group keeps the question. :Set(nil) hides it.
W.GROUPCARD_H = 64
local SLOT_ROLES = { "T", "H", "D", "A" }
local function counterRow(parent, i)
	local r = CreateFrame("Frame", nil, parent)
	r:SetHeight(14); r:SetPoint("TOPLEFT", 0, -(i - 1) * 16); r:SetWidth(5 * 68 - 4)
	r.icon = r:CreateTexture(nil, "ARTWORK"); r.icon:SetSize(14, 14); r.icon:SetPoint("LEFT")
	r.text = ink(r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"))
	r.text:SetPoint("LEFT", r.icon, "RIGHT", 4, 0); r.text:SetWidth(110); r.text:SetJustifyH("LEFT")
	r.barBg = r:CreateTexture(nil, "BORDER"); r.barBg:SetColorTexture(0.24, 0.14, 0.05, 0.45)
	r.barBg:SetPoint("LEFT", r.text, "RIGHT", 4, 0); r.barBg:SetSize(200, 8)
	r.bar = r:CreateTexture(nil, "ARTWORK"); r.bar:SetTexture("Interface/TargetingFrame/UI-StatusBar"); r.bar:SetVertexColor(0.80, 0.55, 0.12)
	r.bar:SetPoint("LEFT", r.barBg, "LEFT", 0, 0); r.bar:SetHeight(6)
	r:Hide()
	return r
end
-- compact (Home): narrower places and one button, so it fits a middle column.
function W.GroupCard(parent, withButtons, compact)
	local step = compact and 54 or 68
	local c = CreateFrame("Button", nil, parent)
	c:SetHeight(W.GROUPCARD_H)
	c.text = ink(c:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"))
	c.text:SetPoint("TOPLEFT"); c.text:SetWidth(5 * step - 4); c.text:SetJustifyH("LEFT"); c.text:SetWordWrap(false)
	c.slots = {}
	for k = 1, 5 do
		local s = W.Slot(c)
		s:SetPoint("TOPLEFT", (k - 1) * step, -16)
		if compact then s:SetWidth(step - 2); s.name:SetWidth(step - 6) end
		s:SetScript("OnClick", function() if c.group and ns.Board.OpenGroupMembers then ns.Board.OpenGroupMembers(c.group) end end)
		c.slots[k] = s
	end
	c.counters = CreateFrame("Frame", nil, c)
	c.counters:SetPoint("TOPLEFT", 0, -18); c.counters:SetSize(5 * 68 - 4, 48)
	c.counters.rows = {}
	for i = 1, 3 do c.counters.rows[i] = counterRow(c.counters, i) end
	c.counters:Hide()
	c.buttons = {}
	if withButtons then for i = 1, (compact and 1 or 3) do c.buttons[i] = cardButton(c, i); if compact then c.buttons[i]:SetWidth(76) end end end
	c:SetScript("OnClick", function(self) if self.group and ns.Board.OpenGroupMembers then ns.Board.OpenGroupMembers(self.group) end end)
	function c:Set(g)
		self.group = g
		if not g then self:Hide(); return end
		local GR = ns.Groups
		local when = g.at and ns.Meetups.When(g) or L.WHEN_NOW
		self.text:SetText(when .. "  ·  " .. g.name .. "  ·  " .. short(g.by) .. (g.note and g.note ~= "" and ("  ·  " .. g.note) or ""))
		if g.size <= 5 then
			self.counters:Hide()
			local k = 0
			for _, role in ipairs(SLOT_ROLES) do
				for n = 1, g.caps[role] or 0 do
					k = k + 1
					local who = g.slots[role] and g.slots[role][n]
					if self.slots[k] then self.slots[k]:Set(role, who and short(who), who and classOf(who)); self.slots[k]:Show() end
				end
			end
			for i = k + 1, 5 do self.slots[i]:Hide() end
		else
			for _, s in ipairs(self.slots) do s:Hide() end
			local i = 0
			for _, role in ipairs(SLOT_ROLES) do
				local cap = g.caps[role]
				if cap then
					i = i + 1
					local row, have = self.counters.rows[i], #(g.slots[role] or {})
					row.text:SetText(string.format("%s %d/%d", L["ROLE_PLURAL_" .. role] or L["ROLE_" .. role], have, cap))
					roleIconPublic(row.icon, role)
					row.bar:SetWidth(math.max(1, 200 * math.min(1, have / cap))); row:Show()
				end
			end
			for j = i + 1, 3 do self.counters.rows[j]:Hide() end
			self.counters:Show()
		end
		if withButtons then
			local specs
			if g.mine then
				specs = { { L.RUN_INVITE_ALL, function() GR.InviteAll(g) end }, { g.src == "now" and L.GR_WITHDRAW or L.DP_CANCEL, function() GR.Cancel(g) end, true } }
			elseif g.myRole then
				specs = { { L.RUN_LEAVE, function() GR.Leave(g) end } }
			elseif g.caps.A then
				specs = { { L.RUN_JOIN, function() GR.Join(g, "A"); ns.Dirty("board") end } }
			else
				specs = { { L.RUN_JOIN, function(b)
					MenuUtil.CreateContextMenu(b, function(_, root)
						for _, role in ipairs({ "T", "H", "D" }) do
							if g.caps[role] and #(g.slots[role] or {}) < g.caps[role] then root:CreateButton(L["ROLE_" .. role], function() GR.Join(g, role); ns.Dirty("board") end) end
						end
					end)
				end } }
			end
			if compact and g.mine then specs = { specs[2] } end   -- one button: withdraw or cancel (Invite all is in the Groups view)
			setButtons(self, specs, g.src .. g.id)
		end
		self:Show()
	end
	c:Hide()
	return c
end
