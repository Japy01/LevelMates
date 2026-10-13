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
local heldIn = {}          -- runId -> dungeon id (the run itself may be gone: a cancel)
local blockedAt = -math.huge
local sending, sendingLine  -- the run and line going out right now (for ADDON_ACTION_BLOCKED)

-- The guild linked its channel, and I linked my account (the game lets nobody else write there). On Forever the
-- link checks are restricted and answer an addon nothing: that is "unknown", not "no". Only an explicit false refuses;
-- if the send is then blocked, the line is held for a click and "Copy for Discord" stays.
local function ask(fn)   -- true, false or nil (unknown)
	if not (C_Discord and C_Discord[fn]) then return false end
	local ok, v = pcall(C_Discord[fn])
	if not ok or v == nil then return nil end
	return v == true
end
function DC.Available()
	if ask("IsEnabled") ~= true then return false, "DISCORD_NO_GUILD" end
	local linked, oauth = ask("IsGuildChannelLinked"), ask("IsUserOAuthed")
	if linked == false then return false, "DISCORD_NO_GUILD" end
	if oauth == false then return false, "DISCORD_NO_USER" end
	if linked == nil or oauth == nil then return true, "DISCORD_UNSURE" end
	return true
end

-- What is still free: "faltan: sanador, 2 daño" or "completa". A join counts the joiner (the leader places them a
-- moment later), a leave or a removal frees their slot.
local function freeText(m, kind, who, role)
	local caps = m.caps or ns.Activities.Caps(m.d, m.size)
	local s = m.now and ns.LFG.Slots({ name = m.by, lr = m.role, caps = caps, joined = m.joined, order = m.order }) or ns.Meetups.Slots(m)
	for r in pairs(caps) do s[r] = s[r] or {} end
	local function drop(name) for r in pairs(caps) do for i = #s[r], 1, -1 do if s[r][i] == name then table.remove(s[r], i) end end end end
	if kind == "join" and role and caps[role] and #s[role] < caps[role] then drop(who); table.insert(s[role], who)
	elseif kind == "leave" or kind == "remove" then drop(who) end
	local parts = {}
	for _, r in ipairs({ "T", "H", "D", "A" }) do
		local free = caps[r] and (caps[r] - #s[r]) or 0
		if free > 0 then
			if r == "A" then parts[#parts + 1] = string.format(L.DC_FREE_ANY, free)
			else parts[#parts + 1] = (free > 1 and (free .. " ") or "") .. L["ROLE_" .. r] end
		end
	end
	return #parts > 0 and string.format(L.DC_FREE, table.concat(parts, ", ")) or L.DC_FULL
end

-- One line, at most 236 bytes, no "|", no links; the note is what gets shortened.
function DC.Line(kind, m, who, role)
	local A = ns.Activities
	local a = A.Get(m.d)
	local what = A.Name(m.d, m.t)
	if a and a.kind ~= "d" then what = L["KIND_" .. a.kind] .. " · " .. what end   -- the type first (a dungeon goes as before)
	local dungeon, when = what, (m.now or not m.at) and L.WHEN_NOW or ns.Meetups.When(m)
	local head
	if kind == "new" then head = string.format(L.DC_NEW, dungeon, when, m.by)
	elseif kind == "join" then head = string.format(L.DC_JOIN, who, L["ROLE_" .. role], dungeon, when)
	elseif kind == "leave" then head = string.format(L.DC_LEAVE, who, dungeon, when)
	elseif kind == "add" then head = string.format(L.DC_ADD, m.by, who, L["ROLE_" .. role], dungeon, when)
	elseif kind == "remove" then head = string.format(L.DC_REMOVE, m.by, who, dungeon, when)
	else head = string.format(L.DC_CANCEL, dungeon, when, m.by) end
	local line = "[LevelMates] " .. head
	if kind ~= "cancel" then line = line .. " · " .. freeText(m, kind, who, role) end
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
	heldIn[m.id] = m.d
	if blocked() then held[m.id] = line; ns.Fire("LM_DISCORD_CHANGED"); return "held" end
	return post(m.id, line) and "sent" or "held"
end
function DC.Held(runId) return held[runId] end
-- Lines waiting for a click, of one dungeon: { { id, line } }, for its panel.
function DC.HeldFor(d)
	local out = {}
	for id, line in pairs(held) do if heldIn[id] == d then out[#out + 1] = { id = id, line = line } end end
	table.sort(out, function(a, b) return a.id < b.id end)
	return out
end
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
