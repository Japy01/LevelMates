-- RaidProbe.lua: /lm sondabanda. Inside an instance and out of combat, one test addon message over the group channel
-- (RAID or PARTY) and one whispered to myself: what the server answers (0 sent, 11 lockdown, 3/8 throttled), whether
-- each echo comes back, and what the client says about the lockdown. Said in chat and kept for /lm informe. Its
-- answer decides whether loot sessions can run live in a raid on Forever (spec 2026-10-16, decision 1): by guild the
-- message is blocked inside (measured); by group nobody has measured it. Nothing else depends on it until then.
local _, ns = ...
local P = {}
ns.RaidProbe = P
local L, C = ns.L, ns.Comm
P.MARK, P.WAIT = "LMPROBE", 5
local pending

local function store() ns.db.probes = ns.db.probes or {}; return ns.db.probes end

local function finish()
	if not pending then return end
	local r = pending.result
	pending = nil
	store().last = r
	local parts = {}
	for _, ch in ipairs({ r.group ~= "-" and r.group or nil, "WHISPER" }) do
		parts[#parts + 1] = ch .. ": " .. tostring(r.codes[ch]) .. (r.echo[ch] and " " .. L.PROBE_ECHO_YES or " " .. L.PROBE_ECHO_NO)
	end
	ns.Chat(L.PROBE_RESULT, table.concat(parts, " · "), r.lock and L.PROBE_LOCK_YES or L.PROBE_LOCK_NO)
end

function P.Run()
	if not (IsInInstance and ns.Plain(IsInInstance()) == true) then ns.Chat(L.PROBE_OUTSIDE); return false end
	if UnitAffectingCombat and UnitAffectingCombat("player") then ns.Chat(L.PROBE_COMBAT); return false end
	local group = (IsInRaid and IsInRaid()) and "RAID" or (IsInGroup and IsInGroup()) and "PARTY" or "-"
	local okL, lock = pcall(function() return C_ChatInfo.InChatMessagingLockdown and C_ChatInfo.InChatMessagingLockdown() end)
	local id = tostring(math.random(100000, 999999))
	local text = P.MARK .. ":" .. id
	local r = { t = time(), group = group, lock = okL and ns.Plain(lock) == true, codes = {}, echo = {}, v = tostring(ns.VERSION) }
	if group ~= "-" then r.codes[group] = ns.Plain(select(2, pcall(C_ChatInfo.SendAddonMessage, C.PREFIX, text, group))) or -1 end
	local me = ns.ShortName(ns.Me()):match("^([^%-]+)") or ns.Me()
	r.codes.WHISPER = ns.Plain(select(2, pcall(C_ChatInfo.SendAddonMessage, C.PREFIX, text, "WHISPER", me))) or -1
	pending = { id = id, result = r }
	ns.Chat(L.PROBE_SENT, group, tostring(r.codes[group] or "-"), tostring(r.codes.WHISPER), P.WAIT)
	C_Timer.After(P.WAIT, function() if pending and pending.id == id then finish() end end)
	return true
end

-- My own probe coming back on each channel (the comm layer ignores RAID/PARTY and my own echoes: this listens apart).
local ev = CreateFrame("Frame")
ev:RegisterEvent("CHAT_MSG_ADDON")
ev:SetScript("OnEvent", function(_, _, prefix, text, channel)
	if not pending or prefix ~= C.PREFIX then return end
	if issecretvalue and (issecretvalue(text) or issecretvalue(channel)) then return end
	if text == P.MARK .. ":" .. pending.id then pending.result.echo[channel] = true end
end)

-- For the report: the last probe in one line.
function P.Line()
	local r = store().last
	if not r then return nil end
	local parts = {}
	for ch, code in pairs(r.codes) do parts[#parts + 1] = ch .. "=" .. tostring(code) .. (r.echo[ch] and "+eco" or "") end
	table.sort(parts)
	return string.format("%s %s · %s · lock=%s · %s", date("%d/%m %H:%M", r.t), r.group, table.concat(parts, " "), tostring(r.lock), tostring(r.v))
end

ns.Slash("sondabanda", P.Run); ns.Slash("raidprobe", P.Run)
