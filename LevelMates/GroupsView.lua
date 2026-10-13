-- GroupsView.lua: the Groups section's main view, inside the book. Left: Now (groups looking for people right away,
-- mine included), today and tomorrow, later this week and the chat's group ads. Right: "Create a group": the type
-- (dungeon, raid, PvP, other), the activity or a name, the size, when (Now or a day and hour), a note, my role and
-- Discord. Publish runs only from its button. Spec 2026-10-13-levelmates-groups-design.
local _, ns = ...
local GV = {}
ns.GroupsView = GV
local L = ns.L   -- the rest load later: looked up when used
GV.NOW, GV.SOON, GV.LATER, GV.CHAT, GV.DAYS = 2, 2, 3, 3, 7
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
local function items(panel, n)
	panel.items = {}
	for i = 1, n do
		local it = CreateFrame("Button", nil, panel)
		it:SetHeight(18); it:SetPoint("TOPLEFT", PAD, -22 - (i - 1) * 20); it:SetPoint("RIGHT", -PAD, 0)
		it.text = ink(it:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"))
		it.text:SetPoint("LEFT"); it.text:SetPoint("RIGHT"); it.text:SetJustifyH("LEFT"); it.text:SetWordWrap(false)
		it:SetScript("OnClick", function(self) if self.fn then self.fn(self) end end)
		it:Hide()
		panel.items[i] = it
	end
end
local function cards(panel, n)
	panel.cards = {}
	for i = 1, n do
		local c = ns.Widgets.GroupCard(panel, true)
		c:SetPoint("TOPLEFT", PAD, -22 - (i - 1) * (ns.Widgets.GROUPCARD_H + 4)); c:SetPoint("RIGHT", -PAD, 0)
		panel.cards[i] = c
	end
end

------------------------------------------------------------------ the form
-- Minutes since 1970 for the chosen day (whenIdx 2 = today, 3 = tomorrow, ...) and hour, in this PC's local time (as
-- MeetDialog.At: time{} applies that day's summer-time rule). nil for Now.
function GV.At()
	local f = GV.form
	if f.whenIdx <= 1 then return nil end
	local d = date("*t", time() + (f.whenIdx - 2) * 86400)
	return math.floor(time({ year = d.year, month = d.month, day = d.day, hour = f.hour, min = f.minute, sec = 0 }) / 60)
end
local function whenName(i) if i == 1 then return L.WHEN_NOW end; return ns.MeetDialog.DayName(i - 2) end

local function formLabels()
	local f, A = GV.form, ns.Activities
	local a = f.d and A.Get(f.d)
	for k, chip in pairs(f.kinds) do chip:SetChecked(k == f.kind) end
	f.activityButton:SetShown(f.kind ~= "o")
	f.activityButton:SetText(a and A.Name(a.id) or L.GR_PICK)
	local free = (f.kind == "o") or (a and a.free)
	f.name:SetShown(free and true or false); f.nameLabel:SetShown(free and true or false)
	local sized = a and (a.sizes or (a.min and a.max)) and true or false
	f.sizeButton:SetShown(sized); f.sizeLabel:SetShown(sized)
	if a then f.size = A.SizeOf(a.id, f.size) end
	f.sizeButton:SetText(tostring(f.size or (a and a.size) or ""))
	for i, chip in ipairs(f.when) do chip:SetText(whenName(i)); chip:SetChecked(i == f.whenIdx) end
	local timed = f.whenIdx > 1
	f.hourButton:SetShown(timed); f.minuteButton:SetShown(timed)
	f.hourButton:SetText(string.format("%02d h", f.hour)); f.minuteButton:SetText(string.format(":%02d", f.minute))
	local roles = not a or a.roles
	f.roleLabel:SetShown(roles and true or false)
	for role, chip in pairs(f.roles) do chip:SetShown(roles and true or false); chip:SetChecked(role == f.role) end
	local ok, why = ns.Discord.Available()
	f.discord:SetEnabled(ok); if not ok then f.discord:SetChecked(false) end
	f.discordWhy:SetText(why and L[why] or "")
	local named = not free or strtrim(f.name:GetText() or "") ~= ""
	f.publish:SetEnabled(a ~= nil and named)
end

local function setKind(kind)
	local f = GV.form
	f.kind = kind
	f.d = kind == "o" and 300 or nil
	f.size = nil
	formLabels()
end

local function publish()
	local f, A = GV.form, ns.Activities
	local a = f.d and A.Get(f.d)
	if not a then return end
	local spec = { d = f.d, x = f.size, t = (a.free and f.name:GetText()) or nil, note = f.note:GetText(), discord = f.discord:GetChecked() }
	spec.role = a.roles and (f.role or ns.Roles.Of(ns.Me())) or "A"
	local ok
	if f.whenIdx <= 1 then ok = ns.LFG.Post(spec)
	else spec.at = GV.At(); ok = ns.Meetups.Create(spec) end
	if ok then
		f.note:SetText(""); f.note:ClearFocus(); f.name:ClearFocus()
		ns.Dirty("board")
	end
end

local function buildForm(p)
	local W = ns.Widgets
	local f = { panel = p, kind = "d", whenIdx = 1, hour = 21, minute = 0 }
	GV.form = f
	local y = -24
	f.kinds = {}
	for i, k in ipairs({ "d", "r", "p", "o" }) do
		local chip = W.Chip(p, L["KIND_" .. k])
		chip:SetWidth(80); chip:SetPoint("TOPLEFT", PAD + (i - 1) * 82, y)
		chip:SetScript("OnClick", function() setKind(k) end)
		f.kinds[k] = chip
	end
	y = y - 26
	f.activityButton = button(p, 240, "", function(self)
		local list = {}
		for _, a in ipairs(ns.Activities.List(f.kind)) do
			list[#list + 1] = { ns.Activities.Name(a.id), function() f.d = a.id; f.size = nil; formLabels() end }
		end
		menu(self, list)
	end)
	f.activityButton:SetPoint("TOPLEFT", PAD, y)
	y = y - 26
	f.nameLabel = ink(p:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"))
	f.nameLabel:SetPoint("TOPLEFT", PAD, y - 4); f.nameLabel:SetText(L.GR_NAME)
	f.name = CreateFrame("EditBox", nil, p, "InputBoxTemplate")
	f.name:SetSize(220, 20); f.name:SetPoint("TOPLEFT", PAD + 74, y); f.name:SetAutoFocus(false); f.name:SetMaxLetters(ns.Activities.NAME_MAX)
	f.name:SetScript("OnTextChanged", function() formLabels() end)
	f.name:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
	y = y - 26
	f.sizeLabel = ink(p:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"))
	f.sizeLabel:SetPoint("TOPLEFT", PAD, y - 4); f.sizeLabel:SetText(L.GR_SIZE)
	f.sizeButton = button(p, 70, "", function(self)
		local a = f.d and ns.Activities.Get(f.d)
		if not a then return end
		local list, sizes = {}, a.sizes
		if not sizes then sizes = {}; for n = a.min, a.max, (a.max - a.min >= 20 and 5 or 1) do sizes[#sizes + 1] = n end end
		for _, n in ipairs(sizes) do list[#list + 1] = { tostring(n), function() f.size = n; formLabels() end } end
		menu(self, list)
	end)
	f.sizeButton:SetPoint("TOPLEFT", PAD + 74, y)
	y = y - 28
	local chips = {}
	for i = 1, GV.DAYS + 1 do
		local chip = W.Chip(p, whenName(i))
		chip:SetWidth(78)
		local row, col = math.floor((i - 1) / 4), (i - 1) % 4
		chip:SetPoint("TOPLEFT", PAD + col * 82, y - row * 24)
		chip:SetScript("OnClick", function() f.whenIdx = i; formLabels() end)
		chips[i] = chip
	end
	f.when = chips   -- Now, today, tomorrow and the next days; f.whenIdx is the chosen one
	y = y - 52
	f.hourButton = button(p, 80, "", function(self)
		local list = {}
		for h = 0, 23 do list[#list + 1] = { string.format("%02d h", h), function() f.hour = h; formLabels() end } end
		menu(self, list)
	end)
	f.hourButton:SetPoint("TOPLEFT", PAD, y)
	f.minuteButton = button(p, 70, "", function(self)
		local list = {}
		for _, mm in ipairs(MINUTES) do list[#list + 1] = { string.format(":%02d", mm), function() f.minute = mm; formLabels() end } end
		menu(self, list)
	end)
	f.minuteButton:SetPoint("LEFT", f.hourButton, "RIGHT", 6, 0)
	y = y - 26
	local noteLabel = ink(p:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"))
	noteLabel:SetPoint("TOPLEFT", PAD, y); noteLabel:SetText(L.MEET_NOTE_HINT)
	f.note = CreateFrame("EditBox", nil, p, "InputBoxTemplate")
	f.note:SetSize(300, 20); f.note:SetPoint("TOPLEFT", PAD + 6, y - 14); f.note:SetAutoFocus(false); f.note:SetMaxLetters(40)
	f.note:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
	y = y - 40
	f.roleLabel = ink(p:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"))
	f.roleLabel:SetPoint("TOPLEFT", PAD, y - 4); f.roleLabel:SetText(L.RUN_MY_ROLE)
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
	f.publish = button(p, 140, L.RUNS_PUBLISH, publish)
	f.publish:SetPoint("BOTTOMRIGHT", -PAD, PAD)
end

------------------------------------------------------------------ build
function GV.Build(parent)
	local W = ns.Widgets
	local fr = CreateFrame("Frame", nil, parent)
	GV.frame = fr
	GV.now = W.Panel(fr, L.GR_NOW); GV.now:SetHint(L.GR_HINT_NOW); cards(GV.now, GV.NOW)
	GV.soon = W.Panel(fr, L.RUNS_SOON); GV.soon:SetHint(L.RUNS_HINT_SOON); cards(GV.soon, GV.SOON)
	GV.later = W.Panel(fr, L.RUNS_LATER); GV.later:SetHint(L.RUNS_HINT_LATER); items(GV.later, GV.LATER)
	GV.chat = W.Panel(fr, L.GR_CHAT); GV.chat:SetHint(L.GR_HINT_CHAT); items(GV.chat, GV.CHAT)
	GV.formPanel = W.Panel(fr, L.GR_FORM)
	buildForm(GV.formPanel)
	GV.form.role = ns.Roles.Of(ns.Me())
	GV.Layout()
	fr:Hide()
	return fr
end

GV.LEFT_W, GV.GAP = 0.58, 12
function GV.Layout()
	local fr = GV.frame
	local w = fr:GetWidth()
	if not w or w <= 0 then w = ns.Board.WIDTH - 2 * ns.Board.MARGIN end
	local h = fr:GetHeight()
	if not h or h <= 0 then h = 436 end
	local lw = math.floor(w * GV.LEFT_W)
	local cardsH = 22 + 2 * (ns.Widgets.GROUPCARD_H + 4) + 2
	GV.now:ClearAllPoints(); GV.now:SetPoint("TOPLEFT", 0, 0); GV.now:SetSize(lw, cardsH)
	GV.soon:ClearAllPoints(); GV.soon:SetPoint("TOPLEFT", 0, -cardsH - 6); GV.soon:SetSize(lw, cardsH)
	local rest = math.max(70, h - 2 * cardsH - 12)
	local half = math.floor((lw - 8) / 2)
	GV.later:ClearAllPoints(); GV.later:SetPoint("TOPLEFT", 0, -2 * cardsH - 12); GV.later:SetSize(half, rest)
	GV.chat:ClearAllPoints(); GV.chat:SetPoint("TOPLEFT", half + 8, -2 * cardsH - 12); GV.chat:SetSize(lw - half - 8, rest)
	GV.formPanel:ClearAllPoints(); GV.formPanel:SetPoint("TOPLEFT", lw + GV.GAP, 0); GV.formPanel:SetSize(w - lw - GV.GAP, h)
end

------------------------------------------------------------------ fill
local function dayIndex(at)   -- 0 today, 1 tomorrow, ...
	local t, n = date("*t", at * 60), date("*t", time())
	return math.floor((time({ year = t.year, month = t.month, day = t.day, hour = 12 }) - time({ year = n.year, month = n.month, day = n.day, hour = 12 })) / 86400 + 0.5)
end

function GV.Refresh()
	if not GV.frame or not GV.frame:IsShown() then return end
	GV.Layout()
	local now, soon, later = {}, {}, {}
	for _, g in ipairs(ns.Groups.List()) do
		if g.src == "now" then now[#now + 1] = g
		else
			local day = dayIndex(g.at)
			if day <= 1 then soon[#soon + 1] = g elseif day < GV.DAYS then later[#later + 1] = g end
		end
	end
	for i = #now, GV.NOW + 1, -1 do table.insert(later, 1, now[i]) end     -- more than the cards: first in the list below
	for i = #soon, GV.SOON + 1, -1 do table.insert(later, 1, soon[i]) end
	for i, c in ipairs(GV.now.cards) do c:Set(now[i]) end
	for i, c in ipairs(GV.soon.cards) do c:Set(soon[i]) end
	GV.now:SetEmpty(#now == 0); GV.soon:SetEmpty(#soon == 0)
	GV.now:SetNote(#now > GV.NOW and string.format(L.RUNS_MORE, #now - GV.NOW) or "")
	GV.soon:SetNote(#soon > GV.SOON and string.format(L.RUNS_MORE, #soon - GV.SOON) or "")
	for i, it in ipairs(GV.later.items) do
		local g = later[i]
		if g then
			it.text:SetText((g.at and ns.Meetups.When(g) or L.WHEN_NOW) .. "  ·  " .. g.name .. "  ·  " .. (ns.ShortName and ns.ShortName(g.by) or g.by) .. "  (" .. g.count .. "/" .. g.size .. ")")
			it.fn = function() ns.Board.OpenGroupMembers(g) end
			it:Show()
		else it:Hide() end
	end
	GV.later:SetEmpty(#later == 0)
	GV.later:SetNote(#later > GV.LATER and string.format(L.RUNS_MORE, #later - GV.LATER) or "")
	local chat = {}
	for _, d in ipairs(ns.Dungeons.Sorted()) do for _, a in ipairs(ns.ChatAds.For(d.id)) do chat[#chat + 1] = { d = d.id, a = a } end end
	table.sort(chat, function(x, y) return x.a.t > y.a.t end)
	for i, it in ipairs(GV.chat.items) do
		local e = chat[i]
		if e then
			it.text:SetText(e.a.name .. ": " .. ns.Dungeons.Name(e.d))
			it.fn = function() ns.Board.Whisper(e.a.name) end
			it:Show()
		else it:Hide() end
	end
	GV.chat:SetEmpty(#chat == 0)
	formLabels()
	ns.Skin.InkPass()
end

-- From an activity's panel: the Groups view with that activity chosen.
function GV.Prefill(d)
	local a = ns.Activities.Get(d)
	if not a then return end
	ns.char.groupsView = "groups"
	ns.Board.ShowTab("lfg")
	local f = GV.form
	f.kind, f.d, f.size = a.kind, a.id, nil
	formLabels()
end
