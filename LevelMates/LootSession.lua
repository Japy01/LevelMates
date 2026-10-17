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

C.SCHEMA.ls = { s = C.V.word(16), m = C.V.oneOf("council", "dkp", "roll"), i = C.V.idlist(80), b = C.V.int(0, 100000) }; C.REQUIRED.ls = { "s", "m", "i" }
C.SCHEMA.lb = { s = C.V.word(16), i = C.V.int(1, 999999), r = C.V.oneOf("bis", "main", "minor", "pass", "bid", "roll"), v = C.V.int(0, 100000), n = C.V.text(60) }; C.REQUIRED.lb = { "s", "i", "r" }
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
-- Open a session for these items ({ id, link }) in the rules' mode; announced to the group.
function LS.Open(items)
	if not groupChannel() or not items or #items == 0 then return false end
	local rules = ns.LootRaid.Rules()
	local ids = {}
	for _, it in ipairs(items) do ids[#ids + 1] = tostring(it.id) end
	local id = string.format("s%x%x", time() % 1000000, math.random(0, 4095))
	LS.session = { id = id, mode = rules.mode, minBid = rules.minBid, items = ids, responses = {} }
	send("ls", { s = id, m = rules.mode, i = table.concat(ids, ","), b = rules.minBid })
	return id
end
-- An answer's words for the window: "main · para tanquear", "puja 25", "tira 100".
function LS.ResponseText(item, name)
	local s = LS.session
	local r = s and s.responses[item] and s.responses[item][name]
	if not r then return "" end
	local text
	if r.r == "bid" then text = string.format(L.LS_BID_OF, r.v or 0)
	elseif r.r == "roll" then text = string.format(L.LS_ROLL_OF, r.v or 100)
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
	LS.session = nil
	send("lc", { s = id })
end

------------------------------------------------------------------ the candidate's side
LS.offer = nil   -- the session on my screen: { id, from, mode, minBid, items = { id… }, mine = { [item] = answer }, given = { [item] = name } }
local function onSession(f, from)
	local items = {}
	for id in tostring(f.i):gmatch("%d+") do items[#items + 1] = tonumber(id) end
	if #items == 0 then return end
	LS.offer = { id = f.s, from = from, mode = f.m, minBid = tonumber(f.b) or 0, items = items, mine = {}, given = {} }
	ns.Fire("LM_LOOT_SESSION")
end
-- My answer, whispered to the master: r and, for a bid or a roll, the number. The minimum bid is kept.
function LS.Answer(item, r, v, note)
	local o = LS.offer
	if not o then return false end
	if r == "bid" then
		v = tonumber(v) or 0
		if v < (o.minBid or 0) then ns.Say(L.LS_MIN_BID, o.minBid or 0); return false, "min" end
	end
	o.mine[item] = { r = r, v = v, n = note }
	send("lb", { s = o.id, i = item, r = r, v = v or 0, n = note and note ~= "" and note:sub(1, 60) or nil }, o.from)
	ns.Fire("LM_LOOT_SESSION")
	return true
end

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
	if name == me() or not R.IsGuildmate(name) then return end
	if kind == "lb" then   -- an answer to my session
		local s = LS.session
		if not s or f.s ~= s.id then return end
		s.responses[f.i] = s.responses[f.i] or {}
		s.responses[f.i][name] = { r = f.r, v = tonumber(f.v) or 0, n = f.n, t = GetTime() }
		ns.Fire("LM_LOOT_SESSION")
	elseif kind == "ls" then onSession(f, name)
	elseif kind == "lw" then
		local o = LS.offer
		if o and f.s == o.id then o.given[f.i] = f.to; ns.Fire("LM_LOOT_SESSION") end
	elseif kind == "lc" then
		local o = LS.offer
		if o and f.s == o.id then LS.offer = nil; ns.Fire("LM_LOOT_SESSION") end
	end
end)
