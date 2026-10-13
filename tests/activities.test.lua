-- the catalogue of activities: the dungeons as they are, raids, PvP, and anything else by name
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
local A, D = ns.Activities, ns.Dungeons
local function caps(t) local parts = {}; for _, r in ipairs({ "T", "H", "D", "A" }) do if t[r] then parts[#parts + 1] = r .. t[r] end end; return table.concat(parts) end

assert(A.Get(5).kind == "d" and A.Name(5) == D.Name(5), "a dungeon as it was")
assert(A.Get(101).kind == "r" and A.Get(101).size == 40 and caps(A.Caps(101)) == "T5H10D25", "Molten Core: 40, 5/10/25")
assert(caps(A.Caps(190, 20)) == "T3H5D12", "a free raid of 20")
assert(caps(A.Caps(190, 10, "T1H2D7")) == "T1H2D7", "a raid leader's own split")
assert(caps(A.Caps(5, 5, "T3H1D1")) == "T1H1D3", "a dungeon keeps 1/1/3 whatever is asked")
assert(caps(A.Caps(203)) == "A40", "Alterac: 40, no roles")
assert(caps(A.Caps(290, 12)) == "A12", "world PvP: the leader's size")
assert(caps(A.Caps(300, 99)) == "A40", "other: at most 40")
assert(caps(A.Caps(300, 1)) == "A2", "other: at least 2")
assert(A.SizeOf(202) == 15 and A.SizeOf(5) == 5 and A.SizeOf(190) == 20 and A.SizeOf(190, 40) == 40, "sizes from the activity")
assert(A.SizeOf(190, 25) == 20 and A.SizeOf(203, 10) == 40, "a size the activity does not have: its own")
assert(A.Name(300, "farmear seda") == "farmear seda" and A.Name(999) == "#999", "free names; unknown ids")
assert(A.Name(101, "otro nombre") == A.Name(101), "a catalogue activity keeps its own name")
local clean = A.CleanName("|cffff0000rojo|r " .. string.rep("x", 60))
assert(not clean:find("|", 1, true) and #clean <= 40 and clean:sub(1, 4) == "rojo", "cleaned and cut: " .. clean)
assert(A.EncodeCaps({ T = 2, H = 3, D = 5 }) == "T2H3D5" and caps(A.DecodeCaps("T2H3D5")) == "T2H3D5", "caps as text and back")
assert(A.DecodeCaps("nonsense") == nil, "bad caps text: nil")
local d = A.List("d")
assert(#d == 14, "14 dungeons")
for i, x in ipairs(D.Sorted()) do assert(d[i].id == x.id, "in the dungeons' order") end
local r = A.List("r")
assert(r[1].id == 101 and r[#r].id == 190 and r[#r].free, "raids, the free one last")
local p = A.List("p")
assert(p[#p].id == 290 and A.Get(290).roles == false, "PvP, world PvP last, no roles")
assert(A.Get(300).free and A.Get(300).kind == "o", "other")
for _, kind in ipairs(A.KINDS) do assert(ns.L["KIND_" .. kind], "a name for the kind " .. kind) end
