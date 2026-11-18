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
local function spanish() return L.READY_SAVE == "Guardar perfil" end
local function label(es, en) return spanish() and es or en end
local function playerClass()
	local ok, _, class = pcall(UnitClass, "player")
	return ok and ns.Plain(class) or nil
end
local function refreshRows(f)
	for i, row in ipairs(f.rows) do
		local item = f.items[f.offset + i]
		local icon = item and C_Item and C_Item.GetItemIconByID and ns.Plain(C_Item.GetItemIconByID(item.id))
		row.icon:SetTexture(icon or 134400)
		row.icon:SetShown(item ~= nil)
		row.item:SetText(item and (ns.Wishlist.Link(item.id) or ns.ItemInfo(item.id) or ("#" .. item.id)) or "")
		row.count:SetText(item and tostring(item.required) or "")
		row.count:SetShown(item ~= nil)
		row.remove:SetShown(item ~= nil)
	end
	f.prev:SetEnabled(f.offset > 0)
	f.next:SetEnabled(f.offset + #f.rows < #f.items)
end
local function captureCounts(f)
	for i, row in ipairs(f.rows) do
		local item = f.items[f.offset + i]
		if item then
			local count = tonumber(row.count:GetText())
			if not count or count < 1 or count > 999 or count ~= math.floor(count) then
				f.status:SetText(label("Escribe una cantidad de 1 a 999.", "Enter a quantity from 1 to 999."))
				return false
			end
		end
	end
	for i, row in ipairs(f.rows) do
		local item = f.items[f.offset + i]
		if item then item.required = tonumber(row.count:GetText()) end
	end
	return true
end
local function addItem(f, value)
	local id = ns.Wishlist.ItemId(value)
	if not id or id < 1 or id > 999999 or not captureCounts(f) then return end
	for _, item in ipairs(f.items) do if item.id == id then return end end
	if #f.items >= P.MAX_ITEMS then f.status:SetText(L.READY_INVALID_ITEMS); return end
	f.items[#f.items + 1] = { id = id, required = 1 }
	f.offset = math.floor((#f.items - 1) / #f.rows) * #f.rows
	f.link:SetText("")
	refreshRows(f)
	return true
end
local function load()
	local f = RR.config
	f.activity:SetText(ns.Activities.Name(f.id))
	f.mode:SetText(L["READY_MODE_" .. f.kind:upper()])
	local class = playerClass()
	local branch = ns.char.raidReadinessBranch
	f.branch:SetText(branch and class and P.ScopeLabel(class .. branch) or label("Mi rama: sin declarar", "My tree: unset"))
	f.scopeButton:SetText(f.kind == "personal" and L.READY_THIS_CHARACTER or P.ScopeLabel(f.scope)); f.scopeButton:SetEnabled(f.kind ~= "personal")
	local rec = f.kind ~= "personal" and P.Get(f.kind, f.id, f.scope)
	f.items = P.Parse(f.kind == "personal" and P.Encode(RR.PersonalItems(f.id)) or rec and rec.d.i or "") or {}
	f.offset = 0
	f.note:SetText(f.kind == "personal" and (RR.PersonalNote(f.id) or "") or rec and rec.d.n or "")
	f.link:SetText("")
	refreshRows(f)
	f.author:SetText(f.kind == "personal" and L.READY_PRIVATE_PROFILE or rec and string.format(L.READY_PROFILE_AUTHOR, rec.o, date("%d/%m %H:%M", rec.v)) or L.READY_PROFILE_NEW)
	f.status:SetText("")
	f.save:SetEnabled(f.kind == "personal" or P.CanPublish(f.kind))
	f.permission:SetText(f.kind == "personal" and L.READY_PERSONAL_EXTRA or P.CanPublish(f.kind) and L.READY_PUBLISH_HELP or L.READY_NO_PERMISSION)
end
local function build()
	local w = ns.Skin.Window("LevelMatesRaidReadiness", UIParent)
	w:SetSize(640, 530); w:SetPoint("CENTER"); w:SetFrameStrata("DIALOG")
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
			local scope = value
			entries[#entries + 1] = { P.ScopeLabel(scope), function() f.scope = scope; load() end }
			if #scope > 1 and scope ~= "ALL" then
				for branch = 1, 3 do
					local key = scope .. branch
					entries[#entries + 1] = { "  " .. P.ScopeLabel(key), function() f.scope = key; load() end }
				end
			end
		end
		menu(self, entries)
	end); f.scopeButton:SetPoint("LEFT", f.mode, "RIGHT", 12, 0)
	f.branch = button(w, 240, "", function(self)
		local class = playerClass()
		if not class then return end
		local entries = { { label("Sin declarar", "Unset"), function() ns.char.raidReadinessBranch = nil; f.branch:SetText(label("Mi rama: sin declarar", "My tree: unset")) end } }
		for i = 1, 3 do
			local branch = i
			local name = P.ScopeLabel(class .. branch)
			entries[#entries + 1] = { name, function() ns.char.raidReadinessBranch = branch; f.branch:SetText(name) end }
		end
		menu(self, entries)
	end)
	f.branch:SetPoint("LEFT", f.next, "RIGHT", 14, 0)
	local hint = w:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	hint:SetPoint("TOPLEFT", 18, -112)
	hint:SetText(label("Pega un enlace o haz Mayús + clic en un objeto.", "Paste an item link or Shift-click an item."))
	f.link = CreateFrame("EditBox", nil, w, "InputBoxTemplate")
	f.link:SetSize(440, 24); f.link:SetPoint("TOPLEFT", 24, -134); f.link:SetAutoFocus(false)
	f.link:SetScript("OnEnterPressed", function(self) addItem(f, self:GetText()) end)
	f.link:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	local add = button(w, 115, label("Añadir objeto", "Add item"), function() addItem(f, f.link:GetText()) end)
	add:SetPoint("LEFT", f.link, "RIGHT", 12, 0)
	local function receiveDrag()
		if not GetCursorInfo then return end
		local ok, kind, id = pcall(GetCursorInfo)
		kind, id = ns.Plain(kind), ns.Plain(id)
		if ok and kind == "item" and type(id) == "number" then
			if addItem(f, "item:" .. id) and ClearCursor then ClearCursor() end
		end
	end
	f.link:SetScript("OnReceiveDrag", receiveDrag)
	add:SetScript("OnReceiveDrag", receiveDrag)
	f.rows = {}
	for i = 1, 5 do
		local index = i
		local row = {}
		row.item = w:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		row.item:SetPoint("TOPLEFT", 50, -177 - (i - 1) * 28)
		row.item:SetWidth(410); row.item:SetJustifyH("LEFT")
		row.icon = w:CreateTexture(nil, "ARTWORK")
		row.icon:SetSize(21, 21); row.icon:SetPoint("RIGHT", row.item, "LEFT", -7, 0)
		row.count = CreateFrame("EditBox", nil, w, "InputBoxTemplate")
		row.count:SetSize(54, 22); row.count:SetPoint("TOPLEFT", 475, -172 - (i - 1) * 28)
		row.count:SetAutoFocus(false); row.count:SetMaxLetters(3)
		row.remove = button(w, 34, "×", function()
			if not captureCounts(f) then return end
			table.remove(f.items, f.offset + index)
			if f.offset > 0 and f.offset >= #f.items then f.offset = f.offset - #f.rows end
			refreshRows(f)
		end)
		row.remove:SetPoint("LEFT", row.count, "RIGHT", 12, 0)
		f.rows[i] = row
	end
	f.prev = button(w, 42, "<", function() if captureCounts(f) then f.offset = f.offset - #f.rows; refreshRows(f) end end)
	f.prev:SetPoint("TOPLEFT", 18, -311)
	f.next = button(w, 42, ">", function() if captureCounts(f) then f.offset = f.offset + #f.rows; refreshRows(f) end end)
	f.next:SetPoint("LEFT", f.prev, "RIGHT", 6, 0)
	local function capture(link)
		if w:IsShown() and ns.Wishlist.ItemId(link) then f.link:SetText(link) end
	end
	if hooksecurefunc then
		if ChatFrameUtil and ChatFrameUtil.InsertLink then hooksecurefunc(ChatFrameUtil, "InsertLink", capture) end
		if ChatEdit_InsertLink then hooksecurefunc("ChatEdit_InsertLink", capture) end
	end
	local noteLabel = w:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	noteLabel:SetPoint("TOPLEFT", 18, -345)
	noteLabel:SetText(label("Instrucción opcional (comprobación manual)", "Optional instruction (manual check)"))
	f.note = CreateFrame("EditBox", nil, w, "InputBoxTemplate")
	f.note:SetSize(545, 24); f.note:SetPoint("TOPLEFT", 24, -365); f.note:SetAutoFocus(false); f.note:SetMaxLetters(160)
	f.author = w:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); f.author:SetPoint("TOPLEFT", 18, -400); f.author:SetWidth(560); f.author:SetJustifyH("LEFT")
	f.permission = w:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); f.permission:SetPoint("TOPLEFT", 18, -422); f.permission:SetWidth(560); f.permission:SetJustifyH("LEFT")
	f.status = w:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); f.status:SetPoint("TOPLEFT", 18, -455); f.status:SetWidth(560); f.status:SetJustifyH("LEFT")
	f.save = button(w, 160, L.READY_SAVE, function()
		if not captureCounts(f) then return end
		local text = P.Encode(f.items)
		local ok, why
		if f.kind == "personal" then ok = RR.SetItems(f.id, text, f.note:GetText()) else ok, why = P.Set(f.kind, f.id, f.scope, text, f.note:GetText()) end
		if ok then f.link:ClearFocus(); load(); f.status:SetText(f.kind == "personal" and L.READY_SAVED or L.READY_SHARED_SAVED)
		else f.status:SetText(why == "permission" and L.READY_NO_PERMISSION or L.READY_INVALID_ITEMS) end
	end); f.save:SetPoint("BOTTOMLEFT", 18, 18)
	f.report = button(w, 160, L.READY_VIEW_REPORT, function() ns.DiscordCopy.OpenText(RR.Text(f.id), label("Mi preparación", "My readiness"), label("Lee el informe o cópialo si quieres compartirlo.", "Read this report or copy it to share.")) end); f.report:SetPoint("LEFT", f.save, "RIGHT", 12, 0)
	f.close = button(w, 160, CLOSE or "Close", function() w:Hide() end); f.close:SetPoint("LEFT", f.report, "RIGHT", 12, 0)
	w:Hide()
end
function RR.OpenConfig(id)
	if not RR.config then build() end
	local a = ns.Activities.Get(tonumber(id))
	if a and a.kind == "r" then RR.config.id = a.id end
	load(); RR.config.frame:Show()
end
