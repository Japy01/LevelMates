-- talents: my class tree's plan read from the game, written as text and back; a loadout code (the game's export
-- format) read against a plan; plans shared with the guild once a session
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
local TL, C = ns.Talents, ns.Comm

-- a small tree: three branches; a single node, a 5-rank node, a 2-choice node, a granted node, an empty node
local layout = {
	class = "MAGE", tree = 77, spec = 1489, hash = string.rep("ab", 16),
	groups = { { id = 11, order = 1, icon = 135932, name = "Arcano" }, { id = 12, order = 2, icon = 135810, name = "Fuego" }, { id = 13, order = 3, icon = 135846, name = "Escarcha" } },
	nodes = {
		{ id = 101, x = 1000, y = 1200, max = 1, type = 0, group = 11, spells = { 1001 }, to = { 102 } },
		{ id = 102, x = 1600, y = 1200, max = 5, type = 0, group = 11, spells = { 1002 } },
		{ id = 103, x = 5000, y = 1200, max = 1, type = 2, group = 12, spells = { 1003, 1004 } },
		{ id = 104, x = 9000, y = 1200, max = 1, type = 0, group = 13, spells = { 1005 } },
		{ id = 105, x = 9000, y = 1800, max = 3, type = 0, group = 13, spells = { 1006 } },
	},
}

-- the game's export format, as its own code writes it: 6 bits a character, each value low bit first
local ALPHA = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local function encode(spec, hashHex, picks)
	local bits = {}
	local function put(v, n) for i = 0, n - 1 do bits[#bits + 1] = math.floor(v / 2 ^ i) % 2 end end
	put(2, 8); put(spec, 16)
	for i = 1, 16 do put(tonumber(hashHex:sub(i * 2 - 1, i * 2), 16), 8) end
	for _, node in ipairs(layout.nodes) do
		local p = picks[node.id]
		if not p then put(0, 1)
		else
			put(1, 1)
			if p.granted then put(0, 1)
			else
				put(1, 1)
				if p.rank < node.max then put(1, 1); put(p.rank, 6) else put(0, 1) end
				if node.type == 2 then put(1, 1); put(p.entry - 1, 2) else put(0, 1) end
			end
		end
	end
	local out = {}
	for i = 1, #bits, 6 do
		local v = 0
		for k = 0, 5 do v = v + (bits[i + k] or 0) * 2 ^ k end
		out[#out + 1] = ALPHA:sub(v + 1, v + 1)
	end
	return table.concat(out)
end

-- the plan as text and back
local text = TL.EncodeLayout(layout)
assert(type(text) == "string" and not text:find("|", 1, true), "text, no pipes")
local back = TL.DecodeLayout(text)
assert(back and back.tree == 77 and back.hash == layout.hash and #back.nodes == 5 and #back.groups == 3, "round trip")
assert(back.nodes[3].type == 2 and back.nodes[3].spells[2] == 1004 and back.nodes[2].max == 5 and back.groups[2].name == "Fuego", "fields kept")
assert(back.nodes[1].to[1] == 102 and #back.nodes[2].to == 0, "arrows kept")
assert(TL.DecodeLayout("rubbish") == nil, "bad text: nil")

-- a loadout read against the plan
local code = encode(1489, layout.hash, { [101] = { rank = 1 }, [102] = { rank = 3 }, [103] = { rank = 1, entry = 2 }, [104] = { granted = true } })
local got, why = TL.Decode(code, layout)
assert(got, "decoded: " .. tostring(why))
assert(got.spec == 1489, "its spec")
assert(got.nodes[101].rank == 1 and got.nodes[102].rank == 3 and got.nodes[103].rank == 1 and got.nodes[103].entry == 2, "ranks and the choice")
assert(got.nodes[104].rank == 1 and got.nodes[104].granted, "granted: rank 1")
assert(not got.nodes[105] or got.nodes[105].rank == 0, "the empty node")
assert(got.points[11] == 4 and got.points[12] == 1 and (got.points[13] or 0) == 0, "points per branch (granted ones are free)")
-- another tree's code: refused, with the reason
local other = encode(1489, string.rep("cd", 16), { [101] = { rank = 1 } })
local none, why2 = TL.Decode(other, layout)
assert(none == nil and why2 == "tree", "a code for another tree: " .. tostring(why2))
-- a zero hash skips the check (as the game does)
assert(TL.Decode(encode(1489, string.rep("00", 16), { [101] = { rank = 1 } }), layout), "zero hash: accepted")
assert(TL.Decode("", layout) == nil and TL.Decode("!!!", layout) == nil, "rubbish codes")

-- my plan from the game (the traits API)
-- the stub plays a warrior
C_ClassTalents = { GetActiveConfigID = function() return 9 end }
C_Traits = {
	GetConfigInfo = function() return { treeIDs = { 77 } } end,
	GetTreeNodes = function() return { 101, 102 } end,
	GetTreeHash = function() local t = {}; for i = 1, 16 do t[i] = 171 end; return t end,
	GetNodeInfo = function(_, id) return { ID = id, posX = id * 10, posY = 50, maxRanks = id == 102 and 5 or 1, type = 0, groupIDs = { 11 }, entryIDs = { id + 1000 }, isVisible = true, visibleEdges = id == 101 and { { targetNode = 102 } } or nil } end,
	GetEntryInfo = function(_, entryID) return { definitionID = entryID + 1 } end,
	GetDefinitionInfo = function(def) return { spellID = def * 2 } end,
	GetGroupDisplayInfoByTreeID = function() return { { groupID = 11, orderIndex = 1, displayName = "Arcano", icon = 135932 } } end,
}
local mine = TL.ReadMine()
assert(mine and mine.tree == 77 and mine.hash == string.rep("ab", 16) and #mine.nodes == 2, "read from the game")
assert(mine.nodes[2].max == 5 and mine.nodes[2].spells[1] == (102 + 1000 + 1) * 2 and mine.groups[1].name == "Arcano", "nodes, spells, branches")
assert(mine.nodes[1].to[1] == 102, "arrows from the game")

-- shared once a session; a guildmate's plan stored by class
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(40)
local sentPlan = false
for _, s in ipairs(STUB.sent) do local k = C.Decode(s.msg); if k == "tlo" or (k == "bl" and s.msg:find("tlo", 1, true)) then sentPlan = true end end
assert(sentPlan, "my plan went out")
STUB.Receive("LVLM2", C.Encode("hb", { l = 30, z = 1412, c = "PRIEST" }), "GUILD", "Ana-Testrealm")
local priest = { class = "PRIEST", tree = 88, hash = string.rep("11", 16), groups = { layout.groups[1] }, nodes = { layout.nodes[1], layout.nodes[2] } }   -- small: fits one message
STUB.Receive("LVLM2", C.Encode("tlo", { c = "PRIEST", h = priest.hash, L = TL.EncodeLayout(priest) }), "GUILD", "Ana-Testrealm")
local stored = TL.LayoutOf("PRIEST")
assert(stored and stored.tree == 88, "a priest's plan kept")

-- not again within the week (a whole tree is long); a request for my class is answered, one for another tree is not
local function plansSent(from)
	local n = 0
	for i = from + 1, #STUB.sent do local m = STUB.sent[i].msg; if C.Decode(m) == "tlo" or m:find("tlo~", 1, true) then n = n + 1 end end
	return n
end
local before = #STUB.sent
STUB.Fire("PLAYER_ENTERING_WORLD", false, true); STUB.Advance(60)
assert(plansSent(before) == 0, "not again this week")
before = #STUB.sent
STUB.Receive("LVLM2", C.Encode("tlq", { c = "WARRIOR", h = string.rep("cd", 16) }), "GUILD", "Ana-Testrealm"); STUB.Advance(70)
assert(plansSent(before) == 0, "another tree's request: no answer")
STUB.Receive("LVLM2", C.Encode("tlq", { c = "WARRIOR" }), "GUILD", "Ana-Testrealm"); STUB.Advance(10)
assert(plansSent(before) > 0, "a request for my class: answered")

-- my build's code made from the talent API, as the game makes it, without its talent window: read back the same
PlayerSpellsFrame = nil
local state = { [101] = { ranksPurchased = 1, activeRank = 1 }, [102] = { ranksPurchased = 3, activeRank = 3 } }
C_Traits.GetNodeInfo = function(_, id)
	local s = state[id] or { ranksPurchased = 0, activeRank = 0 }
	return { ID = id, posX = id * 10, posY = 50, maxRanks = id == 102 and 5 or 1, type = 0, groupIDs = { 11 }, entryIDs = { id + 1000 },
		isVisible = true, ranksPurchased = s.ranksPurchased, activeRank = s.activeRank, activeEntry = { entryID = id + 1000 } }
end
C_Traits.GetLoadoutSerializationVersion = function() return 2 end
local myCode = TL.MyCode()
assert(type(myCode) == "string" and myCode:match("^[%w%+/]+$"), "a code: " .. tostring(myCode))
local mineBack = TL.Decode(myCode, TL.ReadMine())
assert(mineBack and mineBack.version == 2 and mineBack.nodes[101].rank == 1 and mineBack.nodes[102].rank == 3, "read back")
assert(ns.Builds.Mine().b == myCode, "the shared build carries it, no talent window needed")
-- a granted node and a choice
state[101] = { ranksPurchased = 0, activeRank = 1 }
local g = TL.Decode(TL.MyCode(), TL.ReadMine())
assert(g.nodes[101].granted, "granted")
