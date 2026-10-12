STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local C, B, R, L = ns.Comm, ns.Board, ns.Roster, ns.L
local function link(id, name) return "|cff1eff00|Hitem:" .. id .. "::::::::20:::::::|h[" .. name .. "]|h|r" end
local today = math.floor(time() / 86400)
STUB.guildMembers = { Tester = true, Mario = true, Jefa = true }
STUB.guildRoles = { Jefa = 2 }
R.InvalidateGuildRoster()
STUB.player.level = 20
STUB.Receive("LVLM2", C.Encode("hb", { l = 18, z = 1421, c = "MAGE" }), "GUILD", "Mario-Testrealm")
STUB.Receive("LVLM2", C.Encode("hb", { l = 40, z = 1412 }), "GUILD", "Jefa-Testrealm")
STUB.Receive("LVLM2", C.Encode("lfg", { d = 5, r = "T", id = "ad01", m = 20, n = "vamos ya" }), "GUILD", "Mario-Testrealm")
STUB.Receive("LVLM2", C.Encode("go", { id = "j1", ty = "lvl", a = 30, s = today, e = today + 3 }), "GUILD", "Jefa-Testrealm")
STUB.Receive("LVLM2", C.Encode("gp", { l = 25, e = today + 2 }), "GUILD", "Mario-Testrealm")
STUB.items[1001] = link(1001, "Cool Sword")
STUB.Receive("LVLM2", C.Encode("wl", { ids = "1001,4242" }), "GUILD", "Mario-Testrealm")
local D = ns.DiscordCopy
assert(D, "module loaded")

-- each tab as Discord text
local t = D.Text("mates")
assert(t:find(L.TAB_MATES, 1, true) and t:find("**Mario**", 1, true) and t:find(string.format(L.DC_LEVEL, 18), 1, true) and t:find("Map 1421", 1, true), "guildmates: " .. t)
assert(t:find("**Tester**", 1, true), "me too")
t = D.Text("lfg")
assert(t:find("**Mario**", 1, true) and t:find(ns.Dungeons.Name(5), 1, true) and t:find(":shield:", 1, true) and t:find("vamos ya", 1, true), "dungeons: " .. t)
t = D.Text("goals")
assert(t:find(ns.Goals.Text(ns.Goals.Get("j1")), 1, true) and t:find(ns.Goals.ProgressText(ns.Goals.Get("j1")), 1, true), "guild goals: " .. t)
assert(t:find(L.DC_PERSONAL, 1, true) and t:find("Mario", 1, true) and t:find(string.format(L.MYGOAL_TEXT, 25), 1, true), "personal goals")
t = D.Text("wishes")
assert(t:find("**Mario**", 1, true) and t:find("[Cool Sword]", 1, true) and t:find(string.format(L.WISH_UNKNOWN, 4242), 1, true), "wishes: " .. t)
assert(not t:find("|H", 1, true) and not t:find("|c", 1, true), "no game link codes in Discord")

-- journal: the last 7 days only
local J = ns.Journal
J.Add("level", { level = 19 }); J.Add("level", { level = 20 })
J.Add("quest", { id = 1, name = "A" }); J.Add("quest", { id = 2, name = "B" })
J.Add("dungeon", { name = "Ragefire Chasm", mates = { "Mario" } })
J.Add("item", { link = link(2001, "Green Boots"), q = 2 })
J.Add("death", { level = 20 })
local old = J.Add("quest", { id = 3, name = "Old" }); old.t = time() - 8 * 86400
t = D.Text("journal")
assert(t:find(string.format(L.DC_J_LEVELS, 18, 20), 1, true) and t:find(string.format(L.DC_J_QUESTS, 2), 1, true), "levels and quests this week: " .. t)
assert(t:find("Ragefire Chasm", 1, true) and t:find("[Green Boots]", 1, true) and t:find(string.format(L.DC_J_DEATHS, 1), 1, true), "dungeons, items, deaths")

-- at most one Discord message
for i = 1, 80 do STUB.guildMembers["Relleno" .. i] = true end
R.InvalidateGuildRoster()
for i = 1, 80 do STUB.Receive("LVLM2", C.Encode("hb", { l = 10, z = 1421 }), "GUILD", "Relleno" .. i .. "-Testrealm") end
t = D.Text("mates")
assert(#t <= 2000 and t:find(L.DC_MORE:gsub("%%d.*", ""), 1, true), "cut to 2000 with '…and N more': " .. #t)

-- the button: the current tab's text, selected, nothing sent
local sent = #STUB.sent
B.ShowTab("goals")
assert(B.discordButton:IsShown(), "on every tab")
B.discordButton.scripts.OnClick(B.discordButton)
assert(D.frame:IsShown() and D.box:GetText() == D.Text("goals") and D.box.highlighted and D.box.focused, "the goals text, selected for Ctrl+C")
assert(#STUB.sent == sent, "nothing is sent")
D.box.scripts.OnEscapePressed(D.box)
assert(not D.frame:IsShown(), "Escape closes it")
