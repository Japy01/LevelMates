-- The public board uses the same guild sync as other officer publications.
local _, ns = ...
local S, C, R, L = ns.Sync, ns.Comm, ns.Roster, ns.L
local function label(es, en) return L.READY_SAVE == "Guardar perfil" and es or en end
local function officer(name)
	return R.IsOfficer(name) or (name == ns.Me() and R.IAmOfficer())
end
local function valid(limit, multiline)
	return function(value) return type(value) == "string" and #value > 0 and #value <= limit and not (multiline and value:gsub("\n", "") or value):find("[%c|]") end
end
S.Define("gan", { class = "board", life = 90 * 86400, max = 30, relayMax = 30, removerOwns = true,
	fields = { h = valid(60), b = valid(500, true) }, required = { "h", "b" },
	idOwner = function(_, owner) return officer(owner) end,
	accept = function(_, owner) return officer(owner) end,
	may = function(_, who) return officer(who) end,
	relayFrom = function(owner, sender) return owner == sender or officer(sender) end,
	canAnswer = function() return officer(ns.Me()) end,
	onChange = function() ns.Board.Refresh() end })

local A = {}
ns.GuildAnnouncements = A
function A.CanPublish() return officer(ns.Me()) end

-- Keep restricted records out of the guild sync store and all broadcasts.
local function private()
	ns.char.restrictedAnnouncements = ns.char.restrictedAnnouncements or {}
	local guild = ns.GuildKey()
	ns.char.restrictedAnnouncements[guild] = ns.char.restrictedAnnouncements[guild] or {}
	return ns.char.restrictedAnnouncements[guild]
end
local function roster()
	local ranks, members, master = {}, {}, nil
	for _, member in ipairs(R.GuildMembers() or {}) do
		local rank, name = member.verifiedRank, member.rankName
		if type(rank) == "number" and rank >= 0 and rank == math.floor(rank) and type(name) == "string" and name ~= "" then
			ranks[rank], members[member.name] = name, member
			if member.role == 1 then master = rank end
		end
	end
	if not master then return {}, {} end
	for rank in pairs(ranks) do if rank < master then return {}, {} end end
	return ranks, members
end
local function allowed(f, name, ranks, members)
	local member = members[name]
	return ranks[f.r] == f.n and member and member.verifiedRank <= f.r
end
local function isMaster(name)
	if name == ns.Me() and IsGuildLeader then
		local ok, value = pcall(IsGuildLeader)
		if ok and ns.Plain(value) == true then return true end
	end
	for _, member in ipairs(R.GuildMembers() or {}) do
		if member.name == name then return member.role == 1 end
	end
	return false
end
S.Define("gam", { class = "board", life = 365 * 86400, writerOwns = true, writerTieBreak = true,
	fields = { r = C.V.int(0, 255), n = C.V.text(60) }, required = { "r", "n" },
	idOwner = function(id, owner) return id == "moderation" and isMaster(owner) end,
	accept = function(_, owner) return isMaster(owner) end,
	may = function(_, who) return isMaster(who) end,
	relayFrom = function(owner, sender) return owner == sender or officer(sender) end,
	canAnswer = function() return officer(ns.Me()) end,
	onChange = function() ns.Board.Refresh() end })
local function moderator(name, ranks, members)
	if isMaster(name) then return true end
	local policy = S.Get("gam", "moderation")
	return policy and isMaster(policy.o) and allowed(policy.d, name, ranks, members)
end
local function canSend(f, name, ranks, members)
	if f.x then return moderator(name, ranks, members) or (officer(name) and f.id:sub(1, 8) == ns.NameKey(name)) end
	return officer(name) and f.id:sub(1, 8) == ns.NameKey(name)
end
A.IsMaster = isMaster
C.SCHEMA.gar = { id = C.V.word(24), h = valid(60), b = valid(500, true), v = C.V.int(0, 4000000000), r = C.V.int(0, 255), n = C.V.text(60), x = C.V.int(1, 1) }
C.REQUIRED.gar = { "id", "h", "b", "v", "r", "n" }
local function send(f, name, ranks, members)
	if name ~= ns.Me() and allowed(f, name, ranks, members) then
		local guild, full = ns.GuildKey(), members[name].fullName
		if not full or guild == "?" then return end
		C.SendBig("gar", f, "normal", name, { fullTarget = full, canSend = function()
			if ns.GuildKey() ~= guild then return false end
			local currentRanks, currentMembers = roster()
			local member = currentMembers[name]
			return member and member.fullName == full and allowed(f, name, currentRanks, currentMembers) and canSend(f, ns.Me(), currentRanks, currentMembers)
		end })
	end
end
local LIFE = 90 * 86400
C.OnMessage("gar", function(f, author, _, channel)
	if channel ~= "WHISPER" or not R.IsGuildmate(author) then return end
	if f.v > GetServerTime() + 300 or f.v < GetServerTime() - LIFE then return end
	R.InvalidateGuildRoster()
	local ranks, members = roster()
	if not allowed(f, ns.Me(), ranks, members) or not canSend(f, author, ranks, members) then return end
	if f.x and (f.h ~= "-" or f.b ~= "-") then return end
	local old = private()[f.id]
	if old and (old.d.x or old.v >= f.v) then return end
	private()[f.id] = { id = f.id, o = author, v = f.v, d = f }
	ns.Board.Refresh()
end)
local replied = {}
C.OnMessage("hi", function(_, name)
	if not R.IsGuildmate(name) or (replied[name] or -60) + 60 > GetTime() then return end
	replied[name] = GetTime()
	R.InvalidateGuildRoster()
	local ranks, members = roster()
	for _, rec in pairs(private()) do
		if rec.o == ns.Me() and canSend(rec.d, ns.Me(), ranks, members) and rec.v >= GetServerTime() - LIFE then send(rec.d, name, ranks, members) end
	end
end)
function A.List(search)
	local list = S.List("gan")
	local ranks, members = roster()
	for id, rec in pairs(private()) do
		if rec.v < GetServerTime() - LIFE then private()[id] = nil
		elseif not rec.d.x and allowed(rec.d, ns.Me(), ranks, members) then list[#list + 1] = rec end
	end
	if search and search ~= "" then
		local query = search:lower()
		for i = #list, 1, -1 do
			local rec = list[i]
			if not (rec.o .. " " .. rec.d.h .. " " .. rec.d.b):lower():find(query, 1, true) then table.remove(list, i) end
		end
	end
	table.sort(list, function(a, b) return a.v == b.v and a.id > b.id or a.v > b.v end)
	return list
end

local function window(name, title)
	local w = ns.Skin.Window(name, UIParent)
	w:SetSize(560, 320); w:SetPoint("CENTER"); w:SetFrameStrata("DIALOG")
	if w.TitleText then w.TitleText:SetText(title) end
	if UISpecialFrames then table.insert(UISpecialFrames, name) end
	return w
end
local function button(w, text, x, fn)
	local b = ns.Skin.Button(w)
	b:SetSize(145, 24); b:SetPoint("BOTTOMLEFT", x, 18); b:SetText(text); b:SetScript("OnClick", fn)
	return b
end
function A.Audience(rec)
	return rec.d.n and (label("Desde ", "From ") .. rec.d.n) or label("Público", "Public")
end
function A.CanWithdraw(rec)
	if not rec.d.r then return A.CanPublish() end
	local ranks, members = roster()
	return allowed(rec.d, ns.Me(), ranks, members) and
		(moderator(ns.Me(), ranks, members) or (rec.o == ns.Me() and A.CanPublish()))
end
function A.Withdraw(rec)
	if not A.CanWithdraw(rec) then return false end
	if not rec.d.r then return S.Remove("gan", rec.id) end
	local old = private()[rec.id]
	if not old or old.d.x then return false end
	local f = { id = old.id, h = "-", b = "-", v = math.max(GetServerTime(), old.v + 1), r = old.d.r, n = old.d.n, x = 1 }
	private()[f.id] = { id = f.id, o = ns.Me(), v = f.v, d = f }
	R.InvalidateGuildRoster()
	local ranks, members = roster()
	for name, member in pairs(members) do if member.online then send(f, name, ranks, members) end end
	ns.Board.Refresh()
	return true
end
local detail
function A.Detail(rec)
	if rec.d.r then
		local ranks, members = roster()
		if not allowed(rec.d, ns.Me(), ranks, members) then return end
	end
	if not detail then
		local w = window("LevelMatesAnnouncementDetail", L.TAB_ANNOUNCEMENTS)
		local meta = w:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		meta:SetPoint("TOPLEFT", 24, -42)
		local scroll = CreateFrame("ScrollFrame", nil, w, "UIPanelScrollFrameTemplate")
		scroll:SetPoint("TOPLEFT", 24, -72); scroll:SetPoint("BOTTOMRIGHT", -35, 55)
		local content = CreateFrame("Frame", nil, scroll); content:SetWidth(490)
		local body = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		body:SetPoint("TOPLEFT"); body:SetWidth(490); body:SetJustifyH("LEFT"); body:SetWordWrap(true)
		scroll:SetScrollChild(content)
		detail = { frame = w, meta = meta, body = body, content = content, scroll = scroll }
		button(w, CLOSE or "Close", 22, function() w:Hide() end)
		detail.remove = button(w, label("Retirar anuncio", "Withdraw announcement"), 184, function()
			local selected = detail.record
			ns.Confirm(label("¿Retirar este anuncio del tablón?", "Withdraw this announcement from the board?"), function()
				if A.Withdraw(selected) then w:Hide() end
			end)
		end)
	end
	detail.record = rec
	if detail.frame.TitleText then detail.frame.TitleText:SetText(rec.d.h) end
	detail.meta:SetText(rec.o .. " · " .. date("%d/%m/%Y %H:%M", rec.v) .. " · " .. A.Audience(rec))
	detail.body:SetText(rec.d.b)
	detail.remove:SetShown(A.CanWithdraw(rec))
	detail.frame:Show()
	detail.content:SetHeight(math.max(1, detail.body:GetStringHeight()))
	detail.scroll:SetVerticalScroll(0)
end
local editor
function A.Compose()
	if not A.CanPublish() then return end
	if editor then editor:Show(); return end
	local w = window("LevelMatesAnnouncementEditor", L.ANNOUNCEMENTS_NEW)
	editor = w
	local function fieldLabel(text, y)
		local font = w:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		font:SetPoint("TOPLEFT", 24, y); font:SetText(text)
	end
	fieldLabel(label("Título", "Title"), -36)
	fieldLabel(label("Mensaje", "Message"), -88)
	local title = CreateFrame("EditBox", nil, w, "InputBoxTemplate")
	title:SetSize(500, 22); title:SetPoint("TOPLEFT", 24, -55); title:SetAutoFocus(false); title:SetMaxLetters(60)
	local panel = CreateFrame("Frame", nil, w, "BackdropTemplate")
	panel:SetPoint("TOPLEFT", 22, -108); panel:SetPoint("BOTTOMRIGHT", -24, 89)
	ns.Skin.Backdrop(panel, { 0.07, 0.06, 0.05, 1 }, { 0.64, 0.51, 0.32, 1 })
	local scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", 8, -8); scroll:SetPoint("BOTTOMRIGHT", -26, 8)
	local body = CreateFrame("EditBox", nil, scroll)
	body:SetMultiLine(true); body:SetFontObject("ChatFontNormal"); body:SetWidth(477); body:SetHeight(101); body:SetAutoFocus(false); body:SetMaxLetters(500)
	scroll:SetScrollChild(body)
	body:EnableMouse(true)
	scroll:EnableMouse(true)
	scroll:SetScript("OnMouseDown", function() body:SetFocus() end)
	local restricted = CreateFrame("CheckButton", nil, w, "UICheckButtonTemplate")
	restricted:SetPoint("BOTTOMLEFT", 20, 54)
	local caption = CreateFrame("Button", nil, w)
	caption:SetPoint("LEFT", restricted, "RIGHT", 2, 0); caption:SetSize(165, 24)
	local captionText = caption:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	captionText:SetPoint("LEFT"); captionText:SetText(label("Restringir por rango", "Restrict by rank"))
	local rankButton = ns.Skin.Button(w)
	rankButton:SetSize(220, 24); rankButton:SetPoint("BOTTOMRIGHT", -24, 56)
	local rank, rankName
	local prompt = label("Elegir rango mínimo", "Choose minimum rank")
	rankButton:SetText(prompt); rankButton:Hide()
	local function updateRestriction() rankButton:SetShown(restricted:GetChecked() and true or false) end
	restricted:SetScript("OnClick", updateRestriction)
	caption:SetScript("OnClick", function()
		restricted:SetChecked(not restricted:GetChecked())
		updateRestriction()
	end)
	rankButton:SetScript("OnClick", function(self)
		R.InvalidateGuildRoster()
		local ranks, members = roster()
		local mine = members[ns.Me()]
		local order = {}
		for i, name in pairs(ranks) do
			if mine and mine.verifiedRank <= i and C.V.text(60)(name) then order[#order + 1] = i end
		end
		table.sort(order)
		MenuUtil.CreateContextMenu(self, function(_, root)
			for _, i in ipairs(order) do
				local value, name = i, ranks[i]
				root:CreateButton(name, function() rank, rankName = value, name; self:SetText(name) end)
			end
			if #order == 0 then root:CreateTitle(label("Rangos no disponibles", "Ranks unavailable")) end
		end)
	end)
	button(w, label("Publicar", "Publish"), 22, function()
		if not A.CanPublish() then return end
		local h, b = strtrim(title:GetText()), strtrim(body:GetText())
		if not valid(60)(h) then
			title:SetFocus(); ns.Say(label("Introduce un título válido.", "Enter a valid title.")); return
		end
		if not valid(500, true)(b) then
			body:SetFocus(); ns.Say(label("Introduce un mensaje válido.", "Enter a valid message.")); return
		end
		local v = GetServerTime()
		local prefix = ns.NameKey(ns.Me()) .. string.format("%x", v)
		local n = 1
		while S.Store("gan")[prefix .. n] or private()[prefix .. n] do n = n + 1 end
		local id = prefix .. n
		if restricted:GetChecked() then
			R.InvalidateGuildRoster()
			local ranks, members = roster()
			if not rank or not allowed({ r = rank, n = rankName }, ns.Me(), ranks, members) then
				ns.Say(label("Selecciona un rango verificable.", "Select a verifiable rank.")); return
			end
			local f = { id = id, h = h, b = b, v = v, r = rank, n = rankName }
			if not C.Validate("gar", f) then return end
			private()[id] = { id = id, o = ns.Me(), v = v, d = f }
			for name, member in pairs(members) do if member.online then send(f, name, ranks, members) end end
			ns.Board.Refresh()
		else
			if #S.List("gan") >= 30 then ns.Say(label("El tablón está lleno.", "The board is full.")); return end
			S.Put("gan", id, { h = h, b = b })
		end
		title:SetText(""); body:SetText(""); restricted:SetChecked(false)
		rank, rankName = nil, nil; rankButton:SetText(prompt); rankButton:Hide(); w:Hide()
	end)
	button(w, CANCEL or "Cancel", 178, function() w:Hide() end)
	w:Show()
end
function A.ModerationChoices()
	local ranks, members = roster()
	local me = members[ns.Me()]
	local choices = { { value = "master", label = label("Solo el maestro", "Guild master only") } }
	if not me or not isMaster(ns.Me()) then return choices end
	local ordered = {}
	for id, name in pairs(ranks) do
		if id > me.verifiedRank and C.V.text(60)(name) then ordered[#ordered + 1] = id end
	end
	table.sort(ordered)
	for _, id in ipairs(ordered) do
		choices[#choices + 1] = { value = tostring(id), label = label("Desde ", "From ") .. ranks[id] }
	end
	return choices
end
function A.ModerationValue()
	local policy = S.Get("gam", "moderation")
	if not policy or not isMaster(policy.o) then return "master" end
	local ranks, members = roster()
	local owner = members[policy.o]
	if not owner or policy.d.r == owner.verifiedRank or ranks[policy.d.r] ~= policy.d.n then return "master" end
	return tostring(policy.d.r)
end
function A.SetModerationValue(value)
	if not isMaster(ns.Me()) then return false end
	R.InvalidateGuildRoster()
	local ranks, members = roster()
	local me = members[ns.Me()]
	local number = value == "master" and me and me.verifiedRank or tonumber(value)
	if not me or not number or number < me.verifiedRank or not ranks[number] or not C.V.text(60)(ranks[number]) then return false end
	return S.Put("gam", "moderation", { r = number, n = ranks[number] })
end

local function moderationMenu(anchor, selected)
	if not isMaster(ns.Me()) then return end
	R.InvalidateGuildRoster()
	local ranks, members = roster()
	local master = members[ns.Me()]
	if not master then ns.Say(label("Rangos no disponibles.", "Ranks unavailable.")); return end
	local order = {}
	for rank, name in pairs(ranks) do
		if rank >= master.verifiedRank and C.V.text(60)(name) then order[#order + 1] = rank end
	end
	table.sort(order)
	MenuUtil.CreateContextMenu(anchor, function(_, root)
		root:CreateTitle(label("Rango mínimo para retirar anuncios restringidos", "Minimum rank to withdraw restricted announcements"))
		for _, rank in ipairs(order) do
			local value, name = rank, ranks[rank]
			root:CreateButton(rank == master.verifiedRank and label("Solo el maestro", "Guild master only") or label("Desde ", "From ") .. name, function()
				if not isMaster(ns.Me()) then return end
				R.InvalidateGuildRoster()
				local current = roster()
				if current[value] == name and S.Put("gam", "moderation", { r = value, n = name }) then selected() end
			end)
		end
	end)
end
local moderationWindow
function A.OpenModeration()
	if not isMaster(ns.Me()) then ns.Say(L.OPT_ANNOUNCEMENT_PERMISSIONS_TT); return end
	local function refresh()
		local policy = S.Get("gam", "moderation")
		local _, members = roster()
		local owner = policy and members[policy.o]
		local delegated = policy and isMaster(policy.o) and owner and policy.d.r ~= owner.verifiedRank
		moderationWindow.rank:SetText(delegated and label("Desde ", "From ") .. policy.d.n or label("Solo el maestro", "Guild master only"))
	end
	if not moderationWindow then
		local w = window("LevelMatesAnnouncementPermissions", L.OPT_ANNOUNCEMENT_PERMISSIONS)
		w:SetSize(440, 150); w:SetFrameStrata("FULLSCREEN_DIALOG")
		local hint = w:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		hint:SetPoint("TOPLEFT", 24, -42); hint:SetText(label("Rango mínimo para retirar anuncios restringidos", "Minimum rank to withdraw restricted announcements"))
		local rank = ns.Skin.Button(w)
		rank:SetSize(300, 24); rank:SetPoint("TOPLEFT", 24, -66)
		rank:SetScript("OnClick", function(self) moderationMenu(self, refresh) end)
		button(w, CLOSE or "Close", 24, function() w:Hide() end)
		moderationWindow = { frame = w, rank = rank }
	end
	refresh()
	moderationWindow.frame:Show()
end
ns.Slash("anuncios", function() ns.Board.ShowTab("announcements") end)
ns.Slash("announcements", function() ns.Board.ShowTab("announcements") end)
