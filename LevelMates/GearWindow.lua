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
		GameTooltip:SetHyperlink("item:" .. self.itemId .. ":" .. (self.enchant or 0))
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
	f.info = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	f.info:SetPoint("TOP", 0, -30)
	GW.slots = {}
	for i, slot in ipairs(LEFT) do local b = slotButton(f, slot); b:SetPoint("TOPLEFT", 16, -52 - (i - 1) * (SIZE + 4)); GW.slots[slot] = b end
	for i, slot in ipairs(RIGHT) do local b = slotButton(f, slot); b:SetPoint("TOPRIGHT", -16, -52 - (i - 1) * (SIZE + 4)); GW.slots[slot] = b end
	for i, slot in ipairs(BOTTOM) do local b = slotButton(f, slot); b:SetPoint("BOTTOM", (i - 2) * (SIZE + 8), 16); GW.slots[slot] = b end
	local model = CreateFrame("DressUpModel", nil, f)
	model:SetPoint("TOPLEFT", 16 + SIZE + 8, -52); model:SetPoint("BOTTOMRIGHT", -(16 + SIZE + 8), 16 + SIZE + 8)
	GW.model = model
	f:Hide()
end

-- The unit the game can show for this name, if any (in my group, or my target).
local function unitFor(name)
	if UnitName and UnitName("target") == name then return "target" end
	for i = 1, 4 do if UnitName and UnitName("party" .. i) == name then return "party" .. i end end
end

function GW.Open(name)
	local g = ns.Gear.Of(name)
	if not g then return end
	if not GW.frame then Build() end
	local f = GW.frame
	if f.TitleText then f.TitleText:SetText(name) end
	f.info:SetText(string.format(L.GEAR_LINE, g.avg or 0, g.filled or 0))
	for slot, b in pairs(GW.slots) do
		local s = g.slots[slot]
		b.itemId, b.enchant, b.il = s and s.id, s and s.en, s and s.il
		if s then
			b.icon:SetTexture((C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(s.id)) or GetItemIcon(s.id))
			local _, _, quality = GetItemInfo(s.id)
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
	if unit then m:SetUnit(unit); m:Show()
	elseif g.r and (g.x == 2 or g.x == 3) then
		local ok = pcall(function()
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
