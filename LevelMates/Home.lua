-- Home.lua: the Home page's rows, "what do I do now": the guild (level, weekly challenge), what is happening now
-- (help, groups, today's meetups), what is for me (guildmates near my level or in my zone, gifts I wish for, spells at
-- the trainer), this week's top three, and an invite when nobody is seen. Data only; the board draws it.
-- Spec 2026-10-11-levelmates-libro-design.
local _, ns = ...
local HM = {}
ns.Home = HM
local L, R = ns.L, ns.Roster
HM.NEAR, HM.MAX_MATES = 3, 5

local function me() return ns.Me() end

local function section(out, key, items)
	if #items == 0 then return end
	out[#out + 1] = { header = key, count = #items }
	for _, it in ipairs(items) do out[#out + 1] = it end
end

function HM.Rows()
	local out, PT = {}, ns.Points
	-- the guild
	local level, into, need = PT.Level(PT.GuildTotal())
	local ch = PT.Challenge()
	out[#out + 1] = { header = "guild" }
	local motd, by = ns.GuildNotes.Motd()
	if motd then out[#out + 1] = { kind = "motd", text = motd, by = by } end   -- the officers' message first
	out[#out + 1] = { kind = "level", level = level, into = into, need = need }
	out[#out + 1] = { kind = "challenge", text = ch.text, have = ch.have, goal = ch.goal, done = ch.done }
	-- now
	local now = {}
	for _, id in ipairs(ns.Help.List()) do
		local h = ns.Help.active[id]
		now[#now + 1] = { kind = "help", id = id, name = h.name, text = h.text, zone = h.mapId }
	end
	for _, adId in ipairs(ns.LFG.List()) do
		local a = ns.LFG.ads[adId]
		if a and a.name ~= me() then now[#now + 1] = { kind = "lfg", adId = adId, name = a.name, dungeon = a.d, roles = a.r } end
	end
	local today, nowMin = date("*t", time()), ns.Meetups.Now()
	for _, m in ipairs(ns.Meetups.List()) do
		local t = date("*t", m.at * 60)
		if m.at >= nowMin - 60 and t.year == today.year and t.month == today.month and t.day == today.day then now[#now + 1] = { kind = "meet", meet = m } end
	end
	section(out, "now", now)
	-- for me
	local mine, myMap, foryou = UnitLevel("player"), C_Map.GetBestMapForUnit("player"), {}
	local near = {}
	for _, name in ipairs(R.List()) do
		local m = R.mates[name]
		if math.abs((m.level or 0) - mine) <= HM.NEAR or (myMap and m.mapId == myMap) then near[#near + 1] = name end
	end
	table.sort(near, function(a, b) return math.abs(R.mates[a].level - mine) < math.abs(R.mates[b].level - mine) or (math.abs(R.mates[a].level - mine) == math.abs(R.mates[b].level - mine) and a < b) end)
	for i = 1, math.min(HM.MAX_MATES, #near) do foryou[#foryou + 1] = { kind = "mate", name = near[i] } end
	for _, g in ipairs(ns.Gifts.List()) do
		if not g.mine and not g.reservedBy and ns.Wishlist.Has(g.id) then foryou[#foryou + 1] = { kind = "gift", name = g.name, id = g.id, price = g.price } end
	end
	local due = ns.Trainer.Due()
	if #due > 0 then
		local names = {}
		for i = 1, math.min(4, #due) do names[i] = due[i].name end
		foryou[#foryou + 1] = { kind = "trainer", n = #due, names = table.concat(names, ", ") .. (#due > 4 and "…" or "") }
	end
	section(out, "foryou", foryou)
	-- this week
	local week, rk = {}, PT.Rankings()
	for _, cat in ipairs({ "l", "d", "h" }) do if #rk[cat] > 0 then week[#week + 1] = { kind = "rank", cat = cat, top = rk[cat] } end end
	section(out, "week", week)
	-- nobody seen: how to bring the guild in
	if #R.List() == 0 then out[#out + 1] = { kind = "invite" } end
	return out
end

function HM.InviteText()
	return string.format(L.HOME_INVITE_TEXT, GetGuildInfo("player") or "")
end
