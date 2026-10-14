-- Forever's secret values and protected calls, everywhere the audit of 2026-10-14 found a game value compared,
-- formatted or iterated as if it were plain: one helper set in Core, and no error anywhere when the game hides a value
local SECRET = setmetatable({}, { __tostring = function() return "secret" end })
issecretvalue = function(v) return v == SECRET end
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(30)
local R = ns.Roster

-- the helpers
assert(ns.Plain(SECRET) == nil and ns.Plain(5) == 5 and ns.Plain(false) == false, "Plain")
assert(#ns.List(SECRET) == 0 and #ns.List({ 1, 2 }) == 2 and #ns.List(nil) == 0 and #ns.List("x") == 0, "List")
assert(ns.Same("a", "a") and not ns.Same("a", "b") and not ns.Same(nil, nil) and not ns.Same(SECRET, "a"), "Same")
local realGuildInfo = GetGuildInfo
GetGuildInfo = function() return SECRET end
assert(ns.GuildKey() == "?", "GuildKey on a secret")
GetGuildInfo = function() error("hidden") end
assert(ns.GuildKey() == "?", "GuildKey on an error")
GetGuildInfo = realGuildInfo
assert(ns.GuildKey() == "Test Guild", "GuildKey: " .. tostring(ns.GuildKey()))

-- officer: a secret or failing answer is not an officer, never an error
IsGuildLeader = function() return SECRET end
C_GuildInfo = C_GuildInfo or {}
C_GuildInfo.IsGuildOfficer = function() error("hidden") end
local ok, v = pcall(R.IAmOfficer)
assert(ok and v == false, "IAmOfficer with secrets: false, no error: " .. tostring(v))
IsGuildLeader = function() return true end
assert(R.IAmOfficer() == true, "the leader")

-- an unreadable presence is offline, not online
C_Club.GetClubMembers = function() return { "Tester", "Mario" } end
C_Club.GetMemberInfo = function(_, id) return { name = id, level = 20, presence = id == "Mario" and SECRET or 1, role = 4, guildRankOrder = 4 } end
R.InvalidateGuildRoster(); ns.Members.Invalidate()
local online
for _, m in ipairs(ns.Members.List("all")) do if m.name == "Mario" then online = m.online end end
assert(online == false, "secret presence: offline")

-- loops over secret API results: talents, recipes, bags
C_ClassTalents = { GetActiveConfigID = function() return 1 end }
C_Traits = { GetConfigInfo = function() return { treeIDs = { 1 } } end, GetTreeNodes = function() return SECRET end, GetTreeHash = function() return SECRET end,
	GetGroupDisplayInfoByTreeID = function() return SECRET end, GetNodeInfo = function() return SECRET end }
assert(pcall(ns.Talents.ReadMine), "talents: no error on a secret tree")
C_Traits.GetTreeNodes = function() return { 5 } end
assert(pcall(ns.Talents.ReadMine) and pcall(ns.Talents.MyCode), "talents: a secret node is no error")
C_TradeSkillUI = { IsTradeSkillReady = function() return true end, GetAllRecipeIDs = function() return SECRET end,
	GetBaseProfessionInfo = function() return { professionID = 171, skillLevel = 10, maxSkillLevel = 75 } end, GetRecipeInfo = function() return SECRET end,
	IsTradeSkillLinked = function() error("hidden") end }
ns.char.skills = { [171] = { rank = 10, max = 75 } }
assert(pcall(ns.Recipes.Scan), "recipes: no error on a secret list")
C_Container = { GetContainerNumSlots = function() return 2 end, GetContainerItemInfo = function(_, slot) return slot == 1 and SECRET or { itemID = SECRET, isBound = true } end }
C_Item.GetItemInfo = function() return "x", "|Hitem:7001|h[x]|h", 2, 20, 15, "Armor", "Mail", 1, "INVTYPE_CHEST", 1, 100, 4, 1, 2 end
local okB, bound = pcall(ns.Gifts.Bound, 7001)
assert(okB and bound == false, "a secret bag slot is skipped, no error")

-- a secret unit name, a failing inspect, a failing invite: no error from a click
STUB.units.target = { name = SECRET }
assert(pcall(ns.Gear.InspectUnit, "Pepe"), "secret unit name: no error")
STUB.units.target = { name = "Pepe" }
CanInspect = function() return true end
NotifyInspect = function() error("blocked") end
local okI, did = pcall(ns.Gear.Inspect, "target", "Pepe")
assert(okI and did == false, "a blocked inspect: false, no error")
C_PartyInfo = { InviteUnit = function() error("blocked") end }
assert(pcall(ns.Board.Invite, "Mario"), "a blocked invite: no error")

-- chat from a click: nothing during a chat lockdown; a refused send is no error
InChatMessagingLockdown = function() return true end
STUB.lastChat = nil
assert(ns.SendChat("hola", "WHISPER", nil, "Mario") == false and STUB.lastChat == nil, "lockdown: nothing sent")
InChatMessagingLockdown = function() return false end
assert(ns.SendChat("hola", "WHISPER", nil, "Mario") == true and STUB.lastChat and STUB.lastChat.msg == "hola", "sent")
local realSend = SendChatMessage
SendChatMessage = function() error("blocked") end
assert(ns.SendChat("hola", "WHISPER", nil, "Mario") == false, "a refused send: false, no error")
SendChatMessage = realSend
