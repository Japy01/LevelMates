-- Achievements.lua: personal milestones with the game's icons. Counted on this computer from what I do (levels,
-- dungeons with guildmates, helps, gifts, meetups, quests, deaths, a weekly challenge done) and, at first, from the
-- journal already there. Earned ones go to the guild wall (`fe` k=ach) and my list to guildmates (`ac`).
local _, ns = ...
local AC = {}
ns.Achievements = AC
local L, C, R = ns.L, ns.Comm, ns.Roster
AC.FORGET_DAYS = 30

-- id, counter, goal, icon. The order is the wire's numbering: append only, never reorder.
AC.LIST = {
	{ id = "lvl10", cat = "level", n = 10, icon = "Interface\\Icons\\INV_Misc_Book_09" },
	{ id = "lvl20", cat = "level", n = 20, icon = "Interface\\Icons\\INV_Misc_Book_09" },
	{ id = "lvl30", cat = "level", n = 30, icon = "Interface\\Icons\\INV_Misc_Book_11" },
	{ id = "lvl40", cat = "level", n = 40, icon = "Interface\\Icons\\INV_Misc_Book_11" },
	{ id = "lvl50", cat = "level", n = 50, icon = "Interface\\Icons\\INV_Misc_Book_07" },
	{ id = "lvl60", cat = "level", n = 60, icon = "Interface\\Icons\\INV_Misc_Book_07" },
	{ id = "dun1", cat = "d", n = 1, icon = "Interface\\Icons\\INV_Misc_Key_03" },
	{ id = "dun10", cat = "d", n = 10, icon = "Interface\\Icons\\INV_Misc_Key_04" },
	{ id = "dun50", cat = "d", n = 50, icon = "Interface\\Icons\\INV_Misc_Key_13" },
	{ id = "help1", cat = "h", n = 1, icon = "Interface\\Icons\\Spell_Holy_Heal" },
	{ id = "help10", cat = "h", n = 10, icon = "Interface\\Icons\\Spell_Holy_GreaterHeal" },
	{ id = "help50", cat = "h", n = 50, icon = "Interface\\Icons\\Spell_Holy_PrayerOfHealing" },
	{ id = "gift1", cat = "g", n = 1, icon = "Interface\\Icons\\INV_Misc_Bag_10" },
	{ id = "gift10", cat = "g", n = 10, icon = "Interface\\Icons\\INV_Misc_Bag_09" },
	{ id = "meet1", cat = "m", n = 1, icon = "Interface\\Icons\\INV_Misc_PocketWatch_01" },
	{ id = "meet5", cat = "m", n = 5, icon = "Interface\\Icons\\INV_Misc_PocketWatch_02" },
	{ id = "quest100", cat = "q", n = 100, icon = "Interface\\Icons\\INV_Letter_15" },
	{ id = "quest500", cat = "q", n = 500, icon = "Interface\\Icons\\INV_Scroll_03" },
	{ id = "dead10", cat = "dead", n = 10, icon = "Interface\\Icons\\INV_Misc_Bone_HumanSkull_01" },
	{ id = "challenge", cat = "ch", n = 1, icon = "banner" },   -- the faction's banner
}
local BY_ID, INDEX = {}, {}
for i, a in ipairs(AC.LIST) do BY_ID[a.id], INDEX[a.id] = a, i end
function AC.Get(id) return BY_ID[id] end
function AC.Index(id) return INDEX[id] end
function AC.Name(id) return L["ACH_" .. id] or id end
function AC.Desc(id) local a = BY_ID[id]; return string.format(L["ACHD_" .. a.cat], a.n) end
function AC.Icon(id) local a = BY_ID[id]; return a.icon == "banner" and ns.Skin.Banner() or a.icon end
function AC.Link(id) return "|T" .. AC.Icon(id) .. ":14|t " .. AC.Name(id) end

local function me() return (UnitName("player")) end
local function stats() ns.char.stats = ns.char.stats or {}; return ns.char.stats end
local function got() ns.char.ach = ns.char.ach or {}; return ns.char.ach end
function AC.Has(id) return got()[id] ~= nil end
function AC.When(id) return got()[id] end

function AC.Progress(id)
	local a = BY_ID[id]
	if a.cat == "level" then return math.min(a.n, math.max(UnitLevel("player"), AC.level or 0)) end
	return math.min(a.n, stats()[a.cat] or 0)
end

------------------------------------------------------------------ sharing
local function myIds()
	local ids = {}
	for i, a in ipairs(AC.LIST) do if AC.Has(a.id) then ids[#ids + 1] = i end end
	return ids
end
local function sendList(prio)
	local fields = {}
	if ns.db.settings.shareAchievements then
		local ids = myIds()
		if #ids > 0 then fields.ids = table.concat(ids, ",") end
	end
	local ok = C.Send("ac", fields, prio)
	ns.char.achPending = not ok or nil   -- refused (in a dungeon): again with the next heartbeat
	return ok
end
ns.On("LM_HB_SENT", function() if ns.char.achPending then sendList() end end)
function AC.SetSharing() sendList("now") end
-- a few seconds after the login burst (heartbeat, ping, professions...): no hurry for these
ns.On("LM_ANNOUNCED", function() C_Timer.After(10, function() if ns.db.settings.shareAchievements and #myIds() > 0 then sendList() end end) end)
ns.On("LM_PING_ANSWERED", function() if ns.db.settings.shareAchievements and #myIds() > 0 then sendList() end end)

local quiet = true   -- the first count (from the journal already there) earns silently
local function award(id)
	if AC.Has(id) then return end
	got()[id] = time()
	ns.Fire("LM_ACHIEVEMENTS_CHANGED")
	if quiet then return end
	ns.Notice(L.ACH_GOT, AC.Link(id))
	if ns.db.settings.shareAchievements then   -- a moment later: whatever earned it goes out first
		C_Timer.After(3, function() ns.Feed.Share("ach", INDEX[id]); sendList() end)
	end
end

function AC.Check()
	for _, a in ipairs(AC.LIST) do
		if not AC.Has(a.id) and a.cat ~= "ch" and AC.Progress(a.id) >= a.n then award(a.id) end
	end
end

local function count(cat) local s = stats(); s[cat] = (s[cat] or 0) + 1; AC.Check() end

-- What I do (the points module counts the same actions).
ns.On("LM_POINT_EVENT", function(cat, level) if cat ~= "l" then count(cat) else AC.level = level; AC.Check() end end)
ns.On("LM_JOURNAL_ADDED", function(e) if e.k == "death" and not e.sim then count("dead") end end)
ns.On("LM_CHALLENGE_DONE", function() award("challenge") end)

-- Once: what the journal already holds, without notices. The counts never go below the journal's (so a second run,
-- for those whose first one counted only the /lm sim samples, adds nothing twice).
local function backfill()
	if ns.char.statsInit == 2 then return end
	ns.char.statsInit = 2
	local s, d, q, dead = stats(), 0, 0, 0
	for _, e in ipairs(ns.Journal.List("all", "")) do
		if not e.sim then   -- samples from /lm sim are not real
			if e.k == "dungeon" and e.mates and #e.mates > 0 then d = d + 1
			elseif e.k == "quest" then q = q + 1
			elseif e.k == "death" then dead = dead + 1 end
		end
	end
	s.d, s.q, s.dead = math.max(s.d or 0, d), math.max(s.q or 0, q), math.max(s.dead or 0, dead)
end
ns.On("LM_LOADED", function() backfill(); AC.Check(); quiet = false end)

C.OnMessage("ac", function(f, name)
	if not R.mates[name] then return end
	ns.db.ach = ns.db.ach or {}
	local k = GetGuildInfo("player") or "?"
	ns.db.ach[k] = ns.db.ach[k] or {}
	local ids = {}
	for id in tostring(f.ids or ""):gmatch("%d+") do local a = AC.LIST[tonumber(id)]; if a then ids[#ids + 1] = a.id end end
	ns.db.ach[k][name] = #ids > 0 and { ids = ids, t = time() } or nil
	ns.Fire("LM_ACHIEVEMENTS_CHANGED")
end)

-- A guildmate's achievements (ids), newest numbering last.
function AC.Of(name)
	local k = GetGuildInfo("player") or "?"
	local e = ns.db.ach and ns.db.ach[k] and ns.db.ach[k][name]
	if not e or e.t < time() - AC.FORGET_DAYS * 86400 then return {} end
	return e.ids
end
