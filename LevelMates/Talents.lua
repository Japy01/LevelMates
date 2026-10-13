-- Talents.lua: guildmates' talents, read without the game's talent window. Two parts:
--   * the PLAN of a class tree (which talents, where, their ranks and spells): only a client of that class can read it,
--     so each one reads its own (the game's traits API) and shares it once a session; others keep it per class.
--   * the CODE of a build: the game's own loadout export string (Builds.lua shares it). Read here bit by bit against
--     the plan, as the game's own importer does: a header (version 8 bits, spec 16, tree hash 16 x 8), then per node
--     in the tree's order: chosen (1); if chosen, bought (1) — not bought is granted, rank 1; if bought, partial (1)
--     and then its rank (6); a choice (1) and then which (2). Base64, 6 bits a character, each value low bit first.
-- Nothing here opens or touches the game's talent window.
local _, ns = ...
local TL = {}
ns.Talents = TL
local C = ns.Comm

------------------------------------------------------------------ reading a code
local ALPHA = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local VALUE = {}
for i = 1, #ALPHA do VALUE[ALPHA:sub(i, i)] = i - 1 end

local function reader(code)
	local bits = {}
	for i = 1, #code do
		local ch = code:sub(i, i)
		if ch == "=" then break end
		local v = VALUE[ch]
		if not v then return nil end
		for k = 0, 5 do bits[#bits + 1] = math.floor(v / 2 ^ k) % 2 end
	end
	local pos = 0
	return function(n)
		local out = 0
		for k = 0, n - 1 do
			pos = pos + 1
			if bits[pos] == nil then error("short") end
			out = out + bits[pos] * 2 ^ k
		end
		return out
	end
end

-- { version, spec, hash, nodes = { [nodeID] = { rank, entry, granted } }, points = { [groupID] = n } }, or nil and why
-- ("code": not a code; "tree": made for another tree than this plan; "short": cut).
function TL.Decode(code, plan)
	if type(code) ~= "string" or code == "" or not plan then return nil, "code" end
	local read = reader(code)
	if not read then return nil, "code" end
	local ok, res = pcall(function()
		local out = { version = read(8), spec = read(16), nodes = {}, points = {} }
		local hex, zero = {}, true
		for i = 1, 16 do local b = read(8); if b ~= 0 then zero = false end; hex[i] = string.format("%02x", b) end
		out.hash = table.concat(hex)
		if not zero and plan.hash and out.hash ~= plan.hash then return "tree" end   -- a zero hash skips the check, as the game does
		for _, node in ipairs(plan.nodes) do
			if read(1) == 1 then
				local n = { rank = 1, entry = 1 }
				if read(1) == 1 then
					n.rank = read(1) == 1 and read(6) or node.max
					if read(1) == 1 then n.entry = read(2) + 1 end
					out.points[node.group] = (out.points[node.group] or 0) + n.rank
				else
					n.granted = true
				end
				out.nodes[node.id] = n
			end
		end
		return out
	end)
	if not ok then return nil, "short" end
	if res == "tree" then return nil, "tree" end
	return res
end

------------------------------------------------------------------ a plan as text
-- "1~tree~hash~groups~nodes": groups "id,order,icon,name" joined by ";", nodes "id,x,y,max,type,group,spell/spell"
local function clean(s) return (tostring(s or ""):gsub("[~;,|%c]", " ")) end
function TL.EncodeLayout(plan)
	local groups, nodes = {}, {}
	for _, g in ipairs(plan.groups or {}) do groups[#groups + 1] = table.concat({ g.id, g.order or 0, g.icon or 0, clean(g.name) }, ",") end
	for _, n in ipairs(plan.nodes or {}) do
		local spells = {}
		for _, s in ipairs(n.spells or {}) do spells[#spells + 1] = tostring(s) end
		nodes[#nodes + 1] = table.concat({ n.id, n.x or 0, n.y or 0, n.max or 1, n.type or 0, n.group or 0, table.concat(spells, "/") }, ",")
	end
	return table.concat({ "1", plan.tree or 0, plan.hash or "", table.concat(groups, ";"), table.concat(nodes, ";") }, "~")
end
function TL.DecodeLayout(text)
	if type(text) ~= "string" then return nil end
	local v, tree, hash, groups, nodes = text:match("^(%d+)~(%d+)~(%x*)~([^~]*)~([^~]*)$")
	if v ~= "1" then return nil end
	local plan = { tree = tonumber(tree), hash = hash ~= "" and hash or nil, groups = {}, nodes = {} }
	for part in groups:gmatch("[^;]+") do
		local id, order, icon, name = part:match("^(%-?%d+),(%-?%d+),(%-?%d+),(.*)$")
		if id then plan.groups[#plan.groups + 1] = { id = tonumber(id), order = tonumber(order), icon = tonumber(icon), name = name } end
	end
	for part in nodes:gmatch("[^;]+") do
		local id, x, y, max, typ, group, spells = part:match("^(%d+),(%-?%d+),(%-?%d+),(%d+),(%d+),(%-?%d+),([%d/]*)$")
		if not id then return nil end
		local list = {}
		for s in spells:gmatch("%d+") do list[#list + 1] = tonumber(s) end
		plan.nodes[#plan.nodes + 1] = { id = tonumber(id), x = tonumber(x), y = tonumber(y), max = tonumber(max), type = tonumber(typ), group = tonumber(group), spells = list }
	end
	if #plan.nodes == 0 then return nil end
	table.sort(plan.groups, function(a, b) return (a.order or 0) < (b.order or 0) end)
	return plan
end

------------------------------------------------------------------ my plan, from the game
local function call(fn, ...) if not fn then return nil end; local ok, a = pcall(fn, ...); if ok then return a end end
function TL.ReadMine()
	if not (C_ClassTalents and C_Traits) then return nil end
	local config = call(C_ClassTalents.GetActiveConfigID)
	local info = config and call(C_Traits.GetConfigInfo, config)
	local tree = info and info.treeIDs and info.treeIDs[1]
	if not tree then return nil end
	local ids = call(C_Traits.GetTreeNodes, tree)
	if type(ids) ~= "table" or #ids == 0 then return nil end
	local hash = call(C_Traits.GetTreeHash, tree)
	local hex = {}
	for i = 1, 16 do hex[i] = string.format("%02x", (type(hash) == "table" and tonumber(hash[i])) or 0) end
	local plan = { class = select(2, UnitClass("player")), tree = tree, hash = table.concat(hex), groups = {}, nodes = {} }
	for _, g in ipairs(call(C_Traits.GetGroupDisplayInfoByTreeID, tree) or {}) do
		plan.groups[#plan.groups + 1] = { id = g.groupID, order = g.orderIndex or 0, icon = tonumber(g.icon) or 0, name = g.displayName }
	end
	table.sort(plan.groups, function(a, b) return a.order < b.order end)
	for _, id in ipairs(ids) do   -- every node, in the tree's order: the code walks them all
		local n = call(C_Traits.GetNodeInfo, config, id) or {}
		local spells = {}
		for _, entryID in ipairs(n.entryIDs or {}) do
			local e = call(C_Traits.GetEntryInfo, config, entryID)
			local d = e and e.definitionID and call(C_Traits.GetDefinitionInfo, e.definitionID)
			spells[#spells + 1] = d and d.spellID or 0
		end
		plan.nodes[#plan.nodes + 1] = { id = id, x = math.floor(n.posX or 0), y = math.floor(n.posY or 0), max = n.maxRanks or 1,
			type = n.type or 0, group = n.groupIDs and n.groupIDs[1] or 0, spells = spells }
	end
	return plan
end

------------------------------------------------------------------ my build's code, from the game
-- The same text the game's own export gives, made from the talent API alone: its window is never opened nor asked
-- (calling into it from an addon taints it, and the game then blocks changing talents).
local function writer()
	local bits = {}
	local w = {}
	function w.put(n, v) v = math.floor(v or 0); for k = 0, n - 1 do bits[#bits + 1] = math.floor(v / 2 ^ k) % 2 end end
	function w.text()
		local out = {}
		for i = 1, #bits, 6 do
			local v = 0
			for k = 0, 5 do v = v + (bits[i + k] or 0) * 2 ^ k end
			out[#out + 1] = ALPHA:sub(v + 1, v + 1)
		end
		return table.concat(out)
	end
	return w
end
local CHOICE = { [(Enum and Enum.TraitNodeType and Enum.TraitNodeType.Selection) or 2] = true,
	[(Enum and Enum.TraitNodeType and Enum.TraitNodeType.SubTreeSelection) or 3] = true }
function TL.MyCode()
	if not (C_ClassTalents and C_Traits) then return nil end
	local config = call(C_ClassTalents.GetActiveConfigID)
	local info = config and call(C_Traits.GetConfigInfo, config)
	local tree = info and info.treeIDs and info.treeIDs[1]
	local ids = tree and call(C_Traits.GetTreeNodes, tree)
	if type(ids) ~= "table" or #ids == 0 then return nil end
	local spec = PlayerUtil and PlayerUtil.GetCurrentSpecID and call(PlayerUtil.GetCurrentSpecID)
	local hash = call(C_Traits.GetTreeHash, tree)
	local w = writer()
	w.put(8, call(C_Traits.GetLoadoutSerializationVersion) or 1)
	w.put(16, tonumber(spec) or 0)
	for i = 1, 16 do w.put(8, type(hash) == "table" and tonumber(hash[i]) or 0) end
	for _, id in ipairs(ids) do
		local n = call(C_Traits.GetNodeInfo, config, id)
		if not n then return nil end   -- a node we can't read: a wrong code is worse than none
		local bought, active = n.ranksPurchased or 0, n.activeRank or 0
		local selected = bought > 0 or active - bought > 0
		w.put(1, selected and 1 or 0)
		if selected then
			w.put(1, bought > 0 and 1 or 0)
			if bought > 0 then
				local partial = bought ~= (n.maxRanks or 1)
				w.put(1, partial and 1 or 0)
				if partial then w.put(6, bought) end
				local choice = CHOICE[n.type]
				w.put(1, choice and 1 or 0)
				if choice then
					local index
					for k, entryID in ipairs(n.entryIDs or {}) do if n.activeEntry and entryID == n.activeEntry.entryID then index = k end end
					if not index or index > 4 then return nil end
					w.put(2, index - 1)
				end
			end
		end
	end
	return w.text()
end

------------------------------------------------------------------ plans shared
local function store() ns.db.talentLayouts = ns.db.talentLayouts or {}; return ns.db.talentLayouts end
local cache = {}
-- A class's plan: mine from the game, a guildmate's as they sent it.
function TL.LayoutOf(class)
	if not class then return nil end
	if class == select(2, UnitClass("player")) then
		local mine = TL.ReadMine()
		if mine then return mine end
	end
	local e = store()[class]
	if not e then return nil end
	if cache[class] and cache[class].h == e.h then return cache[class].plan end
	local plan = TL.DecodeLayout(e.L)
	if plan then plan.class = class; cache[class] = { h = e.h, plan = plan } end
	return plan
end

local function planText(v) return type(v) == "string" and #v >= 8 and #v <= 9000 and not v:find("[%c|]") end
C.SCHEMA.tlo = { c = C.V.word(16), h = C.V.word(40), L = planText }; C.REQUIRED.tlo = { "c", "h", "L" }
C.SCHEMA.tlq = { c = C.V.word(16), h = C.V.word(40) }; C.REQUIRED.tlq = { "c" }

local lastSent, seen = -math.huge, {}
local function sendMine()
	local plan = TL.ReadMine()
	if not plan or not plan.class then return false end
	lastSent = GetTime()
	ns.db.talentLayoutSent = { h = plan.hash, t = time() }
	return C.SendBig("tlo", { c = plan.class, h = plan.hash, L = TL.EncodeLayout(plan) }, "normal")
end
C.OnMessage("tlo", function(f, name)
	seen[f.c] = GetTime()
	local plan = TL.DecodeLayout(f.L)
	if not plan then return end
	store()[f.c] = { h = f.h, L = f.L, t = time(), by = name }
	cache[f.c] = nil
	ns.Fire("LM_TALENT_LAYOUTS_CHANGED", f.c)
end)
-- Someone needs my class's plan: send it, unless someone sent one a moment ago.
C.OnMessage("tlq", function(f)
	if f.c ~= select(2, UnitClass("player")) or GetTime() - lastSent < 60 then return end
	if f.h then local mine = TL.ReadMine(); if not mine or mine.hash ~= f.h then return end end   -- a plan of another tree: not mine to answer
	local asked = GetTime()
	C_Timer.After(1 + math.random() * 4, function() if (seen[f.c] or -math.huge) < asked then sendMine() end end)
end)
-- Ask the guild for a class's plan: a viewer that has none, or one of another tree than a code (hash: the code's).
function TL.Ask(class, hash)
	if not class or (seen["ask:" .. class] and GetTime() - seen["ask:" .. class] < 60) then return end
	seen["ask:" .. class] = GetTime()
	C.Send("tlq", { c = class, h = hash }, "normal")
end
-- A little after logging in (the tree is read by then): mine goes out when this tree's plan hasn't gone this week.
-- It is long (a whole tree is some 25 chunks): whoever lacks it asks.
local WEEK = 7 * 86400
ns.On("LM_WORLD", function(isInitial, isReloading)
	if not (isInitial or isReloading) then return end
	C_Timer.After(20 + math.random() * 20, function()
		if not C.IsReady() then return end
		local mine, last = TL.ReadMine(), ns.db.talentLayoutSent
		if mine and not (last and last.h == mine.hash and time() - (last.t or 0) < WEEK) then sendMine() end
	end)
end)
