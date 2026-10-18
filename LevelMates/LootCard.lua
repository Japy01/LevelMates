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
	f:SetSize(460, 80); f:SetFrameStrata("DIALOG")
	SK.Remember(f, "lootCard", "CENTER", 0, 120)
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
	-- pass on everything not answered yet (a click: the whispers go from it)
	LC.passRest = SK.Button(f)
	LC.passRest:SetSize(100, 20); LC.passRest:SetPoint("RIGHT", LC.minButton, "LEFT", -4, 0); LC.passRest:SetText(L.LC_PASS_REST)
	if LC.passRest.SetFrameLevel then LC.passRest:SetFrameLevel(LC.minButton:GetFrameLevel()) end
	LC.passRest:SetScript("OnClick", function() LS.PassRest(); LC.Refresh() end)
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
		r.os, r.tm = btn(L.LC_OS, 60), btn(L.LC_TM, 60)
		r.pass = btn(L.LC_PASS, 50)
		r.pass:SetPoint("TOPRIGHT", -4, -4)
		r.tm:SetPoint("RIGHT", r.pass, "LEFT", -4, 0); r.os:SetPoint("RIGHT", r.tm, "LEFT", -4, 0)
		r.minor:SetPoint("RIGHT", r.os, "LEFT", -4, 0); r.main:SetPoint("RIGHT", r.minor, "LEFT", -4, 0); r.bis:SetPoint("RIGHT", r.main, "LEFT", -4, 0)
		r.os:SetScript("OnClick", function() LC.Answer(r, "os") end)
		r.tm:SetScript("OnClick", function() LC.Answer(r, "tm") end)
		r.bidBox = CreateFrame("EditBox", nil, r, "InputBoxTemplate")
		r.bidBox:SetSize(44, 18); r.bidBox:SetAutoFocus(false); r.bidBox:SetMaxLetters(5); r.bidBox:Hide()
		if r.bidBox.SetNumeric then r.bidBox:SetNumeric(true) end
		r.bid = btn(L.LC_BID, 54); r.bid:SetPoint("RIGHT", r.pass, "LEFT", -4, 0); r.bidBox:SetPoint("RIGHT", r.bid, "LEFT", -4, 0)
		r.withdraw = btn(L.LC_WITHDRAW, 90); r.withdraw:SetPoint("RIGHT", r.pass, "LEFT", -4, 0)
		r.withdraw:SetScript("OnClick", function() if r.item then LS.Withdraw(r.item) end end)
		r.roll25 = btn(string.format(L.LC_ROLL_N, 25), 56); r.roll25:SetPoint("RIGHT", r.pass, "LEFT", -4, 0)
		r.roll50 = btn(string.format(L.LC_ROLL_N, 50), 56); r.roll50:SetPoint("RIGHT", r.roll25, "LEFT", -4, 0)
		r.roll100 = btn(string.format(L.LC_ROLL_N, 100), 60); r.roll100:SetPoint("RIGHT", r.roll50, "LEFT", -4, 0)
		r.bis:SetScript("OnClick", function() LC.Answer(r, "bis") end)
		r.main:SetScript("OnClick", function() LC.Answer(r, "main") end)
		r.minor:SetScript("OnClick", function() LC.Answer(r, "minor") end)
		r.pass:SetScript("OnClick", function() LC.Answer(r, "pass") end)
		r.bid:SetScript("OnClick", function() LC.Answer(r, "bid", tonumber(r.bidBox:GetText())) end)
		r.roll100:SetScript("OnClick", function() if r.item then LS.StartRoll(r.item, 100) end end)
		r.roll50:SetScript("OnClick", function() if r.item then LS.StartRoll(r.item, 50) end end)
		r.roll25:SetScript("OnClick", function() if r.item then LS.StartRoll(r.item, 25) end end)
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
-- The first line: who hands out, the mode, how many items, and the time left when there is a limit.
function LC.UpdateClock()
	local o = LS.offer
	if not (o and LC.from) then return end
	local text = string.format(L.LC_FROM, o.from, L["LC_MODE_" .. o.mode] or o.mode) .. " · " .. string.format(L.LC_ITEMS_N, #o.items)
	local left = LS.OfferLeft()
	if left then text = text .. " · " .. (left > 0 and string.format(L.LC_LEFT, string.format("%d:%02d", math.floor(left / 60), math.floor(left % 60))) or L.LC_LIMIT_OVER) end
	LC.from:SetText(text)
end
-- The items on the card: the ones still to answer first, then the rest; at most LC.MAX rows (more wait their turn).
local function answered(o, item)
	local m = o.mine[item]
	if o.given[item] then return true end
	if not m then return false end
	return not (m.r == "bid" and m.ack and m.ack.ok == 0)   -- a refused bid is still to answer
end
local function ordered(o)
	local out = {}
	for _, item in ipairs(o.items) do if not answered(o, item) then out[#out + 1] = item end end
	for _, item in ipairs(o.items) do if answered(o, item) then out[#out + 1] = item end end
	return out
end
function LC.Refresh()
	local o = LS.offer
	if not o then if LC.frame then LC.frame:Hide() end; ns.Cancel("lootCardClock"); return end
	if not LC.frame then build() end
	local f = LC.frame
	LC.UpdateClock()
	LC.minButton:SetText(LC.minimized and "+" or "-")
	local list = ordered(o)
	local open = 0
	for _, item in ipairs(o.items) do if not answered(o, item) then open = open + 1 end end
	LC.passRest:SetShown(open > 1 and not LC.minimized)
	local n = LC.minimized and 0 or math.min(#list, LC.MAX)
	f:SetSize(460, 50 + n * (ROW_H + 4))
	local rs = ns.LootRaid and ns.LootRaid.Rules().responses or { bis = true, main = true, minor = true }
	for i, r in ipairs(LC.rows) do
		local item = list[i]
		if item and i <= LC.MAX and not LC.minimized then
			r.item = item
			local name, link = ns.ItemInfo(item)
			r.itemLink = link
			r.icon:SetTexture((C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(item)) or 134400)
			r.link.text:SetText(link or name or ("#" .. item))
			local reservers = LT.ReservedBy(item)
			r.worn:SetText(wornText(item) .. (#reservers > 0 and (" · " .. string.format(L.LC_RESERVED_BY, table.concat(reservers, ", "))) or ""))
			for _, b in ipairs({ r.bis, r.main, r.minor, r.os, r.tm, r.pass, r.bid, r.roll100, r.roll50, r.roll25, r.withdraw }) do b:Hide() end
			r.bidBox:Hide()
			local given, mine = o.given[item], o.mine[item]
			local refused = mine and mine.r == "bid" and mine.ack and mine.ack.ok == 0
			if given then
				r.status:SetText(string.format(L.LC_GIVEN, given))
			elseif refused then
				r.status:SetText(string.format(L.LC_REFUSED, L["LS_ACK_" .. (mine.ack.y or "late")] or mine.ack.y or "?"))
			elseif mine and mine.r == "bid" then
				local words = string.format(L.LS_BID_OF, mine.v or 0)
				if mine.ack and mine.ack.y == "outbid" then words = words .. " · " .. L.LS_ACK_outbid
				elseif mine.ack and mine.ack.ok == 1 then words = words .. " · " .. L.LS_ACK_OK end
				r.status:SetText(string.format(L.LC_SENT, words))
			elseif mine then
				r.status:SetText(string.format(L.LC_SENT, mine.r == "roll" and string.format(L.LS_ROLL_OF, mine.v or 0, mine.m or 100) or L["LS_R_" .. mine.r] or mine.r))
			elseif LS.RollPending(item) then
				r.status:SetText(L.LC_ROLLING)
			else
				r.status:SetText("")
			end
			-- the council buttons sit right of each other, only the ones on: re-anchor the chain
			local chain, prev = { r.tm, r.os, r.minor, r.main, r.bis }, r.pass
			for _, b in ipairs(chain) do if b:IsShown() then b:ClearAllPoints(); b:SetPoint("RIGHT", prev, "LEFT", -4, 0); prev = b end end
			if not given and mine and mine.r == "bid" and not refused then
				r.withdraw:Show()   -- a standing bid: take it back (a pass goes in its place)
			elseif not given then
				r.pass:Show()
				if o.mode == "dkp" then r.bidBox:Show(); r.bid:Show()
				elseif o.mode == "roll" then r.roll100:Show(); r.roll50:Show(); r.roll25:Show()
				else if rs.bis then r.bis:Show() end; if rs.main then r.main:Show() end; if rs.minor then r.minor:Show() end; if rs.os then r.os:Show() end; if rs.tm then r.tm:Show() end end
			end
			r:Show()
		else
			r.item = nil
			r:Hide()
		end
	end
	f:Show()
	if o.deadline then ns.Every("lootCardClock", 1, function() if LC.frame and LC.frame:IsShown() and LS.offer then LC.UpdateClock() else ns.Cancel("lootCardClock") end end) end
end
-- Back on screen (after Escape, or from the Loot tab), while the session lasts.
function LC.Open()
	if not LS.offer then ns.Say(L.LC_NONE); return false end
	LC.minimized = false
	LC.Refresh()
	return true
end
ns.Slash("tarjeta", LC.Open); ns.Slash("lootcard", LC.Open)
ns.On("LM_LOOT_SESSION", function() LC.Refresh() end)
