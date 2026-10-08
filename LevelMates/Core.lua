-- Core.lua: SavedVariables, event bus, slash commands. Nothing here talks to other players.
local ADDON, ns = ...
ns.VERSION = C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(ADDON, "Version") or "dev"

local DEFAULTS = {
	share = true, sharePos = false, shareQuests = false, shareXp = false,
	matchNotices = true, helpNotices = true, sound = true, minimap = true,
	transport = "auto", debug = false,
}

local bus = {}
function ns.On(event, fn) bus[event] = bus[event] or {}; table.insert(bus[event], fn) end
function ns.Fire(event, ...) local list = bus[event]; if not list then return end; for _, fn in ipairs(list) do fn(...) end end

function ns.Log(fmt, ...)
	if ns.db and ns.db.settings.debug then print("|cff7ec8ffLevelMates|r " .. string.format(fmt, ...)) end
end
function ns.Say(fmt, ...) print("|cff7ec8ffLevelMates|r " .. string.format(fmt, ...)) end

function ns.PlayerKey()
	local name, realm = UnitName("player")
	realm = realm and realm ~= "" and realm or GetRealmName()
	return name .. "-" .. realm
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
		ns.Fire("LM_LOADED")
	elseif event == "PLAYER_ENTERING_WORLD" then
		ns.Fire("LM_WORLD", arg1, ...)   -- isInitialLogin, isReloadingUi
	elseif event == "PLAYER_LOGOUT" then
		ns.Fire("LM_LOGOUT")
	end
end)
