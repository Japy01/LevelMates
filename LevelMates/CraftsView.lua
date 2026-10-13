-- CraftsView.lua: the Crafts tab as two panes inside the book. Left: every profession in the guild, how many have it
-- and how many recipes the guild knows for it. Right: the chosen profession with its crafters (rank bar, when their
-- recipes were read); a crafter's click shows their recipes (Back returns); the search shows who crafts an item.
-- Asking for an item is a whisper, only from a click. Recipes come from each player's own profession window.
local _, ns = ...
local CV = {}
ns.CraftsView = CV
local L, R = ns.L, ns.Roster
local unpack = unpack or table.unpack
CV.ROWS, CV.PROFS = 15, 14
local PAD, ROW_H = 6, 20
local CLASS_ICON = "Interface\\TargetingFrame\\UI-Classes-Circles"

local function ink(fs) ns.Skin.InkFont(fs); return fs end
local function ago(t)
	if not t then return "" end
	return string.format(L.FEED_AGO, ns.Journal.Duration(math.max(0, time() - t)))
end
local function classOf(name)
	if name == ns.Me() then return select(2, UnitClass("player")) end
	local m = R.mates[name]
	return m and m.class
end

------------------------------------------------------------------ data
-- { id, who, recipes } for every profession someone has; recipes: different items the guild can craft with it.
function CV.Professions()
	local P, RC = ns.Professions, ns.Recipes
	local by, order = {}, {}
	for _, c in ipairs(P.List()) do
		if not by[c.id] then by[c.id] = { id = c.id, crafters = {}, items = {} }; order[#order + 1] = c.id end
		table.insert(by[c.id].crafters, c)
		local e = RC.Of(c.name)[c.id]
		for _, item in ipairs(e and e.items or {}) do by[c.id].items[item] = true end
	end
	for _, c in ipairs(RC.Crafters()) do   -- recipes arrived, ranks not (yet): still a crafter
		if not by[c.id] then by[c.id] = { id = c.id, crafters = {}, items = {} }; order[#order + 1] = c.id end
		local listed = false
		for _, x in ipairs(by[c.id].crafters) do if x.name == c.name then listed = true end end
		if not listed then table.insert(by[c.id].crafters, c) end
		local e = RC.Of(c.name)[c.id]
		for _, item in ipairs(e and e.items or {}) do by[c.id].items[item] = true end
	end
	for _, p in pairs(by) do table.sort(p.crafters, function(x, y) if (x.rank or 0) ~= (y.rank or 0) then return (x.rank or 0) > (y.rank or 0) end; return x.name < y.name end) end
	local out = {}
	for _, id in ipairs(order) do
		local n = 0
		for _ in pairs(by[id].items) do n = n + 1 end
		out[#out + 1] = { id = id, who = #by[id].crafters, recipes = n, crafters = by[id].crafters }
	end
	table.sort(out, function(a, b) return P.Name(a.id) < P.Name(b.id) end)
	return out
end
local function itemName(id) local name = ns.ItemInfo(id); return name or ("#" .. id) end
local function itemColor(id)
	local _, link, quality = ns.ItemInfo(id)
	local c = quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
	if c then return c.r, c.g, c.b end
	local hex = link and link:match("|c%x%x(%x%x%x%x%x%x)")
	if hex then return tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255 end
	return 1, 1, 1
end
local function itemIcon(id) return (C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(id)) or "Interface\\Icons\\INV_Misc_QuestionMark" end

------------------------------------------------------------------ build
local function profRow(parent, i)
	local it = CreateFrame("Button", nil, parent)
	it:SetHeight(ROW_H); it:SetPoint("TOPLEFT", PAD, -40 - (i - 1) * ROW_H); it:SetPoint("RIGHT", -PAD, 0)
	it.bg = it:CreateTexture(nil, "BACKGROUND"); it.bg:SetAllPoints(); it.bg:SetColorTexture(unpack(ns.Skin.C.section)); it.bg:Hide()
	it:SetHighlightTexture("Interface/QuestFrame/UI-QuestLogTitleHighlight", "ADD")
	it.icon = it:CreateTexture(nil, "ARTWORK"); it.icon:SetSize(16, 16); it.icon:SetPoint("LEFT", 2, 0)
	it.name = ink(it:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")); it.name:SetPoint("LEFT", it.icon, "RIGHT", 4, 0)
	it.recipes = ink(it:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")); it.recipes:SetPoint("RIGHT", -2, 0); it.recipes:SetWidth(46); it.recipes:SetJustifyH("RIGHT")
	it.who = ink(it:CreateFontString(nil, "OVERLAY", "GameFontNormal")); it.who:SetPoint("RIGHT", it.recipes, "LEFT", -4, 0); it.who:SetWidth(36); it.who:SetJustifyH("RIGHT")
	it:SetScript("OnClick", function(self) CV.Select(self.prof) end)
	it:Hide()
	return it
end
local function mainRow(parent, i)
	local r = CreateFrame("Button", nil, parent)
	r:SetHeight(ROW_H); r:SetPoint("TOPLEFT", PAD, -102 - (i - 1) * ROW_H); r:SetPoint("RIGHT", -PAD, 0)
	r.bg = r:CreateTexture(nil, "BACKGROUND"); r.bg:SetAllPoints(); r.bg:SetColorTexture(1, 1, 1, i % 2 == 0 and 0.06 or 0)
	r:SetHighlightTexture("Interface/QuestFrame/UI-QuestLogTitleHighlight", "ADD")
	r.icon = r:CreateTexture(nil, "ARTWORK"); r.icon:SetSize(16, 16); r.icon:SetPoint("LEFT", 2, 0)
	r.name = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); r.name:SetPoint("LEFT", r.icon, "RIGHT", 4, 0); r.name:SetWidth(190); r.name:SetJustifyH("LEFT"); r.name:SetWordWrap(false)
	r.barBg = r:CreateTexture(nil, "BORDER"); r.barBg:SetColorTexture(0.24, 0.14, 0.05, 0.45); r.barBg:SetSize(110, 8); r.barBg:SetPoint("LEFT", r.name, "RIGHT", 8, 0)
	r.bar = r:CreateTexture(nil, "ARTWORK"); r.bar:SetTexture("Interface/TargetingFrame/UI-StatusBar"); r.bar:SetVertexColor(0.80, 0.55, 0.12); r.bar:SetHeight(6); r.bar:SetPoint("LEFT", r.barBg, "LEFT", 0, 0)
	r.rank = ink(r:CreateFontString(nil, "OVERLAY", "GameFontNormal")); r.rank:SetPoint("LEFT", r.barBg, "RIGHT", 6, 0); r.rank:SetWidth(40); r.rank:SetJustifyH("RIGHT")
	r.read = ink(r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")); r.read:SetPoint("LEFT", r.rank, "RIGHT", 8, 0); r.read:SetPoint("RIGHT", -2, 0); r.read:SetJustifyH("LEFT"); r.read:SetWordWrap(false)
	r.who = ink(r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")); r.who:SetPoint("LEFT", r.name, "RIGHT", 8, 0); r.who:SetPoint("RIGHT", -2, 0); r.who:SetJustifyH("LEFT"); r.who:SetWordWrap(false)
	r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	r:SetScript("OnClick", function(self, mouse) if mouse == "RightButton" then if self.rfn then self.rfn(self) end elseif self.fn then self.fn(self) end end)
	r:Hide()
	return r
end

function CV.Build(parent)
	local W = ns.Widgets
	local fr = CreateFrame("Frame", nil, parent)
	CV.frame = fr
	CV.left = W.Panel(fr, L.CV_PROFESSIONS)
	local h1 = ink(CV.left:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")); h1:SetPoint("TOPLEFT", PAD + 22, -24); h1:SetText(L.CV_NAME)
	local h2 = ink(CV.left:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")); h2:SetPoint("TOPRIGHT", -PAD - 50, -24); h2:SetText(L.CV_WHO)
	local h3 = ink(CV.left:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")); h3:SetPoint("TOPRIGHT", -PAD - 2, -24); h3:SetText(L.CV_RECIPES)
	CV.profs = { items = {} }
	for i = 1, CV.PROFS do CV.profs.items[i] = profRow(CV.left, i) end
	CV.footer = ink(CV.left:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")); CV.footer:SetPoint("BOTTOMLEFT", PAD, PAD); CV.footer:SetPoint("RIGHT", -PAD, 0); CV.footer:SetJustifyH("LEFT")
	CV.right = W.Panel(fr, "")
	CV.right.title:Hide()
	CV.icon = CV.right:CreateTexture(nil, "ARTWORK"); CV.icon:SetSize(36, 36); CV.icon:SetPoint("TOPLEFT", PAD, -24)
	CV.title = ink(CV.right:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")); CV.title:SetPoint("TOPLEFT", CV.icon, "TOPRIGHT", 8, -1)
	CV.sub = ink(CV.right:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")); CV.sub:SetPoint("TOPLEFT", CV.title, "BOTTOMLEFT", 0, -3)
	CV.big = ink(CV.right:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")); CV.big:SetPoint("TOPRIGHT", -PAD - 4, -24)
	CV.bigLabel = ink(CV.right:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")); CV.bigLabel:SetPoint("TOPRIGHT", CV.big, "BOTTOMRIGHT", 0, -1)
	CV.search = CreateFrame("EditBox", nil, CV.right, "SearchBoxTemplate")
	CV.search:SetSize(240, 20); CV.search:SetPoint("TOPLEFT", PAD + 6, -70)
	if CV.search.Instructions then CV.search.Instructions:SetText(L.CV_SEARCH) end
	CV.search:SetScript("OnTextChanged", function(self) CV.query = self:GetText() or ""; CV.page = 1; CV.Refresh() end)
	CV.back = ns.Skin.Button(CV.right); CV.back:SetSize(80, 20); CV.back:SetPoint("TOPRIGHT", -PAD, -70); CV.back:SetText(L.CV_BACK)
	CV.back:SetScript("OnClick", function() CV.crafter = nil; CV.page = 1; CV.Refresh() end)
	CV.back:Hide()
	CV.colName = ink(CV.right:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")); CV.colName:SetPoint("TOPLEFT", PAD + 22, -92)
	CV.rows = {}
	for i = 1, CV.ROWS do CV.rows[i] = mainRow(CV.right, i) end
	CV.prev = ns.Skin.Button(CV.right); CV.prev:SetSize(28, 20); CV.prev:SetText("<")
	CV.next = ns.Skin.Button(CV.right); CV.next:SetSize(28, 20); CV.next:SetText(">")
	CV.next:SetPoint("BOTTOMRIGHT", -PAD, PAD); CV.prev:SetPoint("RIGHT", CV.next, "LEFT", -4, 0)
	CV.prev:SetScript("OnClick", function() CV.page = math.max(1, (CV.page or 1) - 1); CV.Refresh() end)
	CV.next:SetScript("OnClick", function() CV.page = (CV.page or 1) + 1; CV.Refresh() end)
	CV.pageText = ink(CV.right:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")); CV.pageText:SetPoint("RIGHT", CV.prev, "LEFT", -6, 0)
	CV.page, CV.query = 1, ""
	CV.Layout()
	fr:Hide()
	return fr
end

CV.LEFT_W, CV.GAP = 0.32, 12
function CV.Layout()
	local fr = CV.frame
	local w = fr:GetWidth()
	if not w or w <= 0 then w = ns.Board.WIDTH - 2 * ns.Board.MARGIN end
	local h = fr:GetHeight()
	if not h or h <= 0 then h = 436 end
	local lw = math.floor(w * CV.LEFT_W)
	CV.left:ClearAllPoints(); CV.left:SetPoint("TOPLEFT", 0, 0); CV.left:SetSize(lw, h)
	CV.right:ClearAllPoints(); CV.right:SetPoint("TOPLEFT", lw + CV.GAP, 0); CV.right:SetSize(w - lw - CV.GAP, h)
end

function CV.Select(id) CV.prof, CV.crafter, CV.page = id, nil, 1; CV.Refresh() end

------------------------------------------------------------------ fill
local function ask(owner, name, item)
	MenuUtil.CreateContextMenu(owner, function(_, root)
		root:CreateTitle(itemName(item))
		root:CreateButton(string.format(L.RC_ASK_MENU, name), function() ns.Recipes.Ask(name, item) end)
	end)
end
local function setRows(list, fill)
	local pages = math.max(1, math.ceil(#list / CV.ROWS))
	CV.page = math.min(math.max(1, CV.page or 1), pages)
	local first = (CV.page - 1) * CV.ROWS
	for i, r in ipairs(CV.rows) do
		local e = list[first + i]
		r.fn, r.rfn = nil, nil
		if e then fill(r, e); r:Show() else r:Hide() end
	end
	CV.prev:SetShown(pages > 1); CV.next:SetShown(pages > 1)
	CV.prev:SetEnabled(CV.page > 1); CV.next:SetEnabled(CV.page < pages)
	CV.pageText:SetText(pages > 1 and string.format("%d/%d", CV.page, pages) or "")
end
local function plainRow(r, showBar)
	r.barBg:SetShown(showBar); r.bar:SetShown(showBar); r.rank:SetShown(showBar); r.read:SetShown(showBar); r.who:SetShown(not showBar)
end

function CV.Refresh()
	if not CV.frame or not CV.frame:IsShown() then return end
	CV.Layout()
	local P, RC = ns.Professions, ns.Recipes
	local profs = CV.Professions()
	local people, recipes = {}, 0
	for _, p in ipairs(profs) do recipes = recipes + p.recipes; for _, c in ipairs(p.crafters) do people[c.name] = true end end
	local n = 0
	for _ in pairs(people) do n = n + 1 end
	CV.footer:SetText(string.format(L.CV_FOOTER, n, recipes))
	if not CV.prof and profs[1] then CV.prof = profs[1].id end
	local current
	for i, it in ipairs(CV.profs.items) do
		local p = profs[i]
		if p then
			it.prof = p.id
			it.icon:SetTexture(P.Icon(p.id)); it.name:SetText(P.Name(p.id)); it.who:SetText(tostring(p.who)); it.recipes:SetText(tostring(p.recipes))
			it.bg:SetShown(p.id == CV.prof)
			it:Show()
		else it:Hide() end
		if p and p.id == CV.prof then current = p end
	end
	CV.left:SetEmpty(#profs == 0); CV.left:SetHint(L.CRAFTS_EMPTY)
	local q = strtrim(CV.query or "")
	if q ~= "" and (#q >= 3 or tonumber(q) or q:find("item:", 1, true)) then
		-- who crafts what matches
		CV.mode = "search"
		CV.back:Hide()
		CV.icon:SetTexture("Interface\\Icons\\INV_Misc_Spyglass_03"); CV.title:SetText(L.CV_FOUND); CV.colName:SetText(L.CV_ITEM)
		local found = RC.Find(q)
		CV.sub:SetText(string.format(L.CV_FOUND_N, #found)); CV.big:SetText(tostring(#found)); CV.bigLabel:SetText(L.CV_ITEMS)
		setRows(found, function(r, item)
			plainRow(r, false)
			r.icon:SetTexture(itemIcon(item)); r.name:SetText(itemName(item)); r.name:SetTextColor(ns.Skin.Ink(itemColor(item)))
			local who = {}
			for _, c in ipairs(RC.WhoCrafts(item)) do who[#who + 1] = c.name .. (c.online and "" or (" (" .. L.CV_OFFLINE .. ")")) end
			r.who:SetText(table.concat(who, ", "))
			r.fn = function(self)
				MenuUtil.CreateContextMenu(self, function(_, root)
					root:CreateTitle(itemName(item))
					for _, c in ipairs(RC.WhoCrafts(item)) do
						if c.name ~= ns.Me() then root:CreateButton(string.format(L.RC_ASK_MENU, c.name), function() RC.Ask(c.name, item) end) end
					end
				end)
			end
		end)
	elseif CV.crafter and current then
		-- a crafter's recipes in this profession
		CV.mode = "recipes"
		CV.back:Show()
		local c = CV.crafter
		local e = RC.Of(c.name)[current.id]
		local items = {}
		for _, item in ipairs(e and e.items or {}) do items[#items + 1] = item end
		table.sort(items, function(a, b) return itemName(a) < itemName(b) end)
		CV.icon:SetTexture(P.Icon(current.id)); CV.title:SetText(c.name); CV.title:SetTextColor(1, 0.82, 0)
		CV.sub:SetText(string.format(L.CV_CRAFTER_SUB, P.Name(current.id), c.rank or 0, c.max or 0, e and ago(e.t) or L.CV_NOT_READ))
		CV.big:SetText(tostring(#items)); CV.bigLabel:SetText(L.CV_RECIPES_LOWER); CV.colName:SetText(L.CV_ITEM)
		setRows(items, function(r, item)
			plainRow(r, false)
			r.icon:SetTexture(itemIcon(item)); r.name:SetText(itemName(item)); r.name:SetTextColor(ns.Skin.Ink(itemColor(item))); r.who:SetText("")
			if c.name ~= ns.Me() then r.fn = function(self) ask(self, c.name, item) end end
		end)
		if #items == 0 then CV.right:SetHint(string.format(L.CV_NO_RECIPES, c.name)) end
		CV.right:SetEmpty(#items == 0)
		ns.Skin.InkPass()
		return
	else
		-- the profession's crafters
		CV.mode = "crafters"
		CV.back:Hide()
		local crafters = current and current.crafters or {}
		if current then
			CV.icon:SetTexture(P.Icon(current.id)); CV.title:SetText(P.Name(current.id)); CV.title:SetTextColor(1, 0.82, 0)
			CV.sub:SetText(string.format(L.CV_PROF_SUB, current.who, current.recipes))
			CV.big:SetText(tostring(current.who)); CV.bigLabel:SetText(L.CV_CRAFTERS)
		else
			CV.icon:SetTexture(nil); CV.title:SetText(""); CV.sub:SetText(""); CV.big:SetText(""); CV.bigLabel:SetText("")
		end
		CV.colName:SetText(L.CV_NAME)
		setRows(crafters, function(r, c)
			plainRow(r, true)
			local coords = CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[classOf(c.name) or ""]
			if coords then r.icon:SetTexture(CLASS_ICON); r.icon:SetTexCoord(unpack(coords)) else r.icon:SetTexture(P.Icon(c.id)); r.icon:SetTexCoord(0, 1, 0, 1) end
			r.name:SetText(c.name)
			local cc = RAID_CLASS_COLORS and RAID_CLASS_COLORS[classOf(c.name) or ""]
			if cc then r.name:SetTextColor(ns.Skin.Ink(cc.r, cc.g, cc.b)) else r.name:SetTextColor(ns.Skin.Ink(1, 1, 1)) end   -- class colours darkened to read on the page
			local max = c.max and c.max > 0 and c.max or 300
			r.bar:SetWidth(math.max(1, 110 * math.min(1, (c.rank or 0) / max)))
			r.rank:SetText(tostring(c.rank or 0))
			local e = ns.Recipes.Of(c.name)[c.id]
			local parts = {}
			if c.mine then parts[#parts + 1] = L.CV_YOU elseif R.mates[c.name] then parts[#parts + 1] = L.ONLINE end
			local hint = ns.Professions.TrainHint(c.rank, c.max)
			if hint then parts[#parts + 1] = hint end
			if not c.mine then parts[#parts + 1] = e and ago(e.t) or L.CV_NOT_READ end
			r.read:SetText(table.concat(parts, " · "))
			r.fn = function() CV.crafter = c; CV.page = 1; CV.Refresh() end
			if not c.mine then
				r.rfn = function(self)
					MenuUtil.CreateContextMenu(self, function(_, root)
						root:CreateTitle(c.name)
						root:CreateButton(L.MENU_WHISPER, function() ns.Board.Whisper(c.name) end)
						if R.mates[c.name] then root:CreateButton(L.MENU_INVITE, function() ns.Board.Invite(c.name) end) end   -- offline: no invite
					end)
				end
			end
		end)
	end
	CV.right:SetEmpty(false)
	ns.Skin.InkPass()
end
