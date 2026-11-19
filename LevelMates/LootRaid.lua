-- LootRaid.lua: capture in a raid, on an officer's client (spec 2026-10-16, decisions 2, 4, 8). A raid opens itself
-- at the first boss kill (or by /lm banda) and remembers who was there; each kill posts the boss points to everyone
-- present; master loot given from a click becomes an award delivered with strong proof, with the boss just killed
-- (an encounter is remembered five minutes: loot comes after it ends); a completed trade or the loot chat line
-- delivers a pending award; closing the raid posts the attendance. The rules (points, the quality recorded) are one
-- board record the officers write. Everything written here is a board record: inside the instance it waits for the
-- exit (the comm layer holds the loot book four hours). Nothing is sent to chat.
local _, ns = ...
local LR = {}
ns.LootRaid = LR
local L, C, R, S, LT = ns.L, ns.Comm, ns.Roster, ns.Sync, ns.Loot
LR.BOSS_MEMORY, LR.DUPLICATE_WINDOW = 300, 3600

local function me() return ns.Me() end
local function officer() return R.IAmOfficer() or R.IsOfficer(me()) end
local function inside() return IsInInstance and ns.Plain(IsInInstance()) == true end
local function itemOf(link) return link and tonumber(tostring(link):match("item:(%d+)")) end

------------------------------------------------------------------ the rules
S.Define("lru", { class = "board", life = 365 * 86400, writerOwns = true,
	fields = { bp = C.V.int(0, 1000), ap = C.V.int(0, 1000), mq = C.V.int(0, 6), mb = C.V.int(0, 100000), rl = C.V.int(0, 10), md = C.V.oneOf("council", "dkp", "roll") },
	accept = function(f, owner) return R.IsOfficer(owner) end,
	may = function(rec, who) return R.IsOfficer(who) or (who == me() and officer()) end,
	onChange = function() ns.Fire("LM_LOOT_CHANGED") end })
-- The extra rules (lote 1, 2026-10-18) in a record of their own, so clients that predate them keep the base rules:
-- the bid timer in seconds (0: none), who may answer (the guild only, or the whole raid), which council answers
-- are on (a comma list of bis, main, minor; pass is always there).
S.Define("lrx", { class = "board", life = 365 * 86400, writerOwns = true,
	fields = { tm = C.V.int(0, 600), sc = C.V.oneOf("guild", "raid"), rs = C.V.text(40), vr = C.V.oneOf("officers", "master", "all") },
	accept = function(f, owner) return R.IsOfficer(owner) end,
	may = function(rec, who) return R.IsOfficer(who) or (who == me() and officer()) end,
	onChange = function() ns.Fire("LM_LOOT_CHANGED") end })
LR.TIMERS, LR.RESPONSES, LR.QUALITIES = { 0, 60, 120, 180 }, { "bis", "main", "minor", "os", "tm" }, { 2, 3, 4 }
LR.VOTERS = { "officers", "master", "all" }
local IS_RESPONSE = { bis = true, main = true, minor = true, os = true, tm = true }
local function responseSet(text)
	local set, any = {}, false
	for word in tostring(text or ""):gmatch("%a+") do if IS_RESPONSE[word] then set[word] = true; any = true end end
	if not any then set = { bis = true, main = true, minor = true } end
	return set
end
-- boss and attendance points, the lowest quality recorded (3 blue), the minimum bid, reserves per person, the mode;
-- plus the extra: timer (s), scope, responses (a set)
function LR.Rules()
	local rec = S.Get("lru", "rules")
	local d = rec and rec.d or {}
	local x = S.Get("lrx", "rules")
	x = x and x.d or {}
	return { boss = d.bp or 0, att = d.ap or 0, quality = d.mq or 3, minBid = d.mb or 1, reserves = d.rl or 2, mode = d.md or "council",
		timer = x.tm or 0, scope = x.sc or "guild", responses = responseSet(x.rs), voters = x.vr or "officers" }
end
function LR.SetRules(r)
	if not officer() then ns.Say(L.LOOT_NOT_OFFICER); return false end
	local cur = LR.Rules()
	local extra = false
	for k, v in pairs(r or {}) do
		if k == "mode" then if v == "council" or v == "dkp" or v == "roll" then cur.mode = v end
		elseif k == "scope" then if v == "guild" or v == "raid" then cur.scope = v; extra = true end
		elseif k == "voters" then if v == "officers" or v == "master" or v == "all" then cur.voters = v; extra = true end
		elseif k == "responses" and type(v) == "table" then cur.responses = responseSet(table.concat((function() local t = {}; for _, w in ipairs(LR.RESPONSES) do if v[w] then t[#t + 1] = w end end; return t end)(), ",")); extra = true
		elseif k == "timer" and tonumber(v) then cur.timer = math.max(0, math.min(600, math.floor(tonumber(v)))); extra = true
		elseif cur[k] ~= nil and tonumber(v) then cur[k] = math.floor(tonumber(v)) end
	end
	local ok = S.Put("lru", "rules", { bp = cur.boss, ap = cur.att, mq = cur.quality, mb = cur.minBid, rl = cur.reserves, md = cur.mode }) and true or false
	if extra then
		local list = {}
		for _, w in ipairs(LR.RESPONSES) do if cur.responses[w] then list[#list + 1] = w end end
		ok = S.Put("lrx", "rules", { tm = cur.timer, sc = cur.scope, rs = table.concat(list, ","), vr = cur.voters }) and ok
	end
	return ok
end
-- The rules in sentences, for the page and for whoever asks.
function LR.RulesSummary()
	local r = LR.Rules()
	local out = { string.format(L.LOOT_RULE_MODE, L["LC_MODE_" .. r.mode] or r.mode) }
	if r.mode == "council" then
		local names = {}
		for _, w in ipairs(LR.RESPONSES) do if r.responses[w] then names[#names + 1] = L["LS_R_" .. w] end end
		out[#out + 1] = string.format(L.LOOT_RULE_RESPONSES, table.concat(names, ", "))
		out[#out + 1] = L["LOOT_RULE_VOTERS_" .. r.voters] or ""
	elseif r.mode == "dkp" then out[#out + 1] = string.format(L.LOOT_RULE_MINBID, r.minBid) end
	out[#out + 1] = string.format(L.LOOT_RULE_POINTS, r.boss, r.att)
	out[#out + 1] = string.format(L.LOOT_RULE_QUALITY, L["LOOT_QUALITY_" .. r.quality] or tostring(r.quality))
	out[#out + 1] = r.timer > 0 and string.format(L.LOOT_RULE_TIMER, r.timer) or L.LOOT_RULE_NO_TIMER
	out[#out + 1] = r.scope == "raid" and L.LOOT_RULE_SCOPE_RAID or L.LOOT_RULE_SCOPE_GUILD
	out[#out + 1] = string.format(L.LOOT_RULE_RESERVES, r.reserves)
	return table.concat(out, "\n")
end

------------------------------------------------------------------ the raid
-- Everyone in my group, me first, by their short names.
local function groupNames()
	local out, seen = {}, {}
	local function add(name)
		name = ns.Plain(name)
		if type(name) == "string" and name ~= "" then
			name = ns.ShortName(name)
			if not seen[name] then seen[name] = true; out[#out + 1] = name end
		end
	end
	add(me())
	local n = ns.Plain(GetNumGroupMembers and GetNumGroupMembers()) or 0
	local prefix = (IsInRaid and IsInRaid()) and "raid" or "party"
	for i = 1, n do add(UnitName(prefix .. i)) end
	return out
end
-- Observe encounters on every officer's client for loot history, but only the
-- native raid leader may write automated points. An unreadable API grants no authority.
local function isRaidLeader(unit)
	local okRaid, inRaid = pcall(IsInRaid)
	if not okRaid or ns.Plain(inRaid) ~= true then return false end
	local okLeader, leader = pcall(UnitIsGroupLeader, unit)
	return okLeader and ns.Plain(leader) == true
end

-- The open raid lives with the character (a /reload inside loses nothing).
local function raid() return ns.char.lootRaid end
LR.raid = nil
local function sync() LR.raid = ns.char.lootRaid end
function LR.Start()
	if raid() then sync(); return raid() end
	local okI, name = pcall(GetInstanceInfo)
	ns.char.lootRaid = { id = string.format("r%x%x", time() % 10000000, math.random(0, 255)), name = okI and ns.Plain(name) or "?", started = time(), bosses = {}, present = {} }
	for _, n in ipairs(groupNames()) do ns.char.lootRaid.present[n] = true end
	sync()
	ns.Fire("LM_LOOT_RAID")
	return raid()
end
-- Retain the original batch until all recipients have a ledger entry.
local function raidUnit(name)
	local n = ns.Plain(GetNumGroupMembers and GetNumGroupMembers()) or 0
	for i = 1, n do
		local unit = "raid" .. i
		local member = ns.Plain(UnitName(unit))
		if type(member) == "string" and ns.ShortName(member) == name then return unit end
	end
end
local function validRecipients(value)
	return type(value) == "string" and #value > 0 and #value <= 1960 and not value:find("[%c|]")
end
C.SCHEMA.dka = { g = C.V.word(24), b = C.V.int(0, 10000), p = C.V.int(1, 100000),
	r = C.V.text(80), n = validRecipients }
C.REQUIRED.dka = { "g", "b", "p", "r", "n" }
C.SCHEMA.dkk = { g = C.V.word(24), b = C.V.int(0, 10000) }
C.REQUIRED.dkk = { "g", "b" }

local function operationId(raidId, boss)
	return raidId .. (boss == 0 and ":att" or (":boss:" .. boss))
end
local function delegate(award)
	if inside() then return end
	if award.nextAttempt and GetServerTime() < award.nextAttempt then return end
	local candidates = {}
	for _, member in ipairs(groupNames()) do
		if isRaidLeader("player") and member ~= ns.Me() and R.IsOfficer(member) and R.mates[member] then
			candidates[#candidates + 1] = member
		end
	end
	table.sort(candidates)
	if #candidates == 0 then
		for member in pairs(R.mates) do
			if member ~= ns.Me() and not raidUnit(member) and R.IsOfficer(member) then candidates[#candidates + 1] = member end
		end
		table.sort(candidates)
	end
	if #candidates == 0 then return end
	local index = (award.attempt or 0) % #candidates + 1
	local peer = candidates[index]
	award.attempt, award.nextAttempt = (award.attempt or 0) + 1, GetServerTime() + 30
	award.sentTo = award.sentTo or {}
	if C.SendBig("dka", { g = award.raid, b = award.boss, p = award.points,
		r = award.reason, n = table.concat(award.names, ",") }, "normal", peer, { hold = true }) then
		award.sentTo[peer] = true
	end
end

local REVIEW_LIFE = 86400
local function reviews()
	ns.char.lootAwardReviews = ns.char.lootAwardReviews or {}
	local byGuild = ns.char.lootAwardReviews
	local guild = ns.GuildKey()
	byGuild[guild] = byGuild[guild] or {}
	local inbox = byGuild[guild]
	local cutoff = GetServerTime() - REVIEW_LIFE
	for key, award in pairs(inbox) do if award.at < cutoff then inbox[key] = nil end end
	return inbox
end

local function applyDelegation(f, sender, names)
	local kind = f.b == 0 and "att" or "boss"
	if f.p ~= LR.Rules()[kind] then return false end
	local operation = operationId(f.g, f.b)
	if LT.PostAll(names, f.p, kind, f.r, { raid = f.g, operation = operation }) ~= #names then return false end
	C.Whisper("dkk", { g = f.g, b = f.b }, sender, "normal", { hold = true })
	return true
end

C.OnMessage("dka", function(f, sender, _, channel)
	if channel ~= "WHISPER" or not officer() or not R.IsGuildmate(sender) then return end
	local unit = raidUnit(sender)
	if unit and not isRaidLeader(unit) then return end
	local kind = f.b == 0 and "att" or "boss"
	if f.p ~= LR.Rules()[kind] then return end
	local names, seen = {}, {}
	for name in f.n:gmatch("[^,]+") do
		if #name > 48 or seen[name] or name:find("[%s%c|]") then return end
		if unit and kind == "boss" and not raidUnit(name) then return end
		seen[name] = true
		names[#names + 1] = name
	end
	if #names == 0 or #names > 40 or not seen[sender] then return end
	if unit then applyDelegation(f, sender, names); return end

	-- Outside the raid, the guild roster cannot prove that the sender is its leader.
	local inbox = reviews()
	local key = S.OwnerRecordId(sender .. ":" .. operationId(f.g, f.b))
	local existing = inbox[key]
	if existing then
		if existing.approved then C.Whisper("dkk", { g = f.g, b = f.b }, sender, "normal", { hold = true }) end
		return
	end
	local count = 0
	for _ in pairs(inbox) do count = count + 1 end
	if count >= 40 then return end
	inbox[key] = { sender = sender, fields = f, names = names, at = GetServerTime() }
	ns.Say(L.DKP_REVIEW_NEW, sender)
end)

ns.Slash("dkpreview", function(args)
	if not officer() then return end
	local inbox = reviews()
	local action, key = (args or ""):match("^(%S+)%s+(%S+)$")
	local award = key and inbox[key]
	if action == "approve" or action == "reject" then
		if not award then ns.Say(L.DKP_REVIEW_MISSING); return end
		if action == "reject" then award.rejected = true; return end
		if award.rejected or not R.IsGuildmate(award.sender) or not applyDelegation(award.fields, award.sender, award.names) then
			ns.Say(L.DKP_REVIEW_MISSING)
			return
		end
		award.approved = true
		return
	end
	for id, entry in pairs(inbox) do
		if not entry.rejected and not entry.approved then
			ns.Say(L.DKP_REVIEW_ENTRY, id, entry.sender, entry.fields.p, entry.fields.r, table.concat(entry.names, ", "))
		end
	end
	ns.Say(L.DKP_REVIEW_HELP)
end)

C.OnMessage("dkk", function(f, sender, _, channel)
	if channel ~= "WHISPER" or not R.IsOfficer(sender) then return end
	local pending = ns.char.lootAutomaticAwards
	local key = operationId(f.g, f.b)
	local award = pending and pending[key]
	if award and award.guild == ns.GuildKey() and award.sentTo and award.sentTo[sender] then
		pending[key] = nil
	end
end)

local function retryAwards()
	local pending = ns.char.lootAutomaticAwards
	local guild = ns.GuildKey()
	for operation, award in pairs(pending or {}) do
		if award.guild == guild then
			if officer() then
				local posted = LT.PostAll(award.names, award.points, award.kind, award.reason,
					{ raid = award.raid, operation = operation })
				if posted == #award.names then pending[operation] = nil end
			elseif award.boss then
				delegate(award)
			end
		end
	end
end

local function awardOnce(raidId, boss, names, points, kind, reason)
	local operation = operationId(raidId, boss)
	ns.char.lootAutomaticAwards = ns.char.lootAutomaticAwards or {}
	local pending = ns.char.lootAutomaticAwards
	pending[operation] = pending[operation] or {
		guild = ns.GuildKey(), raid = raidId, boss = boss, names = names, points = points, kind = kind, reason = reason,
	}
	retryAwards()
end
ns.On("LM_HB_SENT", retryAwards)
ns.On("LM_ANNOUNCED", retryAwards)

-- Closing: the attendance to everyone seen, then the raid is gone.
function LR.Stop()
	local r = raid()
	if not r then return false end
	ns.char.lootRaid = nil; sync()
	local rules = LR.Rules()
	if rules.att > 0 and isRaidLeader("player") then
		local names = {}
		for n in pairs(r.present) do names[#names + 1] = n end
		table.sort(names)
		awardOnce(r.id, 0, names, rules.att, "att", string.format(L.LOOT_ATT_REASON, r.name or "?", date("%d/%m", r.started or time())))
	end
	ns.Fire("LM_LOOT_RAID")
	return true
end

------------------------------------------------------------------ a boss kill
local lastBoss
local function onEncounterEnd(id, name, _, _, success)
	id, name, success = ns.Plain(id), ns.Plain(name), ns.Plain(success)
	if success ~= 1 or (not officer() and not isRaidLeader("player")) or not inside() then return end
	local r = LR.Start()
	local names = groupNames()
	for _, n in ipairs(names) do r.present[n] = true end
	r.bosses[#r.bosses + 1] = { id = id, name = name, t = time(), n = #names }
	lastBoss = { id = id, name = name, t = GetTime() }
	local rules = LR.Rules()
	if rules.boss > 0 and isRaidLeader("player") then awardOnce(r.id, #r.bosses, names, rules.boss, "boss", tostring(name or id or "?")) end
	ns.Fire("LM_LOOT_RAID")
end
local function bossNow()
	if lastBoss and GetTime() - lastBoss.t < LR.BOSS_MEMORY then return lastBoss end
end
function LR.BossNow() return bossNow() end
function LR.GroupNames() return groupNames() end
-- The cost the master looter's window set for a slot before giving it (LootWindow): the award carries it.
local nextCost = {}
function LR.NextCost(slot, cost) nextCost[slot] = cost end

------------------------------------------------------------------ master loot
local slots, given, recorded, hooked = {}, {}, {}, false
local function hookGive()   -- GiveMasterLoot runs from the game's own click; its arguments say who got which slot
	if hooked or not GiveMasterLoot or not hooksecurefunc then return end
	hooked = true
	hooksecurefunc("GiveMasterLoot", function(slot, index)
		local ok, name = pcall(GetMasterLootCandidate, slot, index)
		given[ns.Plain(slot) or 0] = ok and ns.Plain(name) or nil
	end)
end
local function readSlots()
	slots = {}
	local n = ns.Plain(GetNumLootItems and GetNumLootItems()) or 0
	for i = 1, n do
		local okL, link = pcall(GetLootSlotLink, i)
		local okQ, _, _, _, _, quality = pcall(GetLootSlotInfo, i)
		local okG, guid = pcall(function() return GetLootSourceInfo and (GetLootSourceInfo(i)) end)
		guid = okG and ns.Plain(guid) or nil
		slots[i] = { id = okL and itemOf(ns.Plain(link)), quality = okQ and ns.Plain(quality) or 0, guid = guid,
			npc = guid and tostring(guid):match("^Creature%-%d+%-%d+%-%d+%-%d+%-(%d+)") }
	end
end
local function onSlotCleared(slot)
	slot = ns.Plain(slot)
	local s, to = slot and slots[slot], slot and given[slot]
	if slot then given[slot] = nil end
	if not (s and s.id and to and officer()) then return end
	if (s.quality or 0) < LR.Rules().quality then return end
	local key = tostring(s.guid or "?") .. ":" .. slot .. ":" .. s.id   -- the same corpse opened again is not a new drop
	if recorded[key] and GetTime() - recorded[key] < LR.DUPLICATE_WINDOW then return end
	recorded[key] = GetTime()
	local boss = bossNow()
	local r = raid()
	local cost = nextCost[slot]; nextCost[slot] = nil
	local id = LT.Award(s.id, ns.ShortName(to), { boss = boss and boss.name, enc = boss and boss.id, proof = "ml", cost = cost, raid = r and r.id })
	if id then LT.Confirm(id, "ml"); if ns.LootSession then ns.LootSession.Awarded(s.id, ns.ShortName(to), cost) end end
end

------------------------------------------------------------------ a trade, the chat line
local trade
local function pendingTo(name, itemId)
	for _, a in ipairs(LT.History()) do
		if a.s == "aw" and a.i == itemId and ns.Same(a.to, name) then return a.id end
	end
end
local function onTradeAccept(player, target)
	if not trade or ns.Plain(player) ~= 1 or ns.Plain(target) ~= 1 or not officer() then return end
	local partner = trade.partner and ns.ShortName(trade.partner)
	if not partner then return end
	for i = 1, 6 do
		local okL, link = pcall(function() return GetTradePlayerItemLink and GetTradePlayerItemLink(i) end)
		local id = okL and itemOf(ns.Plain(link))
		local aw = id and pendingTo(partner, id)
		if aw then LT.Confirm(aw, "trade") end
	end
end
-- The game's own loot line as a pattern ("%s receives loot: %s."); Forever's line has no trailing period.
local function patternOf(tpl)
	local p = tostring(tpl):gsub("([%(%)%.%+%-%*%?%[%]%^%$])", "%%%1")
	p = p:gsub("%%s", "(.-)"):gsub("%%d", "(%%d+)")
	p = p:gsub("%%%.$", "%%.?")
	return "^" .. p .. "$"
end
local function onChatLoot(text, sender, ...)
	local guid = select(10, ...)
	if issecretvalue and (issecretvalue(text) or issecretvalue(sender) or issecretvalue(guid)) then return end
	if type(text) ~= "string" or not officer() then return end
	local name, link
	local templates = {}   -- the one with a count first: the other would swallow it; a missing one leaves no hole
	for _, tpl in ipairs({ "LOOT_ITEM_MULTIPLE", "LOOT_ITEM" }) do if type(_G[tpl]) == "string" then templates[#templates + 1] = _G[tpl] end end
	for _, tpl in ipairs(templates) do
		name, link = text:match(patternOf(tpl))
		if name then break end
	end
	local id = itemOf(link)
	if not (name and id) then return end
	local aw = pendingTo(ns.ShortName(name), id)
	if aw then LT.Confirm(aw, "chat") end
end

------------------------------------------------------------------ the hand-over reminder
-- An award still "awarded" to someone else whose item sits in my bags: said once a session (a notice), so it is not
-- forgotten in a bag. Checked a moment after the bags change.
local reminded, bagCheck = {}, nil
local function bagsHave()
	local have = {}
	if not (C_Container and C_Container.GetContainerNumSlots and C_Container.GetContainerItemInfo) then return have end
	for bag = 0, 4 do
		for slot = 1, ns.Plain(C_Container.GetContainerNumSlots(bag)) or 0 do
			local info = ns.Plain(C_Container.GetContainerItemInfo(bag, slot))
			local id = type(info) == "table" and ns.Plain(info.itemID)
			if id then have[id] = true end
		end
	end
	return have
end
-- Awards still to deliver, with whether the item sits in my bags (and where).
function LR.Pending()
	local out, have = {}, {}
	if C_Container and C_Container.GetContainerNumSlots and C_Container.GetContainerItemInfo then
		for bag = 0, 4 do
			for slot = 1, ns.Plain(C_Container.GetContainerNumSlots(bag)) or 0 do
				local info = ns.Plain(C_Container.GetContainerItemInfo(bag, slot))
				local id = type(info) == "table" and ns.Plain(info.itemID)
				if id and not have[id] then have[id] = { bag = bag, slot = slot } end
			end
		end
	end
	for _, a in ipairs(LT.History()) do
		if a.s == "aw" then out[#out + 1] = { id = a.id, i = a.i, to = a.to, inBags = have[a.i] ~= nil, bag = have[a.i] and have[a.i].bag, slot = have[a.i] and have[a.i].slot } end
	end
	return out
end
-- The trade window opened with someone I owe an item: the item goes from my bag into the trade (the game may
-- refuse it on Forever; then the notice already said what to hand over).
function LR.FillTrade(partner)
	if not partner or not (C_Container and C_Container.PickupContainerItem and ClickTradeButton) then return 0 end
	local n = 0
	for _, p in ipairs(LR.Pending()) do
		if p.inBags and ns.Same(p.to, partner) and n < 6 then
			n = n + 1
			local slot = n
			C_Timer.After(0.3 * n, function() pcall(C_Container.PickupContainerItem, p.bag, p.slot); pcall(ClickTradeButton, slot) end)
		end
	end
	return n
end
function LR.CheckHandover()
	local have
	for _, a in ipairs(LT.History()) do
		if a.s == "aw" and a.to ~= me() and not reminded[a.id] then
			have = have or bagsHave()
			if have[a.i] then reminded[a.id] = true; ns.Notice(L.LOOT_HANDOVER, ns.Recipes.Link(a.i), a.to) end
		end
	end
end
local function handoverSoon()
	bagCheck = GetTime() + 1
	C_Timer.After(1.05, function() if bagCheck and GetTime() >= bagCheck then bagCheck = nil; LR.CheckHandover() end end)
end

------------------------------------------------------------------ events, commands
local ev = CreateFrame("Frame")
for _, e in ipairs({ "ENCOUNTER_END", "LOOT_OPENED", "LOOT_SLOT_CLEARED", "LOOT_CLOSED", "TRADE_SHOW", "TRADE_ACCEPT_UPDATE", "TRADE_CLOSED", "CHAT_MSG_LOOT", "GROUP_ROSTER_UPDATE", "BAG_UPDATE_DELAYED" }) do ev:RegisterEvent(e) end
ev:SetScript("OnEvent", function(_, event, ...)
	if not ns.db then return end
	if event == "ENCOUNTER_END" then onEncounterEnd(...)
	elseif event == "LOOT_OPENED" then hookGive(); readSlots()
	elseif event == "LOOT_SLOT_CLEARED" then onSlotCleared(...)
	elseif event == "LOOT_CLOSED" then slots = {}
	elseif event == "TRADE_SHOW" then trade = { partner = ns.Plain(UnitName("NPC")) }; if officer() and trade.partner then LR.FillTrade(ns.ShortName(trade.partner)) end
	elseif event == "TRADE_ACCEPT_UPDATE" then onTradeAccept(...)
	elseif event == "TRADE_CLOSED" then trade = nil
	elseif event == "CHAT_MSG_LOOT" then onChatLoot(...)
	elseif event == "BAG_UPDATE_DELAYED" then handoverSoon()
	elseif event == "GROUP_ROSTER_UPDATE" then   -- the group dissolved outside: the raid is over
		if raid() and not inside() and (ns.Plain(GetNumGroupMembers and GetNumGroupMembers()) or 0) == 0 then LR.Stop() end
	end
end)
ns.On("LM_LOADED", sync)
-- /lm banda: open or close the raid by hand (the attendance goes on closing).
ns.Slash("banda", function()
	if not officer() then ns.Chat(L.LOOT_NOT_OFFICER); return end
	if raid() then LR.Stop(); ns.Chat(L.LOOT_RAID_STOPPED) else LR.Start(); ns.Chat(L.LOOT_RAID_STARTED, raid().name) end
end)
-- /lm botinmodo council|dkp|roll: how the live session asks.
ns.Slash("botinmodo", function(rest)
	local m = strtrim(tostring(rest or "")):lower()
	if m ~= "council" and m ~= "dkp" and m ~= "roll" then ns.Chat(L.LOOT_MODE_HELP, LR.Rules().mode); return end
	if LR.SetRules({ mode = m }) then ns.Chat(L.LOOT_MODE_SET, m) end
end)
-- /lm botinreglas <jefe> <asistencia> [calidad]: the points.
ns.Slash("botinreglas", function(rest)
	local b, a, q = tostring(rest or ""):match("^%s*(%d+)%s+(%d+)%s*(%d*)")
	if not b then ns.Chat(L.LOOT_RULES_HELP, LR.Rules().boss, LR.Rules().att, LR.Rules().quality); return end
	if LR.SetRules({ boss = b, att = a, quality = q ~= "" and q or nil }) then ns.Chat(L.LOOT_RULES_SET, LR.Rules().boss, LR.Rules().att, LR.Rules().quality) end
end)
