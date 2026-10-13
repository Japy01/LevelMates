-- Ding.lua: a banner when I level up: "Level 24!", how long the level took, my XP per hour and my place in the guild;
-- about 8 s, a click closes it, the newest replaces the last. Its own switch; quiet mode turns it off. Nothing is sent.
-- Spec 2026-10-12-levelmates-interface-design (B4).
local _, ns = ...
local DG = {}
ns.Ding = DG
local L = ns.L
DG.SECONDS = 8

-- My place in the guild at this level: 1 + the members above it (me left out); nil without the member list.
function DG.Rank(level)
	local list = ns.Members and ns.Members.List() or {}
	if #list == 0 then return nil end
	local above, me = 0, ns.ShortName and ns.ShortName(ns.Me()) or ns.Me()
	for _, m in ipairs(list) do if m.name ~= me and m.name ~= ns.Me() and (m.level or 0) > level then above = above + 1 end end
	return above + 1
end

local function build()
	local f = CreateFrame("Button", "LevelMatesDing", UIParent)
	DG.frame = f
	f:SetSize(380, 110); f:SetPoint("TOP", 0, -160); f:SetFrameStrata("HIGH")
	f.bg = f:CreateTexture(nil, "BACKGROUND"); f.bg:SetAllPoints(); f.bg:SetColorTexture(0, 0, 0, 0.6)
	f.line = f:CreateTexture(nil, "ARTWORK"); f.line:SetAtlas(ns.Skin.DIVIDER); f.line:SetHeight(10)
	f.line:SetPoint("TOPLEFT", 20, -46); f.line:SetPoint("TOPRIGHT", -20, -46)
	f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
	f.title:SetPoint("TOP", 0, -12)
	if f.title.SetFont then pcall(f.title.SetFont, f.title, "Fonts\\MORPHEUS.TTF", 30, "") end   -- the game's quest-title letters, when the client has them
	f.took = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight"); f.took:SetPoint("TOP", 0, -60)
	f.rate = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); f.rate:SetPoint("TOP", f.took, "BOTTOM", 0, -3)
	f.rank = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); f.rank:SetPoint("TOP", f.rate, "BOTTOM", 0, -3)
	f:SetScript("OnClick", function(self) self.stamp = (self.stamp or 0) + 1; self:Hide() end)
	f:Hide()
end

function DG.Show(level)
	if not DG.frame then build() end
	local f = DG.frame
	local LB = ns.LevelBar
	f.title:SetText(string.format(L.DING_TITLE, level))
	local took = LB and LB.lastLevelTime
	f.took:SetText(took and string.format(L.DING_TOOK, ns.Journal.Duration(took)) or "")
	local rate = LB and LB.Rate()
	f.rate:SetText(rate and string.format(L.DING_RATE, math.floor(rate + 0.5)) or "")
	local rank = DG.Rank(level)
	f.rank:SetText(rank and string.format(L.DING_RANK, rank) or "")
	f.stamp = (f.stamp or 0) + 1
	local stamp = f.stamp
	f:SetAlpha(1); f:Show()
	C_Timer.After(DG.SECONDS - 0.5, function() if f.stamp == stamp then f:SetAlpha(0.5) end end)
	C_Timer.After(DG.SECONDS, function() if f.stamp == stamp then f:Hide() end end)
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LEVEL_UP")
ev:SetScript("OnEvent", function(_, _, level)
	if not ns.db or ns.db.settings.dingBanner == false then return end
	DG.Show(level or UnitLevel("player"))
end)
