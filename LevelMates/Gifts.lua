-- Gifts.lua: the giveaway market. Items I give away (up to 10) go out in `gv` (as wishes do in `wl`); a guildmate
-- reserves one with `gr`, first come. Giveaways and wishes are matched both ways with a notice.
-- Spec 2026-10-10-levelmates-social-leveling-design (A2).
local _, ns = ...
local GF = {}
ns.Gifts = GF
local L, C, R, W = ns.L, ns.Comm, ns.Roster, ns.Wishlist
GF.MAX, GF.FORGET_DAYS = 10, 30

local function me() return (UnitName("player")) end
local function mine() ns.char.gifts = ns.char.gifts or {}; return ns.char.gifts end
local function theirs()
	ns.db.gifts = ns.db.gifts or {}
	local k = GetGuildInfo("player") or "?"
	ns.db.gifts[k] = ns.db.gifts[k] or {}
	return ns.db.gifts[k]
end
local function link(id) return W.Link(id) or string.format(L.WISH_UNKNOWN, id) end

function GF.Has(id) for _, g in ipairs(mine()) do if g.id == id then return g end end end

-- A refused send stays pending in the character's saved data and goes out after the next heartbeat.
local sentAt
local function send(prio)
	local ids = {}
	for _, g in ipairs(mine()) do ids[#ids + 1] = g.id end
	local fields = {}
	if #ids > 0 then fields.ids = table.concat(ids, ",") end
	if C.Send("gv", fields, prio) then ns.char.giftPending, sentAt = nil, GetTime(); return true end
	ns.char.giftPending = true
	return false
end
local function resend() if sentAt ~= GetTime() then send() end end

-- Others' giveaways: updated in the last 30 days, by someone still in the guild (or a sample).
local function others()
	local t, out, cutoff = theirs(), {}, time() - GF.FORGET_DAYS * 86400
	for name, l in pairs(t) do
		if l.t < cutoff then t[name] = nil
		elseif name ~= me() and (l.sim or R.IsGuildmate(name)) then out[#out + 1] = { name = name, ids = l.ids, t = l.t, reserved = l.reserved or {} } end
	end
	table.sort(out, function(a, b) return a.name < b.name end)
	return out
end

-- Matches, told once per person and item each session.
local told = {}
local function tell(key, fmt, ...) if told[key] then return end; told[key] = true; ns.Notice(fmt, ...) end

-- Called from a click (the dialog in gift mode).
function GF.Add(text)
	local id = W.ItemId(text)
	if not id then ns.Say(L.WISH_NOT_ITEM); return false end
	if GF.Has(id) then ns.Say(L.GIFT_DUP); return false end
	local list = mine()
	if #list >= GF.MAX then ns.Say(L.GIFT_FULL, GF.MAX); return false end
	list[#list + 1] = { id = id, t = time() }
	send("now")
	for _, name in ipairs(W.WantedBy(id)) do if name ~= me() then tell(name .. ":w:" .. id, L.GIFT_WANTED, name, link(id)) end end
	ns.Fire("LM_WISHES_CHANGED")
	return true
end

function GF.Remove(id)
	local list = mine()
	for i, g in ipairs(list) do
		if g.id == id then table.remove(list, i); send("now"); ns.Fire("LM_WISHES_CHANGED"); return true end
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
	for _, g in ipairs(mine()) do out[#out + 1] = { name = me(), id = g.id, t = g.t, mine = true, reservedBy = g.reservedBy } end
	for _, o in ipairs(others()) do
		for _, id in ipairs(o.ids) do out[#out + 1] = { name = o.name, id = id, t = o.t, reservedBy = o.reserved[id] } end
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

C.OnMessage("gv", function(f, name)
	if not R.mates[name] then return end
	local t = theirs()
	if f.ids == nil then
		t[name] = nil
	else
		local old = t[name] and t[name].reserved or {}
		local ids, reserved = {}, {}
		for id in tostring(f.ids):gmatch("%d+") do id = tonumber(id); ids[#ids + 1] = id; reserved[id] = old[id] end
		t[name] = { ids = ids, t = time(), reserved = reserved }
		for _, id in ipairs(ids) do if W.Has(id) then tell(name .. ":g:" .. id, L.GIFT_FOR_YOU, name, link(id)) end end
	end
	ns.Fire("LM_WISHES_CHANGED")
end)

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
		if first then ns.Notice(L.GIFT_RESERVED, name, link(f.i)) end
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
	if new and f.by == me() then ns.Notice(L.GIFT_CONFIRMED, name, link(f.i)) end
	ns.Fire("LM_WISHES_CHANGED")
end)
ns.On("LM_PING_ANSWERED", function()
	for _, g in ipairs(mine()) do if g.reservedBy then C.Send("gro", { i = g.id, by = g.reservedBy }) end end
end)

ns.On("LM_PING_ANSWERED", function() if #mine() > 0 then resend() end end)
ns.On("LM_ANNOUNCED", function() if #mine() > 0 then resend() end end)
ns.On("LM_HB_SENT", function() if ns.char.giftPending then send() end end)
ns.On("LM_COMM_DROPPED", function(kind) if kind == "gv" then ns.char.giftPending = true end end)

if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
	TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
		if not ns.db or (tooltip ~= GameTooltip and tooltip ~= ItemRefTooltip) or not data or not data.id then return end
		local names = GF.GivenBy(data.id)
		if #names > 0 then tooltip:AddLine(string.format(L.GIFT_TOOLTIP, table.concat(names, ", ")), 1, 0.82, 0) end
	end)
end

-- Simulation support (/lm sim mercadillo): local samples, never sent.
function GF.AddSample(name, ids) theirs()[name] = { ids = ids, t = time(), sim = true, reserved = {} }; ns.Fire("LM_WISHES_CHANGED") end
function GF.RemoveSamples()
	local t = theirs()
	for name, l in pairs(t) do if l.sim then t[name] = nil end end
	ns.Fire("LM_WISHES_CHANGED")
end
