-- Minimal stub of the WoW client API for running addon logic under plain Lua 5.1 / fengari.
-- Loaded by run-lua-test.mjs before the addon files. Extend per project; keep it honest:
-- everything here mimics the real API shape documented in api-reference.md.
STUB = { events = {}, timers = {}, sent = {}, frames = {}, now = 0, prefixes = {} }

function GetTime() return STUB.now end
-- Advance the clock, firing every due timer in time order; a repeating ticker fires once per
-- interval (Advance(30) on a 0.2 s ticker = 150 calls), as the real client would.
function STUB.Advance(seconds)
	local target = STUB.now + seconds
	STUB.ResolveChannelJoins()
	while true do
		local idx, best
		for i, t in ipairs(STUB.timers) do
			if t.at <= target and (not best or t.at < best.at) then idx, best = i, t end
		end
		if not best then break end
		table.remove(STUB.timers, idx)
		if best.at > STUB.now then STUB.now = best.at end
		if not best.cancelled then
			best.fn()
			if best.every and best.every > 0 and not best.cancelled then best.at = STUB.now + best.every; STUB.timers[#STUB.timers + 1] = best end
		end
	end
	STUB.now = target
end
C_Timer = {
	After = function(sec, fn) STUB.timers[#STUB.timers + 1] = { at = STUB.now + sec, fn = fn } end,
	NewTicker = function(sec, fn, n)
		local t = { at = STUB.now + sec, fn = fn, every = sec }
		function t:Cancel() self.cancelled = true end
		STUB.timers[#STUB.timers + 1] = t
		return t
	end,
}

function STUB.Fire(event, ...)
	for _, f in ipairs(STUB.frames) do
		if f.registered[event] and f.scripts.OnEvent then f.scripts.OnEvent(f, event, ...) end
	end
end

local Region = {}
Region.__index = Region
function Region:SetPoint(...) self.point = { ... } end
function Region:ClearAllPoints() self.point = nil end
function Region:GetEffectiveScale() return 1 end
function Region:GetCenter() local c = STUB.minimapCenter or { 100, 100 }; return c[1], c[2] end
function Region:GetFrameLevel() return self.frameLevel or 1 end
function Region:SetSize(w, h) self.w, self.h = w, h end
function Region:SetWidth(w) self.w = w end
function Region:SetHeight(h) self.h = h end
function Region:GetWidth() return self.w or 0 end
function Region:GetHeight() return self.h or 0 end
function Region:Show() local was = self.shown; self.shown = true; if not was and self.scripts and self.scripts.OnShow then self.scripts.OnShow(self) end end
function Region:Hide() local was = self.shown; self.shown = false; if was and self.scripts and self.scripts.OnHide then self.scripts.OnHide(self) end end
function Region:SetShown(v) if v then self:Show() else self:Hide() end end
function Region:EnableMouseWheel(v) self.wheel = v and true or false end
function Region:SetHyperlinksEnabled(v) self.hyperlinks = v and true or false end
-- a ScrollingMessageFrame: its lines in .messages
function Region:AddMessage(text, r, g, b) self.messages = self.messages or {}; self.messages[#self.messages + 1] = { text = text, r = r, g = g, b = b } end
function Region:Clear() self.messages = {}; self.clears = (self.clears or 0) + 1 end
function Region:SetMaxLines(n) self.maxLines = n end
function Region:SetFading(v) self.fading = v end
function Region:SetInsertMode() end
function Region:SetIndentedWordWrap() end
function Region:SetTextCopyable() end
function Region:ScrollUp() end
function Region:ScrollDown() end
function Region:ScrollToTop() end
function Region:ScrollToBottom() self.scrolledToBottom = true end
function Region:PageUp() end
function Region:PageDown() end
function Region:AtBottom() return self.atBottom ~= false end
function Region:IsShown() return self.shown == true end
function Region:SetText(t) self.text = t end
function Region:GetText() return self.text end
function Region:SetTextColor(r, g, b) self.color = { r, g, b } end
function Region:SetAllPoints() end
function Region:SetEnabled(v) self.enabled = v and true or false end
function Region:IsEnabled() return self.enabled ~= false end
function Region:SetAutoFocus() end
function Region:SetMaxLetters() end
function Region:SetTexCoord(l, r, t, b) self.texcoord = { l, r, t, b } end
function Region:SetHighlightTexture() end
function Region:SetJustifyH() end
function Region:SetWordWrap(v) self.wordWrap = v end
function Region:SetJustifyV() end
function Region:SetAlpha() end
function Region:SetScale(s) self.scale = s end
function Region:GetScale() return self.scale or 1 end
function Region:GetID() return self.id or 0 end
function Region:SetID(id) self.id = id end
function Region:SetFrameStrata(s) self.strata = s end
function Region:GetFrameStrata() return self.strata or "MEDIUM" end
function Region:SetFrameLevel(v) self.frameLevel = v end
function Region:SetMovable() end
function Region:EnableMouse() end
function Region:SetClampedToScreen() end
function Region:RegisterForDrag() end
function Region:StartMoving() end
function Region:StopMovingOrSizing() end
function Region:SetBackdrop() end
function Region:SetColorTexture(r, g, b, a) self.colorTexture = { r, g, b, a } end
function Region:SetTexture(t) self.atlas = nil; self.texture = t end
function Region:SetAtlas(a) self.atlas = a; self.texcoord = nil end
function Region:SetChecked(v) self.checked = v end
function Region:GetChecked() return self.checked end
function Region:CreateFontString() local r = setmetatable({ shown = true, kind = "FontString", parent = self }, Region); self.regions = self.regions or {}; table.insert(self.regions, r); return r end
function Region:CreateTexture() local r = setmetatable({ shown = true, kind = "Texture", parent = self }, Region); self.regions = self.regions or {}; table.insert(self.regions, r); return r end
function Region:GetRegions() return (table.unpack or unpack)(self.regions or {}) end
function Region:GetChildren() return (table.unpack or unpack)(self.children or {}) end
function Region:GetObjectType() return self.kind or "Frame" end
function Region:RegisterEvent(e) self.registered[e] = true end
function Region:UnregisterEvent(e) self.registered[e] = nil end
function Region:UnregisterAllEvents() self.registered = {} end
function Region:SetScript(name, fn) self.scripts[name] = fn end
function Region:GetScript(name) return self.scripts[name] end
function Region:HookScript(name, fn) local old = self.scripts[name]; self.scripts[name] = function(...) if old then old(...) end fn(...) end end
function Region:GetParent() return self.parent end

function CreateFrame(kind, name, parent, template)
	local f = setmetatable({ kind = kind, name = name, parent = parent, template = template, registered = {}, scripts = {}, shown = true, TitleText = setmetatable({}, Region) }, Region)
	STUB.frames[#STUB.frames + 1] = f
	if type(parent) == "table" then parent.children = parent.children or {}; table.insert(parent.children, f) end
	if name then _G[name] = f end
	return f
end
UIParent = CreateFrame("Frame", "UIParent")
UISpecialFrames = {}
SlashCmdList = {}

C_ChatInfo = {
	RegisterAddonMessagePrefix = function(p) STUB.prefixes[p] = true; return 0 end,
	IsAddonMessagePrefixRegistered = function(p) return STUB.prefixes[p] == true end,
	SendAddonMessage = function(prefix, msg, chatType, target)
		if #msg > 255 then return 2 end
		if STUB.lockdown then return 11 end
		if (STUB.throttleNext or 0) > 0 then STUB.throttleNext = STUB.throttleNext - 1; return 3 end
		if chatType == "CHANNEL" and not STUB.joinedChannelIds[target] then return 7 end
		STUB.sent[#STUB.sent + 1] = { prefix = prefix, msg = msg, chatType = chatType or "PARTY", target = target, at = STUB.now }
		return 0
	end,
	-- STUB.reportsRestricted: the restriction flags read true on Forever even outside combat (spike), while sends still succeed.
	InChatMessagingLockdown = function() return STUB.lockdown == true or STUB.reportsRestricted == true end,
	AreOutgoingAddonChatMessagesRestricted = function() return false end,
}
Enum = { SendAddonMessageResult = { Success = 0, InvalidPrefix = 1, InvalidMessage = 2, AddonMessageThrottle = 3, InvalidChatType = 4, NotInGroup = 5, TargetRequired = 6, InvalidChannel = 7, ChannelThrottle = 8, GeneralError = 9, NotInGuild = 10, AddOnMessageLockdown = 11, TargetOffline = 12 } }
-- Deliver an addon message to every frame listening, as the client would.
function STUB.Receive(prefix, text, channel, sender) STUB.Fire("CHAT_MSG_ADDON", prefix, text, channel, sender, "", 0, 0, "", 0) end

STUB.player = { name = "Tester", realm = "Testrealm", level = 20, zone = "Mulgore", guild = "Test Guild", mapId = 1412 }
function UnitName(u) return STUB.player.name, STUB.player.realm end
function UnitLevel(u) return STUB.player.level end
function UnitClass(u) return "Warrior", "WARRIOR", 1 end
function GetRealZoneText() return STUB.player.zone end
function GetZoneText() return STUB.player.zone end
function IsInGuild() return STUB.player.guild ~= nil end
function GetGuildInfo(u) return STUB.player.guild, "Member", 3, STUB.player.realm end
function IsInGroup() return false end
STUB.partyMembers = {}
function UnitInParty(name) return STUB.partyMembers[name] == true end
function UnitInRaid(name) return false end
function IsInInstance() return STUB.inInstance == true, STUB.inInstance and "party" or "none" end
-- Joining a channel is a server round-trip: the id is known only after the next Advance, as in the client.
STUB.channels, STUB.pendingChannels, STUB.joinedChannelIds, STUB.nextChannelId = {}, {}, {}, 10
function JoinTemporaryChannel(name)
	if not STUB.channels[name] and not STUB.pendingChannels[name] then STUB.pendingChannels[name] = true end
	return 0, name
end
function GetChannelName(name) return STUB.channels[name] or 0, name end
function STUB.ResolveChannelJoins()
	for name in pairs(STUB.pendingChannels) do
		STUB.channels[name] = STUB.nextChannelId; STUB.joinedChannelIds[STUB.nextChannelId] = true
		STUB.nextChannelId = STUB.nextChannelId + 1
		STUB.pendingChannels[name] = nil
	end
end
-- Like the client: only my own realm (spelled without spaces) is stripped; other realms stay in the name.
function Ambiguate(name, ctx)
	if STUB.ambiguateKeepsRealm then return name end   -- observed on Forever: own realm is not stripped
	local mine = (STUB.player.realm or ""):gsub("%s", "")
	local n, r = name:match("^(.-)%-(.+)$")
	if n and r == mine then return n end
	return name
end
function GetLocale() return STUB.locale or "enUS" end
function GetBuildInfo() return "1.60.1", "70245", "Oct 6 2026", 16001 end
WOW_PROJECT_CAMELOT = 18
WOW_PROJECT_ID = 18
C_Map = { GetBestMapForUnit = function() return STUB.player.mapId end, GetPlayerMapPosition = function() return { GetXY = function() return 0.5, 0.5 end } end }
C_QuestLog = { GetNumQuestLogEntries = function() return 0, 0 end, GetInfo = function() return nil end, IsOnQuest = function() return false end, IsComplete = function() return false end, GetQuestsOnMap = function() return {} end }
Settings = {
	VarType = { Boolean = "boolean", Number = "number", String = "string" },
	RegisterVerticalLayoutCategory = function(name) local c = { name = name, settings = {} }; function c:GetID() return 1 end; return c, {} end,
	RegisterAddOnSetting = function(cat, var, key, tbl, vtype, name, default)
		if tbl[key] == nil then tbl[key] = default end
		local s = { name = name, key = key, tbl = tbl, default = default }
		function s:SetValueChangedCallback(fn) self.cb = fn end
		function s:NotifyUpdate() self.notified = (self.notified or 0) + 1 end
		function s:GetValue() return self.tbl[self.key] end
		function s:SetValue(v) self.tbl[self.key] = v; if self.cb then self.cb(self, v) end end
		cat.settings[#cat.settings + 1] = s
		return s
	end,
	RegisterProxySetting = function(cat, var, vtype, name, default, get, set)
		local s = { name = name, get = get, set = set }
		function s:SetValueChangedCallback(fn) self.cb = fn end
		function s:NotifyUpdate() self.notified = (self.notified or 0) + 1 end
		function s:GetValue() return self.get() end
		function s:SetValue(v) self.set(v); if self.cb then self.cb(self, v) end end
		cat.settings[#cat.settings + 1] = s
		return s
	end,
	CreateCheckbox = function(cat, setting) setting.checkbox = true end, RegisterAddOnCategory = function() end, OpenToCategory = function() end,
	-- the modern controls: a dropdown over a text container, a slider over its options, recorded on the setting
	CreateDropdown = function(cat, setting, options, tooltip) setting.dropdown = true; setting.options = options end,
	CreateSlider = function(cat, setting, options, tooltip) setting.slider = options end,
	CreateControlTextContainer = function() local c = { data = {} }; function c:Add(v, l) self.data[#self.data + 1] = { value = v, label = l } end; function c:GetData() return self.data end; return c end,
	CreateSliderOptions = function(min, max, step) local o = { min = min, max = max, step = step }; function o:SetLabelFormatter() end; return o end,
}
SettingsPanel = { GetLayout = function(_, cat) cat.layout = cat.layout or { inits = {} }; local l = cat.layout; function l:AddInitializer(i) self.inits[#self.inits + 1] = i end; return l end }
function CreateSettingsListSectionHeaderInitializer(name) return { header = name } end
function CreateSettingsButtonInitializer(name, buttonText, click, tooltip) return { button = name, buttonText = buttonText, click = click } end
MinimalSliderWithSteppersMixin = { Label = { Right = 1 } }
function strsplit(d, s, n) local out, i = {}, 1; for piece in (s .. d):gmatch("(.-)" .. d:gsub("%p", "%%%0")) do out[#out + 1] = piece end; return unpack(out) end
function strtrim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
function strlower(s) return s:lower() end
function tinsert(t, v) t[#t + 1] = v end
function wipe(t) for k in pairs(t) do t[k] = nil end return t end
-- A real (UTC) calendar for date("*t") and time(table): this stub's "local time" is UTC.
local function daysFromCivil(y, m, d)
	y = m <= 2 and y - 1 or y
	local era = math.floor(y / 400)
	local yoe = y - era * 400
	local doy = math.floor((153 * (m + (m > 2 and -3 or 9)) + 2) / 5) + d - 1
	return era * 146097 + yoe * 365 + math.floor(yoe / 4) - math.floor(yoe / 100) + doy - 719468
end
local function civilFromDays(z)
	z = z + 719468
	local era = math.floor(z / 146097)
	local doe = z - era * 146097
	local yoe = math.floor((doe - math.floor(doe / 1460) + math.floor(doe / 36524) - math.floor(doe / 146096)) / 365)
	local doy = doe - (365 * yoe + math.floor(yoe / 4) - math.floor(yoe / 100))
	local mp = math.floor((5 * doy + 2) / 153)
	local d = doy - math.floor((153 * mp + 2) / 5) + 1
	local m = mp < 10 and mp + 3 or mp - 9
	return yoe + era * 400 + (m <= 2 and 1 or 0), m, d
end
STUB.daysFromCivil = daysFromCivil
function date(fmt, t)
	if fmt == "*t" then   -- 1970-01-01 was a Thursday (wday 5)
		t = t or time()
		local days, s = math.floor(t / 86400), t % 86400
		local y, m, d = civilFromDays(days)
		return { year = y, month = m, day = d, hour = math.floor(s / 3600), min = math.floor(s % 3600 / 60), sec = s % 60, wday = (days + 4) % 7 + 1 }
	end
	-- the common fields from the same calendar (%Y %m %d %H %M %S); anything else stays literal
	local tt = date("*t", t)
	local map = { Y = string.format("%04d", tt.year), m = string.format("%02d", tt.month), d = string.format("%02d", tt.day), H = string.format("%02d", tt.hour), M = string.format("%02d", tt.min), S = string.format("%02d", tt.sec) }
	return (tostring(fmt or "%H:%M:%S"):gsub("%%(%a)", function(k) return map[k] or ("%" .. k) end))
end
STUB.printed = {}
function print(...) local parts = {}; for i = 1, select("#", ...) do parts[i] = tostring((select(i, ...))) end; STUB.printed[#STUB.printed + 1] = table.concat(parts, " ") end

-- LevelMates additions
function GetRealmName() return STUB.player.realm end
C_AddOns = { GetAddOnMetadata = function() return "dev" end }
C_AddOns.IsAddOnLoaded = function(name) return STUB.loadedAddons ~= nil and STUB.loadedAddons[name] == true end
STUB.quests = {}
C_QuestLog.GetNumQuestLogEntries = function() return #STUB.quests, #STUB.quests end
C_QuestLog.GetInfo = function(i) local id = STUB.quests[i]; if not id then return nil end; return { questID = id, title = "Quest " .. id, isHeader = false, level = 20 } end
C_QuestLog.IsComplete = function(id) return STUB.completed and STUB.completed[id] or false end
C_QuestLog.IsPushableQuest = function() return true end
function GetNumGroupMembers() return STUB.groupSize or 0 end
function GetNumSubgroupMembers() return math.max(0, (STUB.groupSize or 0) - 1) end
STUB.guildMembers = { Tester = true, Mario = true, Ana = true, Luis = true }
UNKNOWN = "Unknown"
Enum.ClubStreamType = { General = 0, Guild = 1, Officer = 2, Discord = 3 }
-- the club's chat history: STUB.clubStreams = { { streamId, name, streamType } }, STUB.clubMessages[streamId] = { { messageId = { epoch (µs), position }, content, author = { name, classID }, destroyed } }
STUB.clubStreams, STUB.clubMessages, STUB.clubRequested, STUB.clubFocused = {}, {}, {}, {}
C_Club = {
	GetGuildClubId = function() return 1 end,
	GetStreams = function() return STUB.clubStreams end,
	GetMessageRanges = function(_, streamId)
		local list = STUB.clubMessages[streamId] or {}
		if #list == 0 then return {} end
		return { { oldestMessageId = list[1].messageId, newestMessageId = list[#list].messageId } }
	end,
	GetMessagesInRange = function(_, streamId) return STUB.clubMessages[streamId] or {} end,
	RequestMoreMessagesBefore = function(_, streamId, messageId, count) STUB.clubRequested[streamId] = { id = messageId, count = count }; return true end,
	FocusStream = function(_, streamId) STUB.clubFocused[streamId] = true; return true end,
	SetClubPresenceSubscription = function() end,
	GetClubMembers = function() local out = {}; for k in pairs(STUB.guildMembers) do out[#out + 1] = k end; return out end,
	GetMemberInfo = function(_, id)
		local x = STUB.memberInfo and STUB.memberInfo[id] or {}
		return { name = id, level = x.level or 1, presence = x.presence or 3, role = STUB.guildRoles and STUB.guildRoles[id] or 4, guildRankOrder = x.rank or 4, guildRank = x.rankName, classID = x.classID or 8,
			lastOnlineYear = x.lastOnlineYear, lastOnlineMonth = x.lastOnlineMonth, lastOnlineDay = x.lastOnlineDay, lastOnlineHour = x.lastOnlineHour }
	end,
}
function UnitXP() return STUB.player.xp or 0 end
function UnitXPMax() return 1000 end
function GetXPExhaustion() return STUB.player.rested end
RAID_CLASS_COLORS = {}
CLASS_ICON_TCOORDS = { WARRIOR = { 0, 0.25, 0, 0.25 }, MAGE = { 0.25, 0.49609375, 0, 0.25 }, ROGUE = { 0.49609375, 0.7421875, 0, 0.25 }, DRUID = { 0.7421875, 0.98828125, 0, 0.25 },
	HUNTER = { 0, 0.25, 0.25, 0.5 }, SHAMAN = { 0.25, 0.49609375, 0.25, 0.5 }, PRIEST = { 0.49609375, 0.7421875, 0.25, 0.5 }, WARLOCK = { 0.7421875, 0.98828125, 0.25, 0.5 }, PALADIN = { 0, 0.25, 0.5, 0.75 } }
C_Map.GetMapInfo = function(id) return { name = "Map " .. id, mapID = id } end
-- a context menu: recorded as STUB.lastMenu = { title, entries = { { text, cb, radio, selected } } }
MenuUtil = { CreateContextMenu = function(owner, fn)
	local m = { entries = {} }
	local root = {
		CreateTitle = function(_, text) m.title = text end,
		CreateDivider = function() end,
		CreateButton = function(_, text, cb) m.entries[#m.entries + 1] = { text = text, cb = cb } end,
		CreateRadio = function(_, text, isSelected, setSelected, data) m.entries[#m.entries + 1] = { text = text, radio = true, selected = isSelected(data) and true or false, cb = function() setSelected(data) end } end,
	}
	STUB.lastMenu = m
	fn(owner, root)
end }
function STUB.MenuEntry(text) for _, e in ipairs(STUB.lastMenu and STUB.lastMenu.entries or {}) do if e.text == text then return e end end end
ChatFrameUtil = { SendTell = function(name) STUB.lastTell = name end }
function Region:RegisterForClicks() end
function Region:GetPoint() return "CENTER", nil, "CENTER", 0, 0 end
AddonCompartmentFrame = { RegisterAddon = function(_, info) STUB.compartment = info end }
C_QuestLog.GetTitleForQuestID = function(id) return "Quest " .. id end
StaticPopupDialogs = {}
-- Mainline dialogs expose their edit box as dialog.EditBox / dialog:GetEditBox() (GameDialog.xml, parentKey="EditBox").
function StaticPopup_Show(which)
	local dialog = CreateFrame("Frame")
	dialog.EditBox = setmetatable({ parent = dialog, shown = true }, Region)
	function dialog:GetEditBox() return self.EditBox end
	function dialog:GetEditBoxText() return self.EditBox:GetText() end
	STUB.lastPopup, STUB.lastDialog = which, dialog
	return dialog
end
OKAY = "Okay"; CANCEL = "Cancel"
STUB.sounds = {}
function PlaySound(id) STUB.sounds[#STUB.sounds + 1] = id end
SOUNDKIT = { IG_SPELLBOOK_OPEN = 829, IG_SPELLBOOK_CLOSE = 830, IG_CHARACTER_INFO_TAB = 841, IG_QUEST_LOG_OPEN = 844, IG_MAINMENU_OPTION_CHECKBOX_ON = 856, RAID_WARNING = 8959 }
function SendChatMessage(msg, chatType, lang, target) STUB.lastChat = { msg = msg, chatType = chatType or "SAY", lang = lang, target = target } end

-- Minimap button support
Minimap = CreateFrame("Frame", "Minimap"); Minimap:SetSize(140, 140)
STUB.cursor = { 0, 0 }
function GetCursorPosition() return STUB.cursor[1], STUB.cursor[2] end
GameTooltip = { lines = {}, hidden = true,
	SetHyperlink = function(self, link) self.link = link end,
	SetOwner = function(self) self.lines = {}; self.hidden = false end,
	AddLine = function(self, t) self.lines[#self.lines + 1] = t end,
	Show = function(self) self.hidden = false end, Hide = function(self) self.hidden = true end }

STUB.atlases = {}
C_Texture = { GetAtlasInfo = function(a) if STUB.atlases[a] then return { width = 64, height = 64 } end end }

-- Journal support
function time(t)
	if type(t) == "table" then return STUB.daysFromCivil(t.year, t.month, t.day) * 86400 + (t.hour or 12) * 3600 + (t.min or 0) * 60 + (t.sec or 0) end
	return 1760000000 + math.floor(STUB.now)
end
-- the realm clock: the same as time() here (a test can shift it with STUB.serverSkew)
function GetServerTime() return 1760000000 + math.floor(STUB.now) + (STUB.serverSkew or 0) end
function UnitGUID(u) return "Player-1-TESTER" end
function GetInstanceInfo() return STUB.instanceName or "Mulgore", STUB.inInstance and "party" or "none", 0, "", 5, 0, false, STUB.instanceId or 0 end
C_SkillInfo = {
	GetNumSkillLines = function() return STUB.skills and #STUB.skills or 0 end,
	GetSkillLineInfo = function(i) return STUB.skills and STUB.skills[i] end,
}

-- Guild ranks (community roles: 1 Owner, 2 Leader, 3 Moderator, 4 Member)
function IsGuildLeader() return STUB.iAmLeader == true end
C_GuildInfo = { IsGuildOfficer = function() return STUB.iAmOfficer == true end }

-- Panel tabs (SharedUIPanelTemplates): the selected tab is the disabled one, as PanelTemplates_SelectTab does.
function PanelTemplates_SetNumTabs(frame, n) frame.numTabs = n end
function PanelTemplates_SetTab(frame, id)
	frame.selectedTab = id
	for i, tab in ipairs(frame.Tabs or {}) do tab:SetEnabled(i ~= id) end
end
function PanelTemplates_TabResize() end

-- Wishlist support
function hooksecurefunc(a, b, c)
	local tbl, key, fn = a, b, c
	if type(a) == "string" then tbl, key, fn = _G, a, b end
	local old = tbl[key]
	tbl[key] = function(...) local r = { old(...) }; fn(...); return (unpack or table.unpack)(r) end
end
ChatFrameUtil.InsertLink = function() return false end
STUB.tooltipPost = {}
Enum.TooltipDataType = { Item = 0, Unit = 2 }
TooltipDataProcessor = { AddTooltipPostCall = function(kind, fn) STUB.tooltipPost[#STUB.tooltipPost + 1] = { kind = kind, fn = fn } end }
function STUB.TooltipPost(kind, tooltip, data) for _, p in ipairs(STUB.tooltipPost) do if p.kind == kind then p.fn(tooltip, data) end end end
ItemRefTooltip = {}
STUB.items, STUB.itemLoads = {}, {}
-- the client has only C_Item.GetItemInfo (the old global GetItemInfo is gone on Forever)
C_Item = C_Item or {}
function C_Item.GetItemInfo(x)
	local id = tonumber(x) or tonumber(tostring(x):match("item:(%d+)") or "")
	local link = id and STUB.items[id]
	if link then return link:match("%[(.-)%]"), link end
end
Item = { CreateFromItemID = function(_, id) return { ContinueOnItemLoad = function(_, fn) STUB.itemLoads[id] = fn end } end }

-- Copy for Discord support (multi-line edit box in a scroll frame)
function Region:SetMultiLine() end
function Region:SetFontObject(f) self.fontObject = f end
ChatFontNormal = "ChatFontNormal"
-- bags (STUB.bags = { itemId, ... } in bag 0) and the trade window
C_Container = { GetContainerNumSlots = function(bag) return bag == 0 and STUB.bags and #STUB.bags or 0 end,
	GetContainerItemInfo = function(bag, slot) local id = bag == 0 and STUB.bags and STUB.bags[slot]; return id and { itemID = id } or nil end,
	PickupContainerItem = function(bag, slot) STUB.picked = { bag, slot } end }
function ClickTradeButton(i) STUB.tradeSlot = i end
function GetTradePlayerItemLink(i) return STUB.tradeLinks and STUB.tradeLinks[i] end
RANDOM_ROLL_RESULT = "%s rolls %d (%d-%d)"
function RandomRoll(lo, hi) STUB.rolled = { lo, hi } end   -- the game's chat font object, a name here
function Region:SetSpacing(v) self.spacing = v end
function Region:SetScrollChild(child) self.child = child end
function Region:HighlightText() self.highlighted = true end
function Region:SetFocus() if STUB.focus and STUB.focus ~= self then STUB.focus.focused = false end; STUB.focus = self; self.focused = true end   -- one box has the focus, as in the game
function Region:ClearFocus() self.focused = false end

-- Screen notices
UIErrorsFrame = { messages = {}, AddMessage = function(self, text) self.messages[#self.messages + 1] = text end }

-- EventRegistry callbacks (addon chat links arrive as "SetItemRef")
EventRegistry = { callbacks = {} }
function EventRegistry:RegisterCallback(event, fn, owner) self.callbacks[event] = self.callbacks[event] or {}; table.insert(self.callbacks[event], { fn = fn, owner = owner }) end
function STUB.ClickLink(link) for _, c in ipairs(EventRegistry.callbacks.SetItemRef or {}) do c.fn(c.owner, link, link, "LeftButton") end end

-- Units (rares)
STUB.units = {}
function UnitExists(u) return STUB.units[u] ~= nil end
function UnitClassification(u) return STUB.units[u] and STUB.units[u].class or "normal" end
function UnitIsDead(u) return STUB.units[u] and STUB.units[u].dead or false end
function UnitIsPlayer(u) return STUB.units[u] and STUB.units[u].player or false end
local realUnitName = UnitName
function UnitName(u) if STUB.units[u] then return STUB.units[u].name end; return realUnitName(u) end
C_Map.GetPlayerMapPosition = function() return { GetXY = function() return STUB.pos and STUB.pos[1] or 0.5, STUB.pos and STUB.pos[2] or 0.5 end } end

-- Quest objectives
STUB.objectives = {}
C_QuestLog.GetQuestObjectives = function(id) return STUB.objectives[id] end

-- World map
STUB.worldMapId = 1412
WorldMapFrame = CreateFrame("Frame", "WorldMapFrame")
local canvas = CreateFrame("Frame"); canvas:SetSize(1000, 700)
function WorldMapFrame:GetCanvas() return canvas end
function WorldMapFrame:GetMapID() return STUB.worldMapId end
function WorldMapFrame:OnMapChanged() end

-- Guild member counts (total, total, online)
function GetNumGuildMembers() return STUB.guildTotal or 0, STUB.guildTotal or 0, STUB.guildOnline or 0 end
function Region:HasFocus() return self.focused == true end

-- Skinned buttons and backdrops (BackdropTemplate, Button font strings)
function Region:SetFontString(fs) self.fontString = fs end
function Region:GetFontString() return self.fontString end
function Region:SetNormalFontObject() end
function Region:SetHighlightFontObject() end
function Region:SetDisabledFontObject() end
function Region:SetBackdropColor(r, g, b, a) self.backdropColor = { r, g, b, a } end
function Region:SetBackdropBorderColor(r, g, b, a) self.backdropBorder = { r, g, b, a } end
function Region:SetHorizTile() end
function Region:SetVertTile() end
function Region:SetVertexColor(r, g, b, a) self.vertexColor = { r, g, b, a } end
function Region:SetGradient(o, a, b) self.gradient = { o, a, b } end
function CreateColor(r, g, b, a) return { r = r, g = g, b = b, a = a } end
function Region:LockHighlight() self.lit = true end
function Region:UnlockHighlight() self.lit = false end
function Region:SetBlendMode() end
function Region:SetDesaturated(v) self.desaturated = v end
function Region:SetShadowColor() end
function Region:GetTextColor() local c = self.color or { 1, 1, 1 }; return c[1], c[2], c[3], 1 end
STUB.handled = {}
STUB.errorHandler = function(msg) STUB.handled[#STUB.handled + 1] = msg end
function geterrorhandler() return STUB.errorHandler end
function seterrorhandler(fn) STUB.errorHandler = fn end
Settings.RegisterVerticalLayoutSubcategory = function(parent, name) local c = { name = name, settings = {}, parent = parent }; function c:GetID() return 2 end; return c, {} end
function Region:EnableMouse(v) self.mouseEnabled = v end
function Region:SetClampedToScreen(v) self.clamped = v end
function Region:GetRight() return nil end

-- For the multi-client harness: hand over what this client sent since the last drain, one line per message,
-- "prefix\tchatType\ttarget\tmsg" (messages never hold tabs or newlines: the wire forbids control characters
-- except the unit separator).
STUB.drained = 0
function STUB.Drain()
	local out = {}
	for i = STUB.drained + 1, #STUB.sent do
		local s = STUB.sent[i]
		out[#out + 1] = table.concat({ s.prefix, s.chatType or "", tostring(s.target or ""), s.msg }, "\t")
	end
	STUB.drained = #STUB.sent
	return table.concat(out, "\n")
end

-- A record's wire fields for tests: an id (unless given), a rev that always grows, an expiry a day ahead.
STUB.recSeq = 0
function STUB.Rec(f)
	STUB.recSeq = STUB.recSeq + 1
	f.id = f.id or ("r" .. STUB.recSeq)
	f.v = f.v or (GetServerTime() + STUB.recSeq)
	f.e = f.e or (GetServerTime() + 86400)
	return f
end

function UpdateAddOnMemoryUsage() end
function GetAddOnMemoryUsage() return 1234 end

function UnitAffectingCombat(u) return STUB.inCombat == true end

STUB.questTags = {}
C_QuestLog.GetQuestTagInfo = function(id) return STUB.questTags[id] end

-- My profession window: STUB.trade = { line, rank, max, recipes = { { id, item | spell, learned } }, linked, guild, npc }
C_TradeSkillUI = {
	IsTradeSkillReady = function() return STUB.trade ~= nil end,
	IsTradeSkillLinked = function() return STUB.trade ~= nil and STUB.trade.linked == true end,
	IsTradeSkillGuild = function() return STUB.trade ~= nil and STUB.trade.guild == true end,
	IsTradeSkillGuildMember = function() return false end,
	IsNPCCrafting = function() return STUB.trade ~= nil and STUB.trade.npc == true end,
	GetBaseProfessionInfo = function() local t = STUB.trade; return t and { professionID = t.line, skillLevel = t.rank, maxSkillLevel = t.max } end,
	GetAllRecipeIDs = function() local out = {}; for _, r in ipairs(STUB.trade and STUB.trade.recipes or {}) do out[#out + 1] = r.id end; return out end,
	GetRecipeInfo = function(id)
		for _, r in ipairs(STUB.trade and STUB.trade.recipes or {}) do if r.id == id then return { recipeID = id, learned = r.learned ~= false, alternateVerb = r.spell and "Enchant" or nil } end end
	end,
	GetRecipeOutputItemData = function(id)
		for _, r in ipairs(STUB.trade and STUB.trade.recipes or {}) do if r.id == id and r.item then return { itemID = r.item, hyperlink = "item:" .. r.item } end end
	end,
}

-- The guild bank: STUB.bank = { money, tabs = { { name, icon, view = true, slots = { [slot] = { id, n } } } } }
function GetNumGuildBankTabs() return STUB.bank and #STUB.bank.tabs or 0 end
function GetGuildBankTabInfo(t) local x = STUB.bank.tabs[t]; return x.name, x.icon or 134400, x.view ~= false end
function QueryGuildBankTab(t) STUB.bankQueried = (STUB.bankQueried or 0) + 1 end
function GetGuildBankItemLink(t, s) local x = STUB.bank.tabs[t].slots[s]; return x and ("|Hitem:" .. x.id .. "::::|h[Item " .. x.id .. "]|h") end
function GetGuildBankItemInfo(t, s) local x = STUB.bank.tabs[t].slots[s]; if x then return 134400, x.n end; return nil, 0 end
function GetGuildBankMoney() return STUB.bank and STUB.bank.money or 0 end

-- My gear: STUB.gear[slot] = "|Hitem:id:enchant…|h[Name]|h"; item levels from STUB.ilvl[id] (nil = not loaded yet)
STUB.gear, STUB.ilvl = {}, {}
function GetInventoryItemLink(unit, slot) if unit == "player" then return STUB.gear[slot] end end
C_Item = C_Item or {}
C_Item.GetDetailedItemLevelInfo = function(link) local id = tonumber(tostring(link):match("item:(%d+)") or ""); return id and STUB.ilvl[id] end
C_Item.GetItemIconByID = function(id) return 1000 + (id or 0) end
function GetItemIcon(id) return 1000 + (tonumber(id) or 0) end
function UnitRace(u) return "Human", "Human", STUB.raceId or 1 end
function UnitSex(u) return STUB.sex or 2 end
function InCombatLockdown() return STUB.inCombat == true end

-- DressUpModel calls, recorded
function Region:SetUnit(u) self.unit = u end
function Region:SetCustomRace(r, s) self.race, self.sex = r, s end
function Region:Undress() self.tried = {} end
function Region:TryOn(link) self.tried = self.tried or {}; table.insert(self.tried, link) end
function Region:SetCamDistanceScale() end
function Region:ClearModel() self.unit, self.race, self.tried = nil, nil, nil end
