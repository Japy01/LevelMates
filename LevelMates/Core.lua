-- Core.lua: SavedVariables, event bus, slash commands. Nothing here talks to other players.
local ADDON, ns = ...
ns.TITLE = "Forever Guild"   -- the name players see; inside (folder, saved data, messages) it stays LevelMates
ns.VERSION = C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(ADDON, "Version") or "dev"

local DEFAULTS = {
	share = true, sharePos = false, shareQuests = false, shareXp = false, shareRested = false,
	matchNotices = true, helpNotices = true, lfgNotices = true, palNotices = true, restedNotices = true, goalNotices = true, wishNotices = true, screenNotices = true, levelNotices = true, shareProfessions = true, shareFeed = true, feedLoot = true, rareNotices = true, mapPins = true, mapNames = false, shareBank = true, shareGear = true, readChatAds = true, shareBuild = true, shareDeaths = true, trainerNotices = true, groupXp = true, askNotices = true, shareAlts = true, sharePoints = true, shareAchievements = true, ink = 4, theme = "dark", sound = true, minimap = true, stripNotices = true, dingBanner = true, levelBar = false, boardScale = 100, discordTag = false, discordTagOff = false,
	transport = "auto", debug = false, language = "auto",
}

ns.DEFAULTS = DEFAULTS

-- At most max bytes, never cutting a multi-byte UTF-8 character in half (continuation bytes are 0x80-0xBF).
function ns.CutUtf8(s, max)
	if #s <= max then return s end
	local at = max
	while at > 0 do
		local b = s:byte(at + 1)
		if b and b >= 128 and b <= 191 then at = at - 1 else break end
	end
	return s:sub(1, at)
end

-- The addon's language: the game's ("auto") or the one chosen in the options. Spanish overrides English.
function ns.ApplyLocale()
	local choice, loc = ns.db and ns.db.settings.language or "auto", GetLocale()
	local spanish = choice == "esES" or (choice == "auto" and (loc == "esES" or loc == "esMX"))
	ns.spanish = spanish
	if spanish and ns.LocaleES then for k, v in pairs(ns.LocaleES) do ns.L[k] = v end end
	BINDING_NAME_LEVELMATES_TOGGLE = ns.L.BINDING_TOGGLE
	BINDING_NAME_LEVELMATES_PANIC = ns.L.BINDING_PANIC
end

local bus = {}
function ns.On(event, fn) bus[event] = bus[event] or {}; table.insert(bus[event], fn) end
local unpack = unpack or table.unpack
-- Each listener runs on its own: one that fails does not stop the others. Its error is kept for /lm informe and still
-- goes to the game's error handler (BugGrabber, the default one) as any error would.
local function onError(err) if ns.OnError then ns.OnError(err) end; return err end
function ns.Fire(event, ...)
	local list = bus[event]
	if not list then return end
	local n, args = select("#", ...), { ... }
	for _, fn in ipairs(list) do
		local ok, err = xpcall(function() return fn(unpack(args, 1, n)) end, onError)
		if not ok then local h = geterrorhandler and geterrorhandler(); if h then h(err) end end
	end
end

function ns.Log(fmt, ...)
	if ns.db and ns.db.settings.debug then print("|cff7ec8ff" .. ns.TITLE .. "|r " .. string.format(fmt, ...)) end
end
-- An item's info: name, link, quality, ... On Forever only C_Item.GetItemInfo exists (the old global is gone).
function ns.ItemInfo(item)
	local fn = (C_Item and C_Item.GetItemInfo) or GetItemInfo
	if not fn or item == nil then return nil end
	return fn(item)
end
-- What happened on its own (a guildmate, the game): always in chat, where it stays.
-- Forever's secret values: a game result an addon may hold but not read (compare, add, format, index, iterate):
-- any read throws. Every game value that is compared, formatted or iterated goes through these.
function ns.Plain(v) if issecretvalue and issecretvalue(v) then return nil end; return v end
function ns.List(v) v = ns.Plain(v); if type(v) == "table" then return v end; return {} end   -- a list to iterate, or nothing
function ns.Same(a, b) local ok, eq = pcall(function() return a ~= nil and a == b end); return ok and eq == true end   -- GUIDs, names
-- The guild's name as a key for saved data ("?" when the game hides it: nothing is stored under a secret).
function ns.GuildKey()
	local ok, g = pcall(GetGuildInfo, "player")
	g = ok and ns.Plain(g) or nil
	return type(g) == "string" and g ~= "" and g or "?"
end
-- Chat from a click, when the game allows it (not in a chat lockdown); a refused send is false, never an error.
-- policy: click paths only (the chat boxes' Enter and buttons, Discord lines from the run actions)
function ns.SendChat(text, kind, lang, target)
	if InChatMessagingLockdown and InChatMessagingLockdown() then return false end
	return pcall(SendChatMessage, text, kind, lang, target) == true
end
function ns.Chat(fmt, ...) print("|cff7ec8ff" .. ns.TITLE .. "|r " .. string.format(fmt, ...)) end
-- What a click did: at the foot of the book while it is open, else in chat (and lines with a link: chat, to be clicked).
function ns.Say(fmt, ...)
	local text = string.format(fmt, ...)
	local B = ns.Board
	if B and B.frame and B.frame:IsShown() and B.Feedback and not text:find("|H", 1, true) then B.Feedback(text); return end
	print("|cff7ec8ff" .. ns.TITLE .. "|r " .. text)
end

-- Important notices: the chat line, and the same text in the middle of the screen when the option is on
-- (links shown as their plain "[name]").
function ns.Screen(text)
	if not (ns.db and ns.db.settings.screenNotices and UIErrorsFrame) then return end
	local plain = text:gsub("|H.-|h(.-)|h", "%1"):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|cn[^:]-:", ""):gsub("|r", "")
	UIErrorsFrame:AddMessage(plain, 1, 0.82, 0)
end
local function notice(where, text)
	print("|cff7ec8ff" .. ns.TITLE .. "|r " .. text)   -- notices always reach chat, book open or not
	ns.Screen(text)
	if ns.Tray then ns.Tray.Add(text, where) end   -- and the tray keeps them
end
function ns.Notice(fmt, ...) notice(nil, string.format(fmt, ...)) end
-- A notice that points to a tab of the book: the tray offers "Go" there.
function ns.NoticeAt(where, fmt, ...) notice(where, string.format(fmt, ...)) end

-- My name as the guild sees it. On Forever a character can be "Name Surname", and UnitName("player") then gives the
-- surname where the realm would go: put them back together (a realm there, from other clients, is no surname).
function ns.Me()
	local name, second = UnitName("player")
	if second and second ~= "" then
		local function norm(s) return (tostring(s or ""):lower():gsub("[^%w]", "")) end
		local realm = norm(GetRealmName())
		if norm(second) ~= realm and not (GetNormalizedRealmName and norm(second) == norm(GetNormalizedRealmName())) then
			return name .. " " .. second
		end
	end
	return name
end

-- A name as an id part: 8 hex digits of a hash of the whole name (accents and spaces included), so "Élia" and
-- "Ëlia" never share one and a name with no plain letters still has one.
function ns.NameKey(name)
	local h = 5381
	name = tostring(name or "")
	for i = 1, #name do h = (h * 33 + name:byte(i)) % 4294967296 end
	return string.format("%04x%04x", math.floor(h / 65536), h % 65536)
end

function ns.PlayerKey() return ns.Me() .. "-" .. GetRealmName() end

-- "Mario-ClassicBetaPvP" -> "Mario" when the realm is mine. Ambiguate() left my own realm in place on Forever,
-- so strip it here by comparing letters and digits only. One function for every place that compares names.
function ns.ShortName(full)
	local name = Ambiguate(full, "guild")
	local base, realm = name:match("^(.-)%-(.+)$")
	if base then
		local function norm(s) return (tostring(s or ""):lower():gsub("[^%w]", "")) end
		local mine = norm(GetRealmName())
		if norm(realm) == mine or (GetNormalizedRealmName and norm(realm) == norm(GetNormalizedRealmName())) then return base end
	end
	return name
end

local subs = {}
function ns.Slash(sub, fn) subs[sub] = fn end
SLASH_LEVELMATES1 = "/lm"; SLASH_LEVELMATES2 = "/levelmates"; SLASH_LEVELMATES3 = "/foreverguild"; SLASH_LEVELMATES4 = "/guildcompanion"
-- The commands, one line each, in chat (/lm help, /lm ?, or any command that does not exist).
function ns.ListCommands()
	ns.Chat(ns.L.CMD_TITLE)
	for _, c in ipairs(ns.L.CMD_LIST or {}) do print("  |cffffd100/lm " .. c[1] .. "|r  " .. c[2]) end
end
SlashCmdList["LEVELMATES"] = function(msg)
	msg = strtrim(msg or "")
	if msg == "" then ns.Fire("LM_TOGGLE_BOARD"); return end
	local sub, rest = msg:match("^(%S+)%s*(.-)$")
	local fn = subs[sub and sub:lower() or ""]
	if fn then fn(rest)
	elseif sub == "?" or sub:lower() == "help" or sub:lower() == "comandos" or sub:lower() == "commands" then ns.ListCommands()
	else ns.Chat(ns.L.CMD_UNKNOWN, sub); ns.ListCommands() end
end
-- Tab moves the focus along a form's boxes (Shift+Tab back), as the game's own forms do.
function ns.TabOrder(boxes)
	for i, box in ipairs(boxes) do
		box:SetScript("OnTabPressed", function()
			local step = (IsShiftKeyDown and IsShiftKeyDown()) and -1 or 1
			local nextBox = boxes[(i - 1 + step) % #boxes + 1]
			nextBox:SetFocus()
		end)
	end
end

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("PLAYER_LOGOUT")
f:SetScript("OnEvent", function(_, event, arg1, ...)
	if event == "ADDON_LOADED" then
		if arg1 ~= ADDON then return end
		LevelMatesDB = LevelMatesDB or { version = 1, settings = {}, chars = {} }
		ns.db = LevelMatesDB
		ns.db.settings = ns.db.settings or {}
		for k, v in pairs(DEFAULTS) do if ns.db.settings[k] == nil then ns.db.settings[k] = v end end
		ns.db.chars = ns.db.chars or {}
		local key = ns.PlayerKey()
		ns.db.chars[key] = ns.db.chars[key] or {}
		ns.char = ns.db.chars[key]
		ns.ApplyLocale()
		ns.Fire("LM_LOADED")
	elseif event == "PLAYER_ENTERING_WORLD" then
		ns.Fire("LM_WORLD", arg1, ...)   -- isInitialLogin, isReloadingUi
	elseif event == "PLAYER_LOGOUT" then
		ns.Fire("LM_LOGOUT")
	end
end)
