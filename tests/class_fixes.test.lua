C_ClassTalents = { GetActiveConfigID = function() return 7 end }
C_Traits = {
	GetConfigInfo = function() return { treeIDs = { 70 } } end,
	GetGroupDisplayInfoByTreeID = function() return { { groupID = 1001, displayName = "Armas" } } end,
	GetGroupCurrencyInfo = function(cfg, ids) return { { traitNodeGroupID = 1001, currencyInfos = { { spent = 4 } } } } end,
}
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local C, BU, CA, B, L = ns.Comm, ns.Builds, ns.ChatAds, ns.Board, ns.L

-- I1: the code is only mine: not while the talent window shows someone's linked build or another loadout
local frameConfig, inspecting = 7, false
PlayerSpellsFrame = { TalentsFrame = { GetLoadoutExportString = function() return "MINE" end, GetConfigID = function() return frameConfig end, IsInspecting = function() return inspecting end } }
assert(BU.Mine().b == "MINE", "my active loadout")
inspecting = true
assert(BU.Mine().b == nil, "never a linked build I am looking at")
inspecting, frameConfig = false, 8
assert(BU.Mine().b == nil, "never a loadout that is not the active one")
frameConfig = 7

-- I2: a build without level or spec is not stored; the class is what the roster knows
STUB.Receive("LVLM2", C.Encode("hb", { l = 24, z = 1421, c = "WARRIOR" }), "GUILD", "Mario-Testrealm")
STUB.Receive("LVLM2", C.Encode("hb", { l = 22, z = 1421, c = "MAGE" }), "GUILD", "Ana-Testrealm")
STUB.Receive("LVLM2", C.Encode("tb", { c = "WARRIOR", p = "1001:3" }), "GUILD", "Mario-Testrealm")
assert(BU.Of("Mario") == nil, "no level or spec: ignored")
STUB.Receive("LVLM2", C.Encode("tb", { c = "WARRIOR", s = 62, l = 22, p = "2001:9" }), "GUILD", "Ana-Testrealm")
assert(BU.Of("Ana") == nil, "a mage claiming to be a warrior is still a mage")
B.ShowTab("class")   -- and the tab draws
assert(B.tab == "class")

-- I3: View build puts the link in my chat (only on my screen) for the game's own click; no game window from here
local refd
SetItemRef = function() refd = true end
STUB.printed = {}
STUB.Receive("LVLM2", C.Encode("tb", { c = "WARRIOR", s = 71, l = 24, p = "1001:15", b = "CODEmario" }), "GUILD", "Mario-Testrealm")
assert(BU.Open(BU.Of("Mario")), "opened")
assert(not refd, "the addon does not open the game's talent window itself")
assert(STUB.printed[#STUB.printed]:find("|Htalentbuild:71:24:CODEmario|h", 1, true), "the link, for a click: " .. tostring(STUB.printed[#STUB.printed]))

-- I4: guild recruitment, the Spanish word for dungeons and the Dalaran crater are not dungeon ads
assert(CA.Parse("<Los Pepes> recruiting all classes, LF tanks and heals, dm me for inv") == nil, "recruitment spam")
assert(CA.Parse("LFG dm me") == nil, "dm me")
assert(CA.Parse("Hermandad busca gente para hacer las mazmorras") == nil, "the dungeons in general")
assert(CA.Parse("LFG Dalaran quests") == nil and CA.Parse("LFM City of Dalaran") == 10 and CA.Parse("busco grupo ciudad de dalaran") == 10, "the dungeon needs its whole name")
assert(CA.Parse("LFM DM need heal") == 5 and CA.Parse("LFM stockade") == 8, "real ads still count")

-- I5: turning the option off hides what was already read
STUB.Fire("CHAT_MSG_CHANNEL", "LFM DM need heal", "Pepe-Testrealm", "", "2. Trade", "Pepe-Testrealm", "", 0, 2, "Trade")
assert(#CA.For(5) == 1, "read")
ns.db.settings.readChatAds = false
assert(#CA.For(5) == 0, "hidden once off")
