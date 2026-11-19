-- Recruit.lua: guild recruitment for officers and the guild master. Three templates shared between officers (`rt`),
-- placeholders filled in at post time, posted to channel 2 (Trade) or 1 (General) only from a click, with a
-- shared cooldown per General zone or one for Trade (`rcz`). Automatic posting is impossible in the client and against the rules:
-- the reminder only offers a one-click Publish.
local _, ns = ...
local RC = {}
ns.Recruit = RC
local L, C, R = ns.L, ns.Comm, ns.Roster
RC.GAP, RC.MAX_LEN = 600, 200   -- the default wait between posts (10 min); the tab lets each officer choose
RC.EVERY_CHOICES = { 5, 10, 15, 20, 30, 60 }
function RC.Every() local n = ns.char and ns.char.recruitEvery; return type(n) == "number" and n >= 1 and n or 10 end   -- minutes
function RC.Gap() return RC.Every() * 60 end

local function me() return ns.Me() end
-- The server's clock (seconds): every officer counts the shared wait the same way, whatever their PC's clock says.
local function now() return (GetServerTime and GetServerTime()) or time() end
local function store()
	ns.db.recruit = ns.db.recruit or {}
	local k = ns.GuildKey()
	ns.db.recruit[k] = ns.db.recruit[k] or { templates = { L.RECRUIT_DEFAULT, "", "" } }
	return ns.db.recruit[k]
end
function RC.Templates() return store().templates end
local function scope(channel)
	if channel == 2 then return "trade" end
	if channel ~= 1 or not (C_Map and C_Map.GetBestMapForUnit) then return nil end
	local id = ns.Plain(C_Map.GetBestMapForUnit("player"))
	if type(id) ~= "number" or id <= 0 then return nil end
	if C_Map.GetMapInfo then
		for _ = 1, 6 do
			local map = ns.Plain(C_Map.GetMapInfo(id))
			if type(map) ~= "table" or (ns.Plain(map.mapType) or 0) < 4 then break end
			local parent = ns.Plain(map.parentMapID)
			if type(parent) ~= "number" or parent <= 0 or parent == id then break end
			id = parent
		end
	end
	return "zone" .. id
end
function RC.Last(channel)
	local s = store()
	local k = scope(channel or ns.char.recruitChannel or 2)
	local scoped = k and s.posts and s.posts[k]
	if not scoped or (s.last and s.last.at > scoped.at) then return s.last end
	return scoped
end
function RC.Wait(channel)
	local l = RC.Last(channel)
	if not l then return 0 end
	return math.max(0, math.max(RC.Gap(), (l.minutes or 0) * 60) - (now() - l.at))
end

local function plain(v) return (tostring(v):gsub("%%", "%%%%")) end

-- The invite link of a community I belong to (a guild has none on Forever: its finder is off): the game's own
-- "[Join: Name]" link from a ticket that still has uses. The tickets come from the server on request
-- (RC.RequestLinks, at login and when the Recruit tab opens), so the first look may find none yet.
local GUILD_CLUB = 2   -- Enum.ClubType.Guild
local function communities()
	if not (C_Club and C_Club.GetSubscribedClubs) then return {} end
	local ok, clubs = pcall(C_Club.GetSubscribedClubs)
	local out = {}
	for _, club in ipairs(ok and ns.List(clubs) or {}) do
		local kind = ns.Plain(club.clubType)
		if kind ~= nil and kind ~= (Enum and Enum.ClubType and Enum.ClubType.Guild or GUILD_CLUB) and ns.Plain(club.clubId) then out[#out + 1] = club end
	end
	return out
end
function RC.RequestLinks()
	if not (C_Club and C_Club.RequestTickets) then return end
	for _, club in ipairs(communities()) do pcall(C_Club.RequestTickets, club.clubId) end
end
function RC.CommunityLink()
	if not (C_Club and C_Club.GetTickets) then return nil end
	for _, club in ipairs(communities()) do
		local ok, tickets = pcall(C_Club.GetTickets, club.clubId)
		for _, t in ipairs(ok and ns.List(tickets) or {}) do
			local id, allowed, used = ns.Plain(t.ticketId), ns.Plain(t.allowedRedeemCount) or 0, ns.Plain(t.currentRedeemCount) or 0
			if id and (allowed == 0 or used < allowed) then   -- 0 uses allowed means unlimited
				local name = ns.Plain(club.name) or ""
				if GetClubTicketLink then
					local okL, link = pcall(GetClubTicketLink, id, name, ns.Plain(club.clubType))
					if okL and type(link) == "string" then return link end
				end
				return string.format("|HclubTicket:%s|h[%s]|h", id, string.format(CLUB_INVITE_HYPERLINK_TEXT or "%s", name))
			end
		end
	end
	return nil
end

-- {hermandad}/{guild}, {conectados}/{online}, {nivel}/{level}, {enlace}/{link}; at most 255 bytes once filled in.
-- The link is put in last and kept whole: the words give way, a cut link would be dead.
function RC.Expand(text)
	local guild = plain(ns.Plain(GetGuildInfo("player")) or "")
	local online = plain(ns.Plain(select(3, GetNumGuildMembers())) or 0)
	local sum, n = UnitLevel("player"), 1
	for _, m in pairs(R.mates) do if m.level then sum, n = sum + m.level, n + 1 end end
	local level = plain(math.floor(sum / n + 0.5))
	local out = tostring(text or "")
	out = out:gsub("{hermandad}", guild):gsub("{guild}", guild)
	out = out:gsub("{conectados}", online):gsub("{online}", online)
	out = out:gsub("{nivel}", level):gsub("{level}", level)
	local link = (out:find("{enlace}", 1, true) or out:find("{link}", 1, true)) and RC.CommunityLink() or nil
	if not link then return ns.CutUtf8((out:gsub("{enlace}", ""):gsub("{link}", "")), 255) end
	local MARK = string.char(1)
	out = out:gsub("{enlace}", MARK):gsub("{link}", MARK)
	local first = out:find(MARK, 1, true)
	local before, after = out:sub(1, first - 1), (out:sub(first + 1):gsub(MARK, ""))
	local room = 255 - #link - #after
	if room < 0 then after = ""; room = 255 - #link end
	return ns.CutUtf8(before, math.max(0, room)) .. link .. after
end

-- Saved values are Blizzard's static zone-channel IDs, not local /chat slots.
function RC.Channel(channel)
	if channel ~= 1 and channel ~= 2 then return nil end
	if not (GetChannelList and C_ChatInfo and C_ChatInfo.GetChannelInfoFromIdentifier) then return nil end
	local joined = { pcall(GetChannelList) }
	if not joined[1] then return nil end
	for i = 2, #joined, 3 do
		local id, name = ns.Plain(joined[i]), ns.Plain(joined[i + 1])
		if type(id) == "number" and id > 0 and type(name) == "string" and ns.Plain(joined[i + 2]) == false then
			local ok, info = pcall(C_ChatInfo.GetChannelInfoFromIdentifier, name)
			info = ok and ns.Plain(info) or nil
			if type(info) == "table" and ns.Plain(info.zoneChannelID) == channel and ns.Plain(info.localID) == id then return id end
		end
	end
end
function RC.InChannel(channel) return RC.Channel(channel) ~= nil end

function RC.Prepare(index, channel)
	if not R.IAmOfficer() then ns.Say(L.GOAL_NOT_OFFICER); return nil end
	local wait = RC.Wait(channel)
	if wait > 0 then ns.Say(L.RECRUIT_WAIT, math.ceil(wait / 60)); return nil end
	if channel == 1 and GetTime() < (RC.zoneReadyAt or 0) then return nil end
	local text = RC.Expand(RC.Templates()[index] or "")
	if strtrim(text) == "" then ns.Say(L.RECRUIT_EMPTY); return nil end
	local target = RC.Channel(channel)
	if not target or not scope(channel) then ns.Say(L.RECRUIT_NO_CHANNEL, channel); return nil end
	return text, target
end

local function remember(k, at, author, minutes)
	if at > now() + 60 or now() - at >= 3600 then return end
	local s = store()
	s.posts = s.posts or {}
	for old, post in pairs(s.posts) do if now() - post.at >= 3600 then s.posts[old] = nil end end
	local l = k and s.posts[k] or (not k and s.last)
	if l and l.at >= at then return end
	local entry = { at = at, by = author, minutes = minutes }
	if k then s.posts[k] = entry else s.last = entry end
	ns.Fire("LM_RECRUIT_CHANGED")
end
function RC.Posted(channel)
	local k = scope(channel or ns.char.recruitChannel or 2)
	if not k then return end
	local at, minutes = now(), math.min(RC.Every(), 60)
	remember(k, at, me(), minutes)
	C.Send("rcz", { t = at, k = k, by = me(), m = minutes }, "now")
end

function RC.SetTemplate(i, text)
	if not R.IAmOfficer() or type(i) ~= "number" or i < 1 or i > 3 then return false end
	local clean = (strtrim(tostring(text or "")):gsub("[%c|]", ""))
	clean = ns.CutUtf8(clean, RC.MAX_LEN)
	local s = store()
	if s.templates[i] == clean then return true end
	s.templates[i] = clean
	s.versions = s.versions or {}
	s.versions[i] = now()   -- a newer edit wins; an old copy from an officer who missed it does not
	C.Send("rt", { i = i, x = clean ~= "" and clean or nil, v = s.versions[i] }, "now")
	ns.Fire("LM_RECRUIT_CHANGED")
	return true
end

C.OnMessage("rt", function(f, name)
	if not R.IsOfficer(name) then return end
	local s = store()
	s.versions = s.versions or {}
	if f.v <= (s.versions[f.i] or 0) then return end
	s.templates[f.i], s.versions[f.i] = f.x or "", f.v
	ns.Fire("LM_RECRUIT_CHANGED")
end)

C.OnMessage("rc", function(f, name)
	if R.IsOfficer(name) then remember(nil, f.t, name) end
end)
C.OnMessage("rcz", function(f, name)
	if R.IsOfficer(name) and R.IsOfficer(f.by) and (f.k == "trade" or f.k:match("^zone%d+$")) then
		remember(f.k, f.t, f.by, f.m)
	end
end)

local lastReply = -math.huge
local function sharePosts()
	if not R.IAmOfficer() or GetTime() - lastReply < 10 then return end
	lastReply = GetTime()
	for k, l in pairs(store().posts or {}) do
		if now() - l.at < 3600 then C.Send("rcz", { k = k, t = l.at, by = l.by, m = l.minutes }) end
	end
end
C.OnMessage("grq", function(_, name) if R.IsOfficer(name) then sharePosts() end end)
ns.On("LM_HELLO_ANSWERED", function()
	if not R.IAmOfficer() then return end
	local s = store()
	s.versions = s.versions or {}
	for i, x in ipairs(s.templates) do if x ~= "" and (s.versions[i] or 0) > 0 then C.Send("rt", { i = i, x = x, v = s.versions[i] }) end end
	sharePosts()
end)

local lastScope
local function refreshZone()
	local current = scope(1)
	if current == lastScope then return end
	lastScope = current
	if R.IAmOfficer() and C.IsReady() then
		RC.zoneReadyAt = GetTime() + 6
		C.Send("grq", {}, "now")
	end
	ns.Fire("LM_RECRUIT_CHANGED")
end
local zone = CreateFrame("Frame")
zone:RegisterEvent("ZONE_CHANGED_NEW_AREA")
zone:RegisterEvent("ZONE_CHANGED")
zone:SetScript("OnEvent", refreshZone)


-- The reminder: every 10 minutes (when the shared wait is over) a small prompt offers Publish; it never posts by itself.
local snoozeUntil = 0
function RC.Snooze() snoozeUntil = now() + RC.Gap(); if RC.prompt then RC.prompt:Hide() end end

function RC.ShowPrompt()
	if not RC.prompt then
		local p = ns.Skin.Window("LevelMatesRecruitPrompt", UIParent)
		p:SetSize(320, 96); p:SetPoint("TOP", 0, -140); p:SetFrameStrata("DIALOG")
		if p.TitleText then p.TitleText:SetText(L.HEAD_RECRUIT) end
		local text = p:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		text:SetPoint("TOP", 0, -32); text:SetText(L.RECRUIT_PROMPT)
		local post = ns.Skin.Button(p)
		post:SetSize(130, 22); post:SetPoint("BOTTOMLEFT", 16, 12); post:SetText(L.RECRUIT_POST)
		post:SetScript("OnClick", function()   -- a click: the post
			local msg, ch = RC.Prepare(ns.char.recruitTemplate or 1, ns.char.recruitChannel or 2)
			if msg and ns.SendChat(msg, "CHANNEL", nil, ch) then RC.Posted() end
			p:Hide()
		end)
		local later = ns.Skin.Button(p)
		later:SetSize(130, 22); later:SetPoint("BOTTOMRIGHT", -16, 12); later:SetText(L.RECRUIT_LATER)
		later:SetScript("OnClick", function() RC.Snooze() end)
		p:SetScript("OnHide", function() snoozeUntil = math.max(snoozeUntil, now() + RC.Gap()) end)   -- closed any way: not again until the interval passes
		tinsert(UISpecialFrames, "LevelMatesRecruitPrompt")
		RC.prompt, RC.promptPost, RC.promptLater = p, post, later
	end
	RC.prompt:Show()
	ns.Screen(L.RECRUIT_PROMPT)
end

function RC.Tick()
	local board = ns.Board
	if board and board.tab == "recruit" and board.frame and board.frame:IsShown() then ns.Fire("LM_RECRUIT_CHANGED") end
	if not ns.char.recruitRemind or not R.IAmOfficer() then return end
	if RC.Wait() > 0 or now() < snoozeUntil or (ns.char.recruitChannel == 1 and GetTime() < (RC.zoneReadyAt or 0)) then return end
	-- only when a post can happen: out of combat, out of instances, in the chosen channel
	if (InCombatLockdown and InCombatLockdown()) or (IsInInstance and IsInInstance()) or not RC.InChannel(ns.char.recruitChannel or 2) then return end
	if RC.prompt and RC.prompt:IsShown() then return end
	RC.ShowPrompt()
end
ns.On("LM_WORLD", function() if not RC.ticker then RC.ticker = C_Timer.NewTicker(30, RC.Tick) end; RC.RequestLinks(); refreshZone() end)
