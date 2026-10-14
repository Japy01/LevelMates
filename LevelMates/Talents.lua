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
		return math.floor(out)   -- a whole number (not 3.0)
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

-- The tree hash a code was made for (hex), or nil.
function TL.HashOf(code)
	local read = type(code) == "string" and reader(code)
	if not read then return nil end
	local ok, hex = pcall(function()
		read(8); read(16)
		local t = {}
		for i = 1, 16 do t[i] = string.format("%02x", read(8)) end
		return table.concat(t)
	end)
	return ok and hex or nil
end

------------------------------------------------------------------ a plan as text
TL.LAYOUT_VERSION = "2"   -- 2: each node in its real branch (1 took a node's first group, often not its branch)
-- "1~tree~hash~groups~nodes": groups "id,order,icon,name" joined by ";", nodes "id,x,y,max,type,group,spell/spell,to/to,h"
-- (to: the nodes its arrows lead to; h: 1 when the game does not show it)
local function clean(s) return (tostring(s or ""):gsub("[~;,|%c]", " ")) end
function TL.EncodeLayout(plan)
	local groups, nodes = {}, {}
	for _, g in ipairs(plan.groups or {}) do groups[#groups + 1] = table.concat({ g.id, g.order or 0, g.icon or 0, clean(g.name) }, ",") end
	for _, n in ipairs(plan.nodes or {}) do
		local spells = {}
		for _, s in ipairs(n.spells or {}) do spells[#spells + 1] = tostring(s) end
		local to = {}
		for _, t in ipairs(n.to or {}) do to[#to + 1] = tostring(t) end
		nodes[#nodes + 1] = table.concat({ n.id, n.x or 0, n.y or 0, n.max or 1, n.type or 0, n.group or 0, table.concat(spells, "/"), table.concat(to, "/"), n.hidden and "1" or "" }, ",")
	end
	return table.concat({ TL.LAYOUT_VERSION, plan.tree or 0, plan.hash or "", table.concat(groups, ";"), table.concat(nodes, ";") }, "~")
end
function TL.DecodeLayout(text)
	if type(text) ~= "string" then return nil end
	local v, tree, hash, groups, nodes = text:match("^(%d+)~(%d+)~(%x*)~([^~]*)~([^~]*)$")
	if v ~= TL.LAYOUT_VERSION then return nil end   -- an older format: asked again
	local plan = { tree = tonumber(tree), hash = hash ~= "" and hash or nil, groups = {}, nodes = {} }
	for part in groups:gmatch("[^;]+") do
		local id, order, icon, name = part:match("^(%-?%d+),(%-?%d+),(%-?%d+),(.*)$")
		if id then plan.groups[#plan.groups + 1] = { id = tonumber(id), order = tonumber(order), icon = tonumber(icon), name = name } end
	end
	for part in nodes:gmatch("[^;]+") do
		local id, x, y, max, typ, group, spells, to, hidden = part:match("^(%d+),(%-?%d+),(%-?%d+),(%d+),(%d+),(%-?%d+),([%d/]*),?([%d/]*),?(%d?)$")
		if not id then return nil end
		local list, targets = {}, {}
		for s in spells:gmatch("%d+") do list[#list + 1] = tonumber(s) end
		for t in to:gmatch("%d+") do targets[#targets + 1] = tonumber(t) end
		plan.nodes[#plan.nodes + 1] = { id = tonumber(id), x = tonumber(x), y = tonumber(y), max = tonumber(max), type = tonumber(typ), group = tonumber(group), spells = list, to = targets, hidden = hidden == "1" or nil }
	end
	if #plan.nodes == 0 then return nil end
	table.sort(plan.groups, function(a, b) return (a.order or 0) < (b.order or 0) end)
	return plan
end

------------------------------------------------------------------ the tree as the game shows it
-- The step between positions: the smallest gap that is not a stray (at least half the typical one).
local function step(gaps)
	if #gaps == 0 then return 1 end
	table.sort(gaps)
	local typical = gaps[math.ceil(#gaps / 2)]
	for _, g in ipairs(gaps) do if g > 0 and g >= typical / 2 then return g end end
	return 1
end
local function gapsOf(values)
	local seen, list, gaps = {}, {}, {}
	for _, v in ipairs(values) do if not seen[v] then seen[v] = true; list[#list + 1] = v end end
	table.sort(list)
	for i = 2, #list do gaps[#gaps + 1] = list[i] - list[i - 1] end
	return gaps
end

-- The shown nodes on a grid: { trees = { { group, cols } } in branch order, rows, cells = { [nodeID] = { tree, col, row } } }.
-- Columns count within each branch; rows are level across branches, as in the game's window.
function TL.Grid(plan)
	local index, trees = {}, {}
	for i, g in ipairs(plan.groups or {}) do index[g.id] = i; trees[i] = { group = g.id, cols = 1, left = math.huge } end
	local shown, ys, xsBy = {}, {}, {}
	for _, n in ipairs(plan.nodes or {}) do
		local t = index[n.group]
		if t and not n.hidden then
			shown[#shown + 1] = n; ys[#ys + 1] = n.y
			trees[t].left = math.min(trees[t].left, n.x)
			xsBy[t] = xsBy[t] or {}; table.insert(xsBy[t], n.x)
		end
	end
	if #shown == 0 then return nil end
	local pooled = {}   -- the column step from the gaps inside each branch (between branches the gap is wider)
	for _, xs in pairs(xsBy) do for _, g in ipairs(gapsOf(xs)) do pooled[#pooled + 1] = g end end
	local stepX, stepY, top = step(pooled), step(gapsOf(ys)), math.huge
	for _, y in ipairs(ys) do top = math.min(top, y) end
	local grid = { trees = trees, rows = 1, cells = {} }
	for _, n in ipairs(shown) do
		local t = index[n.group]
		local col = math.floor((n.x - trees[t].left) / stepX + 0.5) + 1
		local row = math.floor((n.y - top) / stepY + 0.5) + 1
		grid.cells[n.id] = { tree = t, col = col, row = row }
		trees[t].cols = math.max(trees[t].cols, col)
		grid.rows = math.max(grid.rows, row)
	end
	return grid
end

-- Each shown node's state: "max", "partial", "open" (could be taken now) or "locked" (its row asks 5 points a row in
-- its branch, or a node whose arrow leads to it is not full). got: what TL.Decode gives.
TL.POINTS_PER_ROW = 5
function TL.States(plan, grid, got)
	local states, byId, from = {}, {}, {}
	for _, n in ipairs(plan.nodes) do
		byId[n.id] = n
		for _, t in ipairs(n.to or {}) do from[t] = from[t] or {}; table.insert(from[t], n) end
	end
	local function rankOf(n)
		local p = got.nodes[n.id]
		if not p then return 0 end
		return p.granted and n.max or p.rank
	end
	for id, cell in pairs(grid.cells) do
		local n = byId[id]
		local rank = rankOf(n)
		if rank >= n.max then states[id] = "max"
		elseif rank > 0 then states[id] = "partial"
		else
			local group = grid.trees[cell.tree].group
			local free = (got.points[group] or 0) >= TL.POINTS_PER_ROW * (cell.row - 1)
			for _, src in ipairs(from[id] or {}) do if rankOf(src) < src.max then free = false end end
			states[id] = free and "open" or "locked"
		end
	end
	return states
end

-- A branch's name and icon: the game's, or (Forever names them "Tree 1") the classic ones of the class.
local BRANCH_ICONS = {
	WARRIOR = { 132355, 132347, 134952 }, PALADIN = { 135920, 135893, 135873 }, HUNTER = { 132164, 132222, 132215 },
	ROGUE = { 132292, 132090, 132320 }, PRIEST = { 135940, 237542, 136207 }, SHAMAN = { 136048, 136051, 136052 },
	MAGE = { 135932, 135810, 135846 }, WARLOCK = { 136145, 136172, 136186 }, DRUID = { 136096, 132276, 136041 },
}
function TL.BranchName(class, group, i)
	local name = group and group.name
	if name and name ~= "" and not name:match("^Tree %d+$") and not name:match("^#") then return name end
	return ns.L["TREE_" .. tostring(class) .. "_" .. i] or name or ("#" .. i)
end
function TL.BranchIcon(class, group, i)
	if group and group.icon and group.icon > 0 then return group.icon end
	return BRANCH_ICONS[class] and BRANCH_ICONS[class][i] or 134400
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
	local branch = {}
	for _, g in ipairs(plan.groups) do branch[g.id] = true end
	for _, id in ipairs(ids) do   -- every node, in the tree's order: the code walks them all
		local n = call(C_Traits.GetNodeInfo, config, id) or {}
		local spells = {}
		for _, entryID in ipairs(n.entryIDs or {}) do
			local e = call(C_Traits.GetEntryInfo, config, entryID)
			local d = e and e.definitionID and call(C_Traits.GetDefinitionInfo, e.definitionID)
			spells[#spells + 1] = d and d.spellID or 0
		end
		local to = {}
		for _, e in ipairs(n.visibleEdges or {}) do if e.targetNode then to[#to + 1] = e.targetNode end end
		-- a node can be in several groups (Forever): its branch is the one of them that is a branch
		local group
		for _, gid in ipairs(n.groupIDs or {}) do if branch[gid] and not group then group = gid end end
		plan.nodes[#plan.nodes + 1] = { id = id, x = math.floor(n.posX or 0), y = math.floor(n.posY or 0), max = n.maxRanks or 1,
			type = n.type or 0, group = group, spells = spells, to = to, hidden = n.isVisible == false or nil }
	end
	-- in no branch: the branch whose nodes stand nearest (by column)
	local sum, count = {}, {}
	for _, n in ipairs(plan.nodes) do if n.group then sum[n.group] = (sum[n.group] or 0) + n.x; count[n.group] = (count[n.group] or 0) + 1 end end
	for _, n in ipairs(plan.nodes) do
		if not n.group then
			local best, dist
			for gid, s in pairs(sum) do
				local d = math.abs(n.x - s / count[gid])
				if not dist or d < dist then best, dist = gid, d end
			end
			n.group = best or 0
		end
	end
	return plan
end

-- /lm talentos: what this client reads of my tree (to tell a reading problem from a drawing one).
function TL.Report()
	local plan = TL.ReadMine()
	if not plan then ns.Chat(ns.L.TL_REPORT_NONE); return end
	local per, hidden = {}, 0
	for _, n in ipairs(plan.nodes) do
		if n.hidden then hidden = hidden + 1 else per[n.group] = (per[n.group] or 0) + 1 end
	end
	local parts = {}
	for i, g in ipairs(plan.groups) do parts[#parts + 1] = TL.BranchName(plan.class, g, i) .. " " .. (per[g.id] or 0) end
	ns.Chat(ns.L.TL_REPORT, #plan.nodes, hidden, table.concat(parts, ", "))
	local code = TL.MyCode()
	local got = code and TL.Decode(code, plan)
	if got then
		local pts = {}
		for i, g in ipairs(plan.groups) do pts[#pts + 1] = TL.BranchName(plan.class, g, i) .. " " .. (got.points[g.id] or 0) end
		ns.Chat(ns.L.TL_REPORT_POINTS, table.concat(pts, ", "))
	end
end
ns.Slash("talentos", TL.Report)

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
	ns.db.talentLayoutSent = { h = plan.hash, t = time(), v = TL.LAYOUT_VERSION }
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
		if mine and not (last and last.h == mine.hash and last.v == TL.LAYOUT_VERSION and time() - (last.t or 0) < WEEK) then sendMine() end
	end)
end)
