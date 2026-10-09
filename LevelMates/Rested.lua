-- Rested.lua: my rested XP (percent of a level), the cap notice, and opt-in sharing with the guild.
-- The value travels in its own kind `rx` (-1 = no longer sharing): older versions reject an hb with an unknown field.
local _, ns = ...
local X = {}
ns.Rested = X
local L, C, R = ns.L, ns.Comm, ns.Roster
X.CAP, X.MAX_LEVEL = 150, 60
local STEP, MIN_GAP = 5, 60
local theirs = {}                 -- name -> percent shared by that guildmate
local lastSentPct, lastSentAt = nil, -math.huge
local notifiedMax = false

-- My rested XP as a percent of the current level, capped; nil at max level.
function X.Mine()
	if UnitLevel("player") >= X.MAX_LEVEL then return nil end
	local max = UnitXPMax("player") or 0
	if max <= 0 then return 0 end
	local pct = math.floor((GetXPExhaustion() or 0) / max * 100 + 0.5)
	return math.min(X.CAP, pct)
end

function X.Of(name) return theirs[name] end

local function sharing() return ns.db.settings.shareRested == true end

local function send(p, prio)
	if C.Send("rx", { p = p }, prio) then lastSentPct, lastSentAt = p, GetTime(); return true end
	return false
end

-- force: login, newcomers, turning sharing on. Otherwise only a 5-point change, at most once a minute.
local function sendMine(force)
	if not sharing() then return end
	local p = X.Mine()
	if not p then return end
	if force then
		if lastSentAt == GetTime() and lastSentPct == p then return end   -- a heartbeat already carried it this instant
	else
		if lastSentPct and math.abs(p - lastSentPct) < STEP then return end
		if GetTime() - lastSentAt < MIN_GAP then return end
	end
	send(p)
end

-- Called from the settings check box (a click).
function X.SetSharing(on)
	if on then sendMine(true) else send(-1, "now"); lastSentPct = nil end
end

-- The cap notice and the header refresh.
function X.Check()
	local p = X.Mine()
	if p and p >= X.CAP and not notifiedMax and ns.db.settings.restedNotices then
		notifiedMax = true
		ns.Say(L.RESTED_MAX, X.CAP)
	end
	ns.Fire("LM_RESTED_CHANGED")
end

C.OnMessage("rx", function(f, name)
	if not R.mates[name] then return end   -- only people the roster knows
	theirs[name] = f.p >= 0 and f.p or nil
	ns.Fire("LM_RESTED_CHANGED")
end)

ns.On("LM_HB_SENT", function() sendMine(false) end)
ns.On("LM_ANNOUNCED", function() sendMine(true) end)
ns.On("LM_PING_ANSWERED", function() sendMine(true) end)
ns.On("LM_ROSTER_CHANGED", function()   -- bye and expiry take the value along
	for name in pairs(theirs) do if not R.mates[name] then theirs[name] = nil end end
end)
ns.On("LM_COMM_STOPPING", function() if sharing() then C.SendImmediate("rx", { p = -1 }) end end)
ns.On("LM_COMM_STOPPED", function() wipe(theirs); lastSentPct = nil; ns.Fire("LM_RESTED_CHANGED") end)
ns.On("LM_WORLD", function() C_Timer.After(1, X.Check) end)

local ev = CreateFrame("Frame")
ev:RegisterEvent("UPDATE_EXHAUSTION"); ev:RegisterEvent("PLAYER_UPDATE_RESTING")
ev:RegisterEvent("PLAYER_XP_UPDATE"); ev:RegisterEvent("PLAYER_LEVEL_UP")
ev:SetScript("OnEvent", function() X.Check() end)
