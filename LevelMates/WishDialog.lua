-- WishDialog.lua: "Add a wish". While it is open, a Shift+click on any item puts its link in the box
-- (a post-hook on the client's link insertion); Wishlist.Add runs only from its Add button.
local _, ns = ...
local Dlg = {}
ns.WishDialog = Dlg
local L, W = ns.L, ns.Wishlist

local function Build()
	local f = ns.Skin.Window("LevelMatesWishDialog", UIParent)
	Dlg.frame = f
	f:SetSize(340, 140); f:SetPoint("CENTER"); f:SetFrameStrata("DIALOG")
	f:SetMovable(true); f:EnableMouse(true); f:SetClampedToScreen(true); f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", f.StartMoving); f:SetScript("OnDragStop", f.StopMovingOrSizing)
	if f.TitleText then f.TitleText:SetText(L.WISH_DIALOG_TITLE) end
	tinsert(UISpecialFrames, "LevelMatesWishDialog")
	f:Hide()
	local hint = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	hint:SetPoint("TOP", 0, -34); hint:SetText(L.WISH_HINT)
	local box = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
	box:SetSize(290, 22); box:SetPoint("TOP", 0, -56); box:SetAutoFocus(false); box:SetMaxLetters(255)
	box:SetScript("OnTextChanged", function() Dlg.Refresh() end)
	Dlg.box = box
	-- offer mode: the price in gold (empty = free)
	local price = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
	price:SetSize(90, 22); price:SetPoint("TOPRIGHT", box, "BOTTOMRIGHT", 0, -8); price:SetAutoFocus(false); price:SetMaxLetters(8)
	local priceLabel = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	priceLabel:SetPoint("RIGHT", price, "LEFT", -10, 0); priceLabel:SetText(L.PRICE_LABEL)
	Dlg.price, Dlg.priceLabel = price, priceLabel
	local add = ns.Skin.Button(f)
	add:SetSize(120, 22); add:SetPoint("BOTTOMLEFT", 20, 14); add:SetText(L.WISH_ADD)
	add:SetScript("OnClick", function()
		local ok
		if Dlg.mode == "gift" then
			local p = ns.Gifts.ParsePrice(Dlg.price:GetText())
			if p == false then ns.Say(L.PRICE_BAD); return end
			ok = ns.Gifts.Add(box:GetText(), p)
		else
			ok = W.Add(box:GetText())
		end
		if ok then box:SetText(""); Dlg.price:SetText(""); Dlg.Refresh() end   -- stays open for the next one
	end)
	Dlg.add = add
	local close = ns.Skin.Button(f)
	close:SetSize(120, 22); close:SetPoint("BOTTOMRIGHT", -20, 14); close:SetText(L.LFG_CLOSE)
	close:SetScript("OnClick", function() f:Hide() end)
end

function Dlg.Refresh()
	if Dlg.frame then Dlg.add:SetEnabled(W.ItemId(Dlg.box:GetText() or "") ~= nil) end
end

function Dlg.Open(mode)
	if not Dlg.frame then Build() end
	Dlg.mode = mode == "gift" and "gift" or "wish"
	if Dlg.frame.TitleText then Dlg.frame.TitleText:SetText(Dlg.mode == "gift" and L.GIFT_DIALOG_TITLE or L.WISH_DIALOG_TITLE) end
	Dlg.box:SetText(""); Dlg.price:SetText("")
	Dlg.price:SetShown(Dlg.mode == "gift"); Dlg.priceLabel:SetShown(Dlg.mode == "gift")
	Dlg.frame:SetHeight(Dlg.mode == "gift" and 170 or 140)
	Dlg.frame:Show()
	Dlg.Refresh()
end

-- Shift+click on an item anywhere: the client inserts its link; take it while the dialog is open.
function Dlg.Capture(text)
	if Dlg.frame and Dlg.frame:IsShown() and W.ItemId(text) then Dlg.box:SetText(text); Dlg.Refresh() end
end
if hooksecurefunc then
	if ChatFrameUtil and ChatFrameUtil.InsertLink then hooksecurefunc(ChatFrameUtil, "InsertLink", Dlg.Capture) end
	if ChatEdit_InsertLink then hooksecurefunc("ChatEdit_InsertLink", Dlg.Capture) end
end

ns.On("LM_WISH_ADD", function() Dlg.Open("wish") end)
ns.On("LM_GIFT_ADD", function() Dlg.Open("gift") end)
