-- LevelBar.lua: an optional small bar (off by default; /lm barra): level, XP with the rested part, XP per hour over the
-- last 15 minutes, time to level, time in the level and kills in the level (from the client's own XP message).
-- Movable, with a lock. Spec 2026-10-12-levelmates-interface-design (B3).
local _, ns = ...
local LB = {}
ns.LevelBar = LB
local L = ns.L
LB.WINDOW = 900
local samples, lastXP, lastMax, watchSince = {}, nil, nil, nil

-- "%s dies, you gain %d experience." → "^(.+) dies, you gain (%d+) experience%." (whatever the client's language).
-- Anchored at the start only: a rested or group bonus adds text after it. Numbered arguments ("%1$s") become plain.
local function patternOf(fmt)
	if type(fmt) ~= "string" then return nil end
	local p = fmt:gsub("%%(%d+)%$", "%%")
	p = p:gsub("([%(%)%.%[%]%*%+%-%?%^%$])", "%%%1")
	p = p:gsub("%%s", "(.+)"):gsub("%%d", "(%%d+)")
	return "^" .. p
end

local function start()
	local level = UnitLevel("player")
	local s = ns.char.levelStart
	if not s or level > s.level then s = { level = level, t = time(), kills = 0 }; ns.char.levelStart = s end   -- never back: during a level-up the game still reports the old level
	return s
end

------------------------------------------------------------------ numbers
local function prune()
	local cutoff = GetTime() - LB.WINDOW
	while samples[1] and samples[1][1] < cutoff do table.remove(samples, 1) end
end
-- XP per hour over the last 15 minutes; nil before there is anything to count.
function LB.Rate()
	prune()
	if #samples == 0 then return nil end
	local sum = 0
	for _, s in ipairs(samples) do sum = sum + s[2] end
	local now = GetTime()
	local from = math.max(watchSince or samples[1][1], now - LB.WINDOW)   -- since the bar started watching: the first kill's XP took time too
	return sum * 3600 / math.max(60, now - from)
end
function LB.TimeToLevel()
	local rate = LB.Rate()
	if not rate or rate <= 0 then return nil end
	return math.max(0, UnitXPMax("player") - UnitXP("player")) / rate * 3600
end
function LB.TimeInLevel() if not ns.char then return 0 end; return math.max(0, time() - start().t) end
function LB.Kills() if not ns.char then return 0 end; return start().kills or 0 end

local function onXP()
	local xp, max = UnitXP("player"), UnitXPMax("player")
	if lastXP then
		local gained = xp - lastXP
		if gained < 0 then gained = (lastMax or 0) - lastXP + xp end   -- a level-up between: the rest of the old level counts
		if gained > 0 then samples[#samples + 1] = { GetTime(), gained } end
	end
	lastXP, lastMax = xp, max
end

------------------------------------------------------------------ the bar
local function short(n)
	if n >= 10000 then return string.format("%.0fk", n / 1000) elseif n >= 1000 then return string.format("%.1fk", n / 1000) end
	return tostring(math.floor(n + 0.5))
end
local function minutes(sec) return ns.Journal.Duration(sec) end

function LB.Line()
	local xp, max = UnitXP("player"), UnitXPMax("player")
	local rested = GetXPExhaustion and GetXPExhaustion() or 0
	local pct = max > 0 and math.floor(xp / max * 100 + 0.5) or 0
	local rpct = max > 0 and math.floor((rested or 0) / max * 100 + 0.5) or 0
	local rate, ttl = LB.Rate(), LB.TimeToLevel()
	return string.format(L.LEVELBAR_LINE, UnitLevel("player"), pct, rpct, rate and short(rate) or "—",
		ttl and minutes(ttl) or "—", minutes(LB.TimeInLevel()), LB.Kills())
end

local function build()
	local f = CreateFrame("Frame", "LevelMatesLevelBar", UIParent)
	LB.frame = f
	f:SetSize(300, 30); f:SetFrameStrata("MEDIUM")
	local pos = ns.char.levelBarPos
	if pos then f:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4]) else f:SetPoint("TOP", 0, -120) end
	f:SetMovable(true); f:EnableMouse(true); f:SetClampedToScreen(true); f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", function(self) if not ns.db.settings.levelBarLocked then self:StartMoving() end end)
	f:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		local p, _, rp, x, y = self:GetPoint(); ns.char.levelBarPos = { p, rp, x, y }
	end)
	f:SetScript("OnMouseUp", function(self, button)
		if button ~= "RightButton" then return end
		MenuUtil.CreateContextMenu(self, function(_, root)
			root:CreateButton(ns.db.settings.levelBarLocked and L.LEVELBAR_UNLOCK or L.LEVELBAR_LOCK, function() ns.db.settings.levelBarLocked = not ns.db.settings.levelBarLocked end)
			root:CreateButton(L.LEVELBAR_HIDE, function() LB.Toggle(false) end)
		end)
	end)
	f.bg = f:CreateTexture(nil, "BACKGROUND"); f.bg:SetAllPoints(); f.bg:SetColorTexture(0, 0, 0, 0.55)
	f.barBg = f:CreateTexture(nil, "BORDER"); f.barBg:SetColorTexture(0.2, 0.2, 0.2, 0.8)
	f.barBg:SetPoint("BOTTOMLEFT", 4, 4); f.barBg:SetPoint("BOTTOMRIGHT", -4, 4); f.barBg:SetHeight(6)
	f.rested = f:CreateTexture(nil, "ARTWORK"); f.rested:SetColorTexture(0.25, 0.4, 0.9, 0.6)
	f.rested:SetPoint("TOPLEFT", f.barBg); f.rested:SetHeight(6)
	f.fill = f:CreateTexture(nil, "OVERLAY"); f.fill:SetColorTexture(0.6, 0.25, 0.8, 1)
	f.fill:SetPoint("TOPLEFT", f.barBg); f.fill:SetHeight(6)
	f.text = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	f.text:SetPoint("TOPLEFT", 6, -4); f.text:SetPoint("TOPRIGHT", -6, -4); f.text:SetJustifyH("LEFT"); f.text:SetWordWrap(false)
	f:Hide()
end

function LB.Refresh()
	local f = LB.frame
	if not (f and f:IsShown()) then return end
	f.text:SetText(LB.Line())
	local xp, max = UnitXP("player"), UnitXPMax("player")
	local w = f.barBg:GetWidth()
	if not w or w <= 0 then w = f:GetWidth() - 8 end
	local rested = GetXPExhaustion and GetXPExhaustion() or 0
	f.fill:SetWidth(math.max(1, max > 0 and w * math.min(1, xp / max) or 1))
	f.rested:SetWidth(math.max(1, max > 0 and w * math.min(1, (xp + (rested or 0)) / max) or 1))
end

-- On, off, or the other way round; remembered.
function LB.Toggle(on)
	if on == nil then on = not ns.db.settings.levelBar end
	ns.db.settings.levelBar = on and true or false
	if on then
		if not LB.frame then build() end
		LB.frame:Show(); LB.Refresh()
		ns.Every("levelbar", 1, LB.Refresh)
	else
		if LB.frame then LB.frame:Hide() end
		ns.Cancel("levelbar")
	end
end

------------------------------------------------------------------ events
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_ENTERING_WORLD"); ev:RegisterEvent("PLAYER_XP_UPDATE"); ev:RegisterEvent("PLAYER_LEVEL_UP"); ev:RegisterEvent("CHAT_MSG_COMBAT_XP_GAIN")
ev:SetScript("OnEvent", function(_, event, arg)
	if not ns.char then return end
	if event == "PLAYER_ENTERING_WORLD" then
		if lastXP == nil then lastXP, lastMax, watchSince = UnitXP("player"), UnitXPMax("player"), GetTime() end
		start()
		if ns.db.settings.levelBar and not (LB.frame and LB.frame:IsShown()) then LB.Toggle(true) end
	elseif event == "PLAYER_XP_UPDATE" then
		onXP()
	elseif event == "PLAYER_LEVEL_UP" then
		local s = ns.char.levelStart
		LB.lastLevelTime = s and (time() - s.t) or nil   -- how long the level took, for the banner
		ns.char.levelStart = { level = arg or (UnitLevel("player") + 1), t = time(), kills = 0 }
	elseif event == "CHAT_MSG_COMBAT_XP_GAIN" then
		LB.KILL = LB.KILL or patternOf(COMBATLOG_XPGAIN_FIRSTPERSON)
		local ok, hit = pcall(string.match, tostring(arg), LB.KILL or "^$")
		if LB.KILL and ok and hit then local s = start(); s.kills = (s.kills or 0) + 1 end
	end
end)
ns.Slash("barra", function() LB.Toggle() end); ns.Slash("bar", function() LB.Toggle() end)
