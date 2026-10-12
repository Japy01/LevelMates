-- Discord.lua: runs announced in the guild's Discord channel through WoW Forever's own guild↔Discord link
-- (SendChatMessage to GUILD_DISCORD): no bot, no webhook. Only as the result of a click of whoever posts (the leader
-- creating or cancelling, someone joining or leaving, the leader adding or removing); a line that cannot go out now is
-- kept (the latest per run) for a "Send to Discord" click, never retried on its own.
-- Spec 2026-10-12-levelmates-runs-discord-design (4).
local _, ns = ...
local DC = {}
ns.Discord = DC
local L = ns.L
DC.MAX, DC.COOLDOWN = 236, 30
local held = {}            -- runId -> line
local blockedAt = -math.huge
local sending, sendingLine  -- the run and line going out right now (for ADDON_ACTION_BLOCKED)

-- The guild linked its channel, and I linked my account (the game lets nobody else write there). Unknown is "no".
local function ask(fn)
	if not (C_Discord and C_Discord[fn]) then return false end
	local ok, v = pcall(C_Discord[fn])
	return ok and v == true
end
function DC.Available()
	if not ask("IsEnabled") or not ask("IsGuildChannelLinked") then return false, "DISCORD_NO_GUILD" end
	if not ask("IsUserOAuthed") then return false, "DISCORD_NO_USER" end
	return true
end

-- What is still free: "faltan: sanador, 2 daño" or "completa".
local function freeText(m)
	local s = ns.Meetups.Slots(m)
	local parts = {}
	for _, role in ipairs({ "T", "H", "D" }) do
		local free = ns.Meetups.CAP[role] - #s[role]
		if free > 0 then parts[#parts + 1] = (free > 1 and (free .. " ") or "") .. L["ROLE_" .. role] end
	end
	return #parts > 0 and string.format(L.DC_FREE, table.concat(parts, ", ")) or L.DC_FULL
end

-- One line, at most 236 bytes, no "|", no links; the note is what gets shortened.
function DC.Line(kind, m, who, role)
	local dungeon, when = ns.Dungeons.Name(m.d), ns.Meetups.When(m)
	local head
	if kind == "new" then head = string.format(L.DC_NEW, dungeon, when, m.by)
	elseif kind == "join" then head = string.format(L.DC_JOIN, who, L["ROLE_" .. role], dungeon, when)
	elseif kind == "leave" then head = string.format(L.DC_LEAVE, who, dungeon, when)
	elseif kind == "add" then head = string.format(L.DC_ADD, m.by, who, L["ROLE_" .. role], dungeon, when)
	elseif kind == "remove" then head = string.format(L.DC_REMOVE, m.by, who, dungeon, when)
	else head = string.format(L.DC_CANCEL, dungeon, when, m.by) end
	local line = "[LevelMates] " .. head
	if kind ~= "cancel" then line = line .. " · " .. freeText(m) end
	line = line:gsub("|", "")
	local note = m.n and m.n ~= "" and tostring(m.n):gsub("|", "") or nil
	if note then
		local room = DC.MAX - #line - 5
		if room > 3 then line = line .. ' · "' .. ns.CutUtf8(note, room) .. '"' end
	end
	if #line > DC.MAX then line = ns.CutUtf8(line, DC.MAX) end
	return line
end

-- Blocked: in a fight inside an instance (boss fights and restricted instances), or the game refused one of our
-- sends in the last 30 s. (C_ChatInfo's restriction flag reads true on Forever outside combat too: not used.)
local function blocked()
	if GetTime() - blockedAt < DC.COOLDOWN then return true end
	return IsInInstance and IsInInstance() and UnitAffectingCombat and UnitAffectingCombat("player") or false
end

-- policy: click paths only (DC.Run is called from the run actions of Meetups, which only clicks reach; DC.SendHeld is a button)
local function post(runId, line)
	sending, sendingLine = runId, line
	held[runId] = nil
	local ok = pcall(SendChatMessage, line, "GUILD_DISCORD")
	sending, sendingLine = nil, nil
	if not ok then held[runId] = line end
	ns.Fire("LM_DISCORD_CHANGED")
	return ok and not held[runId]
end

-- From the click paths of Meetups only. "sent", "held" or "off".
function DC.Run(kind, m, who, role)
	if not (m and m.dc) or not DC.Available() then return "off" end
	local line = DC.Line(kind, m, who, role)
	if blocked() then held[m.id] = line; ns.Fire("LM_DISCORD_CHANGED"); return "held" end
	return post(m.id, line) and "sent" or "held"
end
function DC.Held(runId) return held[runId] end
-- Called from a click (the dungeon panel's "Send to Discord").
function DC.SendHeld(runId)
	local line = held[runId]
	if not line then return false end
	blockedAt = -math.huge   -- a click: try again now
	return post(runId, line)
end

-- The game refused our send (no hardware event, a lockdown): keep the line for the button, and wait 30 s.
local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_ACTION_BLOCKED")
ev:SetScript("OnEvent", function(_, _, addon)
	if addon ~= "LevelMates" or not sending then return end
	blockedAt = GetTime()
	held[sending] = sendingLine
end)
