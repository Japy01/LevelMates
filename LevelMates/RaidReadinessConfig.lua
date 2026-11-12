-- Editor for personal reminders and officer/raid-leader requirement profiles.
local _, ns = ...
local RR, P, L = ns.RaidReadiness, ns.RaidRequirements, ns.L
local function menu(owner, entries)
	MenuUtil.CreateContextMenu(owner, function(_, root)
		for _, entry in ipairs(entries) do root:CreateButton(entry[1], entry[2]) end
	end)
end
local function button(parent, width, text, fn)
	local b = ns.Skin.Button(parent); b:SetSize(width, 24); b:SetText(text); b:SetScript("OnClick", fn); return b
end
local function load()
	local f = RR.config
	f.activity:SetText(ns.Activities.Name(f.id))
	f.mode:SetText(L["READY_MODE_" .. f.kind:upper()])
	f.scopeButton:SetText(f.kind == "personal" and L.READY_THIS_CHARACTER or P.ScopeLabel(f.scope)); f.scopeButton:SetEnabled(f.kind ~= "personal")
	local rec = f.kind ~= "personal" and P.Get(f.kind, f.id, f.scope)
	f.box:SetText(f.kind == "personal" and P.Encode(RR.PersonalItems(f.id)) or rec and rec.d.i or "")
	f.author:SetText(f.kind == "personal" and L.READY_PRIVATE_PROFILE or rec and string.format(L.READY_PROFILE_AUTHOR, rec.o, date("%d/%m %H:%M", rec.v)) or L.READY_PROFILE_NEW)
	f.status:SetText("")
	f.save:SetEnabled(f.kind == "personal" or P.CanPublish(f.kind))
	f.permission:SetText(f.kind == "personal" and L.READY_PERSONAL_EXTRA or P.CanPublish(f.kind) and L.READY_PUBLISH_HELP or L.READY_NO_PERMISSION)
end
local function build()
	local w = ns.Skin.Window("LevelMatesRaidReadiness", UIParent)
	w:SetSize(600, 380); w:SetPoint("CENTER"); w:SetFrameStrata("DIALOG")
	if w.TitleText then w.TitleText:SetText(L.READY_CONFIG_TITLE) end
	if UISpecialFrames then table.insert(UISpecialFrames, "LevelMatesRaidReadiness") end
	local f = { frame = w, id = 101, kind = "personal", scope = "ALL" }; RR.config = f
	f.activity = button(w, 270, "", function(self)
		local entries = {}
		for _, a in ipairs(ns.Activities.List("r")) do
			local id = a.id; entries[#entries + 1] = { ns.Activities.Name(id), function() f.id = id; load() end }
		end
		menu(self, entries)
	end); f.activity:SetPoint("TOPLEFT", 18, -40)
	f.mode = button(w, 270, "", function(self)
		local entries = {}
		for _, value in ipairs({ "personal", "guild", "raid" }) do
			local kind = value; entries[#entries + 1] = { L["READY_MODE_" .. kind:upper()], function() f.kind = kind; load() end }
		end
		menu(self, entries)
	end); f.mode:SetPoint("TOPLEFT", 18, -74)
	f.scopeButton = button(w, 270, "", function(self)
		local entries = {}
		for _, value in ipairs(P.SCOPES) do
			local scope = value; entries[#entries + 1] = { P.ScopeLabel(scope), function() f.scope = scope; load() end }
		end
		menu(self, entries)
	end); f.scopeButton:SetPoint("LEFT", f.mode, "RIGHT", 12, 0)
	local hint = w:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	hint:SetPoint("TOPLEFT", 18, -112); hint:SetWidth(560); hint:SetJustifyH("LEFT"); hint:SetText(L.READY_EDITOR_HELP)
	f.box = CreateFrame("EditBox", nil, w, "InputBoxTemplate")
	f.box:SetSize(548, 72); f.box:SetPoint("TOPLEFT", 24, -155); f.box:SetAutoFocus(false); f.box:SetMultiLine(true); f.box:SetMaxLetters(400)
	f.box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	f.author = w:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); f.author:SetPoint("TOPLEFT", 18, -237); f.author:SetWidth(560); f.author:SetJustifyH("LEFT")
	f.permission = w:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); f.permission:SetPoint("TOPLEFT", 18, -259); f.permission:SetWidth(560); f.permission:SetJustifyH("LEFT")
	f.status = w:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); f.status:SetPoint("TOPLEFT", 18, -300); f.status:SetWidth(560); f.status:SetJustifyH("LEFT")
	f.save = button(w, 160, L.READY_SAVE, function()
		local ok, why
		if f.kind == "personal" then ok = RR.SetItems(f.id, f.box:GetText()) else ok, why = P.Set(f.kind, f.id, f.scope, f.box:GetText()) end
		if ok then f.box:ClearFocus(); load(); f.status:SetText(f.kind == "personal" and L.READY_SAVED or L.READY_SHARED_SAVED)
		else f.status:SetText(why == "permission" and L.READY_NO_PERMISSION or L.READY_INVALID_ITEMS) end
	end); f.save:SetPoint("BOTTOMLEFT", 18, 18)
	f.report = button(w, 160, L.READY_VIEW_REPORT, function() ns.DiscordCopy.OpenText(RR.Text(f.id)) end); f.report:SetPoint("LEFT", f.save, "RIGHT", 12, 0)
	f.close = button(w, 160, CLOSE or "Close", function() w:Hide() end); f.close:SetPoint("LEFT", f.report, "RIGHT", 12, 0)
	w:Hide()
end
function RR.OpenConfig(id)
	if not RR.config then build() end
	local a = ns.Activities.Get(tonumber(id))
	if a and a.kind == "r" then RR.config.id = a.id end
	load(); RR.config.frame:Show()
end
