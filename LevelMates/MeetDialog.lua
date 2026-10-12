-- MeetDialog.lua: "Meet here..." from a dungeon card: day, hour, minutes, a note, my role in the run and whether to
-- announce it in the guild's Discord. Meetups.Create runs only from its Create button.
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
	local b = ns.Skin.Button(f)
	b:SetSize(w, 22); b:SetPoint(point, x, y); b:SetText(text)
	b:SetScript("OnClick", onClick)
	return b
end

function Dlg.DayName(offset)
	if offset == 0 then return L.MEET_TODAY elseif offset == 1 then return L.MEET_TOMORROW end
	return L["DAY_" .. date("*t", time() + offset * 86400).wday]
end

-- Minutes since 1970 for the chosen day (0 = today), hour and minute, in this PC's local time; time(table) applies
-- the summer-time rules of that day, so a meetup across a clock change keeps its hour.
function Dlg.At()
	local d = date("*t", time() + Dlg.dayOffset * 86400)
	return math.floor(time({ year = d.year, month = d.month, day = d.day, hour = Dlg.hour, min = Dlg.minute, sec = 0 }) / 60)
end

local function Labels()
	Dlg.dayButton:SetText(Dlg.DayName(Dlg.dayOffset))
	Dlg.hourButton:SetText(string.format("%02d h", Dlg.hour))
	Dlg.minuteButton:SetText(string.format(":%02d", Dlg.minute))
	for role, b in pairs(Dlg.roleButtons or {}) do b:SetEnabled(role ~= Dlg.role) end   -- the chosen one is pressed in
end
-- Discord: available, or why not (and "Copy for Discord" instead).
local function DiscordState()
	local ok, why = ns.Discord.Available()
	Dlg.discord:SetEnabled(ok); if not ok then Dlg.discord:SetChecked(false) end
	Dlg.discordWhy:SetText(ok and "" or L[why])
	Dlg.copy:SetShown(not ok)
end

local function Build()
	local f = ns.Skin.Window("LevelMatesMeetDialog", UIParent)
	Dlg.frame = f
	f:SetSize(330, 290); f:SetPoint("CENTER"); f:SetFrameStrata("DIALOG")
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
	-- my role in the run
	local roleLabel = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	roleLabel:SetPoint("TOPLEFT", 20, -118); roleLabel:SetText(L.RUN_MY_ROLE)
	Dlg.roleButtons = {}
	for i, role in ipairs({ "T", "H", "D" }) do
		Dlg.roleButtons[role] = Button(f, 80, "TOPLEFT", 100 + (i - 1) * 74, -112, L["ROLE_" .. role], function() Dlg.role = role; Labels() end)
		Dlg.roleButtons[role]:SetWidth(72)
	end
	-- announce in Discord
	local dc = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
	dc:SetSize(24, 24); dc:SetPoint("TOPLEFT", 16, -142)
	Dlg.discord = dc
	local dcLabel = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	dcLabel:SetPoint("LEFT", dc, "RIGHT", 4, 0); dcLabel:SetText(L.RUN_DISCORD)
	local why = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	why:SetPoint("TOPLEFT", 22, -170); why:SetWidth(286); why:SetJustifyH("LEFT"); why:SetWordWrap(true)
	Dlg.discordWhy = why
	Dlg.copy = Button(f, 150, "BOTTOMLEFT", 90, 42, L.RUN_COPY_DISCORD, function()
		local m = { id = "x", d = Dlg.dungeon, at = Dlg.At(), n = Dlg.note:GetText(), by = ns.Me(), role = Dlg.role, joined = {} }
		ns.DiscordCopy.OpenText(ns.Discord.Line("new", m))
	end)
	Dlg.ok = Button(f, 130, "BOTTOMLEFT", 16, 14, L.MEET_CREATE, function()
		if M.Create(Dlg.dungeon, Dlg.At(), Dlg.note:GetText(), Dlg.role, Dlg.discord:GetChecked()) then f:Hide() end   -- a refused run keeps the dialog open
	end)
	Button(f, 130, "BOTTOMRIGHT", -16, 14, L.LFG_CLOSE, function() f:Hide() end)
end

function Dlg.Open(d)
	if not D.Get(d) then return end
	if not Dlg.frame then Build() end
	Dlg.dungeon = d
	if Dlg.frame.TitleText then Dlg.frame.TitleText:SetText(string.format(L.MEET_TITLE, D.Name(d))) end
	Dlg.note:SetText("")
	Dlg.role = ns.Roles.Of(ns.Me())
	Labels()
	DiscordState()
	Dlg.frame:Show()
end

-- Open with a day (0 = today), hour and minute already chosen (Together's "make it a run").
function Dlg.OpenAt(d, offset, hour, minute)
	Dlg.Open(d)
	if not Dlg.frame or not Dlg.frame:IsShown() then return end
	Dlg.dayOffset, Dlg.hour, Dlg.minute = offset, hour, minute
	Labels()
end

ns.On("LM_MEET_HERE", Dlg.Open)
