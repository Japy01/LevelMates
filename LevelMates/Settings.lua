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

-- Three pages so nobody gets lost: General (the main switch, language, minimap, sound, transport), Share (what goes
-- to the guild) and Notices (what may pop up). A client without sub-pages gets them all on the one page.
S.pages = {}
function S.AllSettings()
	local out = {}
	for _, page in ipairs(S.pages) do for _, st in ipairs(page.settings or {}) do out[#out + 1] = st end end
	return out
end
local function Sub(parent, name)
	if Settings.RegisterVerticalLayoutSubcategory then
		local sub = Settings.RegisterVerticalLayoutSubcategory(parent, name)
		S.pages[#S.pages + 1] = sub
		return sub
	end
	return parent
end

ns.On("LM_LOADED", function()
	local category = Settings.RegisterVerticalLayoutCategory(L.BOARD_TITLE)
	S.category = category
	S.pages[1] = category
	-- General
	Bool(category, "share", L.OPT_SHARE, L.OPT_SHARE_TT, function(v) if v then ns.Comm.Start() else ns.Comm.Stop() end; ns.Fire("LM_ROSTER_CHANGED") end)
	-- my role in runs: three radio-like checkboxes (also on the Groups tab)
	for _, role in ipairs({ "T", "H", "D" }) do
		local proxy = Settings.RegisterProxySetting(category, "LevelMates_role_" .. role, Settings.VarType.Boolean, L["OPT_ROLE_" .. role], false,
			function() return ns.Roles.Mine() == role end,
			function(v) if v then ns.Roles.Set(role) end end)
		Settings.CreateCheckbox(category, proxy, L.OPT_ROLE_TT)
		table.insert(category.settings or {}, proxy)
	end
	-- language: three radio-like checkboxes; a change asks for a reload (the texts are read at load)
	local function Lang(value, name)
		local proxy = Settings.RegisterProxySetting(category, "LevelMates_language_" .. value, Settings.VarType.Boolean, name, (ns.db.settings.language or "auto") == value,
			function() return (ns.db.settings.language or "auto") == value end,
			function(v) if v and ns.db.settings.language ~= value then ns.db.settings.language = value; S.OfferReload() end end)
		Settings.CreateCheckbox(category, proxy, L.OPT_LANGUAGE_TT)
	end
	Lang("auto", L.OPT_LANGUAGE .. ": " .. L.LANGUAGE_AUTO)
	Lang("enUS", L.OPT_LANGUAGE .. ": English")
	Lang("esES", L.OPT_LANGUAGE .. ": Español")
	Bool(category, "minimap", L.OPT_MINIMAP, L.OPT_MINIMAP_TT, function() ns.Fire("LM_MINIMAP_CHANGED") end)
	Bool(category, "sound", L.OPT_SOUND)
	Bool(category, "mapPins", L.OPT_MAP, L.OPT_MAP_TT, function() ns.GuildMap.Refresh() end)
	Bool(category, "mapNames", L.OPT_MAP_NAMES, L.OPT_MAP_NAMES_TT, function() ns.GuildMap.Refresh() end)
	Bool(category, "groupXp", L.OPT_GROUPXP, L.OPT_GROUPXP_TT, function() ns.GroupXP.Send(true); ns.GroupXP.Refresh() end)
	Bool(category, "readChatAds", L.OPT_CHAT_ADS, L.OPT_CHAT_ADS_TT, function() ns.Fire("LM_LFG_CHANGED") end)
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
	-- Share: what goes to the guild
	local share = Sub(category, L.OPT_PAGE_SHARE)
	Bool(share, "sharePos", L.OPT_POS, L.OPT_POS_TT, function() ns.Roster.SendHeartbeat(true) end)
	Bool(share, "shareBank", L.OPT_BANK, L.OPT_BANK_TT)
	Bool(share, "shareGear", L.OPT_GEAR, L.OPT_GEAR_TT)
	Bool(share, "shareQuests", L.OPT_QUESTS, L.OPT_QUESTS_TT, function(v) if v then ns.Roster.SendQuests() else ns.Roster.WithdrawQuests() end end)
	Bool(share, "shareXp", L.OPT_XPH, L.OPT_XPH_TT)
	Bool(share, "shareRested", L.OPT_RESTED, L.OPT_RESTED_TT, function(v) ns.Rested.SetSharing(v) end)
	Bool(share, "shareProfessions", L.OPT_PROFS, L.OPT_PROFS_TT, function(v) ns.Professions.SetSharing(v) end)
	Bool(share, "shareBuild", L.OPT_BUILD, L.OPT_BUILD_TT, function() ns.Builds.SetSharing() end)
	Bool(share, "shareAlts", L.OPT_ALTS, L.OPT_ALTS_TT, function() ns.Alts.SetSharing() end)
	Bool(share, "sharePoints", L.OPT_POINTS, L.OPT_POINTS_TT, function() ns.Points.SetSharing() end)
	Bool(share, "shareAchievements", L.OPT_ACH, L.OPT_ACH_TT, function() ns.Achievements.SetSharing() end)
	Bool(share, "shareFeed", L.OPT_FEED, L.OPT_FEED_TT)
	Bool(share, "feedLoot", L.OPT_FEED_LOOT, L.OPT_FEED_LOOT_TT)
	Bool(share, "shareDeaths", L.OPT_DEATHS, L.OPT_DEATHS_TT)
	-- Notices: what may pop up
	local notices = Sub(category, L.OPT_PAGE_NOTICES)
	-- Quiet: one switch for the lesser notices, the screen messages and the sound; help, groups and goals stay
	local quiet = Settings.RegisterProxySetting(notices, "LevelMates_quiet", Settings.VarType.Boolean, L.OPT_QUIET, false,
		function() return S.IsQuiet() end, function(v) S.SetQuiet(v) end)
	Settings.CreateCheckbox(notices, quiet, L.OPT_QUIET_TT)
	Bool(notices, "screenNotices", L.OPT_SCREEN, L.OPT_SCREEN_TT)
	Bool(notices, "stripNotices", L.OPT_STRIP, L.OPT_STRIP_TT)
	Bool(notices, "levelBar", L.OPT_LEVELBAR, L.OPT_LEVELBAR_TT, function(v) ns.LevelBar.Toggle(v) end)
	Bool(notices, "helpNotices", L.OPT_HELP, L.OPT_HELP_TT)
	Bool(notices, "lfgNotices", L.OPT_LFG, L.OPT_LFG_TT)
	Bool(notices, "goalNotices", L.OPT_GOAL, L.OPT_GOAL_TT)
	Bool(notices, "levelNotices", L.OPT_LEVELUP, L.OPT_LEVELUP_TT)
	Bool(notices, "matchNotices", L.OPT_MATCH, L.OPT_MATCH_TT)
	Bool(notices, "palNotices", L.OPT_PAL, L.OPT_PAL_TT)
	Bool(notices, "wishNotices", L.OPT_WISH, L.OPT_WISH_TT)
	Bool(notices, "rareNotices", L.OPT_RARE, L.OPT_RARE_TT)
	Bool(notices, "askNotices", L.OPT_ASK, L.OPT_ASK_TT)
	Bool(notices, "trainerNotices", L.OPT_TRAINER, L.OPT_TRAINER_TT)
	Bool(notices, "restedNotices", L.OPT_RESTED_NOTICE, L.OPT_RESTED_NOTICE_TT)
	Settings.RegisterAddOnCategory(category)
end)

S.QUIET_KEYS = { "matchNotices", "palNotices", "restedNotices", "wishNotices", "levelNotices", "rareNotices", "askNotices", "trainerNotices", "screenNotices", "sound", "stripNotices", "dingBanner" }
function S.IsQuiet() return ns.db.settings.quietSaved ~= nil end
-- On: the lesser notices off, what they were kept to come back; off: as they were.
function S.SetQuiet(on)
	local st = ns.db.settings
	if on and not st.quietSaved then
		st.quietSaved = {}
		for _, k in ipairs(S.QUIET_KEYS) do st.quietSaved[k] = st[k]; st[k] = false end
	elseif not on and st.quietSaved then
		for _, k in ipairs(S.QUIET_KEYS) do if st.quietSaved[k] ~= nil then st[k] = st.quietSaved[k] end end
		st.quietSaved = nil
	end
end

function S.OfferReload()
	StaticPopupDialogs["LEVELMATES_RELOAD"] = StaticPopupDialogs["LEVELMATES_RELOAD"] or {
		text = L.LANGUAGE_RELOAD, button1 = L.BTN_RELOAD, button2 = CANCEL,
		timeout = 0, whileDead = true, hideOnEscape = true,
		OnAccept = function() ReloadUI() end,
	}
	StaticPopup_Show("LEVELMATES_RELOAD")
end

function S.Open() if S.category then Settings.OpenToCategory(S.category:GetID()) end end
ns.Slash("options", S.Open); ns.Slash("opciones", S.Open)
ns.Slash("debug", function()
	local c = ns.Comm.stats
	ns.Chat(L.STATUS, #ns.Roster.List(), ns.Comm.ActiveTransport(), c.sent, c.received, c.bad)
	ns.Chat(L.STATUS_QUEUE, c.queued, c.held or 0, c.dropped or 0)
	-- memory counts what was allocated, not what is kept: before and after a collection tells churn from a leak
	if UpdateAddOnMemoryUsage and GetAddOnMemoryUsage then
		UpdateAddOnMemoryUsage(); local before = GetAddOnMemoryUsage("LevelMates")
		pcall(collectgarbage, "collect")
		UpdateAddOnMemoryUsage(); local after = GetAddOnMemoryUsage("LevelMates")
		ns.Chat(L.STATUS_MEMORY, before, after)
	end
end)
