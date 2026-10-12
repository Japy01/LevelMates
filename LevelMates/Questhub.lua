-- Questhub.lua: the guild quest board. Alt+click a quest in my log (or pick it from the Groups tab) and the guild sees
-- "looking for people for this quest", with my objectives; guildmates say "me too". Records on the sync layer (kept
-- and handed to late logins for two hours): qh = a post (id = questId.myKey), qhj = a "me too" (id = postId.myKey).
-- Spec 2026-10-12-levelmates-quests-map-design (1).
local _, ns = ...
local QH = {}
ns.Questhub = QH
local L, C, R, S = ns.L, ns.Comm, ns.Roster, ns.Sync
QH.LIFE, QH.RANGE = 2 * 3600, 5

local function me() return ns.Me() end
local function key(name) return ns.NameKey(name) end
local function suffixOwner(id, owner) return id:match("%.([^%.]+)$") == key(owner) end
local function changed() ns.Fire("LM_QUESTHUB_CHANGED") end

-- My quest log: { id, title, level, header, group } for each quest (headers skipped).
local GROUP_TAGS = { [1] = true, [41] = true, [62] = true, [81] = true, [85] = true, [88] = true, [89] = true }   -- group, elite-ish, dungeon, raid
local function isGroup(id)
	local info = C_QuestLog.GetQuestTagInfo and C_QuestLog.GetQuestTagInfo(id)
	if not info then return false end
	if info.tagID and GROUP_TAGS[info.tagID] then return true end
	local name = tostring(info.tagName or ""):lower()
	return name:find("group", 1, true) or name:find("grupo", 1, true) or name:find("dungeon", 1, true) or name:find("mazmorra", 1, true) or info.isElite == true
end
function QH.MyQuests()
	local out, header = {}, nil
	for i = 1, C_QuestLog.GetNumQuestLogEntries() do
		local info = C_QuestLog.GetInfo(i)
		if info and info.isHeader then header = info.title
		elseif info and info.questID then
			out[#out + 1] = { id = info.questID, title = info.title or ("#" .. info.questID), level = info.level, header = header, group = isGroup(info.questID) and true or false }
		end
	end
	return out
end
local function mine(id) for _, q in ipairs(QH.MyQuests()) do if q.id == id then return q end end end

local function notice(rec)
	if not ns.db.settings.lfgNotices then return end
	local d = rec.d
	if mine(d.q) then ns.Notice(L.QH_NOTICE_HAVE, rec.o, d.t)
	elseif d.g == 1 and d.l and math.abs(d.l - UnitLevel("player")) <= QH.RANGE then ns.Notice(L.QH_NOTICE_LEVEL, rec.o, d.t, d.l) end
end
S.Define("qh", { class = "board", life = QH.LIFE, idOwner = suffixOwner,
	fields = { q = C.V.int(1, 9999999), t = C.V.text(40), l = C.V.int(0, 100), z = C.V.text(30), ob = C.V.text(40), g = C.V.int(0, 1) },
	required = { "q", "t" },
	onChange = function(rec, old, how) if how == "live" and not old and not rec.dead then notice(rec) end; changed() end })
S.Define("qhj", { class = "board", life = QH.LIFE, idOwner = suffixOwner, onChange = function() changed() end })

function QH.MineFor(questId) return S.Get("qh", questId .. "." .. key(me())) ~= nil end

-- Called from a click (Alt+click in the log, or the Groups tab's menu).
function QH.Post(questId)
	local q = mine(questId)
	if not q then return false end
	if not C.IsReady() then ns.Say(L.HELP_NEEDS_SHARE); return false end
	local obj = ns.QuestProgress and ns.QuestProgress.Objectives and ns.QuestProgress.Objectives(questId)
	local fields = { q = questId, t = ns.CutUtf8((tostring(q.title):gsub("[%c|]", "")), 40), l = q.level, g = q.group and 1 or 0 }
	local zone = q.header or GetRealZoneText()
	if zone and zone ~= "" then fields.z = ns.CutUtf8((tostring(zone):gsub("[%c|]", "")), 30) end
	if obj and #obj <= 40 then fields.ob = obj end
	if not S.Put("qh", questId .. "." .. key(me()), fields) then return false end
	ns.Say(L.QH_POSTED, fields.t)
	return true
end
function QH.Withdraw(questId)
	local id = questId .. "." .. key(me())
	if not S.Get("qh", id) then return false end
	return S.Remove("qh", id)
end
function QH.Toggle(questId) if QH.MineFor(questId) then return QH.Withdraw(questId) end; return QH.Post(questId) end

-- The posts, newest first; filter: "all", "zone" (my zone), "level" (±5 of mine), "group".
function QH.List(filter)
	local out, myZone, myLevel = {}, GetRealZoneText(), UnitLevel("player")
	for _, rec in ipairs(S.List("qh")) do
		local d = rec.d
		local keep = filter == nil or filter == "all"
			or (filter == "zone" and d.z == myZone)
			or (filter == "level" and d.l and math.abs(d.l - myLevel) <= QH.RANGE)
			or (filter == "group" and d.g == 1)
		if keep then
			local p = { id = rec.id, q = d.q, t = d.t, l = d.l, z = d.z, ob = d.ob, g = d.g, by = rec.o, at = rec.v, joined = {} }
			local prefix = rec.id .. "."
			for _, j in ipairs(S.List("qhj", function(r) return r.id:sub(1, #prefix) == prefix end)) do p.joined[#p.joined + 1] = j.o end
			table.sort(p.joined)
			out[#out + 1] = p
		end
	end
	table.sort(out, function(a, b) if a.at ~= b.at then return a.at > b.at end; return a.id < b.id end)
	return out
end

-- "Me too" (a click on a post): my name on it while it lasts.
function QH.IJoined(postId) return S.Get("qhj", postId .. "." .. key(me())) ~= nil end
function QH.MeToo(postId)
	local post = S.Get("qh", postId)
	if not post or post.o == me() then return false end
	return S.Put("qhj", postId .. "." .. key(me()), { _exp = post.e })
end
function QH.NotMe(postId)
	local id = postId .. "." .. key(me())
	if not S.Get("qhj", id) then return false end
	return S.Remove("qhj", id)
end

-- Turned in or abandoned: my post goes.
local ev = CreateFrame("Frame")
ev:RegisterEvent("QUEST_TURNED_IN"); ev:RegisterEvent("QUEST_REMOVED")
ev:SetScript("OnEvent", function(_, event, questId)
	if (event == "QUEST_TURNED_IN" or event == "QUEST_REMOVED") and type(questId) == "number" and QH.MineFor(questId) then QH.Withdraw(questId) end
end)

-- Alt+click on a quest in the game's quest log (whichever log this client has: the map's or the classic one). One
-- click toggles once even if both hooks fire; the game's own click goes on as usual.
local lastToggle = {}
local function onTitleClick(button)
	if not (IsAltKeyDown and IsAltKeyDown()) or type(button) ~= "table" then return end
	local id = button.questID
	if not id then
		local index = button.questLogIndex or (button.GetID and button:GetID())
		local info = index and C_QuestLog.GetInfo(index)
		id = info and not info.isHeader and info.questID
	end
	if not id then return end
	if GetTime() - (lastToggle[id] or -math.huge) < 0.5 then return end
	lastToggle[id] = GetTime()
	QH.Toggle(id)
end
local hooked = {}
local function hook()
	for _, name in ipairs({ "QuestMapLogTitleButton_OnClick", "QuestLogTitleButton_OnClick" }) do
		if not hooked[name] and type(_G[name]) == "function" then
			hooked[name] = true
			hooksecurefunc(name, function(button) onTitleClick(button) end)
		end
	end
end
ns.On("LM_WORLD", hook)
ev:RegisterEvent("ADDON_LOADED")
ev:HookScript("OnEvent", function(_, event) if event == "ADDON_LOADED" then hook() end end)
