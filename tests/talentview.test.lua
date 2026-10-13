-- the talent viewer: a guildmate's build drawn on their class tree (three branches side by side, the game's own node
-- art), without the game's talent window; waiting for the tree when we lack it; the game's link as a way out
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local TL, TV, C, L = ns.Talents, ns.TalentView, ns.Comm, ns.L
for _, a in ipairs({ "talents-node-square-yellow", "talents-node-square-green", "talents-node-square-gray", "talents-node-square-locked", "talents-node-choice-yellow", "talent-background-mage" }) do STUB.atlases[a] = true end

local plan = {
	tree = 77, hash = string.rep("00", 16),
	groups = { { id = 11, order = 1, icon = 135932, name = "Arcano" }, { id = 12, order = 2, icon = 135810, name = "Fuego" }, { id = 13, order = 3, icon = 135846, name = "Escarcha" } },
	nodes = {
		{ id = 101, x = 1000, y = 1200, max = 1, type = 0, group = 11, spells = { 1001 }, to = { 102 } },
		{ id = 102, x = 1000, y = 1800, max = 5, type = 0, group = 11, spells = { 1002 }, to = {} },
		{ id = 103, x = 5000, y = 1200, max = 1, type = 2, group = 12, spells = { 1003, 1004 }, to = {} },
		{ id = 104, x = 9000, y = 1200, max = 3, type = 0, group = 13, spells = { 1005 }, to = {} },
		{ id = 105, x = 9000, y = 1800, max = 1, type = 0, group = 13, spells = { 1006 }, to = {} },
		{ id = 106, x = 9600, y = 1800, max = 1, type = 0, group = 13, spells = { 1007 }, to = {}, hidden = true },
	},
}
-- the game's code for: 101 maxed, 102 at 3 of 5, 103 second choice, 104 nothing
local ALPHA = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local bits = {}
local function put(v, n) for i = 0, n - 1 do bits[#bits + 1] = math.floor(v / 2 ^ i) % 2 end end
put(2, 8); put(1482, 16); for _ = 1, 16 do put(0, 8) end
put(1, 1); put(1, 1); put(0, 1); put(0, 1)                 -- 101: bought, full
put(1, 1); put(1, 1); put(1, 1); put(3, 6); put(0, 1)      -- 102: bought, 3
put(1, 1); put(1, 1); put(0, 1); put(1, 1); put(1, 2)      -- 103: bought, choice 2
put(0, 1)                                                  -- 104: none
put(0, 1); put(0, 1)                                       -- 105, 106: none
local out = {}
for i = 1, #bits, 6 do local v = 0; for k = 0, 5 do v = v + (bits[i + k] or 0) * 2 ^ k end; out[#out + 1] = ALPHA:sub(v + 1, v + 1) end
local code = table.concat(out)
local ana = { name = "Ana", c = "MAGE", s = 1482, l = 30, b = code }

-- no tree for her class yet: a note, the guild is asked, the game's link still on offer
assert(TV.Open(ana), "opens")
assert(TV.frame:IsShown() and TV.note:IsShown() and TV.note.text == L.TV_WAITING, "waiting for the tree")
local asked = false
for _, s in ipairs(STUB.sent) do local k, f = C.Decode(s.msg); if k == "tlq" and f.c == "MAGE" then asked = true end end
assert(asked, "asked the guild for the mage tree")
assert(TV.gameButton:IsShown(), "the game's window, by its link")

-- the tree arrives: drawn at once
STUB.Receive("LVLM2", C.Encode("hb", { l = 30, z = 1412, c = "MAGE" }), "GUILD", "Pepe-Testrealm")
ns.db.talentLayouts = { MAGE = { h = plan.hash, L = TL.EncodeLayout(plan), t = time() } }
ns.Fire("LM_TALENT_LAYOUTS_CHANGED", "MAGE"); STUB.Advance(1)
assert(not TV.note:IsShown(), "no note once drawn")
local by = {}
for _, b in ipairs(TV.nodes) do if b:IsShown() then by[b.nodeId] = b end end
assert(by[101] and by[102] and by[103] and by[104], "every node")
assert(by[101].ring.atlas == "talents-node-square-yellow" and by[101].rank.text == "1/1", "maxed: yellow")
assert(by[102].ring.atlas == "talents-node-square-green" and by[102].rank.text == "3/5", "partial: green, its rank")
assert(by[103].ring.atlas == "talents-node-choice-yellow" and by[103].spell == 1004, "a choice: its chosen spell")
assert(by[104].ring.atlas == "talents-node-square-gray" and by[104].icon.desaturated and by[104].state == "open", "not taken, could be: gray, faded")
assert(by[105].state == "locked" and by[105].ring.atlas == "talents-node-square-locked", "row 2 without 5 points: locked")
assert(not by[106], "hidden nodes are not drawn")
assert(TV.total.text == string.format(L.TV_TOTAL, 5), "points in all: " .. tostring(TV.total.text))
-- Forever names its branches "Tree 1": the classic names instead
plan.groups[2].name = "Tree 2"
ns.db.talentLayouts.MAGE = { h = "x", L = TL.EncodeLayout(plan), t = time() }
ns.Fire("LM_TALENT_LAYOUTS_CHANGED", "MAGE")
assert(TV.heads[2].name.text == L.TREE_MAGE_2, "classic branch name")
-- the branches: left to right, side by side
assert(by[101].px < by[103].px and by[103].px < by[104].px and by[101].py > by[102].py, "Arcano left, Escarcha right; top to bottom")
assert(TV.heads[1].name.text == "Arcano" and TV.heads[1].points.text == "4" and TV.heads[2].points.text == "1" and TV.heads[3].points.text == "0", "branch heads with points")
assert((TV.title.text or ""):find("Ana", 1, true), "whose build")

-- a code made for another tree: said, and the guild is asked for the right one
local other = { name = "Mario", c = "MAGE", s = 1482, l = 30, b = code:sub(1, 4) .. "/////////////////" .. code:sub(22) }
TV.Open(other)
assert(TV.note:IsShown() and TV.note.text == L.TV_OTHER_TREE, "another tree")
assert(TL.HashOf(code) == string.rep("00", 16) and TL.HashOf(other.b) ~= TL.HashOf(code) and TL.HashOf("!") == nil, "a code's tree hash")
-- nothing to show: false
assert(not TV.Open({ name = "Nadie", c = "MAGE", s = 1482, l = 30 }), "no code: nothing")
