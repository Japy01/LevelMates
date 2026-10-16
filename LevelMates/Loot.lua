-- Loot.lua: the raid loot's book, kept by everyone and written by officers (spec 2026-10-16, decisions 3 and 4).
-- Two kinds of record:
--   lk: an entry of the points ledger, append-only: who, ±points, kind (att attendance, boss, spend, adj adjustment,
--       refund), reason, maybe an item, a raid, and the entry it undoes. A balance is the sum of someone's entries.
--       Nothing is edited or deleted: a mistake gets an opposite entry that points to the original.
--   la: an award of an item to someone: the boss it came from (an encounter or a corpse, else unknown), how its
--       hand-over was proven (ml master loot from a click, trade, chat line, manual) and its state: aw awarded, rc
--       received, eq equipped, x cancelled, c corrected (replaced by a newer award that points back).
-- Both are board records synced by guild outside instances (the record layer holds them inside). Nothing here sends
-- chat or whispers.
local _, ns = ...
local LT = {}
ns.Loot = LT
local L, C, R, S = ns.L, ns.Comm, ns.Roster, ns.Sync
LT.LEDGER_LIFE, LT.AWARD_LIFE = 365 * 86400, 180 * 86400
LT.KINDS = { att = true, boss = true, spend = true, adj = true, refund = true }
LT.NEXT = { aw = { rc = true, eq = true, x = true, c = true }, rc = { eq = true, x = true, c = true }, eq = { c = true }, x = {}, c = {} }

local function me() return ns.Me() end
local function officer(name) return R.IsOfficer(name) or (name == me() and R.IAmOfficer()) end
local seq = 0
local function newId(prefix) seq = seq + 1; return string.format("%s%s%x%x", prefix, ns.NameKey(me()):sub(1, 6), time() % 100000, seq) end
local function changed() ns.Fire("LM_LOOT_CHANGED") end

S.Define("lk", { class = "board", life = LT.LEDGER_LIFE, relayMax = 1000,
	fields = { w = C.V.text(48), p = C.V.int(-100000, 100000), k = C.V.oneOf("att", "boss", "spend", "adj", "refund"), r = C.V.text(80),
		i = C.V.int(1, 999999), g = C.V.word(24), f = C.V.word(24) },
	required = { "w", "p", "k", "r" },
	accept = function(f, owner) return officer(owner) end,
	onChange = changed })
S.Define("la", { class = "board", life = LT.AWARD_LIFE, relayMax = 500,
	fields = { i = C.V.int(1, 999999), to = C.V.text(48), b = C.V.text(60), en = C.V.int(0, 100000), s = C.V.oneOf("aw", "rc", "eq", "x", "c"),
		pf = C.V.oneOf("ml", "trade", "chat", "manual"), c = C.V.int(0, 100000), g = C.V.word(24), f = C.V.word(24), k = C.V.word(24), at = C.V.int(0, 4000000000), r = C.V.text(80) },
	required = { "i", "to", "s" },
	accept = function(f, owner) return officer(owner) end,
	may = function(rec, who) return rec.o == who or officer(who) end,   -- any officer may move an award on
	onChange = changed })

------------------------------------------------------------------ soft reserves
-- One round a night, opened by an officer (lro, eight hours); a reserve (lr) is one item in one's own name (its id
-- is made from the name: nobody reserves for another). Over the limit is shown, never blocked.
LT.RESERVE_LIFE = 8 * 3600
S.Define("lro", { class = "board", life = LT.RESERVE_LIFE, writerOwns = true, fields = { on = C.V.int(0, 1) }, required = { "on" },
	accept = function(f, owner) return officer(owner) end,
	may = function(rec, who) return officer(who) end,
	onChange = changed })
local function reserveId(name, item) return "v" .. ns.NameKey(name) .. tostring(item) end
S.Define("lr", { class = "board", life = LT.RESERVE_LIFE, fields = { i = C.V.int(1, 999999), b = C.V.text(60) }, required = { "i" },
	idOwner = function(id, owner) return id:sub(2, 9) == ns.NameKey(owner) end,
	onChange = changed })
function LT.ReservesOpen()
	local rec = S.Get("lro", "round")
	return rec ~= nil and rec.d.on == 1
end
function LT.OpenReserves()
	if not officer(me()) then ns.Say(L.LOOT_NOT_OFFICER); return false end
	return S.Put("lro", "round", { on = 1 }) and true or false
end
function LT.CloseReserves()
	if not officer(me()) then ns.Say(L.LOOT_NOT_OFFICER); return false end
	if not LT.ReservesOpen() then return false end
	return S.Remove("lro", "round") and true or false
end
-- Everyone's live reserves while the round is open: { name, i, t }, by name then item.
function LT.Reserves()
	local out = {}
	if not LT.ReservesOpen() then return out end
	for _, rec in ipairs(S.List("lr")) do out[#out + 1] = { name = rec.o, i = rec.d.i, b = rec.d.b, t = rec.v } end
	table.sort(out, function(a, b) if a.name ~= b.name then return a.name < b.name end; return a.i < b.i end)
	return out
end
function LT.ReservedBy(item)
	local names = {}
	for _, r in ipairs(LT.Reserves()) do if r.i == item then names[#names + 1] = r.name end end
	table.sort(names)
	return names
end
-- Mine, oldest first, those past the limit marked over.
function LT.MyReserves()
	local out = {}
	for _, r in ipairs(LT.Reserves()) do if r.name == me() then out[#out + 1] = r end end
	table.sort(out, function(a, b) return a.t < b.t end)
	local limit = ns.LootRaid and ns.LootRaid.Rules().reserves or 2
	for k, r in ipairs(out) do r.over = k > limit end
	return out
end
-- From a click: one item of mine. Refused without a round, or twice the same item.
function LT.Reserve(item, boss)
	item = tonumber(item)
	if not item then return false end
	if not LT.ReservesOpen() then ns.Say(L.LOOT_NO_ROUND); return false end
	if S.Get("lr", reserveId(me(), item)) then return false end
	return S.Put("lr", reserveId(me(), item), { i = item, b = boss }) and true or false
end
function LT.Unreserve(item)
	item = tonumber(item)
	return item ~= nil and S.Remove("lr", reserveId(me(), item)) and true or false
end

------------------------------------------------------------------ the ledger
-- total, earned, spent of someone
function LT.Balance(name)
	local total, earned, spent = 0, 0, 0
	for _, rec in ipairs(S.List("lk")) do
		local d = rec.d
		if d.w == name then
			total = total + d.p
			if d.p > 0 then earned = earned + d.p else spent = spent - d.p end
		end
	end
	return total, earned, spent
end
-- everyone with an entry: { name, total, earned, spent, last }, highest first
function LT.Standings()
	local by, out = {}, {}
	for _, rec in ipairs(S.List("lk")) do
		local d = rec.d
		local e = by[d.w]
		if not e then e = { name = d.w, total = 0, earned = 0, spent = 0, last = 0 }; by[d.w] = e; out[#out + 1] = e end
		e.total = e.total + d.p
		if d.p > 0 then e.earned = e.earned + d.p else e.spent = e.spent - d.p end
		e.last = math.max(e.last, rec.v or 0)
	end
	table.sort(out, function(a, b) if a.total ~= b.total then return a.total > b.total end; return a.name < b.name end)
	return out
end
-- someone's entries, newest first: the data plus id, by (the author) and v (when)
function LT.Ledger(name)
	local out = {}
	for _, rec in ipairs(S.List("lk")) do
		if rec.d.w == name then
			local e = {}
			for k, v in pairs(rec.d) do e[k] = v end
			e.id, e.by, e.v = rec.id, rec.o, rec.v
			out[#out + 1] = e
		end
	end
	table.sort(out, function(a, b) if a.v ~= b.v then return a.v > b.v end; return a.id > b.id end)
	return out
end
-- An entry (a click of an officer). opts: item, raid, ref. Nobody goes below zero. Returns the entry's id, or
-- false and why ("officer", "bad", "low").
function LT.Post(who, points, kind, reason, opts)
	if not officer(me()) then ns.Say(L.LOOT_NOT_OFFICER); return false, "officer" end
	points = tonumber(points)
	reason = strtrim(tostring(reason or ""))
	if not (who and who ~= "" and points and points == math.floor(points) and points ~= 0 and LT.KINDS[kind] and reason ~= "") then return false, "bad" end
	if points < 0 and LT.Balance(who) + points < 0 then ns.Say(L.LOOT_LOW, who, LT.Balance(who)); return false, "low" end
	opts = opts or {}
	local id = newId("k")
	if not S.Put("lk", id, { w = who, p = points, k = kind, r = reason, i = opts.item, g = opts.raid, f = opts.ref }) then return false, "bad" end
	return id
end
-- The same entry for several people (everyone present at a boss).
function LT.PostAll(names, points, kind, reason, opts)
	local n = 0
	for _, name in ipairs(names or {}) do if LT.Post(name, points, kind, reason, opts) then n = n + 1 end end
	return n
end
-- An opposite entry that points to the original; once per entry.
function LT.Refund(entryId, reason)
	local rec = S.Get("lk", entryId)
	if not rec then return false, "bad" end
	for _, r in ipairs(S.List("lk")) do if r.d.f == entryId then return false, "done" end end
	return LT.Post(rec.d.w, -rec.d.p, "refund", reason or L.LOOT_REFUND, { item = rec.d.i, raid = rec.d.g, ref = entryId })
end

-- The standings as plain text (for Discord): one line each.
function LT.StandingsText()
	local lines = { string.format(L.LOOT_COPY_TITLE, date("%d/%m/%Y")) }
	for _, s in ipairs(LT.Standings()) do lines[#lines + 1] = string.format("%s: %d (%s)", s.name, s.total, string.format(L.LOOT_EARNED_SPENT, s.earned, s.spent)) end
	if #lines == 1 then lines[2] = L.LOOT_EMPTY end
	return table.concat(lines, "\n")
end

------------------------------------------------------------------ awards
local function award(id) local rec = S.Get("la", id); return rec and rec.d, rec end
local function put(id, d) return S.Put("la", id, d) end
-- An item to someone (a click of the master looter or an officer). opts: boss, enc, proof, cost, raid, reason.
-- A cost is a spend entry first: too expensive, nothing happens.
function LT.Award(itemId, to, opts)
	if not officer(me()) then ns.Say(L.LOOT_NOT_OFFICER); return false, "officer" end
	opts = opts or {}
	itemId = tonumber(itemId)
	if not (itemId and to and to ~= "") then return false, "bad" end
	local entry
	if (opts.cost or 0) > 0 then
		local name = ns.ItemInfo(itemId) or ("#" .. itemId)
		entry = LT.Post(to, -opts.cost, "spend", name, { item = itemId, raid = opts.raid })
		if not entry then return false, "low" end
	end
	local id = newId("a")
	if not put(id, { i = itemId, to = to, b = opts.boss, en = opts.enc, s = "aw", pf = opts.proof or "manual", c = opts.cost or 0, g = opts.raid, f = opts.ref, k = entry, at = time() }) then return false, "bad" end
	return id
end
local function move(id, state, extra)
	local d = award(id)
	if not d or not LT.NEXT[d.s][state] then return false end
	local n = {}
	for k, v in pairs(d) do n[k] = v end
	n.s = state
	for k, v in pairs(extra or {}) do n[k] = v end
	return put(id, n)
end
function LT.Confirm(id, proof) return move(id, "rc", { pf = proof }) end
function LT.Equipped(id) return move(id, "eq") end
-- Cancelled: the cost comes back.
function LT.Cancel(id, reason)
	local d = award(id)
	if not d or not move(id, "x", { r = reason }) then return false end
	if d.k then LT.Refund(d.k, reason) end
	return true
end
-- Corrected: the old one marked, a new award to someone else that points back; the cost moves with it.
function LT.Correct(id, newTo, reason)
	local d = award(id)
	if not d or not LT.NEXT[d.s].c then return false end
	local n = LT.Award(d.i, newTo, { boss = d.b, enc = d.en, proof = "manual", cost = d.c, raid = d.g, ref = id, reason = reason })
	if not n then return false end
	move(id, "c", { r = reason })
	if d.k then LT.Refund(d.k, reason) end
	return n
end
-- Live awards, newest first: the data plus id and by.
function LT.History(search)
	local q, out = strtrim(tostring(search or "")):lower(), {}
	for _, rec in ipairs(S.List("la")) do
		local e = {}
		for k, v in pairs(rec.d) do e[k] = v end
		e.id, e.by = rec.id, rec.o
		local name = ns.ItemInfo(e.i)
		if q == "" or (e.to or ""):lower():find(q, 1, true) or (name and name:lower():find(q, 1, true)) or (e.b and e.b:lower():find(q, 1, true)) then out[#out + 1] = e end
	end
	table.sort(out, function(a, b) if (a.at or 0) ~= (b.at or 0) then return (a.at or 0) > (b.at or 0) end; return a.id > b.id end)
	return out
end
-- +1: items received (or equipped) of epic quality or better, counted per person (an item whose quality the client
-- does not know yet does not count).
LT.PLUS_ONE_QUALITY = 4
-- an item's quality: what the client says, else read off its link's colour (the client may not have the item yet)
local QUALITY_OF_COLOUR = { ["9d9d9d"] = 0, ffffff = 1, ["1eff00"] = 2, ["0070dd"] = 3, a335ee = 4, ff8000 = 5, e6cc80 = 6 }
local function quality(id)
	local _, link, q = ns.ItemInfo(id)
	if q then return q end
	local hex = link and tostring(link):match("^|c%x%x(%x%x%x%x%x%x)")
	return hex and QUALITY_OF_COLOUR[hex:lower()]
end
function LT.PlusOne(name)
	local n = 0
	for _, rec in ipairs(S.List("la")) do
		local d = rec.d
		if d.to == name and (d.s == "rc" or d.s == "eq") then
			local q = quality(d.i)
			if q and q >= LT.PLUS_ONE_QUALITY then n = n + 1 end
		end
	end
	return n
end
