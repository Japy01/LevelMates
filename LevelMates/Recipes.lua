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
	local items, spells, recipeIDs = {}, {}, {}
	local okA, all = pcall(C_TradeSkillUI.GetAllRecipeIDs)
	for _, rid in ipairs(okA and ns.List(all) or {}) do
		local okI, info = pcall(C_TradeSkillUI.GetRecipeInfo, rid)
		info = okI and ns.Plain(info) or nil
		if type(info) == "table" and ns.Plain(info.learned) ~= false then
			local item = outputItem(rid)
			if item then items[#items + 1] = item; recipeIDs[item] = rid else spells[#spells + 1] = rid end
		end
	end
	local mine = RC.Mine()
	if #items + #spells == 0 and mine[id] then return end   -- an empty read never wipes a filled one
	local old = mine[id]
	local new = { r = math.min(450, rank), m = math.min(450, max), items = items, spells = spells, recipeIDs = recipeIDs, t = time() }
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
	entry.recipeIDs = entry.recipeIDs or {}
	entry.recipeIDs[item] = recipe
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
local requests, replies, lastPeer = {}, {}, {}
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
	local first = 1
	for i, peer in ipairs(peers) do
		if not lastPeer[key] or peer > lastPeer[key] then first = i; break end
	end
	local pending = { at = GetTime(), peers = {} }
	for offset = 0, math.min(1, #peers - 1) do
		local peer = peers[(first + offset - 1) % #peers + 1]
		if C.Whisper("rcq", { p = profession }, peer) then pending.peers[peer] = true; lastPeer[key] = peer end
	end
	if next(pending.peers) then requests[key] = pending end
end
C.OnMessage("rcq", function(f, name, _, channel)
	if channel ~= "WHISPER" or not R.IsGuildmate(name) or not KNOWN_LINES[f.p] then return end
	local key = permissionKey(name, f.p)
	local previous = replies[key]
	if previous and GetTime() - previous.at < 120 then return end
	local books = {}
	for author, known in pairs(theirs()) do
		local book = known[f.p]
		if author ~= name and book and not denied()[permissionKey(author, f.p)] and book.t and GetServerTime() - book.t < RC.FORGET and R.IsGuildmate(author) then
			books[#books + 1] = { author = author, book = book }
		end
	end
	table.sort(books, function(a, b)
		if a.book.t ~= b.book.t then return a.book.t > b.book.t end
		return a.author < b.author
	end)
	local first = previous and previous.nextIndex or 1
	if first > #books then first = 1 end
	local last = math.min(#books, first + 7)
	replies[key] = { at = GetTime(), nextIndex = last + 1 }
	for n = first, last do
		local author, book = books[n].author, books[n].book
		C.SendBig("rcl", { p = f.p, a = author, t = book.t, r = book.r, m = book.m,
			i = RC.Encode(book.items), s = RC.Encode(book.spells) }, "normal", name)
	end
end)
-- Merge only after the transport has established the sender and guild context.
-- Keep transport checks separate from the rules for accepting a cached book.
local function mergeCachedBook(f)
	local now = GetServerTime()
	if f.t > now or now - f.t >= RC.FORGET then return end
	local key = permissionKey(f.a, f.p)
	if denied()[key] or not plausible(f.a, f.r or 0) then return end
	local t = theirs()
	local old = t[f.a] and t[f.a][f.p]
	if old and (old.t or 0) >= f.t then return end
	local items, spells = RC.Decode(f.i or ""), RC.Decode(f.s or "")
	if not items or not spells then return end
	t[f.a] = t[f.a] or {}
	t[f.a][f.p] = { r = f.r or 0, m = f.m or 0, items = items, spells = spells, t = f.t, relayed = true }
	changed()
end
C.OnMessage("rcl", function(f, name, _, channel)
	if channel ~= "WHISPER" or not R.IsGuildmate(name) or not R.IsGuildmate(f.a) or f.a == ns.Me() or not KNOWN_LINES[f.p] then return end
	local requested = requests[ns.GuildKey() .. ":" .. f.p]
	if not requested or not requested.peers[name] or GetTime() - requested.at > 45 then return end
	mergeCachedBook(f)
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
-- Forever recipe data, independently of the guild's recipe books.
-- Entries below are verified against the corresponding Forever spell records.
local catalogue = {
	-- https://www.wowhead.com/forever/spell=2160/embossed-leather-vest
	[2300] = { profession = 165, recipe = 2160, materials = "2318:8,2320:4",
		en = "Embossed Leather Vest", es = "Jubón de cuero repujado" },
	-- https://www.wowhead.com/forever/spell=3292/heavy-copper-broadsword
	[3487] = { profession = 164, recipe = 3292, materials = "2840:14,2880:2,818:2,2319:2",
		en = "Heavy Copper Broadsword", es = "Espada ancha pesada de cobre" },
	-- https://www.wowhead.com/forever/spell=3496/moonsteel-broadsword
	[3853] = { profession = 164, recipe = 3496, materials = "3859:8,3466:2,3486:2,1705:3,4234:3",
		en = "Moonsteel Broadsword", es = "Espada ancha de acero lunar" },
}
local catalogueOutputs = {}
for item, entry in pairs(catalogue) do
	catalogueOutputs[entry.recipe] = item
end

local libraryIndex
local function professionCatalogue()
	if libraryIndex then return libraryIndex end
	local db = LibStub and LibStub("LibProfessionDB-1.0", true)
	if not (db and db.IsReady and db:IsReady() and db.GetRecipes
		and db.GetGameVersion and db:GetGameVersion() == "Forever") then return end

	local data = { items = {}, outputs = {}, professions = {}, spells = {} }
	for _, profession in ipairs(ns.Professions.IDS) do
		for id, recipe in pairs(db:GetRecipes(profession) or {}) do
			local spell = recipe.spellID or recipe.spellId or recipe.recipeId or id
			local item = recipe.craftedItemId
			if type(spell) == "number" and spell > 0 then
				data.professions[profession] = true
				if type(item) == "number" and item > 0 then
					local entry = { profession = profession, recipe = spell, data = recipe }
					local old = data.items[item]
					if not old or spell < old.recipe then data.items[item] = entry end
					data.outputs[spell] = item
				else
					data.spells[profession] = data.spells[profession] or {}
					data.spells[profession][spell] = recipe
				end
			end
		end
	end
	if next(data.professions) then libraryIndex = data; return data end
end

function RC.HasProfessionCatalogue(profession)
	local data = professionCatalogue()
	return data and data.professions[profession]
end

function RC.CatalogueSpells(profession)
	local data = professionCatalogue()
	return data and data.spells[profession] or {}
end

local function catalogueEntry(item)
	local data = professionCatalogue()
	return data and data.items[item] or catalogue[item]
end

function RC.CatalogueItems(profession)
	local items, seen = {}, {}
	local data = professionCatalogue()
	for item, entry in pairs(data and data.items or {}) do
		if entry.profession == profession then items[#items + 1] = item; seen[item] = true end
	end
	for item, entry in pairs(catalogue) do
		if entry.profession == profession and not seen[item] then items[#items + 1] = item end
	end
	table.sort(items)
	return items
end

function RC.CatalogueName(item)
	local entry = catalogueEntry(item)
	if entry and entry.data then return entry.data.name end
	if entry then return L.CV_BACK == "Volver" and entry.es or entry.en end
end
-- Items someone crafts, from an item link, an item number or a part of a known item's name (names the client has
-- not loaded yet are skipped this time and found once it has them). At most ten.
function RC.Find(text)
	text = tostring(text or "")
	local id = tonumber(text:match("item:(%d+)") or "") or tonumber(text)
	if id then
		if not index then build_index() end
		return (index[id] or catalogueEntry(id)) and { id } or {}
	end
	local q = strtrim(text):lower()
	if #q < 3 then return {} end
	local out, seen = {}, {}
	for item, entry in pairs(catalogue) do
		if entry.es:lower():find(q, 1, true) or entry.en:lower():find(q, 1, true) then
			out[#out + 1] = item; seen[item] = true
		end
	end
	local data = professionCatalogue()
	for item, entry in pairs(data and data.items or {}) do
		local name = entry.data.name
		if not seen[item] and type(name) == "string" and name:lower():find(q, 1, true) then
			out[#out + 1] = item; seen[item] = true
		end
	end
	table.sort(out)
	for _, item in ipairs(RC.Known()) do
		if #out >= 10 then break end
		local name = ns.ItemInfo(item)
		if not seen[item] and name and name:lower():find(q, 1, true) then out[#out + 1] = item; if #out >= 10 then break end end
	end
	for i = #out, 11, -1 do out[i] = nil end
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
-- Material details are requested separately so recipe books stay compatible
-- with older clients and large inventories do not carry a second catalogue.
local function decodeMaterials(value)
	if type(value) ~= "string" or #value > 220 then return end
	local list, count = {}, 0
	for pair in value:gmatch("[^,]+") do
		local id, n = pair:match("^(%d+):(%d+)$")
		id, n = tonumber(id), tonumber(n)
		if not id or id < 1 or id > 999999 or not n or n < 1 or n > 999 or #list >= 20 then return end
		list[#list + 1] = { id = id, count = n }
		count = count + #pair
	end
	if #list > 0 and count + #list - 1 == #value then return list end
end
local function ownRecipeID(item)
	for _, book in pairs(RC.Mine()) do
		local id = book.recipeIDs and book.recipeIDs[item]
		if id then return id end
	end
end
local function materialsByRecipe(item, id)
	local T = C_TradeSkillUI
	if not (id and T and T.GetRecipeSchematic) then return end
	local ok, schematic = pcall(T.GetRecipeSchematic, id, false)
	schematic = ok and ns.Plain(schematic) or nil
	if type(schematic) == "table" then
		local output = ns.Plain(schematic.outputItemID)
		if output and output ~= item then return end
		local slots = ns.List(schematic.reagentSlotSchematics)
		local pairs = {}
		for _, slot in ipairs(slots) do
			slot = ns.Plain(slot)
			if type(slot) ~= "table" then return end
			local required = ns.Plain(slot.required)
			if required == nil then return end
			if required then
				local reagents = ns.List(slot.reagents)
				local reagent = ns.Plain(reagents[1])
				local material = type(reagent) == "table" and ns.Plain(reagent.itemID)
				local quantity = ns.Plain(slot.quantityRequired)
				if #reagents ~= 1 or type(material) ~= "number" or type(quantity) ~= "number" then return end
				pairs[#pairs + 1] = string.format("%s:%s", material, quantity)
			end
		end
		local payload = table.concat(pairs, ",")
		if decodeMaterials(payload) then return payload end
	end
end
local function materialCache()
	ns.db.recipeMaterials = ns.db.recipeMaterials or {}
	local key = ns.GuildKey()
	ns.db.recipeMaterials[key] = ns.db.recipeMaterials[key] or {}
	return ns.db.recipeMaterials[key]
end
local materialRequests, materialReplies = {}, {}
C.SCHEMA.rcm = { i = C.V.int(1, 999999) }; C.REQUIRED.rcm = { "i" }
C.SCHEMA.rcd = { i = C.V.int(1, 999999), r = C.V.int(1, RC.TOP), m = function(v) return decodeMaterials(v) ~= nil end }
C.REQUIRED.rcd = { "i" }
local function savedMaterialData(item)
	local cached = materialCache()[item]
	return cached and GetServerTime() - cached.at < RC.FORGET and cached or nil
end
C.OnMessage("rcm", function(f, peer, _, channel)
	if channel ~= "WHISPER" or not ns.db.settings.shareProfessions or not R.IsGuildmate(peer) then return end
	if GetTime() - (materialReplies[peer] or -math.huge) < 5 then return end
	materialReplies[peer] = GetTime()
	local cached = savedMaterialData(f.i)
	local id = ownRecipeID(f.i) or (cached and cached.recipe)
	local value = materialsByRecipe(f.i, id) or (cached and cached.value)
	if id or value then C.SendBig("rcd", { i = f.i, r = id, m = value }, "normal", peer) end
end)
C.OnMessage("rcd", function(f, peer, _, channel)
	local req = materialRequests[f.i]
	if channel ~= "WHISPER" or not req or req.guild ~= ns.GuildKey() or req.peer ~= peer or GetTime() - req.at > 45 or not R.IsGuildmate(peer) then return end
	if not f.r and not f.m then return end
	local old = savedMaterialData(f.i)
	materialCache()[f.i] = { value = f.m or (old and old.recipe == f.r and old.value),
		recipe = f.r or (old and old.recipe), at = GetServerTime() }
	ns.Say(L.RC_MATERIALS_ARRIVED)
end)
function RC.RecipeID(item)
	local cached = savedMaterialData(item)
	return ownRecipeID(item) or (catalogueEntry(item) and catalogueEntry(item).recipe) or (cached and cached.recipe)
end
function RC.RecipeLink(item)
	local id, T = RC.RecipeID(item), C_TradeSkillUI
	if not (id and T and T.GetRecipeLink) then return end
	local ok, link = pcall(T.GetRecipeLink, id)
	link = ok and ns.Plain(link) or nil
	if type(link) == "string" and link ~= "" then return link end
end

-- An item ID identifies the product. A linked recipe identifies the
-- crafting spell and lets the client find its output without a guild crafter.
function RC.ResolveSearch(query)
	local recipe = tonumber(query:match("|Henchant:(%d+)") or query:match("^enchant:(%d+)$") or query:match("^recipe:(%d+)$"))
	if recipe then
		if recipe < 1 or recipe > RC.TOP then return end
		local data = professionCatalogue()
		local known = (data and data.outputs[recipe]) or catalogueOutputs[recipe]
		if known then return known end
		local item = outputItem(recipe)
		if type(item) ~= "number" or item < 1 or item > 999999 or item ~= math.floor(item) then
			local T = C_TradeSkillUI
			local ok, schema = pcall(function() return T and T.GetRecipeSchematic and T.GetRecipeSchematic(recipe, false) end)
			schema = ok and ns.Plain(schema) or nil
			item = type(schema) == "table" and ns.Plain(schema.outputItemID)
		end
		if type(item) ~= "number" or item < 1 or item > 999999 or item ~= math.floor(item) then return end
		local old = savedMaterialData(item)
		if not old or old.recipe ~= recipe then
			materialCache()[item] = { recipe = recipe, value = materialsByRecipe(item, recipe), at = GetServerTime() }
		end
		return item
	end
	local id = tonumber(query:match("|Hitem:(%d+)") or query:match("^item:(%d+)$")) or tonumber(query)
	if id and (id < 1 or id > 999999 or id ~= math.floor(id)) then return end
	if id and catalogueEntry(id) then return id end
	if not id then
		local name = query:lower()
		for item, entry in pairs(catalogue) do
			if entry.en:lower() == name or entry.es:lower() == name then return item end
		end
	end
	local ok, name, link = pcall(ns.ItemInfo, id or query)
	name, link = ns.Plain(name), ns.Plain(link)
	if id and (savedMaterialData(id) or (ok and type(name) == "string")) then return id end
	if not id and ok and type(name) == "string" and type(link) == "string" and name:lower() == query:lower() then
		return tonumber(link:match("|Hitem:(%d+)"))
	end
end
local catalogueMaterialNames = {
	[2318] = { "Light Leather", "Cuero ligero" },
	[2320] = { "Coarse Thread", "Hilo burdo" },
	[2840] = { "Copper Bar", "Lingote de cobre" },
	[2880] = { "Weak Flux", "Fundente débil" },
	[818] = { "Tigerseye", "Ojo de tigre" },
	[2319] = { "Medium Leather", "Cuero medio" },
	[3859] = { "Steel Bar", "Lingote de acero" },
	[3466] = { "Strong Flux", "Fundente fuerte" },
	[3486] = { "Heavy Grinding Stone", "Piedra de pulir pesada" },
	[1705] = { "Lesser Moonstone", "Piedra lunar inferior" },
	[4234] = { "Heavy Leather", "Cuero pesado" },
}

function RC.MaterialText(item, hyperlinks)
	local cached = savedMaterialData(item)
	local id = RC.RecipeID(item)
	local resolved = materialsByRecipe(item, id)
	if resolved and (not cached or cached.value ~= resolved or cached.recipe ~= id) then
		materialCache()[item] = { value = resolved, recipe = id, at = GetServerTime() }
	end
	local entry = catalogueEntry(item)
	local fromLibrary = entry and entry.data and entry.recipe == id and entry.data.reagents
	local payload = resolved or (catalogue[item] and catalogue[item].materials) or (cached and cached.value)
	local materials = decodeMaterials(payload)
	if fromLibrary and not resolved then
		local reagents = {}
		for key, row in pairs(fromLibrary) do
			local reagent, count
			if type(row) == "table" then
				reagent = row.itemId or row.itemID or row[1]
				count = row.count or row.quantity or row[2]
			else
				reagent, count = key, row
			end
			if type(reagent) == "number" and reagent > 0 and type(count) == "number" and count > 0 then
				reagents[#reagents + 1] = { id = reagent, count = count }
			else
				reagents = nil
				break
			end
		end
		if reagents and #reagents > 0 then materials = reagents end
	end
	if not materials then return end
	local lines = { L.RC_MATERIALS }
	for _, material in ipairs(materials) do
		local name, link = ns.ItemInfo(material.id)
		local fallback = catalogueMaterialNames[material.id]
		name = name or (fallback and fallback[L.CV_BACK == "Volver" and 2 or 1])
			or string.format(L.RC_MATERIAL_PENDING, material.id)
		lines[#lines + 1] = string.format("%d × %s", material.count, hyperlinks and link or name)
	end
	return table.concat(lines, "\n")
end
function RC.ShowMaterials(item)
	local materials = RC.MaterialText(item)
	if not materials then
		local req = materialRequests[item]
		if not req or req.guild ~= ns.GuildKey() or GetTime() - req.at >= 45 then
			local function ask(peer)
				if peer == ns.Me() or not R.IsGuildmate(peer) or not C.Whisper("rcm", { i = item }, peer) then return false end
				materialRequests[item] = { peer = peer, at = GetTime(), guild = ns.GuildKey() }
				return true
			end
			local tried
			for _, crafter in ipairs(RC.WhoCrafts(item)) do
				if crafter.online and ask(crafter.name) then tried = true; break end
			end
			if not tried then
				for _, peer in ipairs(R.List()) do if ask(peer) then break end end
			end
		end
	end
	ns.DiscordCopy.OpenLinks(function(hyperlinks)
		local text = RC.MaterialText(item, hyperlinks) or L.RC_MATERIALS_UNKNOWN
		local recipe = RC.RecipeID(item)
		if not recipe then return text end
		local link = hyperlinks and RC.RecipeLink(item)
		return string.format(L.RC_RECIPE_ID, recipe) .. (link and ("\n" .. link) or "") .. "\n\n" .. text
	end, ns.ItemInfo(item) or RC.CatalogueName(item) or ("#" .. item), L.RC_MATERIALS_HINT)
end
function RC.AskLabel(name)
	return string.format(RC.IsOnline(name) and L.RC_ASK_MENU or L.RC_MAIL_MENU, name)
end
function RC.Ask(name, item)
	local message = string.format(L.RC_ASK, RC.Link(item))
	if not RC.IsOnline(name) then
		local materials = RC.MaterialText(item)
		ns.DiscordCopy.OpenText(materials and (message .. "\n\n" .. materials) or message, string.format(L.RC_MAIL_MENU, name), L.RC_MAIL_HINT)
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
