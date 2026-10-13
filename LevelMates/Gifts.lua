-- Gifts.lua: the guild market. Items I offer (up to 10), free or for a price: the free ones go out in `gv` (as wishes do
-- in `wl`, so older versions still see them), the priced ones in `sl`. A guildmate reserves or buys one with `gr`, first
-- come; payment and handing over are up to them (trade or mail): the addon never touches gold. Giveaways and wishes are matched both ways with a notice.
-- My lists are sync records (one gv and one sl per seller, kept and handed over by everyone, so a late login sees the
-- market of sellers who are offline). Specs 2026-10-10-levelmates-social-leveling-design (A2) and 2026-10-12 sync v2.
local _, ns = ...
local GF = {}
ns.Gifts = GF
local L, C, R, W, S = ns.L, ns.Comm, ns.Roster, ns.Wishlist, ns.Sync
GF.MAX, GF.FORGET_DAYS = 10, 30

local function me() return ns.Me() end
local function mine() ns.char.gifts = ns.char.gifts or {}; return ns.char.gifts end
local function theirs()
	ns.db.gifts = ns.db.gifts or {}
	local k = GetGuildInfo("player") or "?"
	ns.db.gifts[k] = ns.db.gifts[k] or {}
	return ns.db.gifts[k]
end
local function link(id) return W.Link(id) or string.format(L.WISH_UNKNOWN, id) end

function GF.Has(id) for _, g in ipairs(mine()) do if g.id == id then return g end end end

-- My lists as records (the sync layer keeps them pending until they really went, and hands them to late logins).
local LIFE = GF.FORGET_DAYS * 86400
local function myKey() return ns.NameKey(me()) end
local function send()
	local ids, sale = {}, {}
	for _, g in ipairs(mine()) do
		if g.price then sale[#sale + 1] = g.id .. ":" .. g.price else ids[#ids + 1] = g.id end
	end
	S.Put("gv", myKey(), { ids = #ids > 0 and table.concat(ids, ",") or nil })
	S.Put("sl", myKey(), { p = #sale > 0 and table.concat(sale, ",") or nil })
	return true
end

-- Prices: typed in gold ("1,5" = 1 gold 50 silver), kept in copper. nil = free, false = not a price.
function GF.ParsePrice(text)
	text = strtrim(tostring(text or ""))
	if text == "" then return nil end
	local gold = tonumber((text:gsub(",", ".")))
	if not gold or gold < 0 or gold > 9999 then return false end
	local copper = math.floor(gold * 10000 + 0.5)
	return copper > 0 and copper or nil
end
-- A price as the game shows money (coin icons), or as text where the client has no such helper.
function GF.Money(copper)
	if GetCoinTextureString then return GetCoinTextureString(copper) end
	local g, s, c = math.floor(copper / 10000), math.floor(copper % 10000 / 100), copper % 100
	local out = {}
	if g > 0 then out[#out + 1] = g .. "g" end
	if s > 0 then out[#out + 1] = s .. "s" end
	if c > 0 then out[#out + 1] = c .. "c" end
	return table.concat(out, " ")
end


-- Others' giveaways: updated in the last 30 days, by someone still in the guild (or a sample).
local function others()
	local t, out, cutoff = theirs(), {}, time() - GF.FORGET_DAYS * 86400
	for name, l in pairs(t) do
		if l.t < cutoff then t[name] = nil
		elseif name ~= me() and (l.sim or R.IsGuildmate(name)) then
			local ids, prices = {}, l.sale or {}
			for _, id in ipairs(l.ids or {}) do if not prices[id] then ids[#ids + 1] = id end end
			local priced = {}
			for id in pairs(prices) do priced[#priced + 1] = id end
			table.sort(priced)
			for _, id in ipairs(priced) do ids[#ids + 1] = id end
			out[#out + 1] = { name = name, ids = ids, prices = prices, t = l.t, reserved = l.reserved or {} }
		end
	end
	table.sort(out, function(a, b) return a.name < b.name end)
	return out
end

-- Matches, told once per person and item each session.
local told = {}
local function tell(key, fmt, ...) if told[key] then return end; told[key] = true; ns.NoticeAt("wishes", fmt, ...) end

-- True when the item surely cannot be traded: it binds when picked up or is a quest item, or every copy of it in my
-- bags is already bound. Two sources for "bound" (the slot's own flag, the item's location), and bound wins: one of
-- them can say "don't know" for a bound item. Not in my bags (the bank?): it may well be tradable.
local NEVER_TRADED = { [1] = true, [4] = true }   -- bind types: on pickup, quest
function GF.Bound(id)
	local bindType = select(14, ns.ItemInfo(id))
	if NEVER_TRADED[bindType] then return true end
	if not (C_Container and C_Container.GetContainerNumSlots and C_Container.GetContainerItemInfo) then return false end
	local copies, free = 0, 0
	for bag = 0, 4 do
		for slot = 1, C_Container.GetContainerNumSlots(bag) or 0 do
			local info = C_Container.GetContainerItemInfo(bag, slot)
			if info and info.itemID == id then
				copies = copies + 1
				local bound = info.isBound == true
				if not bound and ItemLocation and C_Item and C_Item.IsBound then
					local ok, b = pcall(function() return C_Item.IsBound(ItemLocation:CreateFromBagAndSlot(bag, slot)) end)
					bound = ok and b == true
				end
				if not bound then free = free + 1 end
			end
		end
	end
	return copies > 0 and free == 0
end

-- Called from a click (the dialog in gift mode).
function GF.Add(text, price)
	local id = W.ItemId(text)
	if not id then ns.Say(L.WISH_NOT_ITEM); return false end
	if GF.Bound(id) then ns.Say(L.GIFT_BOUND); return false end
	if GF.Has(id) then ns.Say(L.GIFT_DUP); return false end
	local list = mine()
	if #list >= GF.MAX then ns.Say(L.GIFT_FULL, GF.MAX); return false end
	list[#list + 1] = { id = id, t = time(), price = price or nil }
	send()
	for _, name in ipairs(W.WantedBy(id)) do if name ~= me() then tell(name .. ":w:" .. id, L.GIFT_WANTED, name, link(id)) end end
	ns.Fire("LM_WISHES_CHANGED")
	return true
end

function GF.Remove(id)
	local list = mine()
	for i, g in ipairs(list) do
		if g.id == id then table.remove(list, i); send(); ns.Fire("LM_WISHES_CHANGED"); return true end
	end
	return false
end

-- Called from a click (a row's menu): reserve a guildmate's giveaway.
function GF.Reserve(giver, id)
	local e = theirs()[giver]
	if not e or not R.mates[giver] then return false end   -- the giver confirms, so they must be online
	if not C.Send("gr", { i = id, to = giver }, "now") then ns.Say(L.MEET_NOT_NOW); return false end
	ns.Say(L.GIFT_ASKED, giver, link(id))
	return true
end

function GF.List()
	local out = {}
	for _, g in ipairs(mine()) do out[#out + 1] = { name = me(), id = g.id, t = g.t, mine = true, reservedBy = g.reservedBy, price = g.price } end
	for _, o in ipairs(others()) do
		for _, id in ipairs(o.ids) do out[#out + 1] = { name = o.name, id = id, t = o.t, reservedBy = o.reserved[id], price = o.prices[id] } end
	end
	return out
end

function GF.GivenBy(id)
	local names = {}
	if GF.Has(id) then names[#names + 1] = me() end
	for _, o in ipairs(others()) do for _, x in ipairs(o.ids) do if x == id then names[#names + 1] = o.name; break end end end
	table.sort(names)
	return names
end

-- A seller's free list (a record; a removed or empty one clears it).
local function onFree(f, name, live)
	local t = theirs()
	if f.ids == nil then
		if t[name] and t[name].sale then t[name].ids = {} else t[name] = nil end   -- a seller keeps their priced offers
	else
		local old = t[name] and t[name].reserved or {}
		local ids, reserved = {}, {}
		for id in tostring(f.ids):gmatch("%d+") do id = tonumber(id); ids[#ids + 1] = id; reserved[id] = old[id] end
		for id in pairs(t[name] and t[name].sale or {}) do reserved[id] = old[id] end
		t[name] = { ids = ids, sale = t[name] and t[name].sale, t = time(), reserved = reserved }
		if live then for _, id in ipairs(ids) do if W.Has(id) then tell(name .. ":g:" .. id, L.GIFT_FOR_YOU, name, link(id)) end end end
	end
	ns.Fire("LM_WISHES_CHANGED")
end
-- A seller's priced list.
local function onSale(f, name, live)
	local t = theirs()
	local sale = {}
	for id, price in tostring(f.p or ""):gmatch("(%d+):(%d+)") do sale[tonumber(id)] = tonumber(price) end
	if not next(sale) then
		if t[name] then t[name].sale = nil; if #(t[name].ids or {}) == 0 then t[name] = nil end end
	else
		t[name] = t[name] or { ids = {}, reserved = {} }
		t[name].sale, t[name].t = sale, time()
		t[name].reserved = t[name].reserved or {}
		if live then for id, price in pairs(sale) do if W.Has(id) then tell(name .. ":s:" .. id, L.SALE_FOR_YOU, name, link(id), GF.Money(price)) end end end
	end
	ns.Fire("LM_WISHES_CHANGED")
end
local function onRecord(apply)
	return function(rec, _, how)
		if how == "mine" or how == "expired" then return end
		apply(rec.dead and {} or rec.d, rec.o, how == "live")
	end
end
local function ownKey(id, owner) return id == ns.NameKey(owner) end   -- one list per seller, under their own name
S.Define("gv", { class = "board", life = LIFE, fields = { ids = C.V.itemids(10) }, onChange = onRecord(onFree), idOwner = ownKey })
S.Define("sl", { class = "board", life = LIFE, fields = { p = C.V.saleList }, onChange = onRecord(onSale), idOwner = ownKey })

-- A guildmate's wishes against my giveaways (the wishlist module stores them).
C.OnMessage("wl", function(f, name)
	if not R.mates[name] or f.ids == nil then return end
	for id in tostring(f.ids):gmatch("%d+") do
		id = tonumber(id)
		if GF.Has(id) then tell(name .. ":w:" .. id, L.GIFT_WANTED, name, link(id)) end
	end
end)

-- My new wish against guildmates' giveaways.
ns.On("LM_WISH_ADDED", function(id)
	for _, o in ipairs(others()) do
		for _, x in ipairs(o.ids) do if x == id then tell(o.name .. ":g:" .. id, L.GIFT_FOR_YOU, o.name, link(id)) end end
	end
end)

C.OnMessage("gr", function(f, name)
	if not R.mates[name] then return end
	if f.to == me() then
		local g = GF.Has(f.i)
		if not g or (g.reservedBy and g.reservedBy ~= name) then return end   -- first come
		local first = g.reservedBy == nil
		g.reservedBy = name
		if first then ns.NoticeAt("wishes", L.GIFT_RESERVED, name, link(f.i)); ns.Fire("LM_GIFT_GIVEN") end
		C.Send("gro", { i = f.i, by = name }, "now")   -- everyone learns who got it from me
		ns.Fire("LM_WISHES_CHANGED")
	end
end)

-- The giver's word on who reserved a gift (the truth for everyone, the reserver included).
C.OnMessage("gro", function(f, name)
	if not R.mates[name] then return end
	local e = theirs()[name]
	if not e then return end
	e.reserved = e.reserved or {}
	local new = e.reserved[f.i] ~= f.by
	e.reserved[f.i] = f.by
	if new and f.by == me() then ns.NoticeAt("wishes", L.GIFT_CONFIRMED, name, link(f.i)) end
	ns.Fire("LM_WISHES_CHANGED")
end)
ns.On("LM_HELLO_ANSWERED", function()
	for _, g in ipairs(mine()) do if g.reservedBy then C.Send("gro", { i = g.id, by = g.reservedBy }) end end
end)

-- At login and /reload (the guild known by then): my lists go out again when the guild has no live record of them
-- (my first 0.4 login, a 0.3.x pending mark) or they would expire within a week.
ns.On("LM_ANNOUNCED", function()
	if #mine() == 0 and not ns.char.giftPending then return end
	local soon = GetServerTime() + 7 * 86400
	local gv, sl = S.Get("gv", myKey()), S.Get("sl", myKey())
	if ns.char.giftPending or not (gv and sl) or gv.e < soon or sl.e < soon then ns.char.giftPending = nil; send() end
end)

if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
	TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
		if not ns.db or (tooltip ~= GameTooltip and tooltip ~= ItemRefTooltip) or not data or not data.id then return end
		local names = GF.GivenBy(data.id)
		if #names > 0 then tooltip:AddLine(string.format(L.GIFT_TOOLTIP, table.concat(names, ", ")), 1, 0.82, 0) end
	end)
end

-- Simulation support (/lm sim mercadillo): local samples, never sent.
function GF.AddSample(name, ids, sale) theirs()[name] = { ids = ids, sale = sale, t = time(), sim = true, reserved = {} }; ns.Fire("LM_WISHES_CHANGED") end
function GF.RemoveSamples()
	local t = theirs()
	for name, l in pairs(t) do if l.sim then t[name] = nil end end
	ns.Fire("LM_WISHES_CHANGED")
end
