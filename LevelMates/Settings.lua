-- Settings.lua: options page (privacy switches, notices, transport). Pure UI over ns.db.settings.
local ADDON, ns = ...
local S = {}
ns.Settings = S
local L = ns.L

local function Bool(category, key, name, tooltip, onChange)
	local setting = Settings.RegisterAddOnSetting(category, "LevelMates_" .. key, key, ns.db.settings, Settings.VarType.Boolean, name, ns.DEFAULTS[key])   -- the panel's Defaults button restores the shipped value
	if onChange then setting:SetValueChangedCallback(function(_, v) onChange(v) end) end
	Settings.CreateCheckbox(category, setting, tooltip)
	return setting
end

ns.On("LM_LOADED", function()
	local category = Settings.RegisterVerticalLayoutCategory(L.BOARD_TITLE)
	S.category = category
	Bool(category, "share", L.OPT_SHARE, L.OPT_SHARE_TT, function(v) if v then ns.Comm.Start() else ns.Comm.Stop() end; ns.Fire("LM_ROSTER_CHANGED") end)
	Bool(category, "sharePos", L.OPT_POS, L.OPT_POS_TT, function() ns.Roster.SendHeartbeat(true) end)
	Bool(category, "shareQuests", L.OPT_QUESTS, L.OPT_QUESTS_TT, function(v) if v then ns.Roster.SendQuests() end end)
	Bool(category, "shareXp", L.OPT_XPH, L.OPT_XPH_TT)
	Bool(category, "shareRested", L.OPT_RESTED, L.OPT_RESTED_TT, function(v) ns.Rested.SetSharing(v) end)
	Bool(category, "matchNotices", L.OPT_MATCH, L.OPT_MATCH_TT)
	Bool(category, "helpNotices", L.OPT_HELP, L.OPT_HELP_TT)
	Bool(category, "lfgNotices", L.OPT_LFG, L.OPT_LFG_TT)
	Bool(category, "palNotices", L.OPT_PAL, L.OPT_PAL_TT)
	Bool(category, "restedNotices", L.OPT_RESTED_NOTICE, L.OPT_RESTED_NOTICE_TT)
	Bool(category, "sound", L.OPT_SOUND)
	Bool(category, "minimap", L.OPT_MINIMAP, L.OPT_MINIMAP_TT, function() ns.Fire("LM_MINIMAP_CHANGED") end)
	-- transport as three radio-like checkboxes (no dropdowns on Forever)
	local function Radio(key, value, name)
		local proxy = Settings.RegisterProxySetting(category, "LevelMates_transport_" .. value, Settings.VarType.Boolean, name, ns.db.settings.transport == value,
			function() return ns.db.settings.transport == value end,
			function(v) if v then ns.db.settings.transport = value; if ns.Comm.IsReady() then ns.Comm.Stop(); ns.Comm.Start() end end end)
		Settings.CreateCheckbox(category, proxy, L.OPT_TRANSPORT_TT)
	end
	Radio("transport", "auto", L.OPT_TRANSPORT .. ": " .. L.TRANSPORT_AUTO)
	Radio("transport", "guild", L.OPT_TRANSPORT .. ": " .. L.TRANSPORT_GUILD)
	Radio("transport", "channel", L.OPT_TRANSPORT .. ": " .. L.TRANSPORT_CHANNEL)
	Bool(category, "debug", L.OPT_DEBUG)
	Settings.RegisterAddOnCategory(category)
end)

function S.Open() if S.category then Settings.OpenToCategory(S.category:GetID()) end end
ns.Slash("options", S.Open); ns.Slash("opciones", S.Open)
ns.Slash("debug", function()
	local c = ns.Comm.stats
	ns.Say(L.STATUS, #ns.Roster.List(), ns.Comm.ActiveTransport(), c.sent, c.received, c.bad)
end)
