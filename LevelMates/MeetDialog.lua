-- MeetDialog.lua: "Meet here..." from a dungeon card: day, hour, minutes and a note. Meetups.Create runs only
-- from its Create button.
local _, ns = ...
local Dlg = { dayOffset = 0, hour = 21, minute = 0 }
ns.MeetDialog = Dlg
local L, D, M = ns.L, ns.Dungeons, ns.Meetups
local MINUTES = { 0, 15, 30, 45 }

local function Menu(owner, items)
	MenuUtil.CreateContextMenu(owner, function(_, root)
		for _, it in ipairs(items) do root:CreateButton(it[1], it[2]) end
	end)
end
local function Button(f, w, point, x, y, text, onClick)
	local b = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
	b:SetSize(w, 22); b:SetPoint(point, x, y); b:SetText(text)
	b:SetScript("OnClick", onClick)
	return b
end

function Dlg.DayName(offset)
	if offset == 0 then return L.MEET_TODAY elseif offset == 1 then return L.MEET_TOMORROW end
	return L["DAY_" .. date("*t", time() + offset * 86400).wday]
end

-- Minutes since 1970 for the chosen day (0 = today), hour and minute, in this PC's local time.
function Dlg.At()
	local now, t = time(), date("*t")
	local midnight = now - (t.hour * 3600 + t.min * 60 + t.sec)
	return math.floor((midnight + Dlg.dayOffset * 86400 + Dlg.hour * 3600 + Dlg.minute * 60) / 60)
end

local function Labels()
	Dlg.dayButton:SetText(Dlg.DayName(Dlg.dayOffset))
	Dlg.hourButton:SetText(string.format("%02d h", Dlg.hour))
	Dlg.minuteButton:SetText(string.format(":%02d", Dlg.minute))
end

local function Build()
	local f = CreateFrame("Frame", "LevelMatesMeetDialog", UIParent, "BasicFrameTemplateWithInset")
	Dlg.frame = f
	f:SetSize(330, 190); f:SetPoint("CENTER"); f:SetFrameStrata("DIALOG")
	f:SetMovable(true); f:EnableMouse(true); f:SetClampedToScreen(true); f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", f.StartMoving); f:SetScript("OnDragStop", f.StopMovingOrSizing)
	tinsert(UISpecialFrames, "LevelMatesMeetDialog")
	f:Hide()
	Dlg.dayButton = Button(f, 130, "TOPLEFT", 16, -36, "", function(self)
		local items = {}
		for o = 0, 6 do items[#items + 1] = { Dlg.DayName(o), function() Dlg.dayOffset = o; Labels() end } end
		Menu(self, items)
	end)
	Dlg.hourButton = Button(f, 80, "TOPLEFT", 152, -36, "", function(self)
		local items = {}
		for h = 0, 23 do items[#items + 1] = { string.format("%02d h", h), function() Dlg.hour = h; Labels() end } end
		Menu(self, items)
	end)
	Dlg.minuteButton = Button(f, 70, "TOPLEFT", 238, -36, "", function(self)
		local items = {}
		for _, mm in ipairs(MINUTES) do items[#items + 1] = { string.format(":%02d", mm), function() Dlg.minute = mm; Labels() end } end
		Menu(self, items)
	end)
	local hint = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	hint:SetPoint("TOPLEFT", 20, -70); hint:SetText(L.MEET_NOTE_HINT)
	local note = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
	note:SetSize(286, 22); note:SetPoint("TOPLEFT", 22, -86); note:SetAutoFocus(false); note:SetMaxLetters(40)
	Dlg.note = note
	Dlg.ok = Button(f, 130, "BOTTOMLEFT", 16, 14, L.MEET_CREATE, function()
		if M.Create(Dlg.dungeon, Dlg.At(), Dlg.note:GetText()) then f:Hide() end   -- a refused meetup keeps the dialog open
	end)
	Button(f, 130, "BOTTOMRIGHT", -16, 14, L.LFG_CLOSE, function() f:Hide() end)
end

function Dlg.Open(d)
	if not D.Get(d) then return end
	if not Dlg.frame then Build() end
	Dlg.dungeon = d
	if Dlg.frame.TitleText then Dlg.frame.TitleText:SetText(string.format(L.MEET_TITLE, D.Name(d))) end
	Dlg.note:SetText("")
	Labels()
	Dlg.frame:Show()
end

ns.On("LM_MEET_HERE", Dlg.Open)
