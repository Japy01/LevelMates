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

-- Mario goes up one level (runs /lm sim first if he is not there), to try the [Congratulate] link.
local function simLevel()
	if not R.mates.Mario then run() end
	local m = R.mates.Mario
	inject("hb", { l = math.min(60, (m and m.level or 30) + 1), z = m and m.mapId or 1, c = "MAGE", v = "sim" }, "Mario")
end

local function simWall()
	local F = ns.Feed
	F.AddSample("Mario", "lvl", 31, nil, 20)
	F.AddSample("Ana", "dun", 0, "Minas de la Muerte · Mario, Luis", 95)
	F.AddSample("Luis", "itm", 2318, nil, 180)
	F.AddSample("Ana", "pgl", 25, nil, 400)
end
local function simGifts()
	ns.Gifts.AddSample("Ana", { 2589, 765 })
	ns.Gifts.AddSample("Luis", { 2318 })
end
local function simMeetups()
	ns.Meetups.AddSample("Mario", 5, 90, { Ana = "H" })
	ns.Meetups.AddSample("Ana", 4, 24 * 60, {})
end

local function simRare()
	if not R.mates.Mario then run() end
	local map = C_Map.GetBestMapForUnit("player") or 1
	inject("rr", { n = "Mangaleta", z = map, x = 42.5, y = 61.0 }, "Mario")
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
	ns.Personal.AddSample("Mario", 32, day + 4)
end

local function simWishes()
	ns.Wishlist.AddSample("Mario", { 2589, 2318 })
	ns.Wishlist.AddSample("Ana", { 765, 2447 })
end

local function simCrafts()
	ns.Professions.AddSample("Mario", { { id = 171, rank = 120 }, { id = 182, rank = 140 } })
	ns.Professions.AddSample("Ana", { { id = 197, rank = 90 } })
end

-- Class tab and chat ads: builds of my class (with my own build code when the game has given it, to try View build),
-- a shared macro and a chat ad on the Deadmines card.
local function simClass()
	if not R.mates.Mario then run() end
	local BU, class = ns.Builds, select(2, UnitClass("player"))
	local parts = {}
	for i, g in ipairs(BU.Groups()) do parts[#parts + 1] = g.id .. ":" .. (i == 1 and 12 or 3) end
	local mine = BU.Mine()
	BU.AddSample("Mario", { c = class, s = mine.s, l = 31, p = #parts > 0 and table.concat(parts, ",") or "1:12", b = mine.b })
	BU.AddSample("Luis", { c = class, s = mine.s, l = 22, p = #parts > 0 and table.concat(parts, ","):gsub(":%d+", ":5") or "1:5" })
	ns.Macros.AddSample("Mario", "Pull", "#showtooltip\n/startattack\n/say Pull!", class)
	ns.ChatAds.AddSample(5, "Pepe", "LFM DM need heal", 90)
	ns.Ask.AddSample("Mario", "¿Qué rama para subir rápido?", 12)
end

-- Group XP bars (Mario and Ana as if grouped) and deaths for the Cemetery.
local function simXp()
	if not R.mates.Mario then run() end
	ns.GroupXP.AddSample("Mario", 30, 72); ns.GroupXP.AddSample("Ana", 12, 18)
end
local function simDeaths()
	ns.Feed.AddSample("Luis", "dth", 22, "Bosque del Ocaso", 30)
	ns.Feed.AddSample("Ana", "dth", 12, "Los Baldíos", 300)
end

local function off()
	ns.Goals.RemoveSamples(); ns.Personal.RemoveSamples(); ns.Wishlist.RemoveSamples(); ns.Professions.RemoveSamples()
	ns.Feed.RemoveSamples(); ns.Gifts.RemoveSamples(); ns.Meetups.RemoveSamples()
	ns.Builds.RemoveSamples(); ns.Macros.RemoveSamples(); ns.ChatAds.RemoveSamples(); ns.GroupXP.RemoveSamples(); ns.Ask.RemoveSamples()
	ns.Journal.RemoveWhere(function(e) return e.sim end)
	inject("helpok", { id = "sim00001" }, "Mario")
	inject("lfgx", { id = "simlfg01" }, "Mario"); inject("lfgx", { id = "simlfg02" }, "Luis")
	for _, who in ipairs(FAKES) do inject("bye", {}, who) end
end

-- /lm sim arte: a window with candidate game textures for the dungeon cards (file ids near Forever's own loading
-- screens, and classic loading screens), to pick art that ships with the game instead of anyone's files.
local ART = { "LoadScreenUldaman", "LoadScreenStratholme", "LoadScreenScholomance", "LoadScreenScarletMonastery",
	"LoadScreenScarletMonastery2", "LoadScreenScarletHalls", "LoadScreenRazorfenDowns", "LoadScreenBlackrockDepths", "LoadScreenEasternKingdom" }
local function simArt()
	local f = _G.LevelMatesArtPreview
	if not f then
		f = CreateFrame("Frame", "LevelMatesArtPreview", UIParent, "BasicFrameTemplateWithInset")
		f:SetSize(940, 640); f:SetPoint("CENTER"); f:SetFrameStrata("DIALOG")
		f:SetMovable(true); f:EnableMouse(true); f:RegisterForDrag("LeftButton")
		f:SetScript("OnDragStart", f.StartMoving); f:SetScript("OnDragStop", f.StopMovingOrSizing)
		tinsert(UISpecialFrames, "LevelMatesArtPreview")
		local list = {}
		for id = 7963768, 7963785 do list[#list + 1] = { tex = id, label = tostring(id) } end
		list[#list + 1] = { tex = 131865, label = "131865 (RFK, entera)", full = true }
		for _, name in ipairs(ART) do list[#list + 1] = { tex = "Interface\\Glues\\LoadingScreens\\" .. name, label = name } end
		f.thumbs = {}
		for i, c in ipairs(list) do
			local col, row = (i - 1) % 6, math.floor((i - 1) / 6)
			local tex = f:CreateTexture(nil, "ARTWORK")
			tex:SetSize(146, 92); tex:SetPoint("TOPLEFT", 14 + col * 152, -30 - row * 118)
			tex:SetTexture(c.tex); if c.full then tex:SetTexCoord(0, 1, 0, 1) else tex:SetTexCoord(0.02, 0.98, 0.12, 0.88) end
			local label = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
			label:SetPoint("TOP", tex, "BOTTOM", 0, -2); label:SetText(c.label)
			f.thumbs[i] = { tex = tex, label = label }
		end
	end
	f:Show()
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
	elseif rest == "deseos" or rest == "wishes" then simWishes()
	elseif rest == "oficios" or rest == "professions" then simCrafts()
	elseif rest == "nivel" or rest == "level" then simLevel()
	elseif rest == "muro" or rest == "wall" then simWall()
	elseif rest == "mercadillo" or rest == "gifts" then simGifts()
	elseif rest == "quedada" or rest == "meetup" then simMeetups()
	elseif rest == "raro" or rest == "rare" then simRare()
	elseif rest == "arte" or rest == "art" then simArt()
	elseif rest == "clase" or rest == "class" then simClass()
	elseif rest == "xp" then simXp()
	elseif rest == "muertes" or rest == "deaths" then simDeaths()
	else run() end
end)
