-- Minimal stub of the WoW client API for running addon logic under plain Lua 5.1 / fengari.
-- Loaded by run-lua-test.mjs before the addon files. Extend per project; keep it honest:
-- everything here mimics the real API shape documented in api-reference.md.
STUB = { events = {}, timers = {}, sent = {}, frames = {}, now = 0, prefixes = {} }

function GetTime() return STUB.now end
-- Advance the clock, firing every due timer in time order; a repeating ticker fires once per
-- interval (Advance(30) on a 0.2 s ticker = 150 calls), as the real client would.
function STUB.Advance(seconds)
	local target = STUB.now + seconds
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
function Region:SetPoint() end
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
function Region:SetTextColor() end
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
function Region:SetColorTexture() end
function Region:SetTexture() end
function Region:SetChecked(v) self.checked = v end
function Region:GetChecked() return self.checked end
function Region:CreateFontString() return setmetatable({ shown = true }, Region) end
function Region:CreateTexture() return setmetatable({ shown = true }, Region) end
function Region:RegisterEvent(e) self.registered[e] = true end
function Region:UnregisterEvent(e) self.registered[e] = nil end
function Region:SetScript(name, fn) self.scripts[name] = fn end
function Region:GetScript(name) return self.scripts[name] end
function Region:HookScript(name, fn) local old = self.scripts[name]; self.scripts[name] = function(...) if old then old(...) end fn(...) end end

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
		STUB.sent[#STUB.sent + 1] = { prefix = prefix, msg = msg, chatType = chatType or "PARTY", target = target, at = STUB.now }
		return 0
	end,
	InChatMessagingLockdown = function() return STUB.lockdown == true end,
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
STUB.channels = {}
function JoinTemporaryChannel(name) STUB.channels[name] = STUB.channels[name] or (#STUB.channels + 10); return 0, name end
function GetChannelName(name) return STUB.channels[name] or 0, name end
function Ambiguate(name, ctx) return (name:gsub("%-.*$", "")) end
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
		local s = { name = name, key = key, tbl = tbl }
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
