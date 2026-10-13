-- Recipes.lua: what each one can craft. Mine are read from my own profession window (never someone else's), kept per
-- profession as item ids (and spell ids for enchants), and shared as personal state `rcp` in a compact form: sorted
-- ids as base-36 differences. Then "who crafts this?" and a line in item tooltips.
-- Spec 2026-10-12-levelmates-recipes-design.
local _, ns = ...
local RC = {}
ns.Recipes = RC
local L, C, R = ns.L, ns.Comm, ns.Roster
RC.MAX, RC.TOP, RC.SETTLE = 800, 10000000, 1.5
RC.scans = 0

------------------------------------------------------------------ encoding
local DIGITS = "0123456789abcdefghijklmnopqrstuvwxyz"
local function b36(n)
	local s = ""
	repeat local r = n % 36; s = DIGITS:sub(r + 1, r + 1) .. s; n = math.floor(n / 36) until n == 0
	return s
end
-- Sorted, without repeats, each as the difference from the one before, in base 36, joined with "-".
function RC.Encode(list)
	local sorted, seen = {}, {}
	for _, v in ipairs(list or {}) do if not seen[v] then seen[v] = true; sorted[#sorted + 1] = v end end
	table.sort(sorted)
	local parts, prev = {}, 0
	for _, v in ipairs(sorted) do parts[#parts + 1] = b36(v - prev); prev = v end
	return table.concat(parts, "-")
end
-- nil for anything that is not a clean list (a zero difference, too many, too big, a stray character).
function RC.Decode(s)
	if type(s) ~= "string" then return nil end
	if s == "" then return {} end
	if not s:match("^[0-9a-z%-]+$") then return nil end
	local out, prev = {}, 0
	for part in s:gmatch("[^%-]+") do
		local d = tonumber(part, 36)
		if not d or d <= 0 then return nil end
		prev = prev + d
		if prev > RC.TOP then return nil end
		out[#out + 1] = prev
		if #out > RC.MAX then return nil end
	end
	return out
end

------------------------------------------------------------------ my recipes
function RC.Mine() ns.char.recipes = ns.char.recipes or {}; return ns.char.recipes end

-- My window only: not linked, not the guild's view, not an NPC crafter; and the profession is one of mine.
local function myWindow()
	local T = C_TradeSkillUI
	if not (T and T.IsTradeSkillReady and T.IsTradeSkillReady()) then return false end
	for _, fn in ipairs({ "IsTradeSkillLinked", "IsTradeSkillGuild", "IsTradeSkillGuildMember", "IsNPCCrafting" }) do
		if T[fn] and T[fn]() then return false end
	end
	return true
end
-- The profession's line as our skills know it (171 Alchemy…): a newer client may give a child id with its parent.
local KNOWN_LINES = {}
for _, id in ipairs(ns.Professions.IDS) do KNOWN_LINES[id] = true end
local told
local function line()
	local info = C_TradeSkillUI.GetBaseProfessionInfo and C_TradeSkillUI.GetBaseProfessionInfo()
	if type(info) ~= "table" or not info.professionID then return nil end
	local id = info.professionID
	if not KNOWN_LINES[id] and info.parentProfessionID and KNOWN_LINES[info.parentProfessionID] then id = info.parentProfessionID end
	if not KNOWN_LINES[id] then
		if not told then told = true; ns.Log("recipes: unknown profession id %s (parent %s)", tostring(info.professionID), tostring(info.parentProfessionID)) end
		return nil
	end
	return id, info.skillLevel or 0, info.maxSkillLevel or 0
end
local function outputItem(rid)
	local out = C_TradeSkillUI.GetRecipeOutputItemData and C_TradeSkillUI.GetRecipeOutputItemData(rid)
	local item = type(out) == "table" and (out.itemID or tonumber(tostring(out.hyperlink or ""):match("item:(%d+)") or ""))
	if item then return item end
	local link = C_TradeSkillUI.GetRecipeItemLink and C_TradeSkillUI.GetRecipeItemLink(rid)   -- older clients
	return link and tonumber(tostring(link):match("item:(%d+)") or "")
end
function RC.Scan()
	if not myWindow() then return end
	local id, rank, max = line()
	if not id then return end
	local skills = ns.char.skills
	if skills and next(skills) and not skills[id] then return end   -- not one of my professions (as my skills know them)
	RC.scans = RC.scans + 1
	local items, spells = {}, {}
	for _, rid in ipairs(C_TradeSkillUI.GetAllRecipeIDs() or {}) do
		local info = C_TradeSkillUI.GetRecipeInfo(rid)
		if info and info.learned ~= false then
			local item = outputItem(rid)
			if item then items[#items + 1] = item else spells[#spells + 1] = rid end
		end
	end
	local mine = RC.Mine()
	if #items + #spells == 0 and mine[id] then return end   -- an empty read never wipes a filled one
	local old = mine[id]
	local new = { r = math.min(450, rank), m = math.min(450, max), items = items, spells = spells, t = time() }
	mine[id] = new
	while #items > RC.MAX do table.remove(items) end
	while #spells > RC.MAX do table.remove(spells) end
	if not old or RC.Encode(old.items) ~= RC.Encode(items) or RC.Encode(old.spells) ~= RC.Encode(spells) then   -- the rank alone travels in pf
		ns.Fire("LM_RECIPES_CHANGED", id)
	end
end

-- The first list after switching professions is still the previous one: read once things have been quiet 1.5 s.
local settleAt
local function later()
	settleAt = GetTime() + RC.SETTLE
	C_Timer.After(RC.SETTLE + 0.05, function()
		if settleAt and GetTime() >= settleAt then settleAt = nil; RC.Scan() end
	end)
end
local ev = CreateFrame("Frame")
for _, e in ipairs({ "TRADE_SKILL_SHOW", "TRADE_SKILL_LIST_UPDATE", "TRADE_SKILL_DATA_SOURCE_CHANGED" }) do ev:RegisterEvent(e) end
ev:SetScript("OnEvent", later)

------------------------------------------------------------------ sharing
-- One `rcp` per profession: p (its line), r/m (rank/max), i (items) and s (spells), encoded as above; long lists go in
-- chunks. Through the personal-state helper: pending while it cannot go, again to newcomers, nothing when sharing is off.
local function idlist(v) return type(v) == "string" and #v <= 3200 and v:match("^[0-9a-z%-]*$") ~= nil end   -- 800 ids fit
C.SCHEMA.rcp = { p = C.V.int(1, 2000), r = C.V.int(0, 450), m = C.V.int(0, 450), i = idlist, s = idlist }
C.REQUIRED.rcp = { "p" }
local function build()
	local out = {}
	for p, e in pairs(RC.Mine()) do
		local i, s = RC.Encode(e.items), RC.Encode(e.spells)
		out[#out + 1] = { p = p, r = e.r, m = e.m, i = i ~= "" and i or nil, s = s ~= "" and s or nil }
	end
	table.sort(out, function(a, b) return a.p < b.p end)
	return #out > 0 and out or nil
end
local share = ns.Sync.Personal("rcp", build, { save = "recipesPending", helloGap = 600,   -- long lists: newcomers get them at most every 10 minutes
	worth = function() return next(RC.Mine()) ~= nil end,
	enabled = function() return ns.db.settings.shareProfessions end })
-- A real change goes out 8 s later (one message for a burst of changes).
local due
ns.On("LM_RECIPES_CHANGED", function()
	due = GetTime() + 8
	C_Timer.After(8.05, function() if due and GetTime() >= due then due = nil; share.Mark() end end)
end)

------------------------------------------------------------------ theirs
RC.FORGET = 60 * 86400
local function theirs()
	ns.db.recipes = ns.db.recipes or {}
	local g = GetGuildInfo("player") or "?"
	ns.db.recipes[g] = ns.db.recipes[g] or {}
	return ns.db.recipes[g]
end
local index   -- item id -> { { name, line } }, rebuilt when something changed
local building
local function changed() index = nil; ns.Fire("LM_PROFESSIONS_CHANGED") end
ns.On("LM_RECIPES_CHANGED", function() index = nil; ns.Dirty("board") end)

-- A rank the character's level cannot have yet (another's window read by mistake, a broken client): ignored.
local function plausible(name, rank)
	local m = R.mates[name]
	local level = m and m.level
	if not level then return true end
	local need = rank > 225 and 35 or rank > 150 and 20 or rank > 75 and 10 or 0
	return level >= need
end
C.OnMessage("rcp", function(f, name)
	if not plausible(name, f.r or 0) then return end
	local items, spells = RC.Decode(f.i or ""), RC.Decode(f.s or "")
	if not items or not spells then return end
	local t = theirs()
	t[name] = t[name] or {}
	t[name][f.p] = { r = f.r or 0, m = f.m or 0, items = items, spells = spells, t = GetServerTime() }
	changed()
end)

-- Someone's professions with their recipes (mine for me); forgotten 60 days after the last news.
function RC.Of(name)
	if name == ns.Me() then return RC.Mine() end
	local e = theirs()[name]
	if not e then return {} end
	local gone = false
	for p, x in pairs(e) do if GetServerTime() - (x.t or 0) > RC.FORGET then e[p] = nil; gone = true end end
	if not next(e) then theirs()[name] = nil end
	if gone and not building then index = nil end   -- a rebuild in progress already leaves them out
	return e
end
local function build_index()
	building = true
	index = {}
	local function add(name, p, list) for _, id in ipairs(list or {}) do index[id] = index[id] or {}; table.insert(index[id], { name, p }) end end
	for p, e in pairs(RC.Mine()) do add(ns.Me(), p, e.items) end
	local names = {}
	for name in pairs(theirs()) do names[#names + 1] = name end   -- RC.Of may drop someone: not while iterating
	for _, name in ipairs(names) do for p, e in pairs(RC.Of(name)) do add(name, p, e.items) end end
	building = false
end
-- Who crafts an item: { name, line, r, m, t, online }, online first, then the highest rank.
function RC.WhoCrafts(itemId)
	if not index then build_index() end
	local out = {}
	for _, e in ipairs(index[itemId] or {}) do
		local x = RC.Of(e[1])[e[2]]
		if x then out[#out + 1] = { name = e[1], line = e[2], r = x.r, m = x.m, t = x.t, online = e[1] == ns.Me() or R.mates[e[1]] ~= nil } end
	end
	table.sort(out, function(a, b)
		if a.online ~= b.online then return a.online end
		if a.r ~= b.r then return a.r > b.r end
		return a.name < b.name
	end)
	return out
end
-- Everyone whose recipes I hold, per profession: { name, id, rank, max, t } (for the Crafts view, when their
-- profession ranks have not arrived).
function RC.Crafters()
	local out, names = {}, {}
	for name in pairs(theirs()) do names[#names + 1] = name end
	for _, name in ipairs(names) do
		if R.IsGuildmate(name) then   -- someone who left the guild is not a crafter here
			for id, e in pairs(RC.Of(name)) do out[#out + 1] = { name = name, id = id, rank = e.r, max = e.m, t = e.t } end
		end
	end
	return out
end
-- Every item someone in the guild crafts (for the search by name).
function RC.Known()
	if not index then build_index() end
	local out = {}
	for id in pairs(index) do out[#out + 1] = id end
	table.sort(out)
	return out
end

------------------------------------------------------------------ search and ask
-- Items someone crafts, from an item link, an item number or a part of a known item's name (names the client has
-- not loaded yet are skipped this time and found once it has them). At most ten.
function RC.Find(text)
	text = tostring(text or "")
	local id = tonumber(text:match("item:(%d+)") or "") or tonumber(text)
	if id then
		if not index then build_index() end
		return index[id] and { id } or {}
	end
	local q = strtrim(text):lower()
	if #q < 3 then return {} end
	local out = {}
	for _, item in ipairs(RC.Known()) do
		local name = ns.ItemInfo(item)
		if name and name:lower():find(q, 1, true) then out[#out + 1] = item; if #out >= 10 then break end end
	end
	return out
end
function RC.Link(item) local _, link = ns.ItemInfo(item); return link or ("item:" .. item) end

-- policy: click paths only (RC.Ask is called from the Crafts tab's menu): "Could you make me [item]?", once a minute
-- per person and item.
local asked = {}
function RC.Ask(name, item)
	local key = name .. ":" .. item
	if GetTime() - (asked[key] or -math.huge) < 60 then ns.Say(L.RC_ASKED_ALREADY, name); return false end
	asked[key] = GetTime()
	SendChatMessage(string.format(L.RC_ASK, RC.Link(item)), "WHISPER", nil, name)
	return true
end

------------------------------------------------------------------ tooltips
-- "Crafted by: Mario (Alchemy 225), Ana, Luis +2" on any item someone in the guild crafts (online first).
if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
	local broken = false
	TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
		if broken or not ns.db or (tooltip ~= GameTooltip and tooltip ~= ItemRefTooltip) or type(data) ~= "table" or not data.id then return end
		local ok, err = pcall(function()
			local who = RC.WhoCrafts(data.id)
			if #who == 0 then return end
			local parts = {}
			for i = 1, math.min(3, #who) do
				local w = who[i]
				parts[#parts + 1] = i == 1 and string.format("%s (%s %d)", w.name, ns.Professions.Name(w.line), w.r) or w.name
			end
			local text = table.concat(parts, ", ") .. (#who > 3 and (" +" .. (#who - 3)) or "")
			tooltip:AddLine(string.format(L.RC_TOOLTIP, text), 0.6, 0.8, 1, true)
		end)
		if not ok then broken = true; ns.Log("recipe tooltip off: %s", tostring(err)) end   -- one error turns it off
	end)
end
