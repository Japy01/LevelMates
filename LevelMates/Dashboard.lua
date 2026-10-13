-- Dashboard.lua: Home as a dashboard inside the book: four numbers on top (guild level, online, my item level, the
-- week's challenge), the MOTD as a strip, my character on the left, now / next runs / quests in the middle, who is
-- where and the wall on the right. Each panel says what to do when it is empty. Every action runs from a click.
-- Spec 2026-10-12-levelmates-interface-design (A4).
local _, ns = ...
local DB = {}
ns.Dashboard = DB
local L, R = ns.L, ns.Roster
local unpack = unpack or table.unpack
DB.NOW, DB.RUNS, DB.QUESTS, DB.ZONES, DB.WALL = 3, 2, 3, 6, 6
local GEAR_SLOTS = { 1, 2, 3, 15, 5, 9, 10, 6, 7, 8, 11, 12, 13, 14, 16, 17, 18 }   -- the 17 that count (no shirt, no tabard)
local CLASS_ICON = "Interface\\TargetingFrame\\UI-Classes-Circles"
local ITEM_H, PAD = 18, 6

local function ink(fs) ns.Skin.InkFont(fs); return fs end
local function classColor(class)
	local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
	if c then return c.r, c.g, c.b end
	return 1, 1, 1
end
local function classOf(name)
	if name == ns.Me() then return select(2, UnitClass("player")) end
	local m = R.mates[name]
	return m and m.class
end
local function zoneName(mapId) local info = mapId and C_Map.GetMapInfo(mapId); return info and info.name or "" end

-- Lines in a panel: a text, an optional button on the right; the whole line clickable when given an action.
local function items(panel, n, withButton)
	panel.items = {}
	for i = 1, n do
		local it = CreateFrame("Button", nil, panel)
		it:SetHeight(ITEM_H)
		it:SetPoint("TOPLEFT", PAD, -22 - (i - 1) * (ITEM_H + 2)); it:SetPoint("RIGHT", -PAD, 0)
		it.text = ink(it:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"))
		it.text:SetPoint("LEFT"); it.text:SetJustifyH("LEFT"); it.text:SetWordWrap(false)
		if withButton then
			it.action = ns.Skin.Button(it)
			it.action:SetSize(70, 18); it.action:SetPoint("RIGHT")
			it.action:SetScript("OnClick", function(self) if self.fn then self.fn() end end)
			it.text:SetPoint("RIGHT", it.action, "LEFT", -4, 0)
		else
			it.text:SetPoint("RIGHT")
		end
		it:SetScript("OnClick", function(self) if self.fn then self.fn() end end)
		it:Hide()
		panel.items[i] = it
	end
end
local function setItem(it, text, fn, buttonText, buttonFn)
	it.text:SetText(text); it.fn = fn
	if it.action then
		it.action.fn = buttonFn
		it.action:SetText(buttonText or ""); it.action:SetShown(buttonFn ~= nil)
	end
	it:Show()
end
local function fill(panel, list, set)
	for i, it in ipairs(panel.items) do
		if list[i] then set(it, list[i]) else it:Hide() end
	end
	panel:SetEmpty(#list == 0)
end

------------------------------------------------------------------ build
local function buildMe(p)
	p.name = ink(p:CreateFontString(nil, "OVERLAY", "GameFontNormal"))
	p.name:SetPoint("TOPLEFT", PAD, -24); p.name:SetPoint("RIGHT", -PAD, 0); p.name:SetJustifyH("LEFT")
	p.level = ink(p:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"))
	p.level:SetPoint("TOPLEFT", p.name, "BOTTOMLEFT", 0, -4)
	-- the XP bar, with the rested part ahead of it
	p.xpBg = p:CreateTexture(nil, "BORDER"); p.xpBg:SetColorTexture(0, 0, 0, 0.25)
	p.xpBg:SetPoint("TOPLEFT", p.level, "BOTTOMLEFT", 0, -6); p.xpBg:SetPoint("RIGHT", -PAD, 0); p.xpBg:SetHeight(10)
	p.xpRested = p:CreateTexture(nil, "ARTWORK"); p.xpRested:SetColorTexture(0.25, 0.4, 0.9, 0.45)
	p.xpRested:SetPoint("TOPLEFT", p.xpBg); p.xpRested:SetHeight(10)
	p.xpFill = p:CreateTexture(nil, "OVERLAY"); p.xpFill:SetColorTexture(0.55, 0.2, 0.7, 0.9)
	p.xpFill:SetPoint("TOPLEFT", p.xpBg); p.xpFill:SetHeight(10)
	p.xpText = ink(p:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"))
	p.xpText:SetPoint("TOPLEFT", p.xpBg, "BOTTOMLEFT", 0, -3)
	-- the gear in miniature: a square per slot, in its item's quality colour
	p.gearLabel = ink(p:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"))
	p.gearLabel:SetPoint("TOPLEFT", p.xpText, "BOTTOMLEFT", 0, -10)
	p.gear = {}
	for i = 1, #GEAR_SLOTS do
		local sq = CreateFrame("Button", nil, p)
		sq:SetSize(11, 11)
		sq:SetPoint("TOPLEFT", p.gearLabel, "BOTTOMLEFT", (i - 1) * 12, -4)
		sq.tex = sq:CreateTexture(nil, "ARTWORK"); sq.tex:SetAllPoints()
		sq.slot = GEAR_SLOTS[i]
		sq:SetScript("OnEnter", function(self)
			if not (GameTooltip and self.itemId) then return end
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:SetHyperlink("item:" .. self.itemId); GameTooltip:Show()
		end)
		sq:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
		sq:SetScript("OnClick", function() if ns.GearWindow then ns.GearWindow.Open(ns.Me()) end end)
		p.gear[i] = sq
	end
	p.role = ink(p:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"))
	p.role:SetPoint("TOPLEFT", p.gearLabel, "BOTTOMLEFT", 0, -22)
	p.week = ink(p:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"))
	p.week:SetPoint("TOPLEFT", p.role, "BOTTOMLEFT", 0, -6)
	-- my card and my gear, a click away
	p.card = ns.Skin.Button(p)
	p.card:SetSize(100, 20); p.card:SetPoint("TOPLEFT", p.week, "BOTTOMLEFT", 0, -12); p.card:SetText(L.DB_MY_CARD)
	p.card:SetScript("OnClick", function() ns.MateCard.Show(ns.Me()) end)
	p.gearButton = ns.Skin.Button(p)
	p.gearButton:SetSize(100, 20); p.gearButton:SetPoint("LEFT", p.card, "RIGHT", 6, 0); p.gearButton:SetText(L.DB_MY_GEAR)
	p.gearButton:SetScript("OnClick", function() if ns.GearWindow then ns.GearWindow.Open(ns.Me()) end end)
end

local function buildRuns(p)
	p.cards = {}
	for i = 1, DB.RUNS do
		local c = ns.Widgets.RunCard(p)
		c:SetPoint("TOPLEFT", PAD, -22 - (i - 1) * 68); c:SetPoint("RIGHT", -PAD, 0)
		p.cards[i] = c
	end
end

local function buildWhere(p)
	items(p, DB.ZONES, false)
	for _, it in ipairs(p.items) do
		it.icons = {}
		for k = 1, 4 do
			local t = it:CreateTexture(nil, "ARTWORK"); t:SetSize(14, 14)
			t:SetPoint("RIGHT", -(4 - k) * 15 - 26, 0); t:Hide()
			it.icons[k] = t
		end
		it.more = ink(it:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"))
		it.more:SetPoint("RIGHT"); it.more:SetWidth(24); it.more:SetJustifyH("RIGHT")
		it.text:ClearAllPoints(); it.text:SetPoint("LEFT"); it.text:SetPoint("RIGHT", it.icons[1], "LEFT", -4, 0)
	end
end

function DB.Build(parent)
	local W = ns.Widgets
	local f = CreateFrame("Frame", nil, parent)
	DB.frame = f
	-- four numbers
	DB.stats = {}
	for i = 1, 4 do
		DB.stats[i] = W.Stat(f)   -- placed in DB.Layout
	end
	local hits = { function() ns.Board.SetTab("feed") end, function() ns.Board.SetTab("mates") end,
		function() if ns.GearWindow then ns.GearWindow.Open(ns.Me()) end end, function() ns.Board.SetTab("feed") end }
	for i, s in ipairs(DB.stats) do
		s:EnableMouse(true)
		s:SetScript("OnMouseUp", hits[i])
	end
	-- the message of the day
	local motd = CreateFrame("Frame", nil, f)
	motd:SetHeight(18)
	motd.bg = motd:CreateTexture(nil, "BACKGROUND"); motd.bg:SetAllPoints(); motd.bg:SetColorTexture(unpack(ns.Skin.C.section))
	motd.text = ink(motd:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"))
	motd.text:SetPoint("LEFT", 8, 0); motd.text:SetPoint("RIGHT", -8, 0); motd.text:SetJustifyH("LEFT"); motd.text:SetWordWrap(false)
	motd:Hide()
	DB.motd = motd
	-- panels
	DB.me = W.Panel(f, L.DB_ME); buildMe(DB.me)
	DB.now = W.Panel(f, L.DB_NOW); DB.now:SetHint(L.DB_HINT_NOW); items(DB.now, DB.NOW, true)
	DB.runs = W.Panel(f, L.DB_RUNS); DB.runs:SetHint(L.DB_HINT_RUNS); buildRuns(DB.runs)
	DB.quests = W.Panel(f, L.DB_QUESTS); DB.quests:SetHint(L.DB_HINT_QUESTS); items(DB.quests, DB.QUESTS, false)
	DB.where = W.Panel(f, L.DB_WHERE); DB.where:SetHint(L.DB_HINT_WHERE); buildWhere(DB.where)
	DB.wall = W.Panel(f, L.DB_WALL); DB.wall:SetHint(L.DB_HINT_WALL); items(DB.wall, DB.WALL, false)
	-- alone: the invite to copy, in the middle
	local invite = ns.Skin.Button(DB.now)
	invite:SetSize(150, 20); invite:SetPoint("BOTTOM", 0, 8); invite:SetText(L.DB_INVITE)
	invite:SetScript("OnClick", function() ns.DiscordCopy.OpenText(ns.Home.InviteText()) end)
	invite:Hide()
	DB.invite = invite
	DB.Layout()
	f:Hide()
	return f
end

-- Three columns under the numbers and the strip; the middle one the widest.
DB.LEFT_W, DB.RIGHT_W, DB.COL_GAP = 0.27, 0.28, 12
function DB.Layout()
	local f = DB.frame
	local w = f:GetWidth()
	if not w or w <= 0 then w = ns.Board.WIDTH - 2 * ns.Board.MARGIN end
	local h = f:GetHeight()
	if not h or h <= 0 then h = 440 end
	local statW = math.floor((w - 3 * DB.COL_GAP) / 4)
	for i, s in ipairs(DB.stats) do
		s:ClearAllPoints(); s:SetPoint("TOPLEFT", (i - 1) * (statW + DB.COL_GAP), 0); s:SetWidth(statW)
	end
	DB.motd:ClearAllPoints(); DB.motd:SetPoint("TOPLEFT", 0, -60); DB.motd:SetPoint("RIGHT")
	local top = -84
	local lw, rw = math.floor(w * DB.LEFT_W), math.floor(w * DB.RIGHT_W)
	local cw = w - lw - rw - 2 * DB.COL_GAP
	local cx, rx = lw + DB.COL_GAP, lw + cw + 2 * DB.COL_GAP
	local avail = h + top
	DB.me:ClearAllPoints(); DB.me:SetPoint("TOPLEFT", 0, top); DB.me:SetSize(lw, avail)
	local nowH, runsH = 22 + DB.NOW * (ITEM_H + 2) + 8, 22 + DB.RUNS * 68
	DB.now:ClearAllPoints(); DB.now:SetPoint("TOPLEFT", cx, top); DB.now:SetSize(cw, nowH)
	DB.runs:ClearAllPoints(); DB.runs:SetPoint("TOPLEFT", cx, top - nowH - 8); DB.runs:SetSize(cw, runsH)
	DB.quests:ClearAllPoints(); DB.quests:SetPoint("TOPLEFT", cx, top - nowH - runsH - 16); DB.quests:SetSize(cw, math.max(60, avail - nowH - runsH - 16))
	local whereH = 22 + DB.ZONES * (ITEM_H + 2) + 6
	DB.where:ClearAllPoints(); DB.where:SetPoint("TOPLEFT", rx, top); DB.where:SetSize(rw, whereH)
	DB.wall:ClearAllPoints(); DB.wall:SetPoint("TOPLEFT", rx, top - whereH - 8); DB.wall:SetSize(rw, math.max(60, avail - whereH - 8))
end

------------------------------------------------------------------ fill
local function refreshStats()
	local PT = ns.Points
	local level, into, need = PT.Level(PT.GuildTotal())
	DB.stats[1]:Set(level, L.DB_STAT_LEVEL, into .. "/" .. need)
	DB.stats[2]:Set(#R.List() + 1, L.DB_STAT_ONLINE, "")
	local g = ns.Gear.Mine()
	DB.stats[3]:Set(g and g.avg and g.avg > 0 and g.avg or "-", L.DB_STAT_ILVL, g and ((g.filled or 0) .. "/17") or "")
	local ch = PT.Challenge()
	DB.stats[4]:Set(ch.have .. "/" .. ch.goal, ch.text, ch.done and L.HOME_DONE or "")
end

local function refreshMe()
	local p = DB.me
	local name, class = ns.Me(), select(2, UnitClass("player"))
	p.name:SetText(ns.ShortName and ns.ShortName(name) or name); p.name:SetTextColor(classColor(class))
	p.level:SetText(string.format(L.DB_LEVEL_CLASS, UnitLevel("player") or 0, (UnitClass("player")) or ""))
	local xp, max = UnitXP and UnitXP("player") or 0, UnitXPMax and UnitXPMax("player") or 0
	local rested = GetXPExhaustion and GetXPExhaustion() or 0
	local bw = p.xpBg:GetWidth()
	if not bw or bw <= 0 then bw = p:GetWidth() - 2 * PAD end
	if max > 0 then
		local fr, rr = math.min(1, xp / max), math.min(1, (xp + (rested or 0)) / max)
		p.xpFill:SetWidth(math.max(1, bw * fr)); p.xpRested:SetWidth(math.max(1, bw * rr))
		p.xpText:SetText(string.format(L.DB_XP, math.floor(fr * 100 + 0.5), math.floor((rested or 0) / max * 100 + 0.5)))
	else
		p.xpFill:SetWidth(1); p.xpRested:SetWidth(1); p.xpText:SetText("")
	end
	local g = ns.Gear.Mine()
	p.gearButton:SetEnabled(g ~= nil and g.slots ~= nil)   -- read after the first moments out of combat
	p.gearLabel:SetText(g and g.avg and g.avg > 0 and string.format(L.GEAR_ILVL, g.avg) or L.DB_GEAR)
	for _, sq in ipairs(p.gear) do
		local s = g and g.slots and g.slots[sq.slot]
		sq.filled, sq.itemId = s ~= nil, s and s.id
		if s then
			local _, _, quality = ns.ItemInfo(s.id)
			local c = quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
			if c then sq.tex:SetColorTexture(c.r, c.g, c.b, 0.9) else sq.tex:SetColorTexture(0.9, 0.9, 0.9, 0.9) end
		else
			sq.tex:SetColorTexture(0, 0, 0, 0.2)
		end
	end
	local role, guessed = ns.Roles.Of(name)
	p.role:SetText(string.format(L.CARD_ROLE, (L["ROLE_" .. tostring(role)] or "?") .. (guessed and " (?)" or "")))
	local mine = ns.Points.Mine()
	p.week:SetText(string.format(L.DB_WEEK, mine.w == ns.Points.Week() and (mine.t or 0) or 0))
end

local function refreshNow()
	local list = {}
	for _, id in ipairs(ns.Help.List()) do
		local h = ns.Help.active[id]
		local zone = zoneName(h.mapId)
		list[#list + 1] = { text = h.name .. ": " .. h.text .. (zone ~= "" and ("  ·  " .. zone) or ""), button = L.HOME_GO, fn = function() ns.Help.Coming(id) end }
	end
	for _, adId in ipairs(ns.LFG.List()) do
		local a = ns.LFG.ads[adId]
		if a and a.name ~= ns.Me() then
			list[#list + 1] = { text = a.name .. ": " .. ns.Dungeons.Name(a.d) .. "  ·  " .. ns.LFG.RolesShort(a.r), button = L.HOME_JOIN, fn = function() ns.DungeonPanel.Open(a.d) end }
		end
	end
	-- what is for me: an offer of something I wish for, spells waiting at the trainer
	for _, g in ipairs(ns.Gifts.List()) do
		if not g.mine and not g.reservedBy and ns.Wishlist.Has(g.id) then
			local open = function() ns.Board.OpenWishMenu(g.id, "give", false, g.name) end
			list[#list + 1] = { text = g.name .. ": " .. (ns.Wishlist.Link(g.id) or string.format(L.WISH_UNKNOWN, g.id)) .. "  ·  " .. (g.price and ns.Gifts.Money(g.price) or L.GIVES),
				button = g.price and L.HOME_BUY or L.HOME_RESERVE, fn = open }
		end
	end
	local due = ns.Trainer.Due()
	if #due > 0 then
		local names = {}
		for i = 1, math.min(3, #due) do names[i] = due[i].name end
		list[#list + 1] = { text = string.format(L.HOME_TRAINER, #due) .. ": " .. table.concat(names, ", ") .. (#due > 3 and "…" or "") }
	end
	fill(DB.now, list, function(it, e) setItem(it, e.text, e.fn, e.button, e.button and e.fn) end)
	DB.now:SetNote(#list > 0 and tostring(#list) or "")
	local alone = #R.List() == 0
	DB.invite:SetShown(alone)
	DB.now:SetHint(alone and L.HOME_ALONE or L.DB_HINT_NOW)   -- alone: how to bring the guild in, the button under it
end

local function refreshRuns()
	local M, nowMin, list = ns.Meetups, ns.Meetups.Now(), {}
	for _, m in ipairs(M.List()) do if m.at >= nowMin - 30 then list[#list + 1] = m end end
	for i, c in ipairs(DB.runs.cards) do c:Set(list[i]) end
	DB.runs:SetEmpty(#list == 0)
	DB.runs:SetNote(#list > 0 and string.format(L.DB_NEXT, #list) or "")
end

local function refreshQuests()
	local list = {}
	for i, p in ipairs(ns.Questhub.List()) do
		if i > DB.QUESTS then break end
		list[i] = p
	end
	fill(DB.quests, list, function(it, p)
		setItem(it, (p.t or ("#" .. tostring(p.q))) .. "  ·  " .. (ns.ShortName and ns.ShortName(p.by) or p.by) .. (p.z and p.z ~= "" and ("  ·  " .. p.z) or ""),
			function() ns.Board.lfgQuests, ns.Board.lfgCalendar, ns.Board.lfgTogether = true, false, false; ns.Board.SetTab("lfg") end)
	end)
end

local function refreshWhere()
	local zones, order = {}, {}
	for _, name in ipairs(R.List()) do
		local m = R.mates[name]
		local id = m.mapId or 0
		if not zones[id] then zones[id] = {}; order[#order + 1] = id end
		table.insert(zones[id], name)
	end
	table.sort(order, function(a, b) if #zones[a] ~= #zones[b] then return #zones[a] > #zones[b] end; return zoneName(a) < zoneName(b) end)
	local list = {}
	for i = 1, math.min(DB.ZONES, #order) do list[i] = { id = order[i], names = zones[order[i]] } end
	fill(DB.where, list, function(it, z)
		local zn = zoneName(z.id)
		setItem(it, (zn ~= "" and zn or L.DB_SOMEWHERE) .. " (" .. #z.names .. ")", function() ns.Board.SetTab("mates") end)
		for k, t in ipairs(it.icons) do
			local who = z.names[k]
			local coords = who and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[classOf(who) or ""]
			if coords then t:SetTexture(CLASS_ICON); t:SetTexCoord(unpack(coords)); t:Show() else t:Hide() end
		end
		it.more:SetText(#z.names > 4 and ("+" .. (#z.names - 4)) or "")
	end)
end

local function refreshWall()
	local F, list = ns.Feed, {}
	for i, e in ipairs(F.List()) do
		if i > DB.WALL then break end
		list[i] = e
	end
	fill(DB.wall, list, function(it, e)
		setItem(it, F.Who(e) .. " " .. F.Text(e) .. "  ·  " .. F.Ago(e), function() ns.Board.SetTab("feed") end)
	end)
end

function DB.Refresh()
	if not DB.frame or not DB.frame:IsShown() then return end
	DB.Layout()
	refreshStats()
	local motd, by = ns.GuildNotes.Motd()
	if motd then DB.motd.text:SetText((by and (by .. ": ") or "") .. motd) end
	DB.motd:SetShown(motd ~= nil)
	refreshMe(); refreshNow(); refreshRuns(); refreshQuests(); refreshWhere(); refreshWall()
	ns.Skin.InkPass()
end
