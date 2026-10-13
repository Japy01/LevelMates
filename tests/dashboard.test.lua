-- Home as a dashboard: four numbers, my character, now, the next runs, quests, who is where, the wall, the MOTD
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(30)
local C, B, L = ns.Comm, ns.Board, ns.L
local function shown(list) local n = 0; for _, it in ipairs(list) do if it:IsShown() then n = n + 1 end end; return n end

B.ShowTab("home")
local DB = ns.Dashboard
assert(DB.frame and DB.frame:IsShown(), "Home shows the dashboard")
for _, r in ipairs(B.rows) do assert(not r.button:IsShown(), "no list rows on Home") end

-- alone
assert(#DB.stats == 4, "four numbers")
for i = 1, 4 do assert((DB.stats[i].value.text or "") ~= "", "stat " .. i .. " set") end
assert(DB.stats[2].value.text == "1", "just me online: " .. tostring(DB.stats[2].value.text))
for _, k in ipairs({ "now", "runs", "quests", "where", "wall" }) do assert(DB[k].hint:IsShown(), k .. ": says what to do") end
assert(DB.invite and DB.invite:IsShown(), "alone: the invite text is reachable")
assert(not DB.motd:IsShown(), "no MOTD strip without one")
assert(#DB.me.gear == 17, "17 gear squares")

-- with data
STUB.guildRoles = { Luis = 2 }; ns.Roster.InvalidateGuildRoster()
STUB.Receive("LVLM2", C.Encode("hb", { l = 22, z = 1421, c = "MAGE" }), "GUILD", "Mario-Testrealm")
STUB.Receive("LVLM2", C.Encode("hb", { l = 21, z = 1412, c = "PRIEST" }), "GUILD", "Ana-Testrealm")
STUB.Receive("LVLM2", C.Encode("help", { t = "Ogro", z = 1412, x = 40, y = 50, id = "h0000001" }), "GUILD", "Ana-Testrealm")
ns.Meetups.AddSample("Mario", 6, 30, { Ana = "H", Luis = "D" })
STUB.Receive("LVLM2", C.Encode("qh", STUB.Rec{ id = "101." .. ns.NameKey("Mario"), q = 101, t = "Quest 101", l = 20, z = "Mulgore", g = 0 }), "GUILD", "Mario-Testrealm")
ns.Feed.AddSample("Mario", "lvl", 22, nil, 5)
STUB.Receive("LVLM2", C.Encode("gmo", STUB.Rec{ id = "motd", n = "Mazmorra el sábado" }), "GUILD", "Luis-Testrealm")
ns.char.gear = { avg = 21, filled = 2, slots = { [1] = { id = 5001, il = 20 }, [5] = { id = 5005, il = 22 } } }
ns.Dirty("board"); STUB.Advance(0.6)

assert(DB.stats[2].value.text == "3", "me and two mates")
assert(DB.stats[3].value.text == "21", "my item level")
assert(shown(DB.where.items) == 2 and not DB.where.hint:IsShown(), "two zones")
assert(shown(DB.now.items) >= 1 and DB.now.items[1].text.text:find("Ogro", 1, true), "the help request is now")
local coming
local was = ns.Help.Coming
ns.Help.Coming = function(id) coming = id end
DB.now.items[1].action.scripts.OnClick(DB.now.items[1].action)
ns.Help.Coming = was
assert(coming == "h0000001", "its button: on my way")
local card = DB.runs.cards[1]
assert(card:IsShown() and #card.slots == 5, "a run with five slots")
local filled = 0
for _, s in ipairs(card.slots) do if not s.empty then filled = filled + 1 end end
assert(filled == 3, "three slots taken: " .. filled)
assert(shown(DB.quests.items) == 1 and DB.quests.items[1].text.text:find("Quest 101", 1, true), "the quest post")
assert(shown(DB.wall.items) >= 1 and not DB.wall.hint:IsShown(), "the wall")
assert(DB.motd:IsShown() and DB.motd.text.text:find("Mazmorra el sábado", 1, true), "the MOTD strip")
local lit = 0
for _, sq in ipairs(DB.me.gear) do if sq.filled then lit = lit + 1 end end
assert(lit == 2, "two gear squares filled")
assert(not DB.invite:IsShown(), "no invite with mates around")

-- other tabs hide it
B.ShowTab("mates")
assert(not DB.frame:IsShown(), "Mates: the list, not the dashboard")
B.ShowTab("home")
assert(DB.frame:IsShown(), "back on Home")

-- groups on Home: mine Now first (with Withdraw), then the next with a time; "Now" keeps help, gifts and the trainer
local DBp = ns.Dashboard
STUB.Receive("LVLM2", C.Encode("lfg", { d = 6, lr = "T", id = "mario777", m = 20 }), "GUILD", "Mario-Testrealm")
STUB.Advance(31)
assert(ns.LFG.Post{ d = 5, role = "T" }, "my Now group")
ns.Dirty("board"); STUB.Advance(0.6)
assert(DBp.groups.title.text == L.DB_GROUPS, "the panel is Groups: " .. tostring(DBp.groups.title.text))
local first = DBp.groups.cards[1]
local withdraw = false
for _, b in ipairs(first.buttons) do if b:IsShown() and b.text == L.GR_WITHDRAW then withdraw = true end end
assert(first:IsShown() and first.group.mine and withdraw, "mine first, with Withdraw")
for _, it in ipairs(DBp.now.items) do assert(not (it:IsShown() and it.text.text:find("Mario: ", 1, true) and it.text.text:find(ns.Dungeons.Name(6), 1, true)), "no group ads in Now") end
