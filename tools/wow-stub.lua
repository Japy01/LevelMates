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
function Region:GetFrameLevel() return 1 end
function Region:SetSize(w, h) self.w, self.h = w, h end
function Region:SetWidth(w) self.w = w end
function Region:SetHeight(h) self.h = h end
function Region:GetWidth() return self.w or 0 end
function Region:GetHeight() return self.h or 0 end
function Region:Show() self.shown = true end
function Region:Hide() self.shown = false end
function Region:SetShown(v) self.shown = v and true or false end
function Region:IsShown() return self.shown == true end
function Region:SetText(t) self.text = t end
function Region:GetText() return self.text end
function Region:SetTextColor(r, g, b) self.color = { r, g, b } end
function Region:SetAllPoints() end
function Region:SetEnabled(v) self.enabled = v and true or false end
function Region:SetAutoFocus() end
function Region:SetMaxLetters() end
function Region:SetTexCoord(l, r, t, b) self.texcoord = { l, r, t, b } end
function Region:SetHighlightTexture() end
function Region:SetJustifyH() end
function Region:SetWordWrap() end
function Region:SetAlpha() end
function Region:SetScale() end
function Region:GetID() return self.id or 0 end
function Region:SetID(id) self.id = id end
function Region:SetFrameStrata() end
function Region:SetFrameLevel() end
function Region:SetMovable() end
function Region:EnableMouse() end
function Region:SetClampedToScreen() end
function Region:RegisterForDrag() end
function Region:StartMoving() end
function Region:StopMovingOrSizing() end
function Region:SetBackdrop() end
function Region:SetColorTexture(r, g, b, a) self.colorTexture = { r, g, b, a } end
function Region:SetTexture(t) self.atlas = nil end
function Region:SetAtlas(a) self.atlas = a; self.texcoord = nil end
function Region:SetChecked(v) self.checked = v end
function Region:GetChecked() return self.checked end
function Region:CreateFontString() return setmetatable({ shown = true }, Region) end
function Region:CreateTexture() return setmetatable({ shown = true }, Region) end
function Region:RegisterEvent(e) self.registered[e] = true end
function Region:UnregisterEvent(e) self.registered[e] = nil end
function Region:SetScript(name, fn) self.scripts[name] = fn end
function Region:GetScript(name) return self.scripts[name] end
function Region:HookScript(name, fn) local old = self.scripts[name]; self.scripts[name] = function(...) if old then old(...) end fn(...) end end
function Region:GetParent() return self.parent end

function CreateFrame(kind, name, parent, template)
	local f = setmetatable({ kind = kind, name = name, parent = parent, template = template, registered = {}, scripts = {}, shown = true, TitleText = setmetatable({}, Region) }, Region)
	STUB.frames[#STUB.frames + 1] = f
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
		function s:GetValue() return self.tbl[self.key] end
		function s:SetValue(v) self.tbl[self.key] = v; if self.cb then self.cb(self, v) end end
		cat.settings[#cat.settings + 1] = s
		return s
	end,
	RegisterProxySetting = function(cat, var, vtype, name, default, get, set)
		local s = { name = name, get = get, set = set }
		function s:SetValueChangedCallback(fn) self.cb = fn end
		function s:GetValue() return self.get() end
		function s:SetValue(v) self.set(v); if self.cb then self.cb(self, v) end end
		cat.settings[#cat.settings + 1] = s
		return s
	end,
	CreateCheckbox = function() end, CreateSlider = function() end, RegisterAddOnCategory = function() end, OpenToCategory = function() end,
}
function strsplit(d, s, n) local out, i = {}, 1; for piece in (s .. d):gmatch("(.-)" .. d:gsub("%p", "%%%0")) do out[#out + 1] = piece end; return unpack(out) end
function strtrim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
function strlower(s) return s:lower() end
function tinsert(t, v) t[#t + 1] = v end
function wipe(t) for k in pairs(t) do t[k] = nil end return t end
function date(fmt) return "00:00:00" end
STUB.printed = {}
function print(...) local parts = {}; for i = 1, select("#", ...) do parts[i] = tostring((select(i, ...))) end; STUB.printed[#STUB.printed + 1] = table.concat(parts, " ") end

-- LevelMates additions
function GetRealmName() return STUB.player.realm end
C_AddOns = { GetAddOnMetadata = function() return "dev" end }
STUB.quests = {}
C_QuestLog.GetNumQuestLogEntries = function() return #STUB.quests, #STUB.quests end
C_QuestLog.GetInfo = function(i) local id = STUB.quests[i]; if not id then return nil end; return { questID = id, title = "Quest " .. id, isHeader = false, level = 20 } end
C_QuestLog.IsComplete = function(id) return STUB.completed and STUB.completed[id] or false end
C_QuestLog.IsPushableQuest = function() return true end
function GetNumGroupMembers() return STUB.groupSize or 0 end
function GetNumSubgroupMembers() return math.max(0, (STUB.groupSize or 0) - 1) end
STUB.guildMembers = { Tester = true, Mario = true, Ana = true, Luis = true }
C_Club = {
	GetGuildClubId = function() return 1 end,
	GetClubMembers = function() local out = {}; for k in pairs(STUB.guildMembers) do out[#out + 1] = k end; return out end,
	GetMemberInfo = function(_, id) return { name = id, level = 1, presence = 1 } end,
}
function UnitXP() return STUB.player.xp or 0 end
function UnitXPMax() return 1000 end
function GetXPExhaustion() return STUB.player.rested end
RAID_CLASS_COLORS = {}
C_Map.GetMapInfo = function(id) return { name = "Map " .. id, mapID = id } end
MenuUtil = { CreateContextMenu = function(owner, fn) local root = { CreateTitle = function() end, CreateButton = function() end }; fn(owner, root) end }
ChatFrameUtil = { SendTell = function(name) STUB.lastTell = name end }
function Region:RegisterForClicks() end
function Region:GetPoint() return "CENTER", nil, "CENTER", 0, 0 end
AddonCompartmentFrame = { RegisterAddon = function() end }
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
function PlaySound() end
function SendChatMessage(msg, chatType, lang, target) STUB.lastChat = { msg = msg, chatType = chatType or "SAY", lang = lang, target = target } end

-- Minimap button support
Minimap = CreateFrame("Frame", "Minimap"); Minimap:SetSize(140, 140)
STUB.cursor = { 0, 0 }
function GetCursorPosition() return STUB.cursor[1], STUB.cursor[2] end
GameTooltip = { lines = {}, hidden = true,
	SetOwner = function(self) self.lines = {}; self.hidden = false end,
	AddLine = function(self, t) self.lines[#self.lines + 1] = t end,
	Show = function(self) self.hidden = false end, Hide = function(self) self.hidden = true end }

STUB.atlases = {}
C_Texture = { GetAtlasInfo = function(a) if STUB.atlases[a] then return { width = 64, height = 64 } end end }

-- Journal support
function time() return 1760000000 + math.floor(STUB.now) end
function UnitGUID(u) return "Player-1-TESTER" end
function GetInstanceInfo() return STUB.instanceName or "Mulgore", STUB.inInstance and "party" or "none", 0, "", 5, 0, false, STUB.instanceId or 0 end
C_SkillInfo = {
	GetNumSkillLines = function() return STUB.skills and #STUB.skills or 0 end,
	GetSkillLineInfo = function(i) return STUB.skills and STUB.skills[i] end,
}
