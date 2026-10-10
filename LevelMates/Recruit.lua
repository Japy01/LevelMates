-- Recruit.lua: guild recruitment for officers and the guild master. Three templates shared between officers (`rt`),
-- placeholders filled in at post time, posted to channel 2 (Trade) or 1 (General) only from a click, with a
-- 10-minute wait shared by all officers (`rc`). Automatic posting is impossible in the client and against the rules:
-- the reminder only offers a one-click Publish.
local _, ns = ...
local RC = {}
ns.Recruit = RC
local L, C, R = ns.L, ns.Comm, ns.Roster
RC.GAP, RC.MAX_LEN = 600, 200

local function me() return (UnitName("player")) end
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
	return math.max(0, RC.GAP - (time() - l.at))
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

-- Called from the Publish click: the text and channel to post, or nil after saying why.
function RC.Prepare(index, channel)
	if not R.IAmOfficer() then ns.Say(L.GOAL_NOT_OFFICER); return nil end
	local wait = RC.Wait()
	if wait > 0 then ns.Say(L.RECRUIT_WAIT, math.ceil(wait / 60)); return nil end
	local text = RC.Expand(RC.Templates()[index] or "")
	if strtrim(text) == "" then ns.Say(L.RECRUIT_EMPTY); return nil end
	if (GetChannelName(channel)) == 0 then ns.Say(L.RECRUIT_NO_CHANNEL, channel); return nil end
	return text, channel
end

-- After the post: the wait starts for every officer.
function RC.Posted()
	store().last = { at = time(), by = me() }
	C.Send("rc", { t = math.floor(time() / 60) }, "now")
	ns.Fire("LM_RECRUIT_CHANGED")
end

function RC.SetTemplate(i, text)
	if not R.IAmOfficer() or type(i) ~= "number" or i < 1 or i > 3 then return false end
	local clean = (strtrim(tostring(text or "")):gsub("[%c|]", ""))
	clean = ns.CutUtf8(clean, RC.MAX_LEN)
	local t = store().templates
	if t[i] == clean then return true end
	t[i] = clean
	C.Send("rt", { i = i, x = clean ~= "" and clean or nil }, "now")
	ns.Fire("LM_RECRUIT_CHANGED")
	return true
end

C.OnMessage("rt", function(f, name)
	if not R.IsOfficer(name) then return end
	store().templates[f.i] = f.x or ""
	ns.Fire("LM_RECRUIT_CHANGED")
end)

C.OnMessage("rc", function(f, name)
	if not R.IsOfficer(name) then return end
	local at = f.t * 60
	if at > time() + 60 then return end
	local l = store().last
	if not l or at > l.at then store().last = { at = at, by = name }; ns.Fire("LM_RECRUIT_CHANGED") end
end)

-- Officers share the templates and a recent post with newcomers.
ns.On("LM_PING_ANSWERED", function()
	if not R.IAmOfficer() then return end
	for i, x in ipairs(store().templates) do if x ~= "" then C.Send("rt", { i = i, x = x }) end end
	local l = store().last
	if l and time() - l.at < RC.GAP then C.Send("rc", { t = math.floor(l.at / 60) }) end
end)
