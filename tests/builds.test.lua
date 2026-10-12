-- the talent tree as Forever's client gives it: one tree, branches as groups, points spent per branch
C_ClassTalents = { GetActiveConfigID = function() return 7 end }
local spent = { [1001] = 9, [1002] = nil, [1003] = 0 }
C_Traits = {
	GetConfigInfo = function(cfg) return cfg == 7 and { treeIDs = { 70 } } or nil end,
	GetGroupDisplayInfoByTreeID = function(tree) return { { groupID = 1001, displayName = "Armas" }, { groupID = 1002, displayName = "Furia" }, { groupID = 1003, displayName = "Protección" } } end,
	GetGroupCurrencyInfo = function(cfg, ids)
		local out = {}
		for _, id in ipairs(ids) do out[#out + 1] = { traitNodeGroupID = id, currencyInfos = { { spent = spent[id] } } } end
		return out
	end,
}
PlayerUtil = { GetCurrentSpecID = function() return 71 end }
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local C, BU, R, L, B = ns.Comm, ns.Builds, ns.Roster, ns.L, ns.Board
local function last(kind) for i = #STUB.sent, 1, -1 do local k, f = C.Decode(STUB.sent[i].msg); if k == kind then return f end end end
assert(ns.db.settings.shareBuild == true, "shared by default")

-- the wire
assert(C.Validate("tb", {}) and C.Validate("tb", { c = "WARRIOR", s = 71, l = 20, p = "1001:9,1002:0", b = "BkAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA+/" }), "tb format")
assert(not C.Validate("tb", { c = "WARRIOR", s = 71, l = 20, p = "1001:9", b = "bad code!" }) and not C.Validate("tb", { c = "WARRIOR", l = 20, p = "x" }), "shape")

-- mine
local m = BU.Mine()
assert(m.c == "WARRIOR" and m.s == 71 and m.l == 20 and m.p == "1001:9,1002:0,1003:0" and m.b == nil, "points per branch, no code yet: " .. tostring(m.p))
assert(last("tb") and last("tb").p == "1001:9,1002:0,1003:0", "sent with my announce")
-- once the talent window has been open, the game gives the build code
PlayerSpellsFrame = { TalentsFrame = { GetLoadoutExportString = function() return "BkAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA+/" end } }
spent[1001] = 10
STUB.Fire("TRAIT_CONFIG_UPDATED", 7); STUB.Advance(6)
assert(last("tb").p == "1001:10,1002:0,1003:0" and last("tb").b == "BkAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA+/", "a talent change goes out with the code")
local n = #STUB.sent
STUB.Fire("TRAIT_CONFIG_UPDATED", 7); STUB.Advance(6)
local tbs = 0
for i = n + 1, #STUB.sent do if C.Decode(STUB.sent[i].msg) == "tb" then tbs = tbs + 1 end end
assert(tbs == 0, "nothing new, no build sent")
-- a client that cannot export: no code, never an error
PlayerSpellsFrame = { TalentsFrame = { GetLoadoutExportString = function() error("treeInfo nil") end } }
assert(BU.Mine().b == nil, "no code when the game cannot give one")

-- guildmates: only my class is listed
STUB.Receive("LVLM2", C.Encode("hb", { l = 24, z = 1421, c = "WARRIOR" }), "GUILD", "Mario-Testrealm")
STUB.Receive("LVLM2", C.Encode("hb", { l = 22, z = 1421, c = "MAGE" }), "GUILD", "Ana-Testrealm")
STUB.Receive("LVLM2", C.Encode("tb", { c = "WARRIOR", s = 71, l = 24, p = "1001:0,1002:0,1003:15", b = "CODEmario" }), "GUILD", "Mario-Testrealm")
STUB.Receive("LVLM2", C.Encode("tb", { c = "MAGE", s = 62, l = 22, p = "2001:13" }), "GUILD", "Ana-Testrealm")
STUB.Receive("LVLM2", C.Encode("tb", { c = "WARRIOR", s = 71, l = 30, p = "1001:21" }), "GUILD", "Nadie-Testrealm")
local list = BU.List()
assert(#list == 2 and list[1].mine and list[2].name == "Mario", "me first, then my class: " .. #list)
assert(BU.PointsText(list[2]) == "Armas 0 / Furia 0 / Protección 15", "branch names from my own tree: " .. BU.PointsText(list[2]))
assert(BU.PointsText({ p = "1001:3,9999:2" }) == "Armas 3 / #9999 2", "an unknown branch")
assert(BU.Of("Mario").l == 24 and BU.Of("Ana") == nil, "Of: same class only")
STUB.Receive("LVLM2", C.Encode("tb", {}), "GUILD", "Mario-Testrealm")
assert(#BU.List() == 1, "Mario withdrew")
STUB.Receive("LVLM2", C.Encode("tb", { c = "WARRIOR", s = 71, l = 24, p = "1001:0,1002:0,1003:15", b = "CODEmario" }), "GUILD", "Mario-Testrealm")

-- View build: the game's own window, from a click
local ref
assert(BU.Open(BU.Of("Mario")) and (STUB.printed[#STUB.printed] or ""):find("|Htalentbuild:71:24:CODEmario|h", 1, true), "the build link, to click")
local printed = #STUB.printed
assert(not BU.Open({ s = 71, l = 20, p = "1001:1" }) and #STUB.printed == printed, "nothing to open without a code")

-- sharing off withdraws
ns.db.settings.shareBuild = false
BU.SetSharing()
assert(last("tb") and last("tb").p == nil, "withdrawn")
ns.db.settings.shareBuild = true
BU.SetSharing()
assert(last("tb").p ~= nil, "back")
