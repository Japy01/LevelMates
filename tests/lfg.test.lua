STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local C, G, L = ns.Comm, ns.LFG, ns.L
STUB.player.level = 15
local function mate(name, level) STUB.Receive("LVLM2", C.Encode("hb", { l = level or 15, z = 1421 }), "GUILD", name .. "-Testrealm") end
local function ad(from, f) STUB.Receive("LVLM2", C.Encode("lfg", f), "GUILD", from .. "-Testrealm") end
local function lastKind() return (C.Decode(STUB.sent[#STUB.sent].msg)) end
mate("Mario", 18); mate("Ana", 12); mate("Luis", 15)
assert(ns.db.settings.lfgNotices == true, "notices on by default")

-- role helpers
assert(G.NormRoles("DT") == "TD" and G.NormRoles("hd") == "HD" and G.NormRoles("X") == nil and G.NormRoles("") == nil, "roles normalised to T,H,D order")
assert(G.RolesShort("THD") == "T H D", "short roles: " .. G.RolesShort("THD"))

-- posting
assert(G.Post(2, "DT", "con agua") == true, "post works")
local k, f = C.Decode(STUB.sent[#STUB.sent].msg)
assert(k == "lfg" and f.d == 2 and f.lr and f.n == "con agua" and f.m == 20 and f.id == G.mine.id, "ad sent as specified")
assert(f.r and not f.r:find("[^THD]"), "r: the roles still free, from the slots: " .. tostring(f.r))
assert(G.mine.endsAt == GetTime() + 20 * 60, "own ad lives 20 minutes")
local n = #STUB.sent
assert(G.Post(1, "T") == false and #STUB.sent == n, "second post within 30 s refused")
assert(STUB.printed[#STUB.printed]:find(L.LFG_TOO_SOON, 1, true), "and the user is told why")
STUB.Advance(31)
local oldId = G.mine.id
assert(G.Post(1, "T") == true, "after 30 s a new post is allowed")
assert(select(1, C.Decode(STUB.sent[#STUB.sent - 1].msg)) == "lfgx" and G.mine.id ~= oldId, "the old ad is withdrawn first")
G.Cancel()
assert(lastKind() == "lfgx" and G.mine == nil, "cancel sends lfgx")

-- refusals
STUB.Advance(31)
assert(G.Post(99, "T") == false, "unknown dungeon")
STUB.inInstance = true
n = #STUB.sent
assert(G.Post(2, "T") == false and #STUB.sent == n, "not inside an instance")
assert(STUB.printed[#STUB.printed]:find(L.LFG_NO_INSTANCE, 1, true), "and the user is told why")
STUB.inInstance = false
G.Post(2, "T", string.rep("x", 60) .. "|c")
k, f = C.Decode(STUB.sent[#STUB.sent].msg)
assert(k == "lfg" and #f.n == 40, "note cut to 40 bytes: " .. tostring(f.n and #f.n))
G.Cancel()

-- receiving
STUB.Advance(31)
local printedBefore = #STUB.printed
ad("Mario", { d = 2, r = "T", n = "listo", id = "m0000001", m = 15 })
assert(G.ads.m0000001 and G.ads.m0000001.name == "Mario" and G.ads.m0000001.endsAt == GetTime() + 900, "stored with the time left")
assert(#STUB.printed == printedBefore + 1 and STUB.printed[#STUB.printed]:find("Mario", 1, true) and STUB.printed[#STUB.printed]:find(ns.Dungeons.Name(2), 1, true), "notice: dungeon in my range (15 vs 13-18)")
ad("Mario", { d = 2, r = "T", n = "listo", id = "m0000001", m = 14 })
assert(#STUB.printed == printedBefore + 1, "a re-send does not notify again")
STUB.player.level = 40
ad("Ana", { d = 6, r = "D", id = "a0000001", m = 10 })
assert(G.ads.a0000001 and #STUB.printed == printedBefore + 1, "no notice outside my level range, but the ad is listed")
STUB.player.level = 15
ns.db.settings.lfgNotices = false
ad("Luis", { d = 2, r = "H", id = "l0000001", m = 10 })
assert(G.ads.l0000001 and #STUB.printed == printedBefore + 1, "notices off: listed, silent")
ns.db.settings.lfgNotices = true

-- who may announce
ad("Stranger", { d = 2, r = "T", id = "s0000001", m = 10 })
assert(G.ads.s0000001 == nil, "not on the roster: ignored")
ad("Mario", { d = 7, r = "T", id = "m0000009", m = 10 })
assert(G.ads.m0000009 == nil and G.ads.m0000001, "unknown dungeon id ignored, the existing ad untouched")
assert(#STUB.printed == printedBefore + 1, "unknown dungeon id produces no notice")

-- one new ad per player per 30 s; a new ad replaces the old
ad("Mario", { d = 3, r = "H", id = "m0000002", m = 10 })
assert(G.ads.m0000001 and G.ads.m0000002 == nil, "second new ad from the same player within 30 s is ignored")
STUB.Advance(31)
ad("Mario", { d = 3, r = "H", id = "m0000002", m = 10 })
assert(G.ads.m0000002 and G.ads.m0000001 == nil, "after 30 s the new ad replaces the old one")

-- cap of 50, replacing own ad still works at the cap
for i = 1, 60 do
	local name = "Bot" .. i
	mate(name, 20)
	ad(name, { d = 2, r = "D", id = string.format("b%07d", i), m = 20 })
end
local total = 0
for _ in pairs(G.ads) do total = total + 1 end
assert(total == 50, "list capped at 50, got " .. total)
STUB.Advance(31)
ad("Bot1", { d = 3, r = "T", id = "bz000001", m = 20 })
assert(G.ads.bz000001 and G.ads.b0000001 == nil, "replacing your own ad works at the cap")
