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
	if not T then return false end
	local okR, ready = pcall(function() return T.IsTradeSkillReady and T.IsTradeSkillReady() end)
	if not okR or ns.Plain(ready) ~= true then return false end
	for _, fn in ipairs({ "IsTradeSkillLinked", "IsTradeSkillGuild", "IsTradeSkillGuildMember", "IsNPCCrafting" }) do
		local ok, v = pcall(function() return T[fn] and T[fn]() end)
		if not ok or ns.Plain(v) then return false end   -- a check that fails is not "no": not read
	end
	return true
end
-- The profession's line as our skills know it (171 Alchemy…): a newer client may give a child id with its parent.
local KNOWN_LINES = {}
for _, id in ipairs(ns.Professions.IDS) do KNOWN_LINES[id] = true end
local told
local function line()
	local okI, info = pcall(function() return C_TradeSkillUI.GetBaseProfessionInfo and C_TradeSkillUI.GetBaseProfessionInfo() end)
	info = okI and ns.Plain(info) or nil
	if type(info) ~= "table" or not ns.Plain(info.professionID) then return nil end
	local id = info.professionID
	if not KNOWN_LINES[id] and info.parentProfessionID and KNOWN_LINES[info.parentProfessionID] then id = info.parentProfessionID end
	if not KNOWN_LINES[id] then
		if not told then told = true; ns.Log("recipes: unknown profession id %s (parent %s)", tostring(info.professionID), tostring(info.parentProfessionID)) end
		return nil
	end
	return id, info.skillLevel or 0, info.maxSkillLevel or 0
end
local function outputItem(rid)
	local okO, out = pcall(function() return C_TradeSkillUI.GetRecipeOutputItemData and C_TradeSkillUI.GetRecipeOutputItemData(rid) end)
	out = okO and ns.Plain(out) or nil
	local item = type(out) == "table" and (ns.Plain(out.itemID) or tonumber(tostring(ns.Plain(out.hyperlink) or ""):match("item:(%d+)") or ""))
	if item then return item end
	local okL, link = pcall(function() return C_TradeSkillUI.GetRecipeItemLink and C_TradeSkillUI.GetRecipeItemLink(rid) end)   -- older clients
	link = okL and ns.Plain(link) or nil
	return link and tonumber(tostring(link):match("item:(%d+)") or "")
end
function RC.Scan()
	if not myWindow() then return end
	local id, rank, max = line()
	if not id then return end
	local skills = ns.char.skills
	if skills and next(skills) and not skills[id] then return end   -- not one of my professions (as my skills know them)
	if skills and skills[id] and skills[id].rank and math.abs(rank - skills[id].rank) > RC.RANK_MARGIN then return end   -- not my rank: not my window
	RC.scans = RC.scans + 1
	local items, spells = {}, {}
	local okA, all = pcall(C_TradeSkillUI.GetAllRecipeIDs)
	for _, rid in ipairs(okA and ns.List(all) or {}) do
		local okI, info = pcall(C_TradeSkillUI.GetRecipeInfo, rid)
		info = okI and ns.Plain(info) or nil
		if type(info) == "table" and ns.Plain(info.learned) ~= false then
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

-- Against the game's own list of my professions (the skill lines, Journal.lua): a profession I don't have, or kept at
-- a rank well above my real one (skill never goes down: those recipes came from someone else's window), is dropped and
-- the corrected list shared again; otherwise its rank is brought up to date. The margin leaves room for racial and
-- item bonuses the window may count.
RC.RANK_MARGIN = 25
function RC.CheckMine()
	local skills = ns.char.skills
	if not (skills and next(skills)) then return end   -- not known yet: nothing to judge by
	local mine, dropped = RC.Mine(), false
	for p, e in pairs(mine) do
		local s = skills[p]
		if not s or (e.r or 0) > (s.rank or 0) + RC.RANK_MARGIN then
			mine[p] = nil; dropped = true
		elseif s.rank then
			e.r = math.min(450, s.rank)
			if s.max and s.max > 0 then e.m = math.min(450, s.max) end
		end
	end
	if dropped then ns.Fire("LM_RECIPES_CHANGED") end
end
ns.On("LM_SKILLS_CHANGED", function() RC.CheckMine() end)

-- The first list after switching professions is still the previous one: read once things have been quiet 1.5 s.
local settleAt
local function later()
	settleAt = GetTime() + RC.SETTLE
	C_Timer.After(RC.SETTLE + 0.05, function()
		if settleAt and GetTime() >= settleAt then settleAt = nil; RC.Scan() end
	end)
end
local function learnedProfession(recipe)
	local T = C_TradeSkillUI
	if not (T and T.GetTradeSkillLineForRecipe) then return end
	local ok, id, _, parent = pcall(T.GetTradeSkillLineForRecipe, recipe)
	if not ok then return end
	id, parent = ns.Plain(id), ns.Plain(parent)
	if KNOWN_LINES[id] then return id end
	if KNOWN_LINES[parent] then return parent end
end
local function addLearned(recipe, profession)
	local item = outputItem(recipe)
	if type(item) ~= "number" or item < 1 or item > RC.TOP or item ~= math.floor(item) then return false end
	local mine = RC.Mine()
	local entry = mine[profession]
	local skill = ns.char.skills and ns.char.skills[profession]
	if not entry and not skill then return false end
	entry = entry or { r = math.min(450, skill.rank or 0), m = math.min(450, skill.max or 0), items = {}, spells = {} }
	for _, known in ipairs(entry.items) do if known == item then return true end end
	if #entry.items >= RC.MAX then return false end
	entry.items[#entry.items + 1] = item
	entry.t = time()
	mine[profession] = entry
	ns.Fire("LM_RECIPES_CHANGED", profession)
	return true
end
local function openForRefresh(profession)
	if not (C_TradeSkillUI and C_TradeSkillUI.OpenTradeSkill) or (InCombatLockdown and InCombatLockdown()) then
		ns.Chat(L.RC_LEARNED_OPEN_MANUALLY); return
	end
	local ok, opened = pcall(C_TradeSkillUI.OpenTradeSkill, profession)
	if not ok or ns.Plain(opened) ~= true then ns.Chat(L.RC_LEARNED_OPEN_MANUALLY); return end
	ns.Chat(L.RC_LEARNED_REFRESHING, ns.Professions.Name(profession))
	later()
end
if EventRegistry and EventRegistry.RegisterCallback then
	EventRegistry:RegisterCallback("SetItemRef", function(_, link)
		link = ns.Plain(link)
		local id = type(link) == "string" and tonumber(link:match("^addon:LevelMates:recipe:(%d+)$"))
		if id and KNOWN_LINES[id] then openForRefresh(id) end
	end, RC)
end

local pendingLearned, learnTimer = {}, false
local function onLearned(recipe)
	recipe = ns.Plain(recipe)
	if not (ns.db and ns.db.settings.shareProfessions) or type(recipe) ~= "number" or recipe < 1 or recipe ~= math.floor(recipe) then return end
	pendingLearned[recipe] = true
	if learnTimer then return end
	learnTimer = true
	C_Timer.After(RC.SETTLE, function()
		learnTimer = false
		local recipes = pendingLearned
		pendingLearned = {}
		if not ns.db.settings.shareProfessions then return end
		local missing, unknown = {}, false
		for rid in pairs(recipes) do
			local id = learnedProfession(rid)
			if not id then unknown = true
			elseif not addLearned(rid, id) then missing[id] = true end
		end
		for id in pairs(missing) do
			local link = string.format("|Haddon:LevelMates:recipe:%d|h|cff7ec8ff[%s]|r|h", id, L.RC_LEARNED_REFRESH)
			ns.Chat(L.RC_LEARNED_PENDING, ns.Professions.Name(id), link)
		end
		if unknown then ns.Chat(L.RC_LEARNED_OPEN_MANUALLY) end
	end)
end
local ev = CreateFrame("Frame")
for _, e in ipairs({ "TRADE_SKILL_SHOW", "TRADE_SKILL_LIST_UPDATE", "TRADE_SKILL_DATA_SOURCE_CHANGED" }) do ev:RegisterEvent(e) end
pcall(ev.RegisterEvent, ev, "NEW_RECIPE_LEARNED")
ev:SetScript("OnEvent", function(_, event, recipe)
	if event == "NEW_RECIPE_LEARNED" then onLearned(recipe) else later() end
end)

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
-- Fetch one shared snapshot on demand, without opening the crafter's profession window.
C.SCHEMA.rcr = { p = C.V.int(1, 2000) }
C.REQUIRED.rcr = { "p" }
local outgoingRefresh, incomingRefresh, scanned = {}, {}, {}
local recentlyLeft = {}
C.OnMessage("bye", function(_, name) recentlyLeft[name] = GetTime() end)
C.OnMessage("hb", function(_, name) recentlyLeft[name] = nil end)
function RC.IsOnline(name)
	if name == ns.Me() then return true end
	local mate = R.mates[name]
	if mate and mate.seenAt and GetTime() - mate.seenAt <= 120 then return true end
	if GetTime() - (recentlyLeft[name] or -math.huge) <= 120 then return false end
	for _, member in ipairs(R.GuildMembers() or {}) do
		if member.name == name then return member.online end
	end
	return false
end
function RC.RequestRefresh(name, profession)
	if name == ns.Me() or not RC.IsOnline(name) or not R.IsGuildmate(name) then return end
	local key = name .. ":" .. profession
	if GetTime() - (outgoingRefresh[key] or -math.huge) < 120 then return end
	if C.Whisper("rcr", { p = profession }, name) then outgoingRefresh[key] = GetTime() end
end
C.OnMessage("rcr", function(f, name, _, channel)
	if channel ~= "WHISPER" or not R.IsGuildmate(name) or not ns.db.settings.shareProfessions then return end
	local key = name .. ":" .. f.p
	if GetTime() - (incomingRefresh[key] or -math.huge) < 120 then return end
	if GetTime() - (scanned[f.p] or -math.huge) >= 120 and myWindow() and line() == f.p then
		scanned[f.p] = GetTime()
		RC.Scan()
	end
	for _, snapshot in ipairs(build() or {}) do
		if snapshot.p == f.p then
			if C.SendBig("rcp", snapshot, "normal", name) then incomingRefresh[key] = GetTime() end
			return
		end
	end
end)

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
	local g = ns.GuildKey()
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
	if not plausible(name, f.r or 0) then   -- and what was kept for it can't be trusted either
		local e = theirs()[name]
		if e and e[f.p] then e[f.p] = nil; changed() end
		return
	end
	local items, spells = RC.Decode(f.i or ""), RC.Decode(f.s or "")
	if not items or not spells then return end
	local t = theirs()
	t[name] = t[name] or {}
	t[name][f.p] = { r = f.r or 0, m = f.m or 0, items = items, spells = spells, t = GetServerTime() }
	changed()
end)

-- Pull a bounded set of saved books from a guild peer. A relayed snapshot
-- keeps its original receipt time and cannot replace a newer direct copy.
C.SCHEMA.rcq = { p = C.V.int(1, 2000) }
C.REQUIRED.rcq = { "p" }
C.SCHEMA.rcl = { p = C.V.int(1, 2000), a = C.V.text(48), t = C.V.int(1, 4000000000),
	r = C.V.int(0, 450), m = C.V.int(0, 450), i = idlist, s = idlist }
C.REQUIRED.rcl = { "p", "a", "t" }
local requests, replies, authoritative = {}, {}, {}
local function denied()
	ns.db.recipeRelayDenied = ns.db.recipeRelayDenied or {}
	return ns.db.recipeRelayDenied
end
local function permissionKey(name, profession)
	return ns.GuildKey() .. ":" .. name .. ":" .. profession
end
function RC.RequestProfession(profession)
	if not KNOWN_LINES[profession] then return end
	local key = ns.GuildKey() .. ":" .. profession
	if requests[key] and GetTime() - requests[key].at < 120 then return end
	local peers = {}
	for name in pairs(R.mates) do
		if name ~= ns.Me() and R.IsGuildmate(name) then peers[#peers + 1] = name end
	end
	table.sort(peers)
	if #peers == 0 then return end
	local first = math.random(1, #peers)
	local pending = { at = GetTime(), peers = {} }
	for offset = 0, math.min(1, #peers - 1) do
		local peer = peers[(first + offset - 1) % #peers + 1]
		if C.Whisper("rcq", { p = profession }, peer) then pending.peers[peer] = true end
	end
	if next(pending.peers) then requests[key] = pending end
end
C.OnMessage("rcq", function(f, name, _, channel)
	if channel ~= "WHISPER" or not R.IsGuildmate(name) or not KNOWN_LINES[f.p] then return end
	local key = permissionKey(name, f.p)
	if GetTime() - (replies[key] or -math.huge) < 120 then return end
	replies[key] = GetTime()
	local books = {}
	for author, known in pairs(theirs()) do
		local book = known[f.p]
		if author ~= name and book and not book.relayed and book.t and GetServerTime() - book.t < RC.FORGET and R.IsGuildmate(author) then
			books[#books + 1] = { author = author, book = book }
		end
	end
	table.sort(books, function(a, b) return a.book.t > b.book.t end)
	for n = 1, math.min(#books, 8) do
		local author, book = books[n].author, books[n].book
		C.SendBig("rcl", { p = f.p, a = author, t = book.t, r = book.r, m = book.m,
			i = RC.Encode(book.items), s = RC.Encode(book.spells) }, "normal", name)
	end
end)
C.OnMessage("rcl", function(f, name, _, channel)
	if channel ~= "WHISPER" or not R.IsGuildmate(name) or not R.IsGuildmate(f.a) or f.a == ns.Me() or not KNOWN_LINES[f.p] then return end
	local now = GetServerTime()
	local requested = requests[ns.GuildKey() .. ":" .. f.p]
	if not requested or not requested.peers[name] or GetTime() - requested.at > 45 or f.t > now or now - f.t >= RC.FORGET then return end
	local key = permissionKey(f.a, f.p)
	if denied()[key] or not plausible(f.a, f.r or 0) then return end
	local t = theirs()
	local old = t[f.a] and t[f.a][f.p]
	if old and (not old.relayed or old.t >= f.t) then return end
	if authoritative[key] then return end
	local items, spells = RC.Decode(f.i or ""), RC.Decode(f.s or "")
	if not items or not spells then return end
	t[f.a] = t[f.a] or {}
	t[f.a][f.p] = { r = f.r or 0, m = f.m or 0, items = items, spells = spells, t = f.t, relayed = true }
	changed()
end)
C.OnMessage("rcp", function(f, name)
	local key = permissionKey(name, f.p)
	authoritative[key] = true
end)

-- Their own list of professions (pf, the whole list with ranks): recipes kept for a profession not on it, or at a rank
-- well above the real one, go. A withdrawal (no list) is the sharing setting's business, not this.
C.OnMessage("pf", function(f, name)
	if f.p == nil then
		for id in pairs(KNOWN_LINES) do denied()[permissionKey(name, id)] = true end
		if theirs()[name] then theirs()[name] = nil; changed() end
		return
	end
	local e = theirs()[name]
	local ranks = {}
	for id, rank in tostring(f.p):gmatch("(%d+):(%d+)") do ranks[tonumber(id)] = tonumber(rank) end
	local gone = false
	for id in pairs(KNOWN_LINES) do denied()[permissionKey(name, id)] = not ranks[id] or nil end
	for p, x in pairs(e or {}) do
		if not ranks[p] or (x.r or 0) > ranks[p] + RC.RANK_MARGIN then e[p] = nil; gone = true end
	end
	if e and not next(e) then theirs()[name] = nil end
	if gone then changed() end
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
		if x then out[#out + 1] = { name = e[1], line = e[2], r = x.r, m = x.m, t = x.t, online = RC.IsOnline(e[1]) } end
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
local asked, received = {}, {}
C.SCHEMA.rca = { i = C.V.int(1, 999999) }
C.REQUIRED.rca = { "i" }
C.OnMessage("rca", function(f, name, _, channel)
	if channel ~= "WHISPER" or name == ns.Me() or not R.IsGuildmate(name) then return end
	local key = name .. ":" .. f.i
	if GetTime() - (received[key] or -math.huge) < 60 then return end
	for _, recipes in pairs(RC.Mine()) do
		for _, id in ipairs(recipes.items or {}) do
			if id == f.i then
				received[key] = GetTime()
				ns.NoticeAt("crafts", L.RC_REQUEST_RECEIVED, name, RC.Link(id))
				return
			end
		end
	end
end)
function RC.AskLabel(name)
	return string.format(RC.IsOnline(name) and L.RC_ASK_MENU or L.RC_MAIL_MENU, name)
end
function RC.Ask(name, item)
	local message = string.format(L.RC_ASK, RC.Link(item))
	if not RC.IsOnline(name) then
		ns.DiscordCopy.OpenText(message, string.format(L.RC_MAIL_MENU, name), L.RC_MAIL_HINT)
		return false
	end
	ns.DiscordCopy.OpenText(message, string.format(L.RC_ASK_MENU, name), L.RC_WHISPER_HINT, function(text)
		if not RC.IsOnline(name) then ns.Say(L.RC_WHISPER_OFFLINE, name); return false end
		text = strtrim((text or ""):gsub("%s+", " "))
		if text == "" or #text > 255 then ns.Say(L.RC_WHISPER_LENGTH); return false end
		local key = name .. ":" .. item
		if GetTime() - (asked[key] or -math.huge) < 60 then ns.Say(L.RC_ASKED_ALREADY, name); return false end
		if not ns.SendChat(text, "WHISPER", nil, name) then return false end
		asked[key] = GetTime()
		if R.IsGuildmate(name) then C.Whisper("rca", { i = item }, name) end
		return true
	end)
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
