STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local C, F, J, B, R, L = ns.Comm, ns.Feed, ns.Journal, ns.Board, ns.Roster, ns.L
local function last(kind) for i = #STUB.sent, 1, -1 do local k, f = C.Decode(STUB.sent[i].msg); if k == kind then return f, i end end end
local function count(kind, from) local n = 0; for i = (from or 0) + 1, #STUB.sent do if (C.Decode(STUB.sent[i].msg)) == kind then n = n + 1 end end; return n end
local function link(id, name) return "|cff0070dd|Hitem:" .. id .. "::::::::20:::::::|h[" .. name .. "]|h|r" end
STUB.guildMembers = { Tester = true, Mario = true, Ana = true, Luis = true }
R.InvalidateGuildRoster()
assert(ns.db.settings.shareFeed == true and ns.db.settings.feedLoot == true, "defaults on")
local now = F.Now()
assert(C.Validate("fe", { k = "lvl", a = 30, t = now }) and C.Validate("fe", { k = "dun", a = 0, b = "Minas · Ana", t = now }), "fe format")
assert(C.Validate("fe", { k = "gol", a = 1, t = now }) == false and C.Validate("fe", { k = "lvl", a = 30 }) == false, "fe kinds and fields")

-- what I live goes out
J.Add("level", { level = 21 })
local f = last("fe")
assert(f and f.k == "lvl" and f.a == 21, "my level-up")
assert(F.List()[1].who == "Tester" and F.Text(F.List()[1]) == string.format(L.FEED_LVL, 21), "on my wall too")
local n = #STUB.sent
J.Add("dungeon", { name = "Ragefire Chasm", mates = {} })
assert(count("fe", n) == 0, "a dungeon alone: nothing")
J.Add("dungeon", { name = "Ragefire Chasm", mates = { "Mario" } })
assert(last("fe").k == "dun" and last("fe").b == "Ragefire Chasm · Mario", "a dungeon with guildmates")
J.Add("item", { link = link(9001, "Blue Sword"), q = 3 })
assert(last("fe").k == "itm" and last("fe").a == 9001, "rare loot")
n = #STUB.sent
J.Add("item", { link = link(9002, "Green Boots"), q = 2 })
ns.db.settings.feedLoot = false
J.Add("item", { link = link(9003, "Blue Hat"), q = 3 })
ns.db.settings.feedLoot = true
assert(count("fe", n) == 0, "green loot, or loot sharing off: nothing")
ns.Fire("LM_MYGOAL_REACHED", 25)
assert(last("fe").k == "pgl" and last("fe").a == 25, "personal goal reached")

-- guildmates'
STUB.Receive("LVLM", C.Encode("hb", { l = 29, z = 1421 }), "GUILD", "Mario-Testrealm")
STUB.Receive("LVLM", C.Encode("fe", { k = "lvl", a = 29, t = now - 5 }), "GUILD", "Mario-Testrealm")
STUB.Receive("LVLM", C.Encode("fe", { k = "lvl", a = 29, t = now - 5 }), "GUILD", "Mario-Testrealm")
STUB.Receive("LVLM", C.Encode("fe", { k = "lvl", a = 50, t = now }), "GUILD", "Nadie-Testrealm")
STUB.Receive("LVLM", C.Encode("fe", { k = "lvl", a = 31, t = now + 60 }), "GUILD", "Mario-Testrealm")
local mario = 0
for _, e in ipairs(F.List()) do if e.who == "Mario" then mario = mario + 1 end end
assert(mario == 1, "once, from the roster, not from the future")
STUB.Receive("LVLM", C.Encode("hb", { l = 30, z = 1421 }), "GUILD", "Mario-Testrealm")
STUB.Receive("LVLM", C.Encode("fe", { k = "lvl", a = 30, t = now }), "GUILD", "Mario-Testrealm")
mario = 0
for _, e in ipairs(F.List()) do if e.who == "Mario" and e.a == 30 then mario = mario + 1 end end
assert(mario == 1, "a level-up seen by heartbeat and by message: once")
ns.Fire("LM_GOAL_REACHED", { ty = "lvl", a = 20 })
local gol
for _, e in ipairs(F.List()) do if e.k == "gol" then gol = e end end
assert(gol and F.Who(gol) == L.FEED_GUILD and F.Text(gol) == string.format(L.FEED_GOL, ns.Goals.Text({ ty = "lvl", a = 20 })), "guild goal reached")
assert(#F.List("mario") >= 1 and #F.List("zzz") == 0, "search")

-- a newcomer gets my last 24 hours, at most five
n = #STUB.sent
STUB.Receive("LVLM", C.Encode("ping", {}), "GUILD", "Luis-Testrealm"); STUB.Advance(6)
local mine = count("fe", n)
local resent = 0   -- achievements may post to the wall at the same moment: only the re-sent entries count here
for i = n + 1, #STUB.sent do local k, f = C.Decode(STUB.sent[i].msg); if k == "fe" and f.k ~= "ach" then resent = resent + 1 end end
assert(resent >= 1 and resent <= F.RESEND, "re-sent to a newcomer: " .. resent)

-- sharing off: on my wall, not sent
ns.db.settings.shareFeed = false
n = #STUB.sent
J.Add("level", { level = 22 })
assert(count("fe", n) == 0 and F.List()[1].a == 22, "kept locally only")
ns.db.settings.shareFeed = true

-- older than 7 days: gone
F.Add({ who = "Ana", k = "lvl", a = 10, t = now - 8 * 1440 })
for _, e in ipairs(F.List()) do assert(not (e.who == "Ana" and e.a == 10), "pruned") end

-- the tab
B.ShowTab("feed")
assert(B.subs.feed.lit and B.frame.selectedTab == 4 and B.heading.text == L.HEAD_FEED, "the Guild tab's wall")
local rows = {}
for i = 1, #B.rows do if B.rows[i].button:IsShown() then rows[#rows + 1] = B.rows[i] end end
assert(#rows == #F.List() and rows[1].zone.text == F.Text(F.List()[1]) and rows[1].xph.text == F.Ago(F.List()[1]), "rows: who, what, when")
for _, r in ipairs(rows) do
	if r.button.feedItem == 9001 then r.button.scripts.OnEnter(r.button); assert(GameTooltip.link == "item:9001", "item card on hover") end
end
assert(ns.DiscordCopy.Text("feed"):find(L.TAB_FEED, 1, true), "Copy for Discord")
