-- Partner.lua: "looking for a leveling partner". Ticking the box is a click; the only automatic change is turning
-- it off when you group with someone who was also looking. Spec 2026-10-09-levelmates-partner-design.
-- The flag travels in its own message kind `pal`: older versions reject an hb with an unknown field.
local _, ns = ...
local P = {}
ns.Partner = P
local L, C, R = ns.L, ns.Comm, ns.Roster
local RANGE = 3
local marked = {}     -- name -> true: guildmates whose last pal said p=1
local notified = {}   -- name -> true: already announced this session
local REFRESH = 80    -- re-send my mark with a heartbeat at most this often (others forget me after an instance)
local lastPalAt = -math.huge
local dirty = false   -- the guild may not know my current state (a send was refused, e.g. inside an instance)

-- Every pal goes through here so a refused send (instance, lockdown) is retried with the next heartbeat.
local function sendPal(p, prio)
	if C.Send("pal", { p = p }, prio) then lastPalAt = GetTime(); dirty = false; return true end
	dirty = true
	return false
end

function P.IsOn() return ns.char ~= nil and ns.char.lookingPartner == true end
function P.Marked(name) return marked[name] == true end
function P.Matches(name)
	local m = R.mates[name]
	return P.IsOn() and marked[name] == true and m ~= nil and math.abs((m.level or 0) - UnitLevel("player")) <= RANGE
end

local function zoneName(m)
	local info = m.mapId and C_Map.GetMapInfo and C_Map.GetMapInfo(m.mapId)
	return info and info.name or L.UNKNOWN_ZONE
end

-- Forget marks of people the roster no longer has, then announce new matches once.
local function recompute()
	for name in pairs(marked) do if not R.mates[name] then marked[name] = nil end end
	if not P.IsOn() then return end
	for name in pairs(marked) do
		if not notified[name] and P.Matches(name) and ns.db.settings.palNotices then
			notified[name] = true
			local m = R.mates[name]
			ns.Notice(L.PAL_NOTICE, name, m.level, zoneName(m))
		end
	end
end

-- Called from a click (the board check box). Returns false when turning on is refused.
function P.SetOn(on)
	if on and not C.IsReady() then ns.Say(L.HELP_NEEDS_SHARE); return false end
	ns.char.lookingPartner = on and true or false
	if C.IsReady() then sendPal(on and 1 or 0, "now") end
	recompute()
	ns.Fire("LM_PARTNER_CHANGED")
	return true
end

C.OnMessage("pal", function(f, name)
	if not R.mates[name] then return end   -- only people the roster knows
	marked[name] = f.p == 1 or nil
	recompute()
	ns.Fire("LM_PARTNER_CHANGED")
end)

-- Re-announce my flag after the roster's own announce (login, reload, transport restart) and to newcomers,
-- right after my heartbeat, so they already know me.
local function announceMine()
	if P.IsOn() and lastPalAt ~= GetTime() then sendPal(1) end   -- skip if a heartbeat already carried it this instant
end
ns.On("LM_ANNOUNCED", announceMine)
ns.On("LM_PING_ANSWERED", announceMine)
-- After any heartbeat: refresh my mark now and then (people who expired me while I was in an instance get it back),
-- and retry a state the guild may have missed.
ns.On("LM_HB_SENT", function()
	if P.IsOn() then
		if dirty or GetTime() - lastPalAt >= REFRESH then sendPal(1) end
	elseif dirty then
		sendPal(0)
	end
end)
ns.On("LM_ROSTER_CHANGED", recompute)

-- Sharing off: say "no longer looking" while we still can; forget everyone else's marks.
ns.On("LM_COMM_STOPPING", function() if P.IsOn() then C.SendImmediate("pal", { p = 0 }) end end)
ns.On("LM_COMM_STOPPED", function() wipe(marked); wipe(notified); ns.Fire("LM_PARTNER_CHANGED") end)

-- Found a partner: grouping with someone who was looking turns mine off.
local groupFrame = CreateFrame("Frame")
groupFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
groupFrame:SetScript("OnEvent", function()
	if not P.IsOn() then return end
	for name in pairs(marked) do
		if UnitInParty(name) or UnitInRaid(name) then
			ns.char.lookingPartner = false
			sendPal(0, "now")
			ns.Say(L.PAL_FOUND, name)
			ns.Fire("LM_PARTNER_CHANGED")
			return
		end
	end
end)
