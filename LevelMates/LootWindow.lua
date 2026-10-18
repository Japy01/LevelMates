-- LootWindow.lua: the master looter's window (spec 2026-10-16, screens). It opens with the loot when the method is
-- master loot (unknown is not a no), I am an officer and something on the corpse is worth recording. Left, the items;
-- right, the candidates for the chosen one: their points, their +1, whether they wish for it, what they wear in that
-- slot. A cost and Give hand the item over from the click (the game's own master loot; the award follows from the
-- hand-over). Without master loot rights, Give records a manual award instead, to be delivered by trade. Bids and
-- rolls are said in the raid chat; this window only decides. Nothing here sends chat.
local _, ns = ...
local LW = {}
ns.LootWindow = LW
local L, R, LT, LR, SK = ns.L, ns.Roster, ns.Loot, ns.LootRaid, ns.Skin
LW.ROWS, LW.ITEMS = 12, 8

local function officer() return R.IAmOfficer() or R.IsOfficer(ns.Me()) end
local function itemOf(link) return link and tonumber(tostring(link):match("item:(%d+)")) end
-- true, false, or nil when the client does not say
local function masterLoot()
	local ok, m = pcall(function() return C_PartyInfo and C_PartyInfo.GetLootMethod and C_PartyInfo.GetLootMethod() end)
	m = ok and ns.Plain(m) or nil
	if m == nil then return nil end
	local master = Enum and Enum.LootMethod and Enum.LootMethod.Master or 2
	return m == master
end

------------------------------------------------------------------ what is on the corpse
LW.items = {}
function LW.Items() return LW.items end
local function readLoot()
	LW.items = {}
	local floor = LR.Rules().quality
	local n = ns.Plain(GetNumLootItems and GetNumLootItems()) or 0
	for i = 1, n do
		local okL, link = pcall(GetLootSlotLink, i)
		link = okL and ns.Plain(link) or nil
		local okQ, _, _, _, _, quality = pcall(GetLootSlotInfo, i)
		quality = okQ and ns.Plain(quality) or 0
		local id = itemOf(link)
		if id and quality >= floor then LW.items[#LW.items + 1] = { slot = i, id = id, link = link, quality = quality } end
	end
end
-- The candidates: the game's master loot list (its index is what GiveMasterLoot takes), else my group.
local function candidates(slot)
	local out = {}
	if GetMasterLootCandidate then
		for i = 1, 40 do
			local ok, name = pcall(GetMasterLootCandidate, slot, i)
			name = ok and ns.Plain(name) or nil
			if name and name ~= "" then out[#out + 1] = { name = ns.ShortName(name), index = i } end
		end
	end
	if #out == 0 then for _, name in ipairs(LR.GroupNames()) do out[#out + 1] = { name = name } end end
	table.sort(out, function(a, b) return a.name < b.name end)
	return out
end

------------------------------------------------------------------ the window
local function build()
	local f = SK.Window("LevelMatesLootWindow", UIParent)
	f:SetSize(700, 400); f:SetFrameStrata("DIALOG")
	SK.Remember(f, "loot", "CENTER", 0, 60)
	if UISpecialFrames then table.insert(UISpecialFrames, "LevelMatesLootWindow") end
	if f.TitleText then f.TitleText:SetText(L.LW_TITLE) end
	LW.frame = f
	-- the items, left
	LW.itemButtons = {}
	for i = 1, LW.ITEMS do
		local b = CreateFrame("Button", nil, f)
		b:SetSize(200, 22); b:SetPoint("TOPLEFT", 12, -30 - (i - 1) * 24)
		b.bg = b:CreateTexture(nil, "BACKGROUND"); b.bg:SetAllPoints(); b.bg:SetColorTexture(1, 0.82, 0, 0.15); b.bg:Hide()
		b.icon = b:CreateTexture(nil, "ARTWORK"); b.icon:SetSize(18, 18); b.icon:SetPoint("LEFT", 2, 0); b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); b.text:SetPoint("LEFT", b.icon, "RIGHT", 4, 0); b.text:SetPoint("RIGHT", -2, 0); b.text:SetJustifyH("LEFT"); b.text:SetWordWrap(false)
		b:SetScript("OnClick", function() LW.Select(i) end)
		b:SetScript("OnEnter", function(self) if GameTooltip and self.link then GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:SetHyperlink(self.link); GameTooltip:Show() end end)
		b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
		b:Hide()
		LW.itemButtons[i] = b
	end
	-- the candidates, right: name, points, +1, wants it, worn item level, a cost and Give
	LW.head = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	LW.head:SetPoint("TOPLEFT", 230, -30); LW.head:SetText(L.LW_HEAD)
	LW.head:SetWidth(450); LW.head:SetJustifyH("LEFT")
	-- the session's clock and how many answered, top right
	LW.timer = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	LW.timer:SetPoint("TOPRIGHT", -34, -14)
	LW.answered = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	LW.answered:SetPoint("RIGHT", LW.timer, "LEFT", -12, 0)
	f:HookScript("OnHide", function() ns.Cancel("lootClock") end)
	LW.rows = {}
	for i = 1, LW.ROWS do
		local r = CreateFrame("Frame", nil, f)
		r:SetSize(450, 22); r:SetPoint("TOPLEFT", 230, -46 - (i - 1) * 24)
		r.name = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); r.name:SetPoint("LEFT"); r.name:SetWidth(84); r.name:SetJustifyH("LEFT"); r.name:SetWordWrap(false)
		r.points = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); r.points:SetPoint("LEFT", 86, 0); r.points:SetWidth(36); r.points:SetJustifyH("RIGHT")
		r.plus = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); r.plus:SetPoint("LEFT", 126, 0); r.plus:SetWidth(20); r.plus:SetJustifyH("RIGHT")
		r.wish = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); r.wish:SetPoint("LEFT", 150, 0); r.wish:SetWidth(42); r.wish:SetJustifyH("LEFT")
		r.worn = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); r.worn:SetPoint("LEFT", 194, 0); r.worn:SetWidth(28); r.worn:SetJustifyH("RIGHT")
		r.resp = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); r.resp:SetPoint("LEFT", 226, 0); r.resp:SetWidth(90); r.resp:SetJustifyH("LEFT"); r.resp:SetWordWrap(false)
		r.votes = r:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); r.votes:SetPoint("LEFT", 318, 0); r.votes:SetWidth(18); r.votes:SetJustifyH("RIGHT")
		r.vote = SK.Button(r)
		r.vote:SetSize(50, 18); r.vote:SetPoint("RIGHT", -2, 0); r.vote:SetText(L.LW_VOTE)
		r.vote:SetScript("OnClick", function() LW.VoteFor(r) end)
		r.vote:Hide()
		r.cost = CreateFrame("EditBox", nil, r, "InputBoxTemplate")
		r.cost:SetSize(40, 20); r.cost:SetPoint("LEFT", 340, 0); r.cost:SetAutoFocus(false); r.cost:SetMaxLetters(5)
		if r.cost.SetNumeric then r.cost:SetNumeric(true) end
		r.give = SK.Button(r)
		r.give:SetSize(60, 20); r.give:SetPoint("LEFT", r.cost, "RIGHT", 6, 0); r.give:SetText(L.LW_GIVE)
		r.give:SetScript("OnClick", function() LW.Give(r) end)
		SK.Tip(r.give, L.TIP_LW_GIVE); SK.Tip(r.vote, L.TIP_LW_VOTE)
		r:Hide()
		LW.rows[i] = r
	end
	-- the session ends when the master says so (or on its own once everything was handed out)
	LW.closeSession = SK.Button(f)
	LW.closeSession:SetSize(130, 22); LW.closeSession:SetPoint("BOTTOMRIGHT", -12, 10); LW.closeSession:SetText(L.LW_CLOSE_SESSION)
	LW.closeSession:SetScript("OnClick", function() if ns.LootSession then ns.LootSession.Close() end; LW.items = {}; f:Hide() end)
	SK.Tip(LW.closeSession, L.TIP_LW_CLOSE)
	LW.voteNote = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	LW.voteNote:SetPoint("BOTTOMLEFT", 12, 34); LW.voteNote:SetText(""); LW.voteNote:Hide()
	LW.note = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	LW.note:SetPoint("BOTTOMLEFT", 12, 10); LW.note:SetPoint("RIGHT", LW.closeSession, "LEFT", -8, 0); LW.note:SetJustifyH("LEFT"); LW.note:SetWordWrap(true)
	LW.note:SetText(L.LW_NOTE)
end

function LW.Select(i)
	LW.current = i
	LW.Refresh()
end
-- My vote on a row: the master's goes into the session; a council member's is whispered.
function LW.VoteFor(r)
	local c, it = r.candidate, r.item
	if not (c and it) then return end
	local LS = ns.LootSession
	if LW.mode == "council" then LS.CouncilVote(it.id, c.name) else LS.Vote(ns.ShortName(ns.Me()), it.id, c.name) end
	LW.Refresh()
end
-- The council's view: the master's items as relayed, the group as candidates.
function LW.OpenCouncil()
	local LS = ns.LootSession
	local c = LS.council
	if not c then if LW.mode == "council" and LW.frame then LW.frame:Hide(); LW.mode = nil end; return end
	if LS.session then return end   -- my own session takes the window
	if not LW.frame then build() end
	LW.mode = "council"
	LW.items = {}
	for _, id in ipairs(c.items) do local _, link = ns.ItemInfo(id); LW.items[#LW.items + 1] = { id = id, link = link } end
	LW.current = LW.current or 1
	LW.frame:Show()
	LW.Refresh()
end
ns.On("LM_LOOT_COUNCIL", function() LW.OpenCouncil() end)
local function wornLevel(name, itemId)
	local slot = LT.SlotOf(itemId)
	local g = slot and ns.Gear.Of(name)
	local s = g and g.slots and g.slots[slot]
	return s and s.il
end
function LW.Refresh()
	if not LW.frame or not LW.frame:IsShown() then return end
	for i, b in ipairs(LW.itemButtons) do
		local it = LW.items[i]
		if it then
			b.link = it.link
			b.icon:SetTexture((C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(it.id)) or 134400)
			b.text:SetText(it.link or ("#" .. it.id))
			b.bg:SetShown(i == LW.current)
			b:Show()
		else b:Hide() end
	end
	local it = LW.items[LW.current or 1]
	local LS = ns.LootSession
	local council = LW.mode == "council" and LS.council or nil
	if LS.session then LW.mode = "master" end
	local list = {}
	if council then for _, n in ipairs(LR.GroupNames()) do list[#list + 1] = { name = n } end
	elseif it then list = candidates(it.slot) end
	local answerOf = function(name) if council then return it and council.answers[it.id] and council.answers[it.id][name] end; local s = LS.session; return s and it and s.responses[it.id] and s.responses[it.id][name] end
	if it and (LS.session or council) then   -- answered first, by what they said; the silent next; passes last
		table.sort(list, function(a, b)
			local ra, va = LS.RankOf(answerOf(a.name))
			local rb, vb = LS.RankOf(answerOf(b.name))
			if ra ~= rb then return ra < rb end
			if va ~= vb then return va > vb end
			return a.name < b.name
		end)
	end
	-- the votes: the master's tally, or the one relayed to the council
	local count, leaders, tied = {}, {}, false
	if it and LS.session then count, leaders, tied = LS.Votes(it.id)
	elseif it and council then count = council.votes[it.id] or {} end
	local iVote = LS.session and LS.MayVote(ns.ShortName(ns.Me()), ns.ShortName(ns.Me())) or council ~= nil
	local myVote = it and (LS.session and LS.session.votes and LS.session.votes[it.id] and LS.session.votes[it.id][ns.ShortName(ns.Me())] or council and council.mine[it.id]) or nil
	if LW.voteNote then LW.voteNote:SetText(tied and L.LW_TIE or ""); LW.voteNote:SetShown(tied) end
	if LW.closeSession then LW.closeSession:SetShown(LS.session ~= nil) end
	LW.UpdateClock()
	if LS and LS.session and it then
		local names = {}
		for _, c in ipairs(list) do names[#names + 1] = c.name end
		LW.answered:SetText(string.format(L.LW_ANSWERED, LS.Answered(it.id, names), #names)); LW.answered:Show()
	else LW.answered:SetText(""); LW.answered:Hide() end
	local wanted, reserved = {}, {}
	if it then
		for _, n in ipairs(ns.Wishlist.WantedBy(it.id)) do wanted[n] = true end
		for _, n in ipairs(LT.ReservedBy(it.id)) do reserved[n] = true end
	end
	for i, r in ipairs(LW.rows) do
		local c = list[i]
		if c and it then
			r.candidate, r.item = c, it
			r.name:SetText(c.name)
			local col = RAID_CLASS_COLORS and R.mates[c.name] and RAID_CLASS_COLORS[R.mates[c.name].class or ""]
			if col then r.name:SetTextColor(SK.Ink(col.r, col.g, col.b)) else r.name:SetTextColor(SK.Ink(1, 1, 1)) end   -- in ink: the page is parchment
			r.points:SetText(LT.Balance(c.name))
			r.plus:SetText(LT.PlusOne(c.name))
			local prio = wanted[c.name] and ns.Wishlist.PriorityOf(c.name, it.id)
			r.wish:SetText(reserved[c.name] and L.LW_RESERVED or wanted[c.name] and (L.LW_WANTS .. (prio and (" " .. prio) or "")) or "")
			local il = wornLevel(c.name, it.id)
			r.worn:SetText(il and tostring(il) or "")
			r.resp:SetText(LS.WordsOf(answerOf(c.name)))
			local votes = count[c.name] or 0
			r.votes:SetText(votes > 0 and tostring(votes) or "")
			r.vote:SetShown(iVote); r.vote:SetText(myVote == c.name and L.LW_VOTED or L.LW_VOTE)
			r.cost:SetShown(not council); r.give:SetShown(not council)
			r.give:SetEnabled(not tied)   -- a tie: the council has not decided
			r:Show()
		else
			r.candidate, r.item = nil, nil
			r:Hide()
		end
	end
end
-- Give: the cost checked first (nobody goes below zero), then the game's master loot from this click; the award
-- comes from the hand-over (LootRaid). Without master loot rights, a manual award, to be delivered by trade.
function LW.Give(r)
	local c, it = r.candidate, r.item
	if not (c and it) or not officer() then return false end
	local cost = tonumber(r.cost:GetText()) or 0
	if cost < 0 then cost = 0 end
	if cost > 0 and LT.Balance(c.name) < cost then ns.Say(L.LOOT_LOW, c.name, LT.Balance(c.name)); return false end
	if GiveMasterLoot and c.index then
		LR.NextCost(it.slot, cost)
		local ok = pcall(GiveMasterLoot, it.slot, c.index)
		if not ok then LR.NextCost(it.slot, nil); ns.Say(L.LW_GIVE_FAILED); return false end
		return true
	end
	local boss = LR.BossNow()
	local raid = LR.raid
	local id = LT.Award(it.id, c.name, { cost = cost, boss = boss and boss.name, enc = boss and boss.id, proof = "manual", raid = raid and raid.id })
	if id then
		if ns.LootSession then ns.LootSession.Awarded(it.id, c.name, cost) end
		for k, x in ipairs(LW.items) do if x == it then table.remove(LW.items, k); break end end
		LW.current = 1
		if #LW.items == 0 then LW.frame:Hide() else LW.Refresh() end
	end
	return id and true or false
end

-- The clock: "m:ss" since the session opened; blank without one. Ticks once a second while the window shows.
function LW.UpdateClock()
	if not LW.timer then return end
	local LS = ns.LootSession
	local secs = LS and LS.Elapsed()
	if not secs then LW.timer:SetText(""); LW.timer:Hide(); return end
	local left = LS.Left()
	local function mmss(n) return string.format("%d:%02d", math.floor(n / 60), math.floor(n % 60)) end
	if left then LW.timer:SetText(left > 0 and string.format(L.LW_LEFT, mmss(left)) or L.LW_CLOSED_LIMIT)
	else LW.timer:SetText(string.format(L.LW_ELAPSED, mmss(secs))) end
	LW.timer:Show()
end
function LW.Open()
	if not LW.frame then build() end
	LW.mode = "master"
	LW.current = 1
	LW.frame:Show()
	LW.Refresh()
	ns.Every("lootClock", 1, function() if LW.frame and LW.frame:IsShown() then LW.UpdateClock() else ns.Cancel("lootClock") end end)
end
local ev = CreateFrame("Frame")
ev:RegisterEvent("LOOT_OPENED"); ev:RegisterEvent("LOOT_SLOT_CLEARED"); ev:RegisterEvent("LOOT_CLOSED")
ev:SetScript("OnEvent", function(_, event, slot)
	if not ns.db then return end
	if event == "LOOT_OPENED" then
		if not officer() or masterLoot() == false then return end
		local kept = LW.items
		readLoot()
		for _, old in ipairs(kept) do   -- what the running session still holds, from earlier corpses
			local seen = false
			for _, it in ipairs(LW.items) do if it.id == old.id then seen = true end end
			if not seen then old.slot = nil; LW.items[#LW.items + 1] = old end
		end
		if #LW.items > 0 then LW.Open(); if ns.LootSession then ns.LootSession.Open(LW.items) end end
	elseif event == "LOOT_SLOT_CLEARED" then
		slot = ns.Plain(slot)
		for k, it in ipairs(LW.items) do if it.slot == slot then table.remove(LW.items, k); break end end
		if LW.frame and LW.frame:IsShown() then
			LW.current = 1
			if #LW.items == 0 then LW.frame:Hide() else LW.Refresh() end
		end
	elseif event == "LOOT_CLOSED" then
		if #LW.items == 0 then   -- everything handed out: done
			if LW.frame then LW.frame:Hide() end
			if ns.LootSession then ns.LootSession.Close() end
		else   -- the session outlives the corpse: what is left is awarded by hand (a trade) or on the next corpse
			for _, it in ipairs(LW.items) do it.slot = nil end
			LW.Refresh()
		end
	end
end)
ns.On("LM_LOOT_CHANGED", function() LW.Refresh() end)
ns.On("LM_LOOT_SESSION", function() LW.Refresh() end)
