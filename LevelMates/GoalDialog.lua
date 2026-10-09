-- GoalDialog.lua: the officers' "New guild goal" dialog. Goals.Create runs only from its Create button.
local _, ns = ...
local Dlg = {}
ns.GoalDialog = Dlg
local L, G, D = ns.L, ns.Goals, ns.Dungeons
local TYPES = { { "lvl", "GOAL_TYPE_LVL" }, { "dun", "GOAL_TYPE_DUN" }, { "cnt", "GOAL_TYPE_CNT" } }
local WHATS = { { "lvl", "GOAL_WHAT_LVL" }, { "qst", "GOAL_WHAT_QST" }, { "dun", "GOAL_WHAT_DUN" } }
local DAYS = { 1, 3, 7, 14 }
Dlg.days = 7

local function Menu(owner, items)
	MenuUtil.CreateContextMenu(owner, function(_, root)
		for _, it in ipairs(items) do root:CreateButton(it[1], it[2]) end
	end)
end

local function Button(f, w, point, x, y, text, onClick)
	local b = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
	b:SetSize(w, 22); b:SetPoint(point, x, y); b:SetText(text)
	b:SetScript("OnClick", onClick)
	return b
end

local function Build()
	local f = CreateFrame("Frame", "LevelMatesGoalDialog", UIParent, "BasicFrameTemplateWithInset")
	Dlg.frame = f
	f:SetSize(320, 220); f:SetPoint("CENTER"); f:SetFrameStrata("DIALOG")
	f:SetMovable(true); f:EnableMouse(true); f:SetClampedToScreen(true); f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", f.StartMoving); f:SetScript("OnDragStop", f.StopMovingOrSizing)
	if f.TitleText then f.TitleText:SetText(L.GOAL_DIALOG_TITLE) end
	tinsert(UISpecialFrames, "LevelMatesGoalDialog")
	f:Hide()

	Dlg.typeButton = Button(f, 280, "TOP", 0, -36, L.GOAL_PICK_TYPE, function(self)
		local items = {}
		for _, t in ipairs(TYPES) do items[#items + 1] = { L[t[2]], function() Dlg.SetType(t[1]) end } end
		Menu(self, items)
	end)
	local target = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
	target:SetSize(80, 22); target:SetPoint("TOPLEFT", 28, -76); target:SetAutoFocus(false); target:SetMaxLetters(5)
	target:SetScript("OnTextChanged", function() Dlg.Refresh() end)
	Dlg.target = target
	Dlg.dungeonButton = Button(f, 280, "TOP", 0, -74, L.LFG_PICK_DUNGEON, function(self)
		local items = {}
		for _, d in ipairs(D.list) do
			items[#items + 1] = { string.format("%s (%d-%d)", D.Name(d.id), d.min, d.max), function()
				Dlg.dungeon = d.id; Dlg.dungeonButton:SetText(string.format("%s (%d-%d)", D.Name(d.id), d.min, d.max)); Dlg.Refresh()
			end }
		end
		Menu(self, items)
	end)
	Dlg.whatButton = Button(f, 160, "TOPLEFT", 130, -74, L.GOAL_COUNT_WHAT, function(self)
		local items = {}
		for _, w in ipairs(WHATS) do items[#items + 1] = { L[w[2]], function() Dlg.what = w[1]; Dlg.whatButton:SetText(L[w[2]]); Dlg.Refresh() end } end
		Menu(self, items)
	end)
	Dlg.daysButton = Button(f, 120, "TOPLEFT", 20, -118, string.format(L.GOAL_DAYS, Dlg.days), function(self)
		local items = {}
		for _, n in ipairs(DAYS) do items[#items + 1] = { string.format(L.GOAL_DAYS, n), function() Dlg.days = n; Dlg.daysButton:SetText(string.format(L.GOAL_DAYS, n)); Dlg.Refresh() end } end
		Menu(self, items)
	end)
	Dlg.ok = Button(f, 130, "BOTTOMLEFT", 20, 14, L.GOAL_CREATE, function() Dlg.Create() end)
	Button(f, 130, "BOTTOMRIGHT", -20, 14, L.LFG_CLOSE, function() f:Hide() end)
end

function Dlg.SetType(ty)
	Dlg.type = ty
	for _, t in ipairs(TYPES) do if t[1] == ty then Dlg.typeButton:SetText(L[t[2]]) end end
	Dlg.Refresh()
end

local function Target()
	if Dlg.type == "dun" then return Dlg.dungeon end
	return tonumber(Dlg.target:GetText() or "")
end

function Dlg.Refresh()
	if not Dlg.frame then return end
	local ty = Dlg.type
	Dlg.target:SetShown(ty == "lvl" or ty == "cnt")
	Dlg.dungeonButton:SetShown(ty == "dun")
	Dlg.whatButton:SetShown(ty == "cnt")
	local ready = ty ~= nil and Target() ~= nil and (ty ~= "cnt" or Dlg.what ~= nil)
	Dlg.ok:SetEnabled(ready)
end

function Dlg.Create()
	if G.Create(Dlg.type, Target(), Dlg.what, Dlg.days) then Dlg.frame:Hide() end   -- a refused create keeps the dialog open
end

function Dlg.Open()
	if not Dlg.frame then Build() end
	Dlg.frame:Show()
	Dlg.Refresh()
end

ns.On("LM_GOAL_NEW", Dlg.Open)
