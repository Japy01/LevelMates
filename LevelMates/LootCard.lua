-- LootCard.lua: my answer to a live loot session (LootSession): one line per item on the corpse with what I wear in
-- that slot, and the buttons of the mode: council (BiS, main, minor, pass), dkp (a bid and pass), roll (roll and
-- pass; the roll itself is the game's own /roll from this click). What I answered stays written on the line, and
-- who got the item when the master gives it. Nothing is sent but my answer, by whisper, from a click.
local _, ns = ...
local LC = {}
ns.LootCard = LC
local L, LS, LT, SK = ns.L, ns.LootSession, ns.Loot, ns.Skin
LC.MAX = 6
local ROW_H = 50

local function build()
	local f = SK.Window("LevelMatesLootCard", UIParent)
	f:SetSize(460, 80); f:SetPoint("CENTER", 0, 120); f:SetFrameStrata("DIALOG")
	f:SetMovable(true); f:EnableMouse(true); f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", f.StartMoving); f:SetScript("OnDragStop", f.StopMovingOrSizing)
	if UISpecialFrames then table.insert(UISpecialFrames, "LevelMatesLootCard") end
	if f.TitleText then f.TitleText:SetText(L.LC_TITLE) end
	LC.frame = f
	LC.from = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); LC.from:SetPoint("TOPLEFT", 12, -26)
	-- shrink to the title line (the items stay, out of the way of the fight) and back
	LC.minButton = SK.Button(f)
	LC.minButton:SetSize(22, 20); LC.minButton:SetText("-")
	if f.CloseButton then LC.minButton:SetPoint("RIGHT", f.CloseButton, "LEFT", -2, 0) else LC.minButton:SetPoint("TOPRIGHT", -30, -4) end
	if LC.minButton.SetFrameLevel then LC.minButton:SetFrameLevel(((f.CloseButton and f.CloseButton.GetFrameLevel and f.CloseButton:GetFrameLevel()) or f:GetFrameLevel()) + 1) end
	LC.minButton:SetScript("OnClick", function() LC.minimized = not LC.minimized; LC.Refresh() end)
	LC.rows = {}
	for i = 1, LC.MAX do
		local r = CreateFrame("Frame", nil, f)
		r:SetSize(436, ROW_H); r:SetPoint("TOPLEFT", 12, -42 - (i - 1) * (ROW_H + 4))
		r.bg = r:CreateTexture(nil, "BACKGROUND"); r.bg:SetAllPoints(); r.bg:SetColorTexture(1, 1, 1, 0.05)
		r.icon = r:CreateTexture(nil, "ARTWORK"); r.icon:SetSize(28, 28); r.icon:SetPoint("TOPLEFT", 4, -4); r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		r.link = CreateFrame("Button", nil, r)
		r.link:SetSize(260, 16); r.link:SetPoint("TOPLEFT", r.icon, "TOPRIGHT", 6, 0)
		r.link.text = r.link:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); r.link.text:SetAllPoints(); r.link.text:SetJustifyH("LEFT"); r.link.text:SetWordWrap(false)
		r.link:SetScript("OnEnter", function(self) if GameTooltip and self.itemLink then GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:SetHyperlink(self.itemLink); GameTooltip:Show() end end)
		r.link:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
		r.worn = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); r.worn:SetPoint("TOPLEFT", r.link, "BOTTOMLEFT", 0, -2); r.worn:SetWidth(260); r.worn:SetJustifyH("LEFT")
		r.status = r:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); r.status:SetPoint("BOTTOMLEFT", r.icon, "BOTTOMRIGHT", 6, -14); r.status:SetWidth(300); r.status:SetJustifyH("LEFT")
		-- the buttons, right: made for every mode, shown by the mode
		local function btn(text, w) local b = SK.Button(r); b:SetSize(w, 18); b:SetText(text); b:Hide(); return b end
		r.bis, r.main, r.minor = btn(L.LC_BIS, 40), btn(L.LC_MAIN, 64), btn(L.LC_MINOR, 70)
		r.pass = btn(L.LC_PASS, 50)
		r.pass:SetPoint("TOPRIGHT", -4, -4)
		r.minor:SetPoint("RIGHT", r.pass, "LEFT", -4, 0); r.main:SetPoint("RIGHT", r.minor, "LEFT", -4, 0); r.bis:SetPoint("RIGHT", r.main, "LEFT", -4, 0)
		r.bidBox = CreateFrame("EditBox", nil, r, "InputBoxTemplate")
		r.bidBox:SetSize(44, 18); r.bidBox:SetAutoFocus(false); r.bidBox:SetMaxLetters(5); r.bidBox:Hide()
		if r.bidBox.SetNumeric then r.bidBox:SetNumeric(true) end
		r.bid = btn(L.LC_BID, 54); r.bid:SetPoint("RIGHT", r.pass, "LEFT", -4, 0); r.bidBox:SetPoint("RIGHT", r.bid, "LEFT", -4, 0)
		r.roll = btn(L.LC_ROLL, 70); r.roll:SetPoint("RIGHT", r.pass, "LEFT", -4, 0)
		r.bis:SetScript("OnClick", function() LC.Answer(r, "bis") end)
		r.main:SetScript("OnClick", function() LC.Answer(r, "main") end)
		r.minor:SetScript("OnClick", function() LC.Answer(r, "minor") end)
		r.pass:SetScript("OnClick", function() LC.Answer(r, "pass") end)
		r.bid:SetScript("OnClick", function() LC.Answer(r, "bid", tonumber(r.bidBox:GetText())) end)
		r.roll:SetScript("OnClick", function() if RandomRoll then pcall(RandomRoll, 1, 100) end; LC.Answer(r, "roll", 100) end)
		r:Hide()
		LC.rows[i] = r
	end
end
function LC.Rows()
	local out = {}
	for _, r in ipairs(LC.rows or {}) do if r:IsShown() then out[#out + 1] = r end end
	return out
end

function LC.Answer(r, kind, v)
	if not r.item then return end
	local ok, why = LS.Answer(r.item, kind, v)
	if ok then LC.Refresh()
	elseif why == "min" then r.status:SetText(string.format(L.LS_MIN_BID, LS.offer and LS.offer.minBid or 0)) end   -- said on the line too
end

local function wornText(item)
	local slot = LT.SlotOf(item)
	local g = slot and ns.Gear.Mine()
	local s = g and g.slots and g.slots[slot]
	if not slot then return "" end
	return s and s.il and string.format(L.LC_WORN, s.il) or L.LC_WORN_NONE
end
function LC.Refresh()
	local o = LS.offer
	if not o then if LC.frame then LC.frame:Hide() end; return end
	if not LC.frame then build() end
	local f = LC.frame
	LC.from:SetText(string.format(L.LC_FROM, o.from, L["LC_MODE_" .. o.mode] or o.mode) .. (LC.minimized and string.format(L.LC_SHRUNK, #o.items) or ""))
	LC.minButton:SetText(LC.minimized and "+" or "-")
	local n = LC.minimized and 0 or math.min(#o.items, LC.MAX)
	f:SetSize(460, 50 + n * (ROW_H + 4))
	for i, r in ipairs(LC.rows) do
		local item = o.items[i]
		if item and i <= LC.MAX and not LC.minimized then
			r.item = item
			local name, link = ns.ItemInfo(item)
			r.itemLink = link
			r.icon:SetTexture((C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(item)) or 134400)
			r.link.text:SetText(link or name or ("#" .. item))
			r.worn:SetText(wornText(item))
			for _, b in ipairs({ r.bis, r.main, r.minor, r.pass, r.bid, r.roll }) do b:Hide() end
			r.bidBox:Hide()
			local given, mine = o.given[item], o.mine[item]
			if given then
				r.status:SetText(string.format(L.LC_GIVEN, given))
			elseif mine then
				r.status:SetText(string.format(L.LC_SENT, mine.r == "bid" and string.format(L.LS_BID_OF, mine.v or 0) or mine.r == "roll" and L.LS_R_roll or L["LS_R_" .. mine.r] or mine.r))
			else
				r.status:SetText("")
			end
			if not given then
				r.pass:Show()
				if o.mode == "dkp" then r.bidBox:Show(); r.bid:Show()
				elseif o.mode == "roll" then r.roll:Show()
				else r.bis:Show(); r.main:Show(); r.minor:Show() end
			end
			r:Show()
		else
			r.item = nil
			r:Hide()
		end
	end
	f:Show()
end
ns.On("LM_LOOT_SESSION", function() LC.Refresh() end)
