-- GroupXP.lua: a small window with an XP bar for me and each grouped guildmate. The game does not give other
-- players' XP, so each sends their own percent (`xp`) to the guild, only while grouped with a guildmate and at most
-- every 30 seconds. Rested XP shows when they share it (`rx`). Spec 2026-10-10-levelmates-group-tanda-design.
local _, ns = ...
local GX = {}
ns.GroupXP = GX
local L, C, R = ns.L, ns.Comm, ns.Roster
GX.BAR_W, GX.GAP, GX.FRESH = 110, 30, 300

local function grouped(name) return UnitInParty(name) or UnitInRaid(name) end
local function anyMate() for name in pairs(R.mates) do if grouped(name) then return true end end; return false end
local function myPct()
	local max = UnitXPMax("player") or 0
	if max <= 0 then return 0 end
	return math.max(0, math.min(100, math.floor((UnitXP("player") or 0) / max * 100)))
end

local lastAt, waiting = -math.huge, false
function GX.Send(force)
	if not (ns.db and ns.db.settings.groupXp and anyMate()) then return false end
	if not force and GetTime() - lastAt < GX.GAP then
		if not waiting then   -- the newest value goes once the 30 seconds pass
			waiting = true
			C_Timer.After(GX.GAP - (GetTime() - lastAt), function() waiting = false; GX.Send() end)
		end
		return false
	end
	if C.Send("xp", { p = myPct(), l = UnitLevel("player") }) then lastAt = GetTime(); return true end
	return false
end

C.OnMessage("xp", function(f, name)
	local m = R.mates[name]
	if not m then return end
	m.xpPct, m.xpLevel, m.xpAt = f.p, f.l, GetTime()
	GX.Refresh()
end)

-- Me first, then grouped guildmates with a recent value (highest level first).
function GX.Rows()
	local _, class = UnitClass("player")
	local out = { { name = (UnitName("player")), level = UnitLevel("player"), pct = myPct(), rested = ns.Rested.Mine(), class = class, mine = true } }
	local others = {}
	for name, m in pairs(R.mates) do
		if grouped(name) and m.xpAt and GetTime() - m.xpAt <= GX.FRESH then
			others[#others + 1] = { name = name, level = m.xpLevel or m.level, pct = m.xpPct, rested = ns.Rested.Of(name), class = m.class }
		end
	end
	table.sort(others, function(a, b) if a.level ~= b.level then return a.level > b.level end; return a.name < b.name end)
	for _, o in ipairs(others) do out[#out + 1] = o end
	return out
end

local ROW_H = 18
local function Build()
	local f = CreateFrame("Frame", "LevelMatesGroupXP", UIParent, "BackdropTemplate")
	GX.frame = f
	f:SetSize(GX.BAR_W + 150, 24 + 5 * ROW_H)
	f:SetMovable(true); f:EnableMouse(true); f:SetClampedToScreen(true); f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", f.StartMoving)
	f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing(); local p, _, rp, x, y = self:GetPoint(); ns.char.groupXpPos = { p, rp, x, y } end)
	local pos = ns.char.groupXpPos
	if pos then f:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4]) else f:SetPoint("TOPLEFT", 20, -220) end
	local bg = f:CreateTexture(nil, "BACKGROUND"); bg:SetAllPoints(); bg:SetColorTexture(0, 0, 0, 0.55)
	local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	title:SetPoint("TOPLEFT", 8, -6); title:SetText(L.GROUPXP_TITLE)
	f.rows = {}
	for i = 1, 5 do
		local y = -(20 + (i - 1) * ROW_H)
		local text = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		text:SetPoint("TOPLEFT", 8, y); text:SetWidth(100); text:SetJustifyH("LEFT"); text:SetWordWrap(false)
		local barBg = f:CreateTexture(nil, "ARTWORK"); barBg:SetColorTexture(1, 1, 1, 0.12); barBg:SetSize(GX.BAR_W, 10); barBg:SetPoint("TOPLEFT", 110, y - 2)
		local rested = f:CreateTexture(nil, "ARTWORK"); rested:SetColorTexture(0.3, 0.5, 1, 0.45); rested:SetHeight(10); rested:SetPoint("LEFT", barBg, "LEFT", 0, 0)
		local fill = f:CreateTexture(nil, "OVERLAY"); fill:SetColorTexture(0.6, 0.2, 0.9, 0.95); fill:SetHeight(10); fill:SetPoint("LEFT", barBg, "LEFT", 0, 0)
		local pct = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		pct:SetPoint("LEFT", barBg, "RIGHT", 4, 0)
		f.rows[i] = { text = text, barBg = barBg, rested = rested, fill = fill, pct = pct }
	end
	f:Hide()
end

function GX.Refresh()
	local rows = (ns.db and ns.db.settings.groupXp) and GX.Rows() or {}
	if #rows < 2 then if GX.frame then GX.frame:Hide() end; return end
	if not GX.frame then Build() end
	local f = GX.frame
	for i, r in ipairs(f.rows) do
		local d = rows[i]
		local parts = { r.text, r.barBg, r.rested, r.fill, r.pct }
		if d then
			local c = d.class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[d.class]
			r.text:SetText(d.level .. " " .. d.name); r.text:SetTextColor(c and c.r or 1, c and c.g or 1, c and c.b or 1)
			r.fill:SetWidth(math.max(1, math.floor(GX.BAR_W * (d.pct or 0) / 100)))
			local rest = math.min(100, (d.pct or 0) + math.max(0, d.rested or 0))
			r.rested:SetWidth(math.max(1, math.floor(GX.BAR_W * rest / 100)))
			r.rested:SetShown((d.rested or 0) > 0)
			r.pct:SetText((d.pct or 0) .. "%")
			for _, p in ipairs(parts) do if p ~= r.rested then p:Show() end end
		else
			for _, p in ipairs(parts) do p:Hide() end
		end
	end
	f:SetHeight(24 + #rows * ROW_H)
	f:Show()
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_XP_UPDATE"); ev:RegisterEvent("GROUP_ROSTER_UPDATE"); ev:RegisterEvent("PLAYER_LEVEL_UP")
ev:SetScript("OnEvent", function(_, event, unit)
	if event == "PLAYER_XP_UPDATE" then
		if unit and unit ~= "player" then return end
		GX.Send()
	elseif event == "GROUP_ROSTER_UPDATE" then   -- joining: the others learn mine at once (after the roster settles)
		C_Timer.After(2, function() GX.Send(true); GX.Refresh() end)
	else
		C_Timer.After(1, function() GX.Send(true) end)
	end
	GX.Refresh()
end)
ns.On("LM_PING_ANSWERED", function() if anyMate() then GX.Send(true) end end)
ns.On("LM_ROSTER_CHANGED", GX.Refresh)
ns.On("LM_RESTED_CHANGED", GX.Refresh)
