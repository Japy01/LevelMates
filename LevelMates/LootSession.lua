-- LootSession.lua: a live loot session over the group channel (spec 2026-10-16, decision 5; measured the same day:
-- inside an instance PARTY/RAID and WHISPER addon messages pass, only GUILD is blocked). The master looter's client
-- announces the corpse's items and the mode (ls); each candidate answers by whisper (lb: main, minor, bis, pass, a
-- sealed bid, a roll); the master's window shows the answers; the award (lw) and the close (lc) go to the group.
-- Messages are sent as they come; the server's "lockdown" answer (11) holds them and tries again every 30 s for
-- ten minutes (a boss fight drops them silently: loot comes after). Only guildmates are heard. Nothing is chat.
local _, ns = ...
local LS = {}
ns.LootSession = LS
local L, C, R = ns.L, ns.Comm, ns.Roster
LS.RETRY, LS.HOLD = 30, 600
LS.MODES = { council = true, dkp = true, roll = true }

C.SCHEMA.ls = { s = C.V.word(16), m = C.V.oneOf("council", "dkp", "roll"), i = C.V.idlist(80), b = C.V.int(0, 100000), t = C.V.int(0, 600) }; C.REQUIRED.ls = { "s", "m", "i" }
C.SCHEMA.lb = { s = C.V.word(16), i = C.V.int(1, 999999), r = C.V.oneOf("bis", "main", "minor", "pass", "bid", "roll"), v = C.V.int(0, 100000), n = C.V.text(60), m = C.V.int(0, 100) }; C.REQUIRED.lb = { "s", "i", "r" }
LS.KEEP = 4 * 3600   -- a session or an offer saved for a reload lives this long
C.SCHEMA.lw = { s = C.V.word(16), i = C.V.int(1, 999999), to = C.V.text(48), c = C.V.int(0, 100000) }; C.REQUIRED.lw = { "s", "i", "to" }
C.SCHEMA.lc = { s = C.V.word(16) }; C.REQUIRED.lc = { "s" }

local function me() return ns.Me() end
local function groupChannel() if IsInRaid and IsInRaid() then return "RAID" elseif IsInGroup and IsInGroup() then return "PARTY" end end

------------------------------------------------------------------ sending, with the lockdown held
local queue = {}
local function push(text, channel, target)
	if #queue >= 50 then table.remove(queue, 1) end
	queue[#queue + 1] = { text = text, channel = channel, target = target, at = GetTime() }
end
local function trySend(item)
	local ok, code = pcall(C_ChatInfo.SendAddonMessage, C.PREFIX, item.text, item.channel, item.target)
	code = ok and ns.Plain(code) or -1
	return code
end
local retryAt
local function pump()
	retryAt = nil
	local keep = {}
	for _, item in ipairs(queue) do
		if GetTime() - item.at > LS.HOLD then   -- too old to matter
		else
			local code = trySend(item)
			if code == 0 then
			elseif code == 11 or code == 3 or code == 8 then keep[#keep + 1] = item
			end
		end
	end
	queue = keep
	if #queue > 0 then retryAt = GetTime() + LS.RETRY; C_Timer.After(LS.RETRY, function() if retryAt and GetTime() >= retryAt then pump() end end) end
end
-- To the group (no target) or to one person. False when there is no group to speak to.
local function send(kind, fields, target)
	local text = C.Encode(kind, fields)
	if not text then return false end
	local channel = target and "WHISPER" or groupChannel()
	if not channel then return false end
	push(text, channel, target and (ns.ShortName(target):match("^([^%-]+)") or target) or nil)
	pump()
	return true
end
LS.Send = send

------------------------------------------------------------------ the master's side
LS.session = nil
local function nowS() return GetServerTime() end
local function saveSession() if ns.char then ns.char.lootSession = LS.session end end
local function saveOffer() if ns.char then ns.char.lootOffer = LS.offer end end
-- Open a session for these items ({ id, link }) in the rules' mode, or add them to the one running (the same id,
-- announced again with every item; the time limit restarts). Announced to the group; the master's own card opens
-- too, so the master answers for their own drops.
function LS.Open(items)
	if not groupChannel() or not items or #items == 0 then return false end
	local rules = ns.LootRaid.Rules()
	local s = LS.session
	if not s then
		s = { id = string.format("s%x%x", time() % 1000000, math.random(0, 4095)), mode = rules.mode, minBid = rules.minBid, items = {}, responses = {}, openedAt = nowS() }
		LS.session = s
	end
	local have = {}
	for _, id in ipairs(s.items) do have[id] = true end
	for _, it in ipairs(items) do local id = tostring(it.id); if not have[id] then s.items[#s.items + 1] = id; have[id] = true end end
	s.deadline = (rules.timer or 0) > 0 and (nowS() + rules.timer) or nil
	send("ls", { s = s.id, m = s.mode, i = table.concat(s.items, ","), b = s.minBid, t = rules.timer or 0 })
	LS.OfferFrom(s.id, me(), s.mode, s.minBid, s.items, rules.timer)
	saveSession()
	ns.Fire("LM_LOOT_SESSION")
	return s.id
end
-- Seconds left to answer (the master's session), nil without a limit.
function LS.Left() local s = LS.session; if not (s and s.deadline) then return nil end; return s.deadline - nowS() end
-- Back from a reload: the session and the offer saved in this character, while they are fresh.
function LS.Restore()
	local c = ns.char
	if not c then return end
	if c.lootSession and (nowS() - (c.lootSession.openedAt or 0)) < LS.KEEP then LS.session = c.lootSession else c.lootSession = nil end
	if c.lootOffer and (nowS() - (c.lootOffer.at or 0)) < LS.KEEP then LS.offer = c.lootOffer else c.lootOffer = nil end
	if LS.session or LS.offer then ns.Fire("LM_LOOT_SESSION") end
end
ns.On("LM_WORLD", function() LS.Restore() end)
-- How a candidate's answer ranks for the window: BiS, main, minor, bids (high first), rolls (high first), the
-- silent, passes last. Returns the rank and the number (bid or roll) for ties.
local RANK = { bis = 1, main = 2, minor = 3, bid = 4, roll = 5, pass = 7 }
LS.SILENT_RANK = 6
function LS.Rank(item, name)
	local s = LS.session
	local r = s and s.responses[item] and s.responses[item][name]
	if not r then return LS.SILENT_RANK, 0 end
	if r.r == "roll" then return RANK.roll, (r.m or 100) * 1000 + (r.v or 0) end   -- the range first (100 beats 50), then the number
	return RANK[r.r] or LS.SILENT_RANK, r.v or 0
end
-- How many of the names answered for the item.
function LS.Answered(item, names)
	local s, n = LS.session, 0
	local got = s and s.responses[item]
	if got then for _, name in ipairs(names) do if got[name] then n = n + 1 end end end
	return n
end
-- Seconds since the session opened, or nil.
function LS.Elapsed() return LS.session and LS.session.openedAt and math.max(0, nowS() - LS.session.openedAt) or nil end
-- An answer's words for the window: "main · para tanquear", "puja 25", "tira 100".
function LS.ResponseText(item, name)
	local s = LS.session
	local r = s and s.responses[item] and s.responses[item][name]
	if not r then return "" end
	local text
	if r.r == "bid" then text = string.format(L.LS_BID_OF, r.v or 0)
	elseif r.r == "roll" then text = string.format(L.LS_ROLL_OF, r.v or 0, r.m or 100)
	else text = L["LS_R_" .. r.r] or r.r end
	if r.n and r.n ~= "" then text = text .. " · " .. r.n end
	return text
end
function LS.Awarded(item, to, cost)
	if not LS.session then return end
	send("lw", { s = LS.session.id, i = item, to = to, c = cost or 0 })
end
function LS.Close()
	if not LS.session then return end
	local id = LS.session.id
	LS.session = nil; saveSession()
	if LS.offer and LS.offer.id == id then LS.offer = nil; saveOffer() end
	send("lc", { s = id })
	ns.Fire("LM_LOOT_SESSION")
end

------------------------------------------------------------------ the candidate's side
LS.offer = nil   -- the session on my screen: { id, from, mode, minBid, items = { id… }, mine = { [item] = answer }, given = { [item] = name }, deadline, at }
-- A session offered to me (or my own, as the master): new, or the same one with more items (answers kept).
function LS.OfferFrom(id, from, mode, minBid, itemIds, timer)
	local items = {}
	for _, v in ipairs(itemIds or {}) do local n = tonumber(v); if n then items[#items + 1] = n end end
	if #items == 0 then return end
	local o = LS.offer
	if o and o.id == id then
		local have = {}
		for _, i in ipairs(o.items) do have[i] = true end
		for _, i in ipairs(items) do if not have[i] then o.items[#o.items + 1] = i end end
		o.mode, o.minBid = mode, minBid
	else
		o = { id = id, from = from, mode = mode, minBid = minBid, items = items, mine = {}, given = {}, at = nowS() }
		LS.offer = o
	end
	o.deadline = (tonumber(timer) or 0) > 0 and (nowS() + tonumber(timer)) or nil
	saveOffer()
	ns.Fire("LM_LOOT_SESSION")
end
local function onSession(f, from)
	local ids = {}
	for id in tostring(f.i):gmatch("%d+") do ids[#ids + 1] = id end
	LS.OfferFrom(f.s, from, f.m, tonumber(f.b) or 0, ids, f.t)
end
-- Seconds left to answer the offer on my screen, nil without a limit.
function LS.OfferLeft() local o = LS.offer; if not (o and o.deadline) then return nil end; return o.deadline - nowS() end
-- My answer: r and, for a bid or a roll, the number (and the roll's range). Whispered to the master; the master's
-- own answer goes straight into the session. The minimum bid is kept.
function LS.Answer(item, r, v, note, max)
	local o = LS.offer
	if not o then return false end
	if r == "bid" then
		v = tonumber(v) or 0
		if v < (o.minBid or 0) then ns.Say(L.LS_MIN_BID, o.minBid or 0); return false, "min" end
	end
	o.mine[item] = { r = r, v = v, n = note, m = max }
	local s = LS.session
	if o.from == me() and s and s.id == o.id then
		s.responses[item] = s.responses[item] or {}
		s.responses[item][me()] = { r = r, v = v or 0, n = note, m = max, t = GetTime() }
		saveSession()
	else
		send("lb", { s = o.id, i = item, r = r, v = v or 0, n = note and note ~= "" and note:sub(1, 60) or nil, m = max }, o.from)
	end
	saveOffer()
	ns.Fire("LM_LOOT_SESSION")
	return true
end
-- Pass on every item I have not answered yet.
function LS.PassRest()
	local o = LS.offer
	if not o then return 0 end
	local n = 0
	for _, item in ipairs(o.items) do if not o.mine[item] and not o.given[item] then LS.Answer(item, "pass"); n = n + 1 end end
	return n
end

------------------------------------------------------------------ real rolls
-- The roll is the game's own (/roll from the click); the number comes back on the game's own line and goes to
-- the master with its range (100, 50 or 25), so a 100 roll beats a 50 roll whatever the numbers.
local pendingRoll, rollPattern
local function rollPatternOf()
	if rollPattern then return rollPattern end
	local fmt = RANDOM_ROLL_RESULT or "%s rolls %d (%d-%d)"
	local escaped = fmt:gsub("[%(%)%.%+%-%*%?%[%]%^%$]", function(c) return "%" .. c end)
	rollPattern = "^" .. escaped:gsub("%%s", "(.+)"):gsub("%%d", "(%%d+)") .. "$"
	return rollPattern
end
function LS.StartRoll(item, max)
	if not LS.offer then return false end
	pendingRoll = { item = item, max = max, at = GetTime() }
	if RandomRoll then pcall(RandomRoll, 1, max) end
	ns.Fire("LM_LOOT_SESSION")
	return true
end
function LS.RollPending(item) return pendingRoll and pendingRoll.item == item and GetTime() - pendingRoll.at < 30 end
local sys = CreateFrame("Frame")
sys:RegisterEvent("CHAT_MSG_SYSTEM")
sys:SetScript("OnEvent", function(_, _, text)
	if not pendingRoll or GetTime() - pendingRoll.at > 30 then pendingRoll = nil; return end
	text = ns.Plain(text)
	if type(text) ~= "string" then return end
	local who, v, lo, hi = text:match(rollPatternOf())
	if not who or ns.ShortName(who) ~= me() or tonumber(hi) ~= pendingRoll.max then return end
	local p = pendingRoll
	pendingRoll = nil
	LS.Answer(p.item, "roll", tonumber(v), nil, tonumber(hi))
end)

------------------------------------------------------------------ hearing the group
local ev = CreateFrame("Frame")
ev:RegisterEvent("CHAT_MSG_ADDON")
ev:SetScript("OnEvent", function(_, _, prefix, text, channel, sender)
	if prefix ~= C.PREFIX or not ns.db then return end
	if issecretvalue and (issecretvalue(text) or issecretvalue(channel) or issecretvalue(sender)) then return end
	if channel ~= "PARTY" and channel ~= "RAID" and channel ~= "WHISPER" then return end
	local kind, f = C.Decode(text)
	if not kind or (kind ~= "ls" and kind ~= "lb" and kind ~= "lw" and kind ~= "lc") then return end
	local name = ns.ShortName(sender)
	if name == me() then return end
	local inGroup = false
	for _, g in ipairs(ns.LootRaid.GroupNames()) do if g == name then inGroup = true; break end end
	if not R.IsGuildmate(name) and not (inGroup and ns.LootRaid.Rules().scope == "raid") then return end   -- the rules may let the whole raid in
	if kind == "lb" then   -- an answer to my session
		local s = LS.session
		if not s or f.s ~= s.id then return end
		if s.deadline and nowS() > s.deadline + 3 then return end   -- late: not counted (the rules said so)
		s.responses[f.i] = s.responses[f.i] or {}
		s.responses[f.i][name] = { r = f.r, v = tonumber(f.v) or 0, n = f.n, m = tonumber(f.m), t = GetTime() }
		saveSession()
		ns.Fire("LM_LOOT_SESSION")
	elseif kind == "ls" then onSession(f, name)
	elseif kind == "lw" then
		local o = LS.offer
		if o and f.s == o.id then o.given[f.i] = f.to; saveOffer(); ns.Fire("LM_LOOT_SESSION") end
	elseif kind == "lc" then
		local o = LS.offer
		if o and f.s == o.id then LS.offer = nil; saveOffer(); ns.Fire("LM_LOOT_SESSION") end
	end
end)
