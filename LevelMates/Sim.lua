-- Sim.lua: /lm sim, /lm sim help, /lm sim off. Local-only fake guildmates for testing alone.
-- Messages go through the real decode and validation path; nothing is sent to anyone.
local _, ns = ...
local C, R = ns.Comm, ns.Roster
local FAKES = { "Mario", "Ana", "Luis" }

local function inject(kind, fields, who)
	local text = C.Encode(kind, fields)
	-- sender names carry the realm without spaces ("Classic Beta PvP" -> "ClassicBetaPvP"), as the client sends them
	local realm = (GetRealmName() or "Realm"):gsub("%s", "")
	if text then C.Inject(text, who .. "-" .. realm) end
end

local function myQuestId()
	return next(R.MyQuests()) or 1098
end

local function run()
	local map = C_Map.GetBestMapForUnit("player") or 1
	inject("hb", { l = 30, z = map, g = 1, s = 1, c = "MAGE", x = 42.5, y = 61.0, v = "sim" }, "Mario")
	inject("q", { i = "1/1", ids = myQuestId() .. ",959" }, "Mario")
	inject("hb", { l = 12, z = map == 1412 and 1421 or 1412, c = "WARRIOR", v = "sim" }, "Ana")
	inject("hb", { l = 22, z = map, g = 1, s = 0, c = "PRIEST", r = 18000, v = "sim" }, "Luis")
	ns.Say("sim: %d guildmates (local only, nothing sent). /lm sim help, /lm sim off", #R.List())
end

local function simHelp()
	local map = C_Map.GetBestMapForUnit("player") or 1
	inject("help", { t = "Fuerte Colmillo (elite)", z = map, x = 42.5, y = 61.0, id = "sim00001" }, "Mario")
end

local function simLfg()
	if not R.mates.Mario then run() end   -- the ads need their posters in the roster
	inject("lfg", { d = 2, r = "TD", n = "con agua y paciencia", id = "simlfg01", m = 20 }, "Mario")
	inject("lfg", { d = 5, r = "H", id = "simlfg02", m = 20 }, "Luis")
end

local function simPal()
	if not R.mates.Luis then run() end   -- the marks need their owners in the roster
	inject("pal", { p = 1 }, "Luis"); inject("pal", { p = 1 }, "Mario")
end

local function simRested()
	if not R.mates.Mario then run() end   -- the values need their owners in the roster
	inject("rx", { p = 80 }, "Mario"); inject("rx", { p = 150 }, "Luis")
end

local function simJournal()
	local J = ns.Journal
	local green = "|cff1eff00|Hitem:2589::::::::20:::::::|h[Linen Cloth]|h|r"
	J.Add("level", { level = 21, took = 4800, sim = true })
	J.Add("quest", { id = 1098, name = "Fuerte Colmillo", sim = true })
	J.Add("dungeon", { name = "Ragefire Chasm", mates = { "Mario" }, sim = true })
	J.Add("group", { name = "Mario", sim = true })
	J.Add("item", { link = green, q = 2, sim = true })
	J.Add("skill", { name = "Herbalism", rank = 50, sim = true })
	J.Add("death", { level = 21, sim = true })
end

local function simGoals()
	local G, day = ns.Goals, math.floor(time() / 86400)
	G.AddSample({ id = "simgo01", ty = "lvl", a = 25, s = day, e = day + 3, by = "Jefa" })
	G.AddSample({ id = "simgo02", ty = "dun", a = 5, s = day, e = day + 5, by = "Jefa" })
	G.AddSample({ id = "simgo03", ty = "cnt", a = 50, w = "qst", s = day, e = day + 7, by = "Jefa", contrib = { Mario = 12, Luis = 7 } })
end

local function off()
	ns.Goals.RemoveSamples()
	ns.Journal.RemoveWhere(function(e) return e.sim end)
	inject("helpok", { id = "sim00001" }, "Mario")
	inject("lfgx", { id = "simlfg01" }, "Mario"); inject("lfgx", { id = "simlfg02" }, "Luis")
	for _, who in ipairs(FAKES) do inject("bye", {}, who) end
end

ns.Slash("sim", function(rest)
	rest = strlower(strtrim(rest or ""))
	if rest == "off" then off()
	elseif rest == "help" or rest == "ayuda" then simHelp()
	elseif rest == "lfg" or rest == "grupo" then simLfg()
	elseif rest == "pal" or rest == "compa" then simPal()
	elseif rest == "rested" or rest == "descanso" then simRested()
	elseif rest == "diario" or rest == "journal" then simJournal()
	elseif rest == "metas" or rest == "goals" then simGoals()
	else run() end
end)
