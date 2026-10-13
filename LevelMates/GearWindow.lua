-- GearWindow.lua: a guildmate's gear as the character sheet shows it: the slots in two columns and the weapons below,
-- each with its item's icon, quality border and tooltip; the model in the middle, dressed in it.
-- Spec 2026-10-12-levelmates-armory-design (2).
local _, ns = ...
local GW = {}
ns.GearWindow = GW
local L = ns.L
local LEFT = { 1, 2, 3, 15, 5, 4, 19, 9 }
local RIGHT = { 10, 6, 7, 8, 11, 12, 13, 14 }
local BOTTOM = { 16, 17, 18 }
local EMPTY = { [1] = "Head", [2] = "Neck", [3] = "Shoulder", [4] = "Shirt", [5] = "Chest", [6] = "Waist", [7] = "Legs", [8] = "Feet", [9] = "Wrists",
	[10] = "Hands", [11] = "Finger", [12] = "Finger", [13] = "Trinket", [14] = "Trinket", [15] = "Chest", [16] = "MainHand", [17] = "SecondaryHand", [18] = "Ranged", [19] = "Tabard" }
local SIZE = 36

local function slotButton(f, slot)
	local b = CreateFrame("Button", nil, f)
	b:SetSize(SIZE, SIZE)
	b.icon = b:CreateTexture(nil, "ARTWORK"); b.icon:SetAllPoints()
	b.border = b:CreateTexture(nil, "OVERLAY"); b.border:SetAllPoints(); b.border:SetTexture("Interface\\Buttons\\UI-ActionButton-Border"); b.border:SetBlendMode("ADD")
	b.slot = slot
	b:SetScript("OnEnter", function(self)
		if not (GameTooltip and self.itemId) then return end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetHyperlink(ns.Gear.ItemString({ id = self.itemId, en = self.enchant, sf = self.suffix }))
		if self.il and self.il > 0 then GameTooltip:AddLine(string.format(L.GEAR_ILVL, self.il), 1, 0.82, 0) end
		GameTooltip:Show()
	end)
	b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
	return b
end

local function Build()
	local f = ns.Skin.Window("LevelMatesGearWindow", UIParent)
	GW.frame = f
	f:SetSize(330, 420); f:SetPoint("CENTER", -220, 0); f:SetFrameStrata("DIALOG")
	f:SetMovable(true); f:EnableMouse(true); f:SetClampedToScreen(true); f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", f.StartMoving); f:SetScript("OnDragStop", f.StopMovingOrSizing)
	tinsert(UISpecialFrames, "LevelMatesGearWindow")
	f.info = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	f.info:SetPoint("TOP", 0, -25)   -- two short lines, over the slots
	GW.slots = {}
	for i, slot in ipairs(LEFT) do local b = slotButton(f, slot); b:SetPoint("TOPLEFT", 16, -52 - (i - 1) * (SIZE + 4)); GW.slots[slot] = b end
	for i, slot in ipairs(RIGHT) do local b = slotButton(f, slot); b:SetPoint("TOPRIGHT", -16, -52 - (i - 1) * (SIZE + 4)); GW.slots[slot] = b end
	for i, slot in ipairs(BOTTOM) do local b = slotButton(f, slot); b:SetPoint("BOTTOM", (i - 2) * (SIZE + 8), 16); GW.slots[slot] = b end
	local model = CreateFrame("DressUpModel", nil, f)
	model:SetPoint("TOPLEFT", 16 + SIZE + 8, -52); model:SetPoint("BOTTOMRIGHT", -(16 + SIZE + 8), 16 + SIZE + 8)
	GW.model = model
	-- out of sight where the game cannot dress a model by race (Forever): their class crest and a note instead
	local away = CreateFrame("Frame", nil, f)
	away:SetAllPoints(model)
	away.crest = away:CreateTexture(nil, "ARTWORK"); away.crest:SetSize(72, 72); away.crest:SetPoint("CENTER", 0, 24)
	away.text = away:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	away.text:SetPoint("TOP", away.crest, "BOTTOM", 0, -10); away.text:SetWidth(130); away.text:SetJustifyH("CENTER")
	away.text:SetText(L.GEAR_AWAY)
	away:Hide()
	GW.away = away
	f:Hide()
end

-- The unit the game can show for this name, if any (me, in my group, or my target).
local function crest(tex, class)
	local atlas = class and "classicon-" .. class:lower()
	if atlas and ns.Skin.HasAtlas(atlas) then tex:SetAtlas(atlas); return end
	local coords = CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[class or ""]
	if coords then tex:SetTexture("Interface/TargetingFrame/UI-Classes-Circles"); tex:SetTexCoord(unpack(coords))
	else tex:SetTexture(134400) end
end

local function unitFor(name)
	if name == ns.Me() then return "player" end
	if UnitName and UnitName("target") == name then return "target" end
	for i = 1, 4 do if UnitName and UnitName("party" .. i) == name then return "party" .. i end end
end

-- Under the item level: how old the data is and where it came from; in a warning colour after a few days.
GW.OLD_DAYS = 3
local SOURCE = { sync = "GEAR_SRC_SYNC", inspect = "GEAR_SRC_INSPECT" }
function GW.InfoLine(g)
	local line = string.format(L.GEAR_LINE, g.avg or 0, g.filled or 0)
	if g.src == "self" or not g.t then return line end
	local age = string.format(L.FEED_AGO, ns.Journal.Duration(math.max(0, time() - g.t)))
	local note = age .. " · " .. (L[SOURCE[g.src] or "GEAR_SRC_SYNC"])
	if time() - g.t > GW.OLD_DAYS * 86400 then note = "|cffd9a441" .. note .. "|r" end
	return line .. "\n" .. note
end

local function draw(name)
	local known = ns.Gear.Of(name)
	local g = known or { slots = {} }
	if not GW.frame then Build() end
	local f = GW.frame
	GW.name = name
	if f.TitleText then f.TitleText:SetText(name) end
	f.info:SetText(known and GW.InfoLine(known) or L.GEAR_INSPECTING)
	for slot, b in pairs(GW.slots) do
		local s = g.slots[slot]
		b.itemId, b.enchant, b.il, b.suffix = s and s.id, s and s.en, s and s.il, s and s.sf
		if s then
			b.icon:SetTexture((C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(s.id)) or (GetItemIcon and GetItemIcon(s.id)))
			local _, _, quality = ns.ItemInfo(s.id)
			local c = quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
			if c then b.border:SetVertexColor(c.r, c.g, c.b); b.border:Show() else b.border:Hide() end
		else
			b.icon:SetTexture("Interface\\PaperDoll\\UI-PaperDoll-Slot-" .. EMPTY[slot]); b.border:Hide()
		end
	end
	-- the model: the person when the game can show them, else their race and sex dressed in their items; or none
	local m = GW.model
	if m.ClearModel then m:ClearModel() end
	local unit = unitFor(name)
	GW.away:Hide()
	if unit then m:SetUnit(unit); m:Show()
	elseif not m.SetCustomRace then   -- Forever: no model by race (measured); never my own body in their clothes
		m:Hide()
		local mate = ns.Roster.mates[name]
		crest(GW.away.crest, mate and mate.class)
		GW.away:Show()
	elseif g.r and (g.x == 2 or g.x == 3) then
		local ok = pcall(function()
			m:SetUnit("player")   -- a player model first: SetCustomRace changes a loaded model
			m:SetCustomRace(g.r, g.x - 2)
			m:Undress()
			for slot = 1, 19 do local s = g.slots[slot]; if s and slot ~= 4 and slot ~= 19 then m:TryOn("item:" .. s.id) end end
		end)
		m:SetShown(ok)
	else
		m:Hide()
	end
	f:Show()
	ns.Skin.InkWindow(f)
end

-- Open someone's gear: what we know, and an inspect when the game lets me (my target, my group), LevelMates or not.
function GW.Open(name)
	local unit = ns.Gear.InspectUnit(name)
	local asked = unit and ns.Gear.Inspect(unit, name)
	if not ns.Gear.Of(name) and not asked then return end
	draw(name)
end
ns.On("LM_GEAR_CHANGED", function(name)
	if GW.frame and GW.frame:IsShown() and name == GW.name then draw(name) end
end)
