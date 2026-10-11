-- Core.lua: SavedVariables, event bus, slash commands. Nothing here talks to other players.
local ADDON, ns = ...
ns.VERSION = C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(ADDON, "Version") or "dev"

local DEFAULTS = {
	share = true, sharePos = false, shareQuests = false, shareXp = false, shareRested = false,
	matchNotices = true, helpNotices = true, lfgNotices = true, palNotices = true, restedNotices = true, goalNotices = true, wishNotices = true, screenNotices = true, levelNotices = true, shareProfessions = true, shareFeed = true, feedLoot = true, rareNotices = true, mapPins = true, readChatAds = true, shareBuild = true, shareDeaths = true, trainerNotices = true, groupXp = true, askNotices = true, shareAlts = true, sharePoints = true, sound = true, minimap = true,
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
function ns.Fire(event, ...) local list = bus[event]; if not list then return end; for _, fn in ipairs(list) do fn(...) end end

function ns.Log(fmt, ...)
	if ns.db and ns.db.settings.debug then print("|cff7ec8ffLevelMates|r " .. string.format(fmt, ...)) end
end
function ns.Say(fmt, ...) print("|cff7ec8ffLevelMates|r " .. string.format(fmt, ...)) end

-- Important notices: the chat line, and the same text in the middle of the screen when the option is on
-- (links shown as their plain "[name]").
function ns.Screen(text)
	if not (ns.db and ns.db.settings.screenNotices and UIErrorsFrame) then return end
	local plain = text:gsub("|H.-|h(.-)|h", "%1"):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|cn[^:]-:", ""):gsub("|r", "")
	UIErrorsFrame:AddMessage(plain, 1, 0.82, 0)
end
function ns.Notice(fmt, ...)
	local text = string.format(fmt, ...)
	ns.Say("%s", text)
	ns.Screen(text)
end

function ns.PlayerKey()
	local name, realm = UnitName("player")
	realm = realm and realm ~= "" and realm or GetRealmName()
	return name .. "-" .. realm
end

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
SLASH_LEVELMATES1 = "/lm"; SLASH_LEVELMATES2 = "/levelmates"
SlashCmdList["LEVELMATES"] = function(msg)
	msg = strtrim(msg or "")
	local sub, rest = msg:match("^(%S+)%s*(.-)$")
	local fn = subs[sub and sub:lower() or ""]
	if fn then fn(rest) else ns.Fire("LM_TOGGLE_BOARD") end
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
