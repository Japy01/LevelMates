-- Tray.lua: every notice is kept in a tray (the last 30, none older than 2 hours), the minimap button counts the unread,
-- and a strip under the minimap shows the newest for 10 s: never in the first 20 s after entering the world, and after
-- combat rather than during it. Opening the tray marks all as read. Spec 2026-10-12-levelmates-interface-design (B2).
local _, ns = ...
local T = {}
ns.Tray = T
local L = ns.L
T.MAX, T.KEEP, T.STRIP_SECONDS, T.STRIP_GRACE, T.ROWS = 30, 7200, 10, 20, 12
local enteredAt, pendingStrip = -math.huge, false

local function store()
	ns.char.tray = ns.char.tray or { list = {}, read = 0 }
	return ns.char.tray
end
local function prune(s)
	local cutoff = time() - T.KEEP
	for i = #s.list, 1, -1 do if s.list[i].t < cutoff then table.remove(s.list, i) end end
	while #s.list > T.MAX do table.remove(s.list, 1) end
end

-- Newest first.
function T.List()
	if not ns.char then return {} end
	local s = store()
	prune(s)
	local out = {}
	for i = #s.list, 1, -1 do out[#out + 1] = s.list[i] end
	return out
end
function T.Unread()
	if not ns.char then return 0 end
	local s, n = store(), 0
	prune(s)
	for _, e in ipairs(s.list) do if e.unread then n = n + 1 end end
	return n
end
function T.MarkRead()
	local s = store()
	s.read = time()
	for _, e in ipairs(s.list) do e.unread = nil end
	ns.Fire("LM_TRAY_CHANGED")
end

------------------------------------------------------------------ the strip
local function inCombat() return (InCombatLockdown and InCombatLockdown()) or (UnitAffectingCombat and UnitAffectingCombat("player")) end
local function buildStrip()
	local s = CreateFrame("Button", "LevelMatesStrip", UIParent)
	s:SetSize(240, 20); s:SetPoint("TOP", Minimap, "BOTTOM", 0, -18); s:SetFrameStrata("MEDIUM")
	s.bg = s:CreateTexture(nil, "BACKGROUND"); s.bg:SetAllPoints(); s.bg:SetColorTexture(0, 0, 0, 0.6)
	s.text = s:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	s.text:SetPoint("LEFT", 6, 0); s.text:SetPoint("RIGHT", -6, 0); s.text:SetWordWrap(false)
	s:SetScript("OnClick", function(self) self:Hide(); T.Open() end)
	s:Hide()
	T.strip = s
end
local function showStrip()
	local s = store().list
	local e = s[#s]
	if not e then return end
	if not T.strip then buildStrip() end
	local st = T.strip
	st.stamp = (st.stamp or 0) + 1
	local stamp = st.stamp
	st.text:SetText((e.text:gsub("|H.-|h(.-)|h", "%1")))
	st:SetAlpha(1); st:Show()
	C_Timer.After(T.STRIP_SECONDS - 0.5, function() if st.stamp == stamp then st:SetAlpha(0.5) end end)
	C_Timer.After(T.STRIP_SECONDS, function() if st.stamp == stamp then st:Hide() end end)
end
local function strip()
	if ns.db.settings.stripNotices == false then return end
	if GetTime() - enteredAt < T.STRIP_GRACE then return end
	if inCombat() then pendingStrip = true; return end
	showStrip()
end

-- A notice: kept, counted, and on the strip.
function T.Add(text, where)
	if not ns.char then return end
	local s = store()
	s.list[#s.list + 1] = { t = time(), text = text, where = where, unread = true }
	prune(s)
	ns.Fire("LM_TRAY_CHANGED")
	strip()
end

------------------------------------------------------------------ the tray window
local function buildTray()
	local f = ns.Skin.Window("LevelMatesTray", UIParent)
	T.frame = f
	f:SetSize(380, 60 + T.ROWS * 22); f:SetPoint("TOPRIGHT", -220, -200); f:SetFrameStrata("DIALOG")
	f:SetMovable(true); f:EnableMouse(true); f:SetClampedToScreen(true); f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", f.StartMoving); f:SetScript("OnDragStop", f.StopMovingOrSizing)
	tinsert(UISpecialFrames, "LevelMatesTray")
	if f.TitleText then f.TitleText:SetText(L.TRAY_TITLE) end
	T.rows = {}
	for i = 1, T.ROWS do
		local r = CreateFrame("Frame", nil, f)
		r:SetHeight(20); r:SetPoint("TOPLEFT", 14, -30 - (i - 1) * 22); r:SetPoint("RIGHT", -14, 0)
		r.text = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		r.text:SetPoint("LEFT"); r.text:SetJustifyH("LEFT"); r.text:SetWordWrap(false)
		r.go = ns.Skin.Button(r)
		r.go:SetSize(44, 18); r.go:SetPoint("RIGHT"); r.go:SetText(L.TRAY_GO)
		r.go:SetScript("OnClick", function(self) if self.where then ns.Board.ShowTab(self.where) end end)
		r.text:SetPoint("RIGHT", r.go, "LEFT", -4, 0)
		r:Hide()
		T.rows[i] = r
	end
	f.empty = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	f.empty:SetPoint("TOP", 0, -40); f.empty:SetText(L.TRAY_EMPTY)
	local clear = ns.Skin.Button(f)
	clear:SetSize(100, 20); clear:SetPoint("BOTTOMRIGHT", -14, 10); clear:SetText(L.TRAY_CLEAR)
	clear:SetScript("OnClick", function() wipe(store().list); ns.Fire("LM_TRAY_CHANGED"); T.Refresh() end)
	f:Hide()
end
function T.Refresh()
	if not (T.frame and T.frame:IsShown()) then return end
	local list = T.List()
	for i, r in ipairs(T.rows) do
		local e = list[i]
		if e then
			r.text:SetText(date("%H:%M", e.t) .. "  " .. e.text)
			r.go.where = e.where; r.go:SetShown(e.where ~= nil)
			r:Show()
		else r:Hide() end
	end
	T.frame.empty:SetShown(#list == 0)
	ns.Skin.InkWindow(T.frame)
end
function T.Open()
	if not T.frame then buildTray() end
	T.frame:Show()
	T.MarkRead()
	T.Refresh()
end
function T.Toggle() if T.frame and T.frame:IsShown() then T.frame:Hide() else T.Open() end end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_ENTERING_WORLD"); ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:SetScript("OnEvent", function(_, event)
	if event == "PLAYER_ENTERING_WORLD" then enteredAt = GetTime()
	elseif pendingStrip then pendingStrip = false; showStrip() end
end)
ns.On("LM_TRAY_CHANGED", function() T.Refresh() end)
ns.On("LM_LOADED", function() if not T.strip and Minimap then buildStrip() end end)
ns.Slash("avisos", T.Toggle); ns.Slash("tray", T.Toggle)
