-- LfgDialog.lua: the "Find a dungeon group" dialog. G.Post only runs from the Post button or Enter in the note box.
local _, ns = ...
local Dlg = {}
ns.LfgDialog = Dlg
local L, G, D = ns.L, ns.LFG, ns.Dungeons
local ROLES = { "T", "H", "D" }

local function Build()
	local f = ns.Skin.Window("LevelMatesLfgDialog", UIParent)
	Dlg.frame = f
	f:SetSize(320, 230); f:SetPoint("CENTER"); f:SetFrameStrata("DIALOG")
	f:SetMovable(true); f:EnableMouse(true); f:SetClampedToScreen(true); f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", f.StartMoving); f:SetScript("OnDragStop", f.StopMovingOrSizing)
	if f.TitleText then f.TitleText:SetText(L.LFG_DIALOG_TITLE) end
	tinsert(UISpecialFrames, "LevelMatesLfgDialog")
	f:Hide()

	local pick = ns.Skin.Button(f)
	pick:SetSize(280, 22); pick:SetPoint("TOP", 0, -36); pick:SetText(L.LFG_PICK_DUNGEON)
	pick:SetScript("OnClick", function(self)
		MenuUtil.CreateContextMenu(self, function(_, root)
			for _, d in ipairs(D.list) do
				root:CreateButton(string.format("%s (%d-%d)", D.Name(d.id), d.min, d.max), function() Dlg.SelectDungeon(d.id) end)
			end
		end)
	end)
	Dlg.pick = pick

	local rolesLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	rolesLabel:SetPoint("TOPLEFT", 20, -68); rolesLabel:SetText(L.LFG_ROLES_LABEL)
	Dlg.roleChecks = {}
	for i, ch in ipairs(ROLES) do
		local cb = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
		cb:SetSize(24, 24); cb:SetPoint("TOPLEFT", 20 + (i - 1) * 95, -86)
		local label = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		local text = L["ROLE_" .. ch]
		label:SetPoint("LEFT", cb, "RIGHT", 2, 0); label:SetText(text:sub(1, 1):upper() .. text:sub(2))
		cb:SetScript("OnClick", function() Dlg.Refresh() end)
		Dlg.roleChecks[ch] = cb
	end

	local noteLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	noteLabel:SetPoint("TOPLEFT", 20, -122); noteLabel:SetText(L.LFG_NOTE_HINT)
	local note = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
	note:SetSize(270, 22); note:SetPoint("TOP", 0, -146); note:SetAutoFocus(false); note:SetMaxLetters(40)
	note:SetScript("OnEnterPressed", function() Dlg.Publish() end)
	note:SetScript("OnEscapePressed", function() f:Hide() end)
	Dlg.note = note

	local ok = ns.Skin.Button(f)
	ok:SetSize(130, 22); ok:SetPoint("BOTTOMLEFT", 20, 14); ok:SetText(L.LFG_PUBLISH)
	ok:SetScript("OnClick", function() Dlg.Publish() end)
	Dlg.ok = ok
	local close = ns.Skin.Button(f)
	close:SetSize(130, 22); close:SetPoint("BOTTOMRIGHT", -20, 14); close:SetText(L.LFG_CLOSE)
	close:SetScript("OnClick", function() f:Hide() end)
end

local function Roles()
	local out = ""
	for _, ch in ipairs(ROLES) do if Dlg.roleChecks[ch]:GetChecked() then out = out .. ch end end
	return out
end

function Dlg.Refresh()
	if not Dlg.frame then return end
	Dlg.ok:SetEnabled(Dlg.dungeon ~= nil and Roles() ~= "")
end

function Dlg.SelectDungeon(id)
	local d = D.Get(id)
	if not d then return end
	Dlg.dungeon = id
	Dlg.pick:SetText(string.format("%s (%d-%d)", D.Name(id), d.min, d.max))
	Dlg.Refresh()
end

function Dlg.Publish()
	local roles = Roles()
	if not Dlg.dungeon or roles == "" then return end
	if G.Post(Dlg.dungeon, roles, Dlg.note:GetText()) then Dlg.frame:Hide() end   -- a refused post keeps the dialog open
end

-- Opens with the last dungeon and roles remembered, the note empty.
function Dlg.Open()
	if not Dlg.frame then Build() end
	Dlg.note:SetText("")
	Dlg.frame:Show()
	Dlg.Refresh()
end

ns.On("LM_LFG_BUTTON", function()
	if G.mine then G.Cancel() else Dlg.Open() end
end)

-- A dungeon card's "Look for a group here": the dialog with that dungeon chosen.
ns.On("LM_LFG_HERE", function(id) Dlg.Open(); Dlg.SelectDungeon(id) end)
