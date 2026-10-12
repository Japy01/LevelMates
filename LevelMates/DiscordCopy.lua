-- DiscordCopy.lua: "Copy for Discord". Turns the board's current tab into Discord text (bold, bullets, :emoji:
-- shortcodes Discord turns into icons) in a box, selected for Ctrl+C. Nothing is sent anywhere.
local _, ns = ...
local D = {}
ns.DiscordCopy = D
local L = ns.L
D.MAX = 2000   -- one Discord message
local ROLE_EMOJI = { T = ":shield:", H = ":green_heart:", D = ":crossed_swords:" }
local TAB_TITLE = { mates = "TAB_MATES", lfg = "TAB_LFG", journal = "TAB_JOURNAL", goals = "TAB_GOALS", wishes = "TAB_WISHES", crafts = "TAB_CRAFTS", class = "TAB_CLASS", home = "TAB_HOME", recruit = "HEAD_INACTIVE", feed = "TAB_FEED" }

local function me() return ns.Me() end
-- "[Name]" from a game link; Discord shows the codes as they are.
local function plain(link) return link and ("[" .. (link:match("|h%[(.-)%]|h") or link:match("%[(.-)%]") or "?") .. "]") end
local function mapName(id) local info = id and C_Map.GetMapInfo(id); return info and info.name or "" end

local builders = {}

function builders.mates()
	local lines = { string.format("• **%s** · %s · %s", me(), string.format(L.DC_LEVEL, UnitLevel("player")), GetRealZoneText() or "") }
	for _, name in ipairs(ns.Roster.List()) do
		local m = ns.Roster.mates[name]
		lines[#lines + 1] = string.format("• **%s** · %s · %s", name, string.format(L.DC_LEVEL, m.level or 0), mapName(m.mapId))
	end
	return lines
end

local function roles(r)
	local out = {}
	for ch in tostring(r or ""):gmatch(".") do out[#out + 1] = ROLE_EMOJI[ch] end
	return table.concat(out, " ")
end
local function adLine(name, a)
	local d = ns.Dungeons.Get(a.d)
	local where = d and string.format("%s (%d-%d)", ns.Dungeons.Name(a.d), d.min, d.max) or ns.Dungeons.Name(a.d)
	local line = string.format(L.DC_LFG, "**" .. name .. "**", "**" .. where .. "**") .. " · " .. string.format(L.DC_ROLES, roles(a.r))
	if a.n then line = line .. " · \"" .. a.n .. "\"" end
	return "• " .. line
end
function builders.lfg()
	local lines, LFG = {}, ns.LFG
	if LFG.mine and not LFG.ads[LFG.mine.id] then lines[1] = adLine(me(), LFG.mine) end
	for _, id in ipairs(LFG.List()) do lines[#lines + 1] = adLine(LFG.ads[id].name, LFG.ads[id]) end
	return lines
end

function builders.journal()
	local from, lines = time() - 7 * 86400, {}
	local lo, hi, quests, deaths, dungeons, items = nil, nil, 0, 0, {}, {}
	for _, e in ipairs(ns.Journal.List("all", "")) do
		if e.t >= from and not e.sim then
			if e.k == "level" then lo = math.min(lo or e.level, e.level); hi = math.max(hi or e.level, e.level)
			elseif e.k == "quest" then quests = quests + 1
			elseif e.k == "death" then deaths = deaths + 1
			elseif e.k == "dungeon" then
				dungeons[#dungeons + 1] = e.name .. ((e.mates and #e.mates > 0) and string.format(L.J_WITH, table.concat(e.mates, ", ")) or "")
			elseif e.k == "item" then items[#items + 1] = plain(e.link) end
		end
	end
	if lo then lines[#lines + 1] = "• " .. string.format(L.DC_J_LEVELS, lo - 1, hi) end
	if quests > 0 then lines[#lines + 1] = "• " .. string.format(L.DC_J_QUESTS, quests) end
	if #dungeons > 0 then lines[#lines + 1] = "• " .. string.format(L.DC_J_DUNGEONS, table.concat(dungeons, "; ")) end
	if #items > 0 then lines[#lines + 1] = "• " .. string.format(L.DC_J_ITEMS, table.concat(items, ", ")) end
	if deaths > 0 then lines[#lines + 1] = "• " .. string.format(L.DC_J_DEATHS, deaths) end
	return lines
end

function builders.goals()
	local G, P, lines = ns.Goals, ns.Personal, {}
	for _, g in ipairs(G.List()) do
		lines[#lines + 1] = string.format("• %s%s — %s (%s)", G.IsDone(g) and ":white_check_mark: " or "", G.Text(g), G.ProgressText(g), string.format(L.DC_UNTIL, G.UntilText(g)))
	end
	local personal = P.List()
	if #personal > 0 then
		lines[#lines + 1] = "**" .. L.DC_PERSONAL .. "**"
		for _, p in ipairs(personal) do
			lines[#lines + 1] = string.format("• %s%s: %s — %s (%s)", P.IsDone(p) and ":white_check_mark: " or "", p.name, P.Text(p), P.ProgressText(p), string.format(L.DC_UNTIL, G.UntilText(p)))
		end
	end
	return lines
end

function builders.wishes()
	local W, lines, byName, order = ns.Wishlist, {}, {}, {}
	for _, w in ipairs(W.List()) do
		if not byName[w.name] then byName[w.name] = {}; order[#order + 1] = w.name end
		local l = W.Link(w.id)
		table.insert(byName[w.name], l and plain(l) or string.format(L.WISH_UNKNOWN, w.id))
	end
	for _, name in ipairs(order) do lines[#lines + 1] = string.format("• **%s**: %s", name, table.concat(byName[name], ", ")) end
	local gives, gorder = {}, {}
	for _, g in ipairs(ns.Gifts.List()) do
		if not gives[g.name] then gives[g.name] = {}; gorder[#gorder + 1] = g.name end
		local l = W.Link(g.id)
		table.insert(gives[g.name], (l and plain(l) or string.format(L.WISH_UNKNOWN, g.id)) .. (g.reservedBy and (" (" .. string.format(L.GIFT_RESERVED_BY, g.reservedBy) .. ")") or ""))
	end
	for _, name in ipairs(gorder) do lines[#lines + 1] = string.format("• **%s** %s: %s", name, L.GIVES, table.concat(gives[name], ", ")) end
	return lines
end

function builders.crafts()
	local P, lines, byProf, order = ns.Professions, {}, {}, {}
	for _, c in ipairs(P.List()) do
		if not byProf[c.id] then byProf[c.id] = {}; order[#order + 1] = c.id end
		table.insert(byProf[c.id], c.name .. " " .. c.rank)
	end
	for _, id in ipairs(order) do lines[#lines + 1] = string.format("• **%s**: %s", P.Name(id), table.concat(byProf[id], ", ")) end
	return lines
end

function builders.class()
	local lines = {}
	for _, e in ipairs(ns.Builds.List()) do lines[#lines + 1] = string.format("• **%s** (%d): %s", e.name, e.l, ns.Builds.PointsText(e)) end
	for _, m in ipairs(ns.Macros.Guild()) do lines[#lines + 1] = string.format("• %s: %s", m.by, m.name) end
	return lines
end

function builders.recruit()
	local lines = {}
	if ns.Board.recruitView ~= "inactive" then   -- the templates view: the message as it would be posted
		local t = ns.Recruit.Templates()[ns.char.recruitTemplate or 1]
		return t and t ~= "" and { ns.Recruit.Expand(t) } or {}
	end
	for _, e in ipairs(ns.Inactive.List(ns.char.inactiveDays or 14)) do
		lines[#lines + 1] = string.format("• **%s** (%d, %s): %s · %s", e.name, e.level, e.rank, ns.Inactive.AwayText(e), ns.Inactive.JoinedText(e))
	end
	return lines
end

function builders.home()
	local PT, lines = ns.Points, {}
	local level, into, need = PT.Level(PT.GuildTotal())
	lines[#lines + 1] = string.format("• %s (%d/%d)", string.format(L.HOME_LEVEL, level), into, need)
	local ch = PT.Challenge()
	lines[#lines + 1] = string.format("• %s: %d/%d", ch.text, ch.have, ch.goal)
	for _, cat in ipairs({ "l", "d", "h" }) do
		local top = PT.Rankings()[cat]
		if #top > 0 then
			local parts = {}
			for k, t in ipairs(top) do parts[#parts + 1] = k .. ". " .. t.name .. " (" .. t.n .. ")" end
			lines[#lines + 1] = "• **" .. L["HOME_RANK_" .. cat] .. "**: " .. table.concat(parts, ", ")
		end
	end
	return lines
end

function builders.feed()
	local F, lines = ns.Feed, {}
	for _, e in ipairs(F.List()) do
		local what = F.Text(e):gsub("|c[^|]-|H.-|h%[(.-)%]|h|r", "[%1]")
		lines[#lines + 1] = string.format("• **%s** %s (%s)", F.Who(e), what, F.Ago(e))
	end
	return lines
end

-- The text for a tab, at most one Discord message: lines that do not fit become "…and N more".
function D.Text(tab)
	tab = builders[tab] and tab or "mates"
	local guild = GetGuildInfo("player")
	local head = "**" .. L.BOARD_TITLE .. (guild and (" · " .. guild) or "") .. " · " .. (tab == "journal" and string.format(L.DC_J_TITLE, me()) or tab == "recruit" and ns.Board.recruitView ~= "inactive" and L.TAB_RECRUIT or L[TAB_TITLE[tab]]) .. "**"
	local lines = builders[tab]()
	if #lines == 0 then return head .. "\n" .. L.DC_NOTHING end
	local text, used = head, #head
	for i, line in ipairs(lines) do
		local rest = #lines - i   -- room is kept for the "…and N more" line while lines remain after this one
		local need = used + 1 + #line + (rest > 0 and #("\n" .. string.format(L.DC_MORE, rest)) or 0)
		if need > D.MAX then return text .. "\n" .. string.format(L.DC_MORE, rest + 1) end
		text, used = text .. "\n" .. line, used + 1 + #line
	end
	return text
end

local function Build()
	local f = ns.Skin.Window("LevelMatesDiscordDialog", UIParent)
	D.frame = f
	f:SetSize(480, 320); f:SetPoint("CENTER"); f:SetFrameStrata("DIALOG")
	f:SetMovable(true); f:EnableMouse(true); f:SetClampedToScreen(true); f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", f.StartMoving); f:SetScript("OnDragStop", f.StopMovingOrSizing)
	if f.TitleText then f.TitleText:SetText(L.DC_TITLE) end
	tinsert(UISpecialFrames, "LevelMatesDiscordDialog")
	f:Hide()
	local hint = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	hint:SetPoint("TOP", 0, -32); hint:SetText(L.DC_HINT)
	local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", 16, -50); scroll:SetPoint("BOTTOMRIGHT", -34, 44)
	local box = CreateFrame("EditBox", nil, scroll)
	box:SetMultiLine(true); box:SetAutoFocus(false); box:SetFontObject("ChatFontNormal"); box:SetWidth(420)
	box:SetScript("OnEscapePressed", function() f:Hide() end)
	box:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
	scroll:SetScrollChild(box)
	D.box = box
	local close = ns.Skin.Button(f)
	close:SetSize(120, 22); close:SetPoint("BOTTOM", 0, 12); close:SetText(L.LFG_CLOSE)
	close:SetScript("OnClick", function() f:Hide() end)
end

-- Any text in the box (Home's invite): to copy and paste anywhere; nothing is sent.
function D.OpenText(text)
	if not D.frame then Build() end
	D.box:SetText(text)
	D.frame:Show()
	D.box:SetFocus(); D.box:HighlightText()
end

function D.Open(tab)
	if not D.frame then Build() end
	D.box:SetText(D.Text(tab))
	D.frame:Show()
	D.box:SetFocus(); D.box:HighlightText()
end

ns.On("LM_DISCORD_COPY", D.Open)
