-- ChatAds.lua: group ads read from the public channels (Trade, General, LookingForGroup...) for the dungeon cards.
-- Only reads: nothing is sent, and a whisper to a poster happens from a click on the card's menu. Text the game marks
-- secret (chat lockdown in instances and combat) is never read. Spec 2026-10-10-levelmates-class-tanda-design.
local _, ns = ...
local CA = {}
ns.ChatAds = CA
CA.LIFETIME = 600

-- Names and abbreviations, already in normal form (lower case, no accents, single spaces).
local ALIASES = {
	[1]  = { "hall of thanes", "thanes", "salon de los feudales", "feudales" },
	[2]  = { "ragefire chasm", "ragefire", "rfc", "sima ignea", "sima" },
	[3]  = { "ruins of lordaeron", "ruinas de lordaeron", "lordaeron" },
	[4]  = { "wailing caverns", "wc", "cuevas de los lamentos", "lamentos" },
	[5]  = { "deadmines", "dm", "vc", "minas de la muerte", "minas" },
	[6]  = { "shadowfang keep", "shadowfang", "sfk", "castillo de colmillo oscuro", "colmillo oscuro" },
	[7]  = { "blackfathom deeps", "blackfathom", "bfd", "cavernas de brazanegra", "brazanegra" },
	[8]  = { "stockade", "stockades", "stocks", "las mazmorras" },
	[9]  = { "excavation site", "excavation", "excavacion" },
	[10] = { "city of dalaran", "ciudad de dalaran", "dalaran" },
	[11] = { "gnomeregan", "gnomer" },
	[12] = { "razorfen kraul", "rfk", "kraul", "horado rajacieno", "rajacieno", "horado" },
	[13] = { "sm graveyard", "sm gy", "graveyard", "gy", "sm cementerio", "cementerio" },
	[14] = { "sm library", "sm lib", "library", "lib", "sm biblioteca", "biblioteca", "biblio" },
}
local GROUP = {}
for w in ("lfm lfg lf lf1m lf2m lf3m lf4m need needs busco buscamos buscando falta faltan tank tanque heal heals healer healers sanador dps grupo group run runs inv"):gmatch("%S+") do GROUP[w] = true end

local ACCENTS = { ["á"] = "a", ["é"] = "e", ["í"] = "i", ["ó"] = "o", ["ú"] = "u", ["ü"] = "u", ["ñ"] = "n",
	["Á"] = "a", ["É"] = "e", ["Í"] = "i", ["Ó"] = "o", ["Ú"] = "u", ["Ü"] = "u", ["Ñ"] = "n" }
local function normal(text)
	local s = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|H.-|h", ""):gsub("|h", "")
	s = s:gsub("[\195][\128-\191]", function(ch) return ACCENTS[ch] or " " end)
	s = s:lower():gsub("[^%w]+", " ")
	return " " .. s .. " "
end

-- The dungeon an ad is about (the first one named), or nil when it names none or has no group word.
function CA.Parse(text)
	if type(text) ~= "string" then return nil end
	local s = normal(text)
	local grouped = false
	for w in s:gmatch("%S+") do if GROUP[w] then grouped = true; break end end
	if not grouped then return nil end
	local best, at
	for id, list in pairs(ALIASES) do
		for _, alias in ipairs(list) do
			local pos = s:find(" " .. alias .. " ", 1, true)
			if pos and (not at or pos < at or pos == at and id < best) then best, at = id, pos end
		end
	end
	return best
end

local ads = {}   -- by full sender name: { id, name, full, text, t }
local function hidden(chan) return type(chan) == "string" and chan:match("^LM%x%x%x%x%x%x%x%x$") ~= nil end
local function secret(v) return issecretvalue and issecretvalue(v) end

function CA.Hear(text, sender, channel)
	if secret(text) or secret(sender) or secret(channel) then return end
	if not (ns.db and ns.db.settings.readChatAds) or type(text) ~= "string" or type(sender) ~= "string" or sender == "" then return end
	if hidden(channel) then return end
	local name = ns.ShortName(sender)
	if name == UnitName("player") then return end
	local id = CA.Parse(text)
	local had = ads[sender]
	if id then ads[sender] = { id = id, name = name, full = sender, text = ns.CutUtf8(text, 120), t = GetTime() }
	else ads[sender] = nil end   -- their newest message is what they are doing now
	if id or had then ns.Fire("LM_LFG_CHANGED") end
end

-- The live ads for a dungeon, newest first.
function CA.For(id)
	local out, now = {}, GetTime()
	for key, a in pairs(ads) do
		if now - a.t > CA.LIFETIME then ads[key] = nil
		elseif a.id == id then out[#out + 1] = a end
	end
	table.sort(out, function(a, b) if a.t ~= b.t then return a.t > b.t end; return a.name < b.name end)
	return out
end

function CA.AddSample(id, name, text, secondsAgo) ads[name .. "-Sim"] = { id = id, name = name, full = name, text = text, t = GetTime() - (secondsAgo or 0), sim = true }; ns.Fire("LM_LFG_CHANGED") end
function CA.RemoveSamples() for k, a in pairs(ads) do if a.sim then ads[k] = nil end end; ns.Fire("LM_LFG_CHANGED") end

local frame = CreateFrame("Frame")
frame:RegisterEvent("CHAT_MSG_CHANNEL")
frame:SetScript("OnEvent", function(_, _, text, sender, _, channelName, _, _, _, _, baseName)
	CA.Hear(text, sender, baseName or channelName)
end)
