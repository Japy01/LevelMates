-- WhatsNew.lua: a welcome the first time the addon runs and "what's new" after an update: a small window a few
-- seconds after login, once per version (a development checkout never asks). /lm novedades brings it back. Its
-- buttons open the book and the options. The lines come from the locale (L.WN_NEWS, kept with the changelog).
local _, ns = ...
local WN = {}
ns.WhatsNew = WN
local L, SK = ns.L, ns.Skin
WN.DELAY = 6   -- seconds after entering the world: the loading screen and the game's own notices settle first

local function build()
	local f = SK.Window("LevelMatesWhatsNew", UIParent)
	f:SetSize(540, 380); f:SetPoint("CENTER", 0, 80); f:SetFrameStrata("DIALOG")
	f:SetMovable(true); f:EnableMouse(true); f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", f.StartMoving); f:SetScript("OnDragStop", f.StopMovingOrSizing)
	if UISpecialFrames then table.insert(UISpecialFrames, "LevelMatesWhatsNew") end
	WN.frame = f
	WN.body = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	WN.body:SetPoint("TOPLEFT", 18, -32); WN.body:SetPoint("BOTTOMRIGHT", -18, 46)
	WN.body:SetJustifyH("LEFT"); WN.body:SetJustifyV("TOP"); WN.body:SetWordWrap(true)
	if WN.body.SetSpacing then WN.body:SetSpacing(3) end
	WN.open = SK.Button(f)
	WN.open:SetSize(150, 22); WN.open:SetPoint("BOTTOMLEFT", 16, 12); WN.open:SetText(L.WN_OPEN)
	WN.open:SetScript("OnClick", function() f:Hide(); ns.Board.ShowTab("home") end)
	WN.options = SK.Button(f)
	WN.options:SetSize(120, 22); WN.options:SetPoint("LEFT", WN.open, "RIGHT", 8, 0); WN.options:SetText(L.WN_OPTIONS)
	WN.options:SetScript("OnClick", function() f:Hide(); ns.Settings.Open() end)
end

-- The words: the welcome (first run) or the version's news as a list, with how to see them again.
function WN.Text(kind)
	if kind == "welcome" then return L.WN_WELCOME .. "\n\n" .. L.WN_AGAIN end
	local out = {}
	for _, line in ipairs(L.WN_NEWS or {}) do out[#out + 1] = "- " .. line end
	return table.concat(out, "\n") .. "\n\n" .. L.WN_AGAIN
end
function WN.Show(kind)
	if not WN.frame then build() end
	WN.kind = kind or WN.kind or "news"
	if WN.frame.TitleText then WN.frame.TitleText:SetText(string.format(L.WN_TITLE, ns.TITLE, tostring(ns.VERSION or ""))) end
	WN.body:SetText(WN.Text(WN.kind))
	WN.frame:Show()
end
function WN.Toggle() if WN.frame and WN.frame:IsShown() then WN.frame:Hide() else WN.Show() end end
ns.Slash("novedades", WN.Toggle); ns.Slash("whatsnew", WN.Toggle)

ns.On("LM_WORLD", function()
	local v = ns.VERSION
	if not ns.db or type(v) ~= "string" or v == "dev" or v == "" or v:find("@", 1, true) then return end   -- unpackaged: never nags
	if ns.db.seenVersion == v then return end
	local kind = ns.db.seenVersion == nil and "welcome" or "news"
	ns.db.seenVersion = v
	C_Timer.After(WN.DELAY, function() WN.Show(kind) end)
end)
