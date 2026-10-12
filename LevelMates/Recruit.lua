-- Recruit.lua: guild recruitment for officers and the guild master. Three templates shared between officers (`rt`),
-- placeholders filled in at post time, posted to channel 2 (Trade) or 1 (General) only from a click, with a
-- 10-minute wait shared by all officers (`rc`). Automatic posting is impossible in the client and against the rules:
-- the reminder only offers a one-click Publish.
local _, ns = ...
local RC = {}
ns.Recruit = RC
local L, C, R = ns.L, ns.Comm, ns.Roster
RC.GAP, RC.MAX_LEN = 600, 200

local function me() return ns.Me() end
-- The server's clock (seconds): every officer counts the shared wait the same way, whatever their PC's clock says.
local function now() return (GetServerTime and GetServerTime()) or time() end
local function store()
	ns.db.recruit = ns.db.recruit or {}
	local k = GetGuildInfo("player") or "?"
	ns.db.recruit[k] = ns.db.recruit[k] or { templates = { L.RECRUIT_DEFAULT, "", "" } }
	return ns.db.recruit[k]
end
function RC.Templates() return store().templates end
function RC.Last() return store().last end   -- { at = seconds, by = name }
function RC.Wait()
	local l = store().last
	if not l then return 0 end
	return math.max(0, RC.GAP - (now() - l.at))
end

local function plain(v) return (tostring(v):gsub("%%", "%%%%")) end
-- {hermandad}/{guild}, {conectados}/{online}, {nivel}/{level}; at most 255 bytes once filled in.
function RC.Expand(text)
	local guild = plain(GetGuildInfo("player") or "")
	local online = plain(select(3, GetNumGuildMembers()) or 0)
	local sum, n = UnitLevel("player"), 1
	for _, m in pairs(R.mates) do if m.level then sum, n = sum + m.level, n + 1 end end
	local level = plain(math.floor(sum / n + 0.5))
	local out = tostring(text or "")
	out = out:gsub("{hermandad}", guild):gsub("{guild}", guild)
	out = out:gsub("{conectados}", online):gsub("{online}", online)
	out = out:gsub("{nivel}", level):gsub("{level}", level)
	return ns.CutUtf8(out, 255)
end

-- In that public channel: the slot is taken, and not by our own hidden channel ("LM" and 8 hex digits).
function RC.InChannel(channel)
	local id, name = GetChannelName(channel)
	return (id or 0) ~= 0 and name ~= nil and not tostring(name):find("^LM%x%x%x%x%x%x%x%x$")
end

-- Called from the Publish click: the text and channel to post, or nil after saying why.
function RC.Prepare(index, channel)
	if not R.IAmOfficer() then ns.Say(L.GOAL_NOT_OFFICER); return nil end
	local wait = RC.Wait()
	if wait > 0 then ns.Say(L.RECRUIT_WAIT, math.ceil(wait / 60)); return nil end
	local text = RC.Expand(RC.Templates()[index] or "")
	if strtrim(text) == "" then ns.Say(L.RECRUIT_EMPTY); return nil end
	if not RC.InChannel(channel) then ns.Say(L.RECRUIT_NO_CHANNEL, channel); return nil end
	return text, channel
end

-- After the post: the wait starts for every officer.
function RC.Posted()
	store().last = { at = now(), by = me() }
	C.Send("rc", { t = now() }, "now")
	ns.Fire("LM_RECRUIT_CHANGED")
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
	if not R.IsOfficer(name) then return end
	local at = f.t
	if at > now() + 60 then return end
	local l = store().last
	if not l or at > l.at then store().last = { at = at, by = name }; ns.Fire("LM_RECRUIT_CHANGED") end
end)

-- Officers share the templates and a recent post with newcomers.
ns.On("LM_PING_ANSWERED", function()
	if not R.IAmOfficer() then return end
	local s = store()
	s.versions = s.versions or {}
	for i, x in ipairs(s.templates) do if x ~= "" and (s.versions[i] or 0) > 0 then C.Send("rt", { i = i, x = x, v = s.versions[i] }) end end
	local l = s.last
	if l and now() - l.at < RC.GAP then C.Send("rc", { t = l.at }) end
end)


-- The reminder: every 10 minutes (when the shared wait is over) a small prompt offers Publish; it never posts by itself.
local snoozeUntil = 0
function RC.Snooze() snoozeUntil = now() + RC.GAP; if RC.prompt then RC.prompt:Hide() end end

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
			if msg then SendChatMessage(msg, "CHANNEL", nil, ch); RC.Posted() end
			p:Hide()
		end)
		local later = ns.Skin.Button(p)
		later:SetSize(130, 22); later:SetPoint("BOTTOMRIGHT", -16, 12); later:SetText(L.RECRUIT_LATER)
		later:SetScript("OnClick", function() RC.Snooze() end)
		p:SetScript("OnHide", function() snoozeUntil = math.max(snoozeUntil, now() + RC.GAP) end)   -- closed any way: not again for 10 min
		tinsert(UISpecialFrames, "LevelMatesRecruitPrompt")
		RC.prompt, RC.promptPost, RC.promptLater = p, post, later
	end
	RC.prompt:Show()
	ns.Screen(L.RECRUIT_PROMPT)
end

function RC.Tick()
	if not ns.char.recruitRemind or not R.IAmOfficer() then return end
	if RC.Wait() > 0 or now() < snoozeUntil then return end
	-- only when a post can happen: out of combat, out of instances, in the chosen channel
	if (InCombatLockdown and InCombatLockdown()) or (IsInInstance and IsInInstance()) or not RC.InChannel(ns.char.recruitChannel or 2) then return end
	if RC.prompt and RC.prompt:IsShown() then return end
	RC.ShowPrompt()
end
ns.On("LM_WORLD", function() if not RC.ticker then RC.ticker = C_Timer.NewTicker(30, RC.Tick) end end)
