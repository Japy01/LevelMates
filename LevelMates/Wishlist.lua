-- Wishlist.lua: items each player wants (up to 10 per character), shared with the guild in its own kind `wl`
-- (the whole list as item ids; no ids withdraws it). Spec 2026-10-09-levelmates-wishlist-design.
local _, ns = ...
local W = {}
ns.Wishlist = W
local L, C, R = ns.L, ns.Comm, ns.Roster
W.MAX, W.FORGET_DAYS = 10, 30

local function me() return ns.Me() end
function W.IsExternal() return ns.char.wishSource == "needroll" end
-- Interoperability adapter for the installed NeedRoll wishlist schema (observed in 1.4.1/1.7.0).
-- Read-only: never assign into NeedRollDB or persist a second list in our character data.
function W.NeedRollItems()
	if not (C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("NeedRoll")) then return nil end
	local db = NeedRollDB
	local store = type(db) == "table" and db.wishlist
	if type(store) ~= "table" or type(store.lists) ~= "table" or type(store.current) ~= "string" or #store.lists > 100 then return nil end
	local selected
	for _, list in ipairs(store.lists) do
		if type(list) ~= "table" then return nil end
		if list.name == store.current then selected = list; break end
	end
	if not selected or type(selected.items) ~= "table" or #selected.items > 500 then return nil end
	local out, seen, total = {}, {}, 0
	for _, entry in ipairs(selected.items) do
		local id = type(entry) == "table" and ns.Plain(entry.itemID)
		if type(id) ~= "number" or id < 1 or id > 999999 or id ~= math.floor(id) then return nil end
		if not seen[id] then
			seen[id], total = true, total + 1
			if #out < W.MAX then out[#out + 1] = { id = id, t = ns.char.wishSourceAt or time() } end
		end
	end
	return out, total
end
local function mine()
	if W.IsExternal() then return W.NeedRollItems() or {} end
	ns.char.wishes = ns.char.wishes or {}; return ns.char.wishes
end
local function theirs()
	ns.db.wishes = ns.db.wishes or {}
	local k = ns.GuildKey()
	ns.db.wishes[k] = ns.db.wishes[k] or {}
	return ns.db.wishes[k]
end

function W.ItemId(text)
	local id = type(text) == "string" and tonumber(text:match("item:(%d+)") or "")
	if id and id >= 1 and id <= 999999 then return id end
end

function W.Has(id) for _, w in ipairs(mine()) do if w.id == id then return true end end; return false end

-- My list, whole, in `wl` (no ids withdraws it): the sync layer's personal helper keeps a refused send pending in the
-- character's saved data, sends it after the next heartbeat, and resends a non-empty list to newcomers.
local P = ns.Sync.Personal("wl", function()
	local ids = {}
	for _, w in ipairs(mine()) do ids[#ids + 1] = w.id end
	return { ids = #ids > 0 and table.concat(ids, ",") or nil }
end, { save = "wishPending", worth = function() return #mine() > 0 end })
local function send(prio) return P.Mark(prio) end
-- Priorities (1 first, 3 last) ride in their own kind, so clients that predate them keep the wishes themselves.
local PP = ns.Sync.Personal("wp", function()
	local parts = {}
	for _, w in ipairs(mine()) do if w.p then parts[#parts + 1] = w.id .. ":" .. w.p end end
	return { p = #parts > 0 and table.concat(parts, ","):sub(1, 120) or nil }
end, { save = "wishPrioPending", worth = function() for _, w in ipairs(mine()) do if w.p then return true end end; return false end })
local sourceSignature
function W.SourceTick()
	if not W.IsExternal() then return end
	local items = W.NeedRollItems()
	local ids = {}; for _, w in ipairs(items or {}) do ids[#ids + 1] = w.id end
	local signature = (items and "ready:" or "unavailable:") .. table.concat(ids, ",")
	if signature ~= sourceSignature then
		sourceSignature = signature
		send("now"); PP.Mark("now"); ns.Fire("LM_WISHES_CHANGED")
	end
end
function W.SetSource(source)
	if source ~= "local" and source ~= "needroll" then return false end
	if source == "needroll" and not W.NeedRollItems() then ns.Say(L.WISH_SOURCE_UNAVAILABLE); return false end
	ns.char.wishSource, ns.char.wishSourceAt = source, time()
	sourceSignature = nil
	send("now"); PP.Mark("now"); ns.Fire("LM_WISHES_CHANGED")
	return true
end
function W.SourceStatus()
	if not W.IsExternal() then return L.WISH_SOURCE_LOCAL end
	local items, total = W.NeedRollItems()
	if not items then return L.WISH_SOURCE_UNAVAILABLE end
	return string.format(L.WISH_SOURCE_NEEDROLL, #items, total)
end
ns.Slash("wishsource", function(rest)
	local source = strtrim(rest or "")
	if source ~= "" and not W.SetSource(source) then ns.Say(L.WISH_SOURCE_HELP); return end
	ns.Say(W.SourceStatus()); ns.Say(L.WISH_SOURCE_HELP)
end)
ns.On("LM_WORLD", function()
	if not W.sourceTicker then W.sourceTicker = C_Timer.NewTicker(5, W.SourceTick) end
	W.SourceTick()
end)

function W.SetPriority(id, prio)
	if W.IsExternal() then ns.Say(L.WISH_SOURCE_MANAGED); return false end
	prio = tonumber(prio)
	for _, w in ipairs(mine()) do
		if w.id == id then
			w.p = (prio and prio >= 1 and prio <= 3) and math.floor(prio) or nil
			PP.Mark("now"); ns.Fire("LM_WISHES_CHANGED")
			return true
		end
	end
	return false
end
function W.PriorityOf(name, id)
	if name == me() then for _, w in ipairs(mine()) do if w.id == id then return w.p end end; return nil end
	local l = theirs()[name]
	return l and l.prio and l.prio[id] or nil
end
-- Who wants an item, with their priority when they set one: "Luis (2), Tester (1)".
function W.WantedText(id)
	local parts = {}
	for _, n in ipairs(W.WantedBy(id)) do local p = W.PriorityOf(n, id); parts[#parts + 1] = n .. (p and (" (" .. p .. ")") or "") end
	return table.concat(parts, ", ")
end
C.OnMessage("wp", function(f, name)
	if not R.mates[name] then return end
	local t = theirs()
	t[name] = t[name] or { ids = {}, t = time() }
	local prio = {}
	for id, p in tostring(f.p or ""):gmatch("(%d+):(%d)") do prio[tonumber(id)] = tonumber(p) end
	t[name].prio = prio
	ns.Fire("LM_WISHES_CHANGED")
end)

-- Called from a click (the "Add a wish" dialog).
function W.Add(link)
	if W.IsExternal() then ns.Say(L.WISH_SOURCE_MANAGED); return false end
	local id = W.ItemId(link)
	if not id then ns.Say(L.WISH_NOT_ITEM); return false end
	if W.Has(id) then ns.Say(L.WISH_DUP); return false end
	local list = mine()
	if #list >= W.MAX then ns.Say(L.WISH_FULL, W.MAX); return false end
	list[#list + 1] = { id = id, t = time() }
	ns.Fire("LM_WISH_ADDED", id)
	send("now")
	ns.Fire("LM_WISHES_CHANGED")
	return true
end

function W.Remove(id)
	if W.IsExternal() then ns.Say(L.WISH_SOURCE_MANAGED); return false end
	local list = mine()
	for i, w in ipairs(list) do
		if w.id == id then
			table.remove(list, i)
			send("now")
			ns.Fire("LM_WISHES_CHANGED")
			return true
		end
	end
	return false
end

-- Others' lists still worth showing: updated in the last 30 days, by someone still in the guild (or a sample).
local function others()
	local t, out, cutoff = theirs(), {}, time() - W.FORGET_DAYS * 86400
	for name, l in pairs(t) do
		if l.t < cutoff then t[name] = nil
		elseif name ~= me() and (l.sim or R.IsGuildmate(name)) then out[#out + 1] = { name = name, ids = l.ids, t = l.t } end
	end
	table.sort(out, function(a, b) return a.name < b.name end)
	return out
end

function W.List()
	local out = {}
	for _, w in ipairs(mine()) do out[#out + 1] = { name = me(), id = w.id, t = w.t, mine = true } end
	for _, o in ipairs(others()) do
		for _, id in ipairs(o.ids) do out[#out + 1] = { name = o.name, id = id, t = o.t } end
	end
	return out
end

function W.WantedBy(id)
	local names = {}
	if W.Has(id) then names[#names + 1] = me() end
	for _, o in ipairs(others()) do
		for _, x in ipairs(o.ids) do if x == id then names[#names + 1] = o.name; break end end
	end
	table.sort(names)
	return names
end

-- The item's link, or nil while the client has not loaded it (asked once; the board refreshes when it arrives).
local asked = {}
function W.Link(id)
	local info = (C_Item and C_Item.GetItemInfo) or GetItemInfo
	local link = info and select(2, info(id))
	if link then return link end
	if not asked[id] and Item and Item.CreateFromItemID then
		asked[id] = true
		Item:CreateFromItemID(id):ContinueOnItemLoad(function() ns.Fire("LM_WISHES_CHANGED") end)
	end
	return nil
end

C.OnMessage("wl", function(f, name)
	if not R.mates[name] then return end   -- only people the roster knows
	local t = theirs()
	if f.ids == nil then
		t[name] = nil
	else
		local ids = {}
		for id in tostring(f.ids):gmatch("%d+") do ids[#ids + 1] = tonumber(id) end
		t[name] = { ids = ids, t = time() }
	end
	ns.Fire("LM_WISHES_CHANGED")
end)

-- My loot: my own wish is done; a guildmate's wish gets a notice, once per item and person each session.
local told = {}
ns.On("LM_MY_LOOT", function(link)
	local id = W.ItemId(link)
	if not id then return end
	if W.Has(id) and not W.IsExternal() then
		W.Remove(id)
		ns.NoticeAt("wishes", L.WISH_GOT, link)
	end
	if not ns.db.settings.wishNotices then return end
	for _, o in ipairs(others()) do
		for _, x in ipairs(o.ids) do
			if x == id and not told[o.name .. ":" .. id] then
				told[o.name .. ":" .. id] = true
				ns.NoticeAt("wishes", L.WISH_THEY_WANT, o.name, link)
			end
		end
	end
end)



-- Item tooltips anywhere in the game: who wants it.
if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
	TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
		if not ns.db or (tooltip ~= GameTooltip and tooltip ~= ItemRefTooltip) or not data or not data.id then return end
		local names = W.WantedBy(data.id)
		if #names > 0 then tooltip:AddLine(string.format(L.WISH_TOOLTIP, W.WantedText(data.id)), 0.4, 1, 0.4) end
	end)
end

-- Simulation support (/lm sim deseos): local samples, never sent.
function W.AddSample(name, ids) theirs()[name] = { ids = ids, t = time(), sim = true }; ns.Fire("LM_WISHES_CHANGED") end
function W.RemoveSamples()
	local t = theirs()
	for name, l in pairs(t) do if l.sim then t[name] = nil end end
	ns.Fire("LM_WISHES_CHANGED")
end
