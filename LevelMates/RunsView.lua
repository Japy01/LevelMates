-- RunsView.lua: Groups → Runs, inside the book: today's and tomorrow's runs as cards (slots and buttons), later days as
-- a list, and the Create-run form beside them. Meetups.Create runs only from Publish.
-- Spec 2026-10-12-levelmates-interface-design (B1).
local _, ns = ...
local RV = {}
ns.RunsView = RV
local L = ns.L   -- Meetups and Dungeons load later: looked up when used
RV.CARDS, RV.LATER, RV.DAYS = 4, 5, 7
local MINUTES = { 0, 15, 30, 45 }
local PAD = 6

local function ink(fs) ns.Skin.InkFont(fs); return fs end
local function menu(owner, items)
	MenuUtil.CreateContextMenu(owner, function(_, root)
		for _, it in ipairs(items) do root:CreateButton(it[1], it[2]) end
	end)
end
local function button(parent, w, text, fn)
	local b = ns.Skin.Button(parent)
	b:SetSize(w, 20); b:SetText(text or "")
	b:SetScript("OnClick", fn)
	return b
end

-- Minutes since 1970 for the form's day, hour and minute, in this PC's local time (as MeetDialog.At: time{} applies
-- that day's summer-time rule).
function RV.At()
	local f = RV.form
	local d = date("*t", time() + f.dayOffset * 86400)
	return math.floor(time({ year = d.year, month = d.month, day = d.day, hour = f.hour, min = f.minute, sec = 0 }) / 60)
end

------------------------------------------------------------------ build
local function formLabels()
	local f = RV.form
	f.dungeonButton:SetText(f.dungeon and ns.Dungeons.Name(f.dungeon) or L.RUNS_PICK_DUNGEON)
	f.hourButton:SetText(string.format("%02d h", f.hour))
	f.minuteButton:SetText(string.format(":%02d", f.minute))
	for i, chip in ipairs(f.days) do chip:SetText(ns.MeetDialog.DayName(i - 1)); chip:SetChecked(i - 1 == f.dayOffset) end   -- names follow the clock past midnight
	for role, chip in pairs(f.roles) do chip:SetChecked(role == f.role) end
	local ok, why = ns.Discord.Available()
	f.discord:SetEnabled(ok); if not ok then f.discord:SetChecked(false) end
	f.discordWhy:SetText(why and L[why] or "")   -- why not, or that the game would not say
	f.publish:SetEnabled(f.dungeon ~= nil)
end

local function buildForm(p)
	local W = ns.Widgets
	local f = { panel = p, dayOffset = 0, hour = 21, minute = 0 }
	RV.form = f
	local y = -24
	f.dungeonButton = button(p, 200, "", function(self)
		local items = {}
		for _, d in ipairs(ns.Dungeons.Sorted()) do items[#items + 1] = { ns.Dungeons.Name(d.id), function() f.dungeon = d.id; formLabels() end } end
		menu(self, items)
	end)
	f.dungeonButton:SetPoint("TOPLEFT", PAD, y)
	y = y - 26
	f.days = {}
	for i = 1, RV.DAYS do
		local chip = W.Chip(p, ns.MeetDialog.DayName(i - 1))
		chip:SetWidth(78)
		local row, col = math.floor((i - 1) / 4), (i - 1) % 4
		chip:SetPoint("TOPLEFT", PAD + col * 82, y - row * 24)
		chip:SetScript("OnClick", function() f.dayOffset = i - 1; formLabels() end)
		f.days[i] = chip
	end
	y = y - 52
	f.hourButton = button(p, 80, "", function(self)
		local items = {}
		for h = 0, 23 do items[#items + 1] = { string.format("%02d h", h), function() f.hour = h; formLabels() end } end
		menu(self, items)
	end)
	f.hourButton:SetPoint("TOPLEFT", PAD, y)
	f.minuteButton = button(p, 70, "", function(self)
		local items = {}
		for _, mm in ipairs(MINUTES) do items[#items + 1] = { string.format(":%02d", mm), function() f.minute = mm; formLabels() end } end
		menu(self, items)
	end)
	f.minuteButton:SetPoint("LEFT", f.hourButton, "RIGHT", 6, 0)
	y = y - 28
	local noteLabel = ink(p:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"))
	noteLabel:SetPoint("TOPLEFT", PAD, y); noteLabel:SetText(L.MEET_NOTE_HINT)
	f.note = CreateFrame("EditBox", nil, p, "InputBoxTemplate")
	f.note:SetSize(300, 20); f.note:SetPoint("TOPLEFT", PAD + 6, y - 14); f.note:SetAutoFocus(false); f.note:SetMaxLetters(40)
	y = y - 40
	local roleLabel = ink(p:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"))
	roleLabel:SetPoint("TOPLEFT", PAD, y - 4); roleLabel:SetText(L.RUN_MY_ROLE)
	f.roles = {}
	for i, role in ipairs({ "T", "H", "D" }) do
		local chip = W.Chip(p, L["ROLE_" .. role])
		chip:SetWidth(74); chip:SetPoint("TOPLEFT", PAD + 80 + (i - 1) * 78, y)
		chip:SetScript("OnClick", function() f.role = role; formLabels() end)
		f.roles[role] = chip
	end
	y = y - 26
	f.discord = CreateFrame("CheckButton", nil, p, "UICheckButtonTemplate")
	f.discord:SetSize(22, 22); f.discord:SetPoint("TOPLEFT", PAD, y)
	local dcLabel = ink(p:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"))
	dcLabel:SetPoint("LEFT", f.discord, "RIGHT", 2, 0); dcLabel:SetText(L.RUN_DISCORD)
	f.discordWhy = ink(p:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"))
	f.discordWhy:SetPoint("TOPLEFT", PAD, y - 24); f.discordWhy:SetPoint("RIGHT", -PAD, 0)
	f.discordWhy:SetJustifyH("LEFT"); f.discordWhy:SetWordWrap(true)
	f.publish = button(p, 140, L.RUNS_PUBLISH, function()
		if not f.dungeon then return end
		if ns.Meetups.Create(f.dungeon, RV.At(), f.note:GetText(), f.role, f.discord:GetChecked()) then   -- a refused run keeps the form
			f.note:SetText(""); f.note:ClearFocus()
			ns.Dirty("board")
		end
	end)
	f.publish:SetPoint("BOTTOMRIGHT", -PAD, PAD)
end

function RV.Build(parent)
	local W = ns.Widgets
	local fr = CreateFrame("Frame", nil, parent)
	RV.frame = fr
	RV.soon = W.Panel(fr, L.RUNS_SOON); RV.soon:SetHint(L.RUNS_HINT_SOON)
	RV.cards = {}
	for i = 1, RV.CARDS do
		local c = W.RunCard(RV.soon, true)
		c:SetPoint("TOPLEFT", PAD, -22 - (i - 1) * (W.RUNCARD_H + 4)); c:SetPoint("RIGHT", -PAD, 0)
		RV.cards[i] = c
	end
	RV.later = W.Panel(fr, L.RUNS_LATER); RV.later:SetHint(L.RUNS_HINT_LATER)
	RV.later.items = {}
	for i = 1, RV.LATER do
		local it = CreateFrame("Button", nil, RV.later)
		it:SetHeight(18); it:SetPoint("TOPLEFT", PAD, -22 - (i - 1) * 20); it:SetPoint("RIGHT", -PAD, 0)
		it.text = ink(it:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"))
		it.text:SetPoint("LEFT"); it.text:SetPoint("RIGHT"); it.text:SetJustifyH("LEFT"); it.text:SetWordWrap(false)
		it:SetScript("OnClick", function(self) if self.meet then ns.Board.OpenMeetMenu(self.meet) end end)
		it:Hide()
		RV.later.items[i] = it
	end
	RV.formPanel = W.Panel(fr, L.RUNS_FORM)
	buildForm(RV.formPanel)
	RV.form.role = ns.Roles.Of(ns.Me())
	RV.Layout()
	fr:Hide()
	return fr
end

-- Left the runs (58%), right the form; the later list under the cards.
RV.LEFT_W, RV.GAP = 0.58, 12
function RV.Layout()
	local fr = RV.frame
	local w = fr:GetWidth()
	if not w or w <= 0 then w = ns.Board.WIDTH - 2 * ns.Board.MARGIN end
	local h = fr:GetHeight()
	if not h or h <= 0 then h = 464 end
	local lw = math.floor(w * RV.LEFT_W)
	local soonH = 22 + RV.CARDS * (ns.Widgets.RUNCARD_H + 4) + 4
	RV.soon:ClearAllPoints(); RV.soon:SetPoint("TOPLEFT", 0, 0); RV.soon:SetSize(lw, soonH)
	RV.later:ClearAllPoints(); RV.later:SetPoint("TOPLEFT", 0, -soonH - 8); RV.later:SetSize(lw, math.max(60, h - soonH - 8))
	RV.formPanel:ClearAllPoints(); RV.formPanel:SetPoint("TOPLEFT", lw + RV.GAP, 0); RV.formPanel:SetSize(w - lw - RV.GAP, h)
end

------------------------------------------------------------------ fill
local function dayIndex(at)   -- 0 today, 1 tomorrow, ...
	local t, n = date("*t", at * 60), date("*t", time())
	return math.floor((time({ year = t.year, month = t.month, day = t.day, hour = 12 }) - time({ year = n.year, month = n.month, day = n.day, hour = 12 })) / 86400 + 0.5)
end

function RV.Refresh()
	if not RV.frame or not RV.frame:IsShown() then return end
	RV.Layout()
	local now, soon, later = ns.Meetups.Now(), {}, {}
	for _, m in ipairs(ns.Meetups.List()) do
		if m.at >= now then   -- not the ones already started
			local day = dayIndex(m.at)
			if day <= 1 then soon[#soon + 1] = m elseif day < RV.DAYS then later[#later + 1] = m end
		end
	end
	for i, c in ipairs(RV.cards) do c:Set(soon[i]) end
	RV.soon:SetEmpty(#soon == 0)
	for i = #soon, RV.CARDS + 1, -1 do table.insert(later, 1, soon[i]) end   -- more than the cards: first in the list below, still reachable
	RV.soon:SetNote(#soon > RV.CARDS and string.format(L.RUNS_MORE, #soon - RV.CARDS) or "")
	RV.later:SetNote(#later > RV.LATER and string.format(L.RUNS_MORE, #later - RV.LATER) or "")
	for i, it in ipairs(RV.later.items) do
		local m = later[i]
		it.meet = m
		if m then
			it.text:SetText(ns.Meetups.When(m) .. "  ·  " .. ns.Dungeons.Name(m.d) .. "  ·  " .. (ns.ShortName and ns.ShortName(m.by) or m.by) .. "  (" .. ns.Meetups.Count(m) .. "/5)")
			it:Show()
		else it:Hide() end
	end
	RV.later:SetEmpty(#later == 0)
	formLabels()
	ns.Skin.InkPass()
end
