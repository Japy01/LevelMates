-- Settings.lua: options page (privacy switches, notices, transport). Pure UI over ns.db.settings.
local ADDON, ns = ...
local S = {}
ns.Settings = S
local L = ns.L

S.byKey = {}   -- the switch objects by their key: quiet mode tells the ones it changes to redraw
local function Bool(category, key, name, tooltip, onChange)
	local setting = Settings.RegisterAddOnSetting(category, "LevelMates_" .. key, key, ns.db.settings, Settings.VarType.Boolean, name, ns.DEFAULTS[key])   -- the panel's Defaults button restores the shipped value
	if onChange then setting:SetValueChangedCallback(function(_, v) onChange(v) end) end
	Settings.CreateCheckbox(category, setting, tooltip)
	S.byKey[key] = setting
	return setting
end
-- A button on a page (the game's own), nothing when the client lacks it.
local function Button(category, name, text, click, tooltip)
	pcall(function()
		local layout = SettingsPanel and SettingsPanel.GetLayout and SettingsPanel:GetLayout(category)
		if layout and CreateSettingsButtonInitializer then layout:AddInitializer(CreateSettingsButtonInitializer(name, text, click, tooltip)) end
	end)
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

-- A section header on a page (the game's own, as its settings pages have them); nothing when the client lacks it.
local function Header(category, name)
	pcall(function()
		local layout = SettingsPanel and SettingsPanel.GetLayout and SettingsPanel:GetLayout(category)
		if layout and CreateSettingsListSectionHeaderInitializer then layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(name)) end
	end)
end
-- One of several: a dropdown where the client has them, else one checkbox per choice (as before).
local function Choice(category, var, name, tooltip, choices, get, set)
	if Settings.CreateDropdown and Settings.CreateControlTextContainer then
		local proxy = Settings.RegisterProxySetting(category, "LevelMates_" .. var, Settings.VarType.String, name, choices[1].value, get, set)
		local function options()
			local c = Settings.CreateControlTextContainer()
			for _, ch in ipairs(choices) do c:Add(ch.value, ch.label) end
			return c:GetData()
		end
		Settings.CreateDropdown(category, proxy, options, tooltip)
		return proxy
	end
	for _, ch in ipairs(choices) do
		local proxy = Settings.RegisterProxySetting(category, "LevelMates_" .. var .. "_" .. ch.value, Settings.VarType.Boolean, name .. ": " .. ch.label, get() == ch.value,
			function() return get() == ch.value end,
			function(v) if v then set(ch.value) end end)
		Settings.CreateCheckbox(category, proxy, tooltip)
	end
end

ns.On("LM_LOADED", function()
	local category = Settings.RegisterVerticalLayoutCategory(L.BOARD_TITLE)
	S.category = category
	S.pages[1] = category
	-- General: you, the book, map and group, the connection
	Header(category, L.OPT_H_ME)
	Bool(category, "share", L.OPT_SHARE, L.OPT_SHARE_TT, function(v) if v then ns.Comm.Start() else ns.Comm.Stop() end; ns.Fire("LM_ROSTER_CHANGED") end)
	Choice(category, "role", L.OPT_ROLE, L.OPT_ROLE_TT, { { value = "T", label = L.ROLE_T }, { value = "H", label = L.ROLE_H }, { value = "D", label = L.ROLE_D } },
		function() return (ns.Roles.Of(ns.Me())) end, function(v) ns.Roles.Set(v) end)
	Choice(category, "language", L.OPT_LANGUAGE, L.OPT_LANGUAGE_TT, { { value = "auto", label = L.LANGUAGE_AUTO }, { value = "enUS", label = "English" }, { value = "esES", label = "Español" } },
		function() return ns.db.settings.language or "auto" end,
		function(v) if ns.db.settings.language ~= v then ns.db.settings.language = v; S.OfferReload() end end)
	Header(category, L.OPT_H_BOOK)
	-- the book's size: a slider where the client has one, else three choices
	if Settings.CreateSliderOptions and Settings.CreateSlider then
		local size = Settings.RegisterProxySetting(category, "LevelMates_boardScale", Settings.VarType.Number, L.OPT_SIZE, 100,
			function() return ns.db.settings.boardScale or 100 end, function(v) ns.Board.SetScale(v) end)
		local options = Settings.CreateSliderOptions(ns.Board.SCALE_MIN or 80, ns.Board.SCALE_MAX or 150, 5)
		if options.SetLabelFormatter and MinimalSliderWithSteppersMixin then options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, function(v) return math.floor(v) .. "%" end) end
		Settings.CreateSlider(category, size, options, L.OPT_SIZE_TT)
	else
		Choice(category, "size", L.OPT_SIZE, L.OPT_SIZE_TT, { { value = "100", label = L.SIZE_NORMAL }, { value = "115", label = L.SIZE_BIG }, { value = "130", label = L.SIZE_HUGE } },
			function() return tostring(ns.db.settings.boardScale or 100) end, function(v) ns.Board.SetScale(tonumber(v)) end)
	end
	-- the ink: how dark the writing is, 1 (lightest) to 5 (darkest)
	if Settings.CreateSliderOptions and Settings.CreateSlider then
		local ink = Settings.RegisterProxySetting(category, "LevelMates_ink", Settings.VarType.Number, L.OPT_INK, 4,
			function() return ns.Skin.InkLevel() end, function(v) ns.db.settings.ink = math.floor(v); ns.Skin.InkPass() end)
		Settings.CreateSlider(category, ink, Settings.CreateSliderOptions(1, #ns.Skin.INK_LEVELS, 1), L.OPT_INK_TT)
	end
	Button(category, L.OPT_RESET_POS, L.OPT_RESET_POS_BTN, function() ns.Board.ResetPosition() end, L.OPT_RESET_POS_TT)
	Bool(category, "minimap", L.OPT_MINIMAP, L.OPT_MINIMAP_TT, function() ns.Fire("LM_MINIMAP_CHANGED") end)
	Bool(category, "sound", L.OPT_SOUND)
	Header(category, L.OPT_H_MAP)
	Bool(category, "mapPins", L.OPT_MAP, L.OPT_MAP_TT, function() ns.GuildMap.Refresh() end)
	Bool(category, "mapNames", L.OPT_MAP_NAMES, L.OPT_MAP_NAMES_TT, function() ns.GuildMap.Refresh() end)
	Bool(category, "groupXp", L.OPT_GROUPXP, L.OPT_GROUPXP_TT, function() ns.GroupXP.Send(true); ns.GroupXP.Refresh() end)
	Bool(category, "readChatAds", L.OPT_CHAT_ADS, L.OPT_CHAT_ADS_TT, function() ns.Fire("LM_LFG_CHANGED") end)
	Header(category, L.OPT_H_LINK)
	Choice(category, "transport", L.OPT_TRANSPORT, L.OPT_TRANSPORT_TT, { { value = "auto", label = L.TRANSPORT_AUTO }, { value = "guild", label = L.TRANSPORT_GUILD }, { value = "channel", label = L.TRANSPORT_CHANNEL } },
		function() return ns.db.settings.transport or "auto" end,
		function(v) if ns.db.settings.transport ~= v then ns.db.settings.transport = v; if ns.Comm.IsReady() then ns.Comm.Stop(); ns.Comm.Start() end end end)
	Bool(category, "debug", L.OPT_DEBUG)
	-- Share: what goes to the guild
	local share = Sub(category, L.OPT_PAGE_SHARE)
	Header(share, L.OPT_H_WHERE)
	Bool(share, "sharePos", L.OPT_POS, L.OPT_POS_TT, function() ns.Roster.SendHeartbeat(true) end)
	Bool(share, "shareQuests", L.OPT_QUESTS, L.OPT_QUESTS_TT, function(v) if v then ns.Roster.SendQuests() else ns.Roster.WithdrawQuests() end end)
	Bool(share, "shareXp", L.OPT_XPH, L.OPT_XPH_TT)
	Bool(share, "shareRested", L.OPT_RESTED, L.OPT_RESTED_TT, function(v) ns.Rested.SetSharing(v) end)
	Header(share, L.OPT_H_CHAR)
	Bool(share, "shareGear", L.OPT_GEAR, L.OPT_GEAR_TT)
	Bool(share, "shareBuild", L.OPT_BUILD, L.OPT_BUILD_TT, function() ns.Builds.SetSharing() end)
	Bool(share, "shareProfessions", L.OPT_PROFS, L.OPT_PROFS_TT, function(v) ns.Professions.SetSharing(v) end)
	Bool(share, "shareAlts", L.OPT_ALTS, L.OPT_ALTS_TT, function() ns.Alts.SetSharing() end)
	Bool(share, "sharePoints", L.OPT_POINTS, L.OPT_POINTS_TT, function() ns.Points.SetSharing() end)
	Bool(share, "shareAchievements", L.OPT_ACH, L.OPT_ACH_TT, function() ns.Achievements.SetSharing() end)
	Header(share, L.OPT_H_GUILD)
	Bool(share, "shareBank", L.OPT_BANK, L.OPT_BANK_TT)
	Bool(share, "shareFeed", L.OPT_FEED, L.OPT_FEED_TT)
	Bool(share, "feedLoot", L.OPT_FEED_LOOT, L.OPT_FEED_LOOT_TT)
	Bool(share, "shareDeaths", L.OPT_DEATHS, L.OPT_DEATHS_TT)
	Header(share, L.OPT_H_DISCORD)
	Bool(share, "discordTag", L.OPT_DISCORD_TAG, L.OPT_DISCORD_TAG_TT)
	-- for the whole guild: only the guild master or an officer can change it; everyone sees what it is
	local guildTag = Settings.RegisterProxySetting(share, "LevelMates_guildTag", Settings.VarType.Boolean, L.OPT_GUILD_TAG, false,
		function() return ns.GuildNotes.GuildTag() end,
		function(v) if v ~= ns.GuildNotes.GuildTag() then ns.GuildNotes.SetGuildTag(v) end end)
	Settings.CreateCheckbox(share, guildTag, L.OPT_GUILD_TAG_TT)
	Bool(share, "discordTagOff", L.OPT_TAG_OFF, L.OPT_TAG_OFF_TT)
	-- Notices: what may pop up
	local notices = Sub(category, L.OPT_PAGE_NOTICES)
	Header(notices, L.OPT_H_GENERAL)
	-- Quiet: one switch for the lesser notices, the screen messages and the sound; help, groups and goals stay
	local quiet = Settings.RegisterProxySetting(notices, "LevelMates_quiet", Settings.VarType.Boolean, L.OPT_QUIET, false,
		function() return S.IsQuiet() end, function(v) S.SetQuiet(v) end)
	Settings.CreateCheckbox(notices, quiet, L.OPT_QUIET_TT)
	Bool(notices, "screenNotices", L.OPT_SCREEN, L.OPT_SCREEN_TT)
	Bool(notices, "stripNotices", L.OPT_STRIP, L.OPT_STRIP_TT)
	Bool(notices, "levelBar", L.OPT_LEVELBAR, L.OPT_LEVELBAR_TT, function(v) ns.LevelBar.Toggle(v) end)
	Bool(notices, "dingBanner", L.OPT_DING, L.OPT_DING_TT)
	Header(notices, L.OPT_H_ABOUT)
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
	for _, k in ipairs(S.QUIET_KEYS) do   -- the switches on the page show their new state at once
		local s = S.byKey[k]
		if s and s.NotifyUpdate then pcall(s.NotifyUpdate, s) end
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
