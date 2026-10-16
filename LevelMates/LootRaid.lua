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
	fields = { bp = C.V.int(0, 1000), ap = C.V.int(0, 1000), mq = C.V.int(0, 6), mb = C.V.int(0, 100000), rl = C.V.int(0, 10) },
	accept = function(f, owner) return R.IsOfficer(owner) end,
	may = function(rec, who) return R.IsOfficer(who) or (who == me() and officer()) end,
	onChange = function() ns.Fire("LM_LOOT_CHANGED") end })
-- boss and attendance points, the lowest quality recorded (3 blue), the minimum bid, reserves per person
function LR.Rules()
	local rec = S.Get("lru", "rules")
	local d = rec and rec.d or {}
	return { boss = d.bp or 0, att = d.ap or 0, quality = d.mq or 3, minBid = d.mb or 1, reserves = d.rl or 2 }
end
function LR.SetRules(r)
	if not officer() then ns.Say(L.LOOT_NOT_OFFICER); return false end
	local cur = LR.Rules()
	for k, v in pairs(r or {}) do if cur[k] ~= nil and tonumber(v) then cur[k] = math.floor(tonumber(v)) end end
	return S.Put("lru", "rules", { bp = cur.boss, ap = cur.att, mq = cur.quality, mb = cur.minBid, rl = cur.reserves }) and true or false
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
-- Closing: the attendance to everyone seen, then the raid is gone.
function LR.Stop()
	local r = raid()
	if not r then return false end
	ns.char.lootRaid = nil; sync()
	local rules = LR.Rules()
	if rules.att > 0 and officer() then
		local names = {}
		for n in pairs(r.present) do names[#names + 1] = n end
		table.sort(names)
		LT.PostAll(names, rules.att, "att", string.format(L.LOOT_ATT_REASON, r.name or "?", date("%d/%m", r.started or time())), { raid = r.id })
	end
	ns.Fire("LM_LOOT_RAID")
	return true
end

------------------------------------------------------------------ a boss kill
local lastBoss
local function onEncounterEnd(id, name, _, _, success)
	id, name, success = ns.Plain(id), ns.Plain(name), ns.Plain(success)
	if success ~= 1 or not officer() or not inside() then return end
	local r = LR.Start()
	local names = groupNames()
	for _, n in ipairs(names) do r.present[n] = true end
	r.bosses[#r.bosses + 1] = { id = id, name = name, t = time(), n = #names }
	lastBoss = { id = id, name = name, t = GetTime() }
	local rules = LR.Rules()
	if rules.boss > 0 then LT.PostAll(names, rules.boss, "boss", tostring(name or id or "?"), { raid = r.id }) end
	ns.Fire("LM_LOOT_RAID")
end
local function bossNow()
	if lastBoss and GetTime() - lastBoss.t < LR.BOSS_MEMORY then return lastBoss end
end

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
	local id = LT.Award(s.id, ns.ShortName(to), { boss = boss and boss.name, enc = boss and boss.id, proof = "ml", raid = r and r.id })
	if id then LT.Confirm(id, "ml") end
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

------------------------------------------------------------------ events, commands
local ev = CreateFrame("Frame")
for _, e in ipairs({ "ENCOUNTER_END", "LOOT_OPENED", "LOOT_SLOT_CLEARED", "LOOT_CLOSED", "TRADE_SHOW", "TRADE_ACCEPT_UPDATE", "TRADE_CLOSED", "CHAT_MSG_LOOT", "GROUP_ROSTER_UPDATE" }) do ev:RegisterEvent(e) end
ev:SetScript("OnEvent", function(_, event, ...)
	if not ns.db then return end
	if event == "ENCOUNTER_END" then onEncounterEnd(...)
	elseif event == "LOOT_OPENED" then hookGive(); readSlots()
	elseif event == "LOOT_SLOT_CLEARED" then onSlotCleared(...)
	elseif event == "LOOT_CLOSED" then slots = {}
	elseif event == "TRADE_SHOW" then trade = { partner = ns.Plain(UnitName("NPC")) }
	elseif event == "TRADE_ACCEPT_UPDATE" then onTradeAccept(...)
	elseif event == "TRADE_CLOSED" then trade = nil
	elseif event == "CHAT_MSG_LOOT" then onChatLoot(...)
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
-- /lm botinreglas <jefe> <asistencia> [calidad]: the points.
ns.Slash("botinreglas", function(rest)
	local b, a, q = tostring(rest or ""):match("^%s*(%d+)%s+(%d+)%s*(%d*)")
	if not b then ns.Chat(L.LOOT_RULES_HELP, LR.Rules().boss, LR.Rules().att, LR.Rules().quality); return end
	if LR.SetRules({ boss = b, att = a, quality = q ~= "" and q or nil }) then ns.Chat(L.LOOT_RULES_SET, LR.Rules().boss, LR.Rules().att, LR.Rules().quality) end
end)
