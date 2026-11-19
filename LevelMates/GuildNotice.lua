-- GuildNotice.lua: the guild's info (the game's Guild Information text) said in guild chat by itself, every so often,
-- so whoever is online reads it without opening anything. Officers and the guild master who turn it on (off by
-- default); one of them sends it: the last time is shared between officers (`gi`), and a random wait before sending
-- lets the one who waits longer hear the other first.
-- The one place the addon writes in chat without a click (asked 2026-11-06). It is the guild's own chat, never a public
-- channel: tested in game that day, guild chat takes a line sent from a timer; public channels still need a click.
local _, ns = ...
local GN = {}
ns.GuildNotice = GN
local L, C, R = ns.L, ns.Comm, ns.Roster
GN.EVERY_CHOICES = { 30, 60, 120, 240 }   -- minutes
GN.MAX_LINES, GN.SETTLE, GN.JITTER = 5, 120, 20   -- messages per notice; seconds after entering the world; longest random wait
GN.PACE = 0.3   -- seconds between the lines of one notice

local function now() return (GetServerTime and GetServerTime()) or time() end
local function store()
	ns.db.guildNotice = ns.db.guildNotice or {}
	local k = ns.GuildKey()
	ns.db.guildNotice[k] = ns.db.guildNotice[k] or {}
	return ns.db.guildNotice[k]
end

-- On for the guild it was turned on in (its key), not for the character: changing guild never carries it over.
function GN.On()
	local k = ns.GuildKey()
	return ns.char ~= nil and k ~= "?" and ns.char.guildNotice == k
end
function GN.SetOn(on) if ns.char then ns.char.guildNotice = on and ns.GuildKey() or nil end end
function GN.Every()
	local n = ns.char and ns.char.guildNoticeEvery
	for _, c in ipairs(GN.EVERY_CHOICES) do if c == n then return n end end
	return 60
end
-- What to say: "info" (the guild info, by default), "motd" (the game's message of the day), "both" (that one first) or
-- "text" (the officer's own, written in the Recruit tab and kept per guild; not shared with the other officers).
GN.WHAT_CHOICES = { "info", "motd", "both", "text" }
GN.TEXT_MAX = 250   -- letters
function GN.What()
	local w = ns.char and ns.char.guildNoticeWhat
	for _, c in ipairs(GN.WHAT_CHOICES) do if c == w then return w end end
	return "info"
end
function GN.Last() return store().last end   -- { at = seconds, by = name }
function GN.Wait()
	local l = store().last
	if not l then return 0 end
	return math.max(0, math.max(GN.Every(), l.minutes or 0) * 60 - (now() - l.at))
end

-- What is said: the chosen text's lines that say something, without codes ("|n" is a line break), each line in
-- messages of at most 255 bytes broken between words, and at most GN.MAX_LINES messages in all.
local function wrap(line, out)
	while #line > 255 and #out < GN.MAX_LINES do
		local cut = ns.CutUtf8(line, 255)
		local space = cut:match("^.*() ")
		if space and space > 1 then cut = line:sub(1, space - 1) end
		out[#out + 1] = (cut:gsub("%s+$", ""))
		line = (line:sub(#cut + 1):gsub("^%s+", ""))
	end
	if line ~= "" and #out < GN.MAX_LINES then out[#out + 1] = line end
end
local function infoText()
	local ok, info = pcall(function() return GetGuildInfoText and GetGuildInfoText() end)
	info = ok and ns.Plain(info) or nil
	return type(info) == "string" and info or ""
end
-- The game's message of the day comes only with its GUILD_MOTD event (at login, or when it changes): asking for it
-- (C_GuildInfo.GetMOTD) is a blocked action on Forever. Kept per guild, so a /reload does not lose it.
local motdEv = CreateFrame("Frame")
motdEv:RegisterEvent("GUILD_MOTD")
motdEv:SetScript("OnEvent", function(_, _, text)
	text = ns.Plain(text)
	if type(text) ~= "string" then return end
	if ns.db and ns.GuildKey() ~= "?" then store().motd = text; GN.earlyMotd = nil else GN.earlyMotd = text end   -- before the guild is known: kept until it is
end)
local function motdText()
	if not ns.db or ns.GuildKey() == "?" then return "" end
	if GN.earlyMotd then store().motd = GN.earlyMotd; GN.earlyMotd = nil end
	local m = store().motd
	return type(m) == "string" and m or ""
end

function GN.Text() local t = ns.db and ns.GuildKey() ~= "?" and store().text; return type(t) == "string" and t or "" end
function GN.SetText(text)
	if not ns.db or ns.GuildKey() == "?" then return false end
	local clean = tostring(text or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|", ""):gsub("%c", " ")
	store().text = ns.CutUtf8(strtrim(clean), GN.TEXT_MAX * 4)
	ns.Fire("LM_RECRUIT_CHANGED")
	return true
end

function GN.Lines()
	local what, out = GN.What(), {}
	local parts = {}
	if what == "text" then parts[1] = GN.Text() end
	if what == "motd" or what == "both" then parts[#parts + 1] = motdText() end
	if what == "info" or what == "both" then parts[#parts + 1] = infoText() end
	local info = table.concat(parts, "\n")
	info = info:gsub("|n", "\n"):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|H.-|h(.-)|h", "%1"):gsub("|T.-|t", ""):gsub("|", "")
	for line in (info .. "\n"):gmatch("([^\n]*)\n") do
		line = line:gsub("%c", " "):gsub("^%s+", ""):gsub("%s+$", "")
		if line ~= "" then wrap(line, out) end
		if #out >= GN.MAX_LINES then break end
	end
	return out
end

-- Never in combat or in an instance: that is when the game holds chat (its own lockdown flag reads true all the time on
-- Forever, so it cannot tell; see ns.SendChat). The notice waits for the next turn instead.
local function free() return not ((InCombatLockdown and InCombatLockdown()) or (IsInInstance and IsInInstance())) end
local function ready() return GN.On() and R.IAmOfficer() and C.IsReady() and now() >= (GN.readyAt or 0) and GN.Wait() == 0 and free() end

-- Said: the wait starts for every officer.
local function said()
	local at, by, minutes = now(), ns.Me(), GN.Every()
	store().last = { at = at, by = by, minutes = minutes }
	C.Send("gi", { t = at }, "now")
	C.Send("gin", { t = at, by = by, m = minutes }, "now")
	ns.Fire("LM_RECRUIT_CHANGED")
end

-- After the random wait: still due (nobody else said it meanwhile, still out of combat)? Then the lines, a moment apart.
-- Refused by the game before the first line: not said, the next turn tries again.
function GN.Send()
	GN.pending = false
	if not ready() then return end
	local lines = GN.Lines()
	if #lines == 0 then return end
	if not ns.SendChat(lines[1], "GUILD") then return end
	said()
	for i = 2, #lines do C_Timer.After((i - 1) * GN.PACE, function() ns.SendChat(lines[i], "GUILD") end) end
end

function GN.Tick()
	if GN.pending or not ready() then return end
	GN.pending = true
	C.Send("grq", {}, "now")
	C_Timer.After(6 + math.random(0, GN.JITTER - 6), GN.Send)
end

local function remember(at, author, minutes)
	if at > now() + 60 or now() - at >= 240 * 60 then return end
	local previous = store().last
	if previous and (at < previous.at or (at == previous.at and (not minutes or previous.minutes))) then return end
	store().last = { at = at, by = author, minutes = minutes }
	ns.Fire("LM_RECRUIT_CHANGED")
end
C.OnMessage("gi", function(f, name)
	if R.IsOfficer(name) then remember(f.t, name) end
end)
C.OnMessage("gin", function(f, name)
	if R.IsOfficer(name) and R.IsOfficer(f.by) then remember(f.t, f.by, f.m) end
end)

local lastReply = -math.huge
local function shareLast()
	if not R.IAmOfficer() or GetTime() - lastReply < 5 then return end
	local l = store().last
	if not l or now() - l.at >= 240 * 60 then return end
	lastReply = GetTime()
	C.Send("gin", { t = l.at, by = l.by, m = l.minutes or GN.Every() }, "now")
end
C.OnMessage("grq", function(_, name) if R.IsOfficer(name) then shareLast() end end)
ns.On("LM_HELLO_ANSWERED", shareLast)

ns.On("LM_WORLD", function()
	GN.readyAt = now() + GN.SETTLE   -- time to hear the others' last time first
	if not GN.ticker then GN.ticker = C_Timer.NewTicker(30, GN.Tick) end
end)
