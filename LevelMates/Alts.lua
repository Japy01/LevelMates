-- Alts.lua: every character that logs in with LevelMates is noted in the account's data (name, level, class, guild,
-- professions). My other characters in this same guild and realm are shared (`al`), never others; guildmates' alts
-- show on their card and in the board tooltip. `/lm alts` opens my own card. Spec 2026-10-10-levelmates-guild-tanda-design.
local _, ns = ...
local AL = {}
ns.Alts = AL
local L, C, R = ns.L, ns.Comm, ns.Roster

function AL.Chars() ns.db.characters = ns.db.characters or {}; return ns.db.characters end   -- ns.db.chars is each character's own data
local function me() return ns.Me() end
local function myRealm() return GetRealmName() end   -- UnitName's second value can be a surname on Forever

-- This character, as it is now.
function AL.Note()
	if not ns.db then return end
	local _, class = UnitClass("player")
	local profs = {}
	for _, p in ipairs(ns.Professions.Mine()) do profs[#profs + 1] = { id = p.id, rank = p.rank } end
	AL.Chars()[ns.PlayerKey()] = { name = me(), realm = myRealm(), level = UnitLevel("player"), class = class, guild = GetGuildInfo("player"), profs = profs, t = time() }
end

-- My other characters in this guild and realm, highest level first.
function AL.MyAlts()
	local guild, realm, out = GetGuildInfo("player"), myRealm(), {}
	if not guild then return out end
	for _, c in pairs(AL.Chars()) do
		if c.guild == guild and c.realm == realm and c.name ~= me() then out[#out + 1] = c end
	end
	table.sort(out, function(a, b) if a.level ~= b.level then return a.level > b.level end; return a.name < b.name end)
	return out
end

local function fields()
	if not ns.db.settings.shareAlts then return {} end
	local names = {}
	for _, c in ipairs(AL.MyAlts()) do
		if #table.concat(names, ",") + #c.name + 1 > 120 then break end
		if R.IsGuildmate(c.name) then names[#names + 1] = c.name end   -- one that left the guild since it last logged in: never shared
	end
	return #names > 0 and { n = table.concat(names, ",") } or {}
end

-- My alts in `al` (none withdraws them), through the sync layer's personal helper: a refused send (a dungeon) goes
-- with the next heartbeat; announces and newcomers get them when there are some.
local PS = ns.Sync.Personal("al", fields, { save = "altsPending", worth = function() return fields().n ~= nil end })
function AL.SetSharing() PS.Mark("now") end

local function store()
	ns.db.alts = ns.db.alts or {}
	local k = ns.GuildKey()
	ns.db.alts[k] = ns.db.alts[k] or {}
	return ns.db.alts[k]
end
C.OnMessage("al", function(f, name)
	if not R.mates[name] then return end
	local list = {}
	for n in tostring(f.n or ""):gmatch("[^,]+") do list[#list + 1] = n end
	store()[name] = #list > 0 and { list = list, t = time() } or nil
	ns.Fire("LM_ALTS_CHANGED")
end)

-- A guildmate's alts that are still in the guild.
function AL.Of(name)
	local e, out = store()[name], {}
	for _, n in ipairs(e and e.list or {}) do if R.IsGuildmate(n) then out[#out + 1] = n end end
	return out
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LEVEL_UP"); ev:RegisterEvent("PLAYER_GUILD_UPDATE")
ev:SetScript("OnEvent", function() C_Timer.After(1, AL.Note) end)
ns.On("LM_LOADED", AL.Note)
ns.On("LM_WORLD", AL.Note)
ns.On("LM_SKILLS_CHANGED", AL.Note)
ns.Slash("alts", function() AL.Note(); ns.MateCard.Show(me()) end)
