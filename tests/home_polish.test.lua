-- the design pass of 2026-10-15: Guildmates lists who was seen today when offline (and offers the invite when nobody
-- else has the addon); the wall writes two lines per entry; Now shows the trainer's spells one per line with an icon
-- and the invite lives in "Who is where"; the four numbers say one thing each; Home's heading has no rested text;
-- my panel sums up my achievements, guild firsts and goal
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(30)
local B, C, L, R, DB = ns.Board, ns.Comm, ns.L, ns.Roster, nil
STUB.player.level = 20; STUB.player.rested = 450

-- 1: Mario was online a while ago; he is remembered and listed under "Seen today", grey, with when
STUB.Receive("LVLM2", C.Encode("hb", { l = 24, z = 1421, c = "MAGE" }), "GUILD", "Mario-Testrealm")
STUB.Advance(160)   -- past the roster's expiry (checked every 30 s): offline
assert(#R.List() == 0, "Mario expired")
local seen = R.Seen()
assert(#seen == 1 and seen[1].name == "Mario" and seen[1].level == 24 and seen[1].class == "MAGE", "remembered: " .. #seen)
B.Toggle(); B.ShowTab("mates")
local header, row
for _, r in ipairs(B.rows) do
	if r.button:IsShown() and r.name.text and r.name.text:find(L.SEEN_TODAY, 1, true) then header = r end
	if r.button:IsShown() and r.name.text == "Mario" then row = r end
end
assert(header and header.button.tall, "a section header: Seen today")
assert(row and row.zone.text == string.format(L.SEEN_AGO, ns.Journal.Short(130)) and tostring(row.level.text) == "24" and row.button.mate == "Mario", "Mario's row, when he was seen: " .. tostring(row and row.zone.text))
assert(row.icon.desaturated, "greyed")
assert(not B.inviteButton:IsShown(), "someone has the addon: no invite here")
-- nobody else has the addon: the invite under the empty line
ns.db.lastSeen = nil
B.Refresh()
assert(B.inviteButton:IsShown() and B.frame.empty.text == L.EMPTY, "alone: the invite to copy")
B.inviteButton.scripts.OnClick(B.inviteButton)
assert(ns.DiscordCopy.frame and ns.DiscordCopy.frame:IsShown(), "copy box")
ns.DiscordCopy.frame:Hide()

-- 5: Home's heading: no rested text (it is in my panel); Guildmates still has it
B.ShowTab("home")
DB = ns.Dashboard
assert(B.restedText.text == "", "no rested beside the heading on Home")
B.ShowTab("mates")
assert(B.restedText.text:find(string.format(L.RESTED_MINE, 45), 1, true), "rested on Guildmates")
B.ShowTab("home")

-- 3: the trainer's spells, one per line with an icon; the invite in "Who is where" when alone
ns.char.trainer = { seen = true, spells = {}, due = { { name = "Aura de resistencia al Fuego", rank = "Rango 2", level = 18 }, { name = "Juicio", level = 20 } } }
B.Refresh()
local texts = {}
for _, it in ipairs(DB.now.items) do if it:IsShown() then texts[#texts + 1] = it.text.text; assert(it.icon and it.icon:IsShown(), "an icon on the line") end end
assert(#texts == 2 and texts[1]:find("Aura de resistencia al Fuego", 1, true) and texts[1]:find("Rango 2", 1, true) and texts[2]:find("Juicio", 1, true), "spells one per line: " .. table.concat(texts, " | "))
assert(DB.invite:GetParent() == DB.where and DB.invite:IsShown(), "the invite in Who is where, alone")
assert(DB.where.hint.text == L.HOME_ALONE and DB.now.hint.text == L.DB_HINT_NOW, "alone: the explanation under Who is where, Now keeps its own")

-- 4: the four numbers: the challenge says "0/9" and "helps this week", not "9 helps" twice
local ch = ns.Points.Challenge()
assert(DB.stats[4].value.text == ch.have .. "/" .. ch.goal and DB.stats[4].label.text == L["CHALLENGE_WEEK_" .. ch.cat] and DB.stats[4].sub.text == "", "challenge tile: " .. tostring(DB.stats[4].label.text))
assert(DB.stats[1].label.text == L.DB_STAT_LEVEL and DB.stats[1].sub.text ~= "", "level tile keeps its points")

-- 6: my panel: achievements, guild firsts and my goal
ns.char.ach = { lvl10 = time(), lvl20 = time() }
ns.char.goal = { l = 30, e = time() + 86400 * 5 }
STUB.Fire("PLAYER_LEVEL_UP", 20); STUB.Advance(2)   -- a guild first claimed (level 20)
B.Refresh()
assert(DB.me.ach.text == string.format(L.DB_ACH, 2, #ns.Achievements.LIST) and DB.me.firsts.text == string.format(L.DB_FIRSTS, 1), "achievements and firsts: " .. tostring(DB.me.ach.text))
assert(DB.me.goal.text == string.format(L.DB_GOAL, 30) and DB.me.goal:IsShown(), "my goal")
ns.char.goal = nil
B.Refresh()
assert(not DB.me.goal:IsShown(), "no goal: the line goes")

-- 2: the wall: the whole text on one line, the time small under it
ns.Feed.AddSample("Mario", "lvl", 22, nil, 5)
ns.Feed.AddSample("Mario", "dth", 22, "Minas", 6)
B.Refresh()
local w1   -- my own level-up and first are newer: find Mario's entry
for _, it in ipairs(DB.wall.items) do if it:IsShown() and it.text.text:find("Mario", 1, true) and not w1 then w1 = it end end
assert(w1 and w1.right.text == string.format(L.FEED_AGO, ns.Journal.Short(300)), "wall: full text and a short time: " .. tostring(w1 and w1.right.text))
assert(w1:GetHeight() >= 28, "two lines tall")
assert(ns.Journal.Short(45) == L.J_DUR_LT and ns.Journal.Short(300) == string.format(L.J_DUR_M, 5) and ns.Journal.Short(3600 * 10 + 60 * 34) == string.format(L.J_DUR_H, 10) and ns.Journal.Short(86400 * 2 + 3600) == string.format(L.J_DUR_D, 2), "short durations")
