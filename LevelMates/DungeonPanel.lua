-- DungeonPanel.lua: an activity's own panel next to the book (a dungeon, a raid, a battleground), opened from its card.
-- At the top its picture and name; then its groups as cards (Now and with a time, the same cards as the Groups view);
-- then lines: my runs' places to manage (add or take out, who waits, Discord lines waiting for a click), guildmates of
-- its levels online, and group ads read from chat. "Create a group here" goes to the Groups view's form, prefilled.
-- Every action runs from its button's click. Spec 2026-10-13-levelmates-groups-design.
local _, ns = ...
local DP = {}
ns.DungeonPanel = DP
local L, R = ns.L, ns.Roster
local unpack = unpack or table.unpack
DP.WIDTH, DP.LINES, DP.LINE_H, DP.CARDS = 470, 12, 24, 3
local TOP_GROUPS = 98
local function cardsH() return 22 + DP.CARDS * (ns.Widgets.GROUPCARD_H + 4) + 4 end

local function me() return ns.Me() end
local function Cap(s) return (s:gsub("^%l", string.upper)) end
local function section(out, key, items)
	if #items == 0 then return end
	out[#out + 1] = { header = key, count = #items }
	for _, it in ipairs(items) do out[#out + 1] = it end
end

-- The panel's lines for an activity (the groups themselves are the cards above).
function DP.Rows(id)
	local out, a = {}, ns.Activities.Get(id)
	local manage = {}
	if ns.LFG.mine and ns.LFG.mine.d == id then   -- who joined my Now group: to invite them one by one
		local who = {}
		for name, role in pairs(ns.LFG.mine.joined or {}) do who[#who + 1] = { kind = "joiner", name = name, role = role } end
		table.sort(who, function(x, y) return x.name < y.name end)
		for _, w in ipairs(who) do manage[#manage + 1] = w end
	end
	for _, m in ipairs(ns.Meetups.List(id)) do   -- my runs of five: each place, to add or take out; who waits
		if m.by == me() and m.size <= 5 then
			local s = ns.Meetups.Slots(m)
			for _, role in ipairs({ "T", "H", "D", "A" }) do
				for k = 1, m.caps[role] or 0 do manage[#manage + 1] = { kind = "slot", meet = m, role = role, name = s[role][k], confirmed = s.confirmed } end
			end
			for _, name in ipairs(s.waiting) do manage[#manage + 1] = { kind = "waiting", meet = m, name = name } end
		end
	end
	for _, h in ipairs(ns.Discord.HeldFor(id)) do manage[#manage + 1] = { kind = "held", id = h.id, line = h.line } end   -- Discord lines waiting for a click
	section(out, "manage", manage)
	local mates = {}
	for _, name in ipairs(R.List()) do
		local m = R.mates[name]
		local fits = a and a.kind == "d" and m.level and m.level >= a.min - 2 and m.level <= a.max + 2
		if fits then mates[#mates + 1] = { kind = "mate", name = name } end
	end
	section(out, "mates", mates)
	local chat = {}
	for _, ad in ipairs(ns.ChatAds.For(id)) do chat[#chat + 1] = { kind = "chat", ad = ad } end
	section(out, "chat", chat)
	return out
end

------------------------------------------------------------------ the window
local function SmallButton(parent, w)
	local b = ns.Skin.Button(parent)
	b:SetSize(w or 62, 20)
	return b
end

local function Build()
	local f = ns.Skin.Window("LevelMatesDungeonPanel", UIParent)
	DP.frame = f
	f:SetSize(DP.WIDTH, TOP_GROUPS + cardsH() + 6 + DP.LINES * DP.LINE_H + 44)
	f:SetFrameStrata("HIGH"); f:EnableMouse(true); f:SetClampedToScreen(true)   -- clicks stay on the panel, which stays on screen
	tinsert(UISpecialFrames, "LevelMatesDungeonPanel")
	f.title = f.TitleText or f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	-- the picture across the top
	f.art = f:CreateTexture(nil, "ARTWORK")
	f.art:SetPoint("TOPLEFT", 10, -28); f.art:SetPoint("TOPRIGHT", -10, -28); f.art:SetHeight(64)
	f.levels = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	f.levels:SetPoint("BOTTOMLEFT", f.art, "BOTTOMLEFT", 6, 4)
	-- its groups, as cards
	DP.groups = ns.Widgets.Panel(f, L.DP_GROUPS)
	DP.groups:SetPoint("TOPLEFT", 10, -TOP_GROUPS); DP.groups:SetSize(DP.WIDTH - 20, cardsH())
	DP.groups:SetHint(L.DP_HINT_GROUPS)
	DP.groups.cards = {}
	for i = 1, DP.CARDS do
		local c = ns.Widgets.GroupCard(DP.groups, true)
		c:SetPoint("TOPLEFT", 6, -22 - (i - 1) * (ns.Widgets.GROUPCARD_H + 4)); c:SetPoint("RIGHT", -6, 0)
		DP.groups.cards[i] = c
	end
	-- the lines below
	local top = TOP_GROUPS + cardsH() + 6
	DP.lines = {}
	for i = 1, DP.LINES do
		local line = CreateFrame("Frame", nil, f)
		line:SetSize(DP.WIDTH - 20, DP.LINE_H); line:SetPoint("TOPLEFT", 10, -(top + (i - 1) * DP.LINE_H))
		line.text = line:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		line.text:SetPoint("LEFT", 2, 0); line.text:SetJustifyH("LEFT"); line.text:SetWordWrap(false)
		line.buttons = {}
		for k = 1, 3 do
			local b = SmallButton(line, 62)
			if k == 1 then b:SetPoint("RIGHT", line, "RIGHT", 0, 0) else b:SetPoint("RIGHT", line.buttons[k - 1], "LEFT", -2, 0) end
			b:SetScript("OnClick", function(self)
				if self.confirm and not (self.pending and GetTime() - self.pending <= 5) then   -- what removes something asks first
					self.pending = GetTime(); self:SetText(L.CONFIRM_SURE)
					local stamp = self.pending
					C_Timer.After(5.05, function() if self.pending == stamp then self.pending = nil; self:SetText(self.label or "") end end)
					return
				end
				self.pending = nil
				if self.action then self.action() end
				DP.Refresh()
			end)
			b:Hide()
			line.buttons[k] = b
		end
		line:Hide()
		DP.lines[i] = line
	end
	DP.create = SmallButton(f, 180); DP.create:SetPoint("BOTTOM", 0, 10); DP.create:SetText(L.DP_CREATE)
	DP.create:SetScript("OnClick", function() if DP.id then ns.GroupsView.Prefill(DP.id) end end)
	f:Hide()
end

-- What a line shows, as a key that survives redraws (the rows are new tables each time).
local function entryKey(e)
	if not e then return "" end
	return table.concat({ e.kind or "", e.meet and e.meet.id or "", e.ad and tostring(e.ad.id or e.ad.name or "") or "", e.role or "", e.name or "", e.id or "" }, "|")
end
-- Up to three buttons on a line, right to left: { text, action, confirm }. A pending "Are you sure?" stays while the
-- button keeps the same job on the same entry; a different one resets it.
local function setButtons(line, list)
	local key = entryKey(line.entry)
	for k, b in ipairs(line.buttons) do
		local spec = list[k]
		if spec then
			local same = b.label == spec[1] and b.entry == key
			b.label, b.action, b.confirm, b.entry = spec[1], spec[2], spec[3], key
			if not (same and b.pending) then b.pending = nil; b:SetText(spec[1]) end
			b:Show()
		else b.action, b.pending = nil, nil; b:Hide() end
	end
end

local HEAD_COLOR = { manage = { 0.6, 0.8, 1 }, mates = { 1, 0.82, 0 }, chat = { 0.8, 0.8, 0.8 } }
function DP.Refresh()
	if not (DP.frame and DP.frame:IsShown() and DP.id) then return end
	local A = ns.Activities
	local id, a = DP.id, A.Get(DP.id)
	DP.frame.title:SetText(A.Name(id))
	local tex, coords = a and a.art, a and a.coords
	if tex then DP.frame.art:SetTexture(tex); DP.frame.art:SetTexCoord(unpack(coords)); DP.frame.art:Show() else DP.frame.art:Hide() end
	if a and a.kind == "d" then
		DP.frame.levels:SetText(string.format(L.CARD_LEVELS, a.min, a.max) .. (ns.Dungeons.Fits(id, UnitLevel("player")) and ("  ·  " .. L.DP_YOUR_LEVEL) or ""))
	else DP.frame.levels:SetText("") end
	-- the cards
	local groups = ns.Groups.List(id)
	for i, c in ipairs(DP.groups.cards) do c:Set(groups[i]) end
	DP.groups:SetEmpty(#groups == 0)
	DP.groups:SetNote(#groups > DP.CARDS and string.format(L.RUNS_MORE, #groups - DP.CARDS) or "")
	-- the lines
	local rows = DP.Rows(id)
	for i, line in ipairs(DP.lines) do
		local e = rows[i]
		line.entry = e
		if not e then line:Hide()
		else
			line:Show()
			local btns = {}
			if e.header then
				line.text:SetText(L["DP_" .. e.header:upper()] .. "  •  " .. e.count); line.text:SetTextColor(unpack(HEAD_COLOR[e.header]))
			elseif e.kind == "joiner" then
				line.text:SetText("   " .. e.name .. " (" .. L["ROLE_" .. e.role] .. ")"); line.text:SetTextColor(0.4, 1, 0.4)
				btns[1] = { L.DP_INVITE, function() ns.Board.Invite(e.name) end }
			elseif e.kind == "chat" then
				line.text:SetText(e.ad.name .. ": " .. e.ad.text); line.text:SetTextColor(0.85, 0.85, 0.85)
				btns[1] = { L.DP_WHISPER, function() ns.Board.Whisper(e.ad.full) end }
			elseif e.kind == "slot" then
				local m = e.meet
				local label = "   " .. Cap(L["ROLE_" .. e.role]) .. ": "
				if e.name then
					line.text:SetText(label .. e.name .. (e.confirmed and "" or (" " .. L.RUN_UNCONFIRMED))); line.text:SetTextColor(1, 1, 1)
					if e.name ~= me() then btns[1] = { L.DP_REMOVE, function() ns.Meetups.RemoveMember(m.id, e.name) end, true } end
				else
					line.text:SetText(label .. L.RUN_FREE); line.text:SetTextColor(0.55, 0.55, 0.55)
					btns[1] = { L.DP_ADD, function() DP.AddMenu(m, e.role) end }
				end
			elseif e.kind == "held" then
				line.text:SetText("   " .. L.DP_DISCORD_WAITING); line.text:SetTextColor(0.55, 0.6, 1)
				btns[1] = { L.DP_DISCORD, function() ns.Discord.SendHeld(e.id) end }
			elseif e.kind == "waiting" then
				line.text:SetText("   " .. string.format(L.RUN_WAITING, e.name)); line.text:SetTextColor(0.8, 0.7, 0.5)
			elseif e.kind == "mate" then
				local m = R.mates[e.name]
				line.text:SetText(e.name .. " · " .. string.format(L.LEVEL_N, m and m.level or 0)); line.text:SetTextColor(1, 1, 1)
				btns[1] = { L.DP_INVITE, function() ns.Board.Invite(e.name) end }
				btns[2] = { L.DP_WHISPER, function() ns.Board.Whisper(e.name) end }
			end
			setButtons(line, btns)
			line.text:SetWidth(DP.WIDTH - 24 - 64 * #btns)
		end
	end
	ns.Skin.InkWindow(DP.frame)
end

function DP.Open(id)
	if not DP.frame then Build() end
	DP.id = id
	DP.frame:ClearAllPoints()
	local board = ns.Board.frame
	if board and board:IsShown() then
		local right, screen = board:GetRight(), UIParent:GetRight()
		if right and screen and right + DP.WIDTH + 4 > screen then DP.frame:SetPoint("TOPRIGHT", board, "TOPLEFT", -4, 0)   -- no room on the right
		else DP.frame:SetPoint("TOPLEFT", board, "TOPRIGHT", 4, 0) end
	else
		DP.frame:SetPoint("CENTER")
	end
	DP.frame:Show()
	if ns.Board.frame and not DP.hooked then DP.hooked = true; ns.Board.frame:HookScript("OnHide", DP.Close) end   -- closes with the book
	DP.Refresh()
end
-- The leader's "Add…": guildmates online who are not in the run yet.
function DP.AddMenu(m, role)
	local s = ns.Meetups.Slots(m)
	local inRun = {}
	for _, r in ipairs({ "T", "H", "D", "A" }) do for _, n in ipairs(s[r] or {}) do inRun[n] = true end end
	MenuUtil.CreateContextMenu(DP.frame, function(_, root)
		root:CreateTitle(string.format(L.RUN_ADD_AS, L["ROLE_" .. role]))
		for _, name in ipairs(R.List()) do
			if not inRun[name] then root:CreateButton(name, function() ns.Meetups.AddMember(m.id, name, role); DP.Refresh() end) end
		end
	end)
end

function DP.Close() if DP.frame then DP.frame:Hide() end end

for _, e in ipairs({ "LM_LFG_CHANGED", "LM_MEETUPS_CHANGED", "LM_CHATADS_CHANGED", "LM_ROSTER_CHANGED", "LM_DISCORD_CHANGED", "LM_ROLES_CHANGED" }) do ns.On(e, function() ns.Dirty("dungeon") end) end
ns.OnRedraw("dungeon", function() return DP.frame and DP.frame:IsShown() end, function() DP.Refresh() end)
