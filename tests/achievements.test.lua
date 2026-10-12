STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
local AC, C, L, J = ns.Achievements, ns.Comm, ns.L, ns.Journal
local function last(kind) for i = #STUB.sent, 1, -1 do local k, f = C.Decode(STUB.sent[i].msg); if k == kind then return f end end end
assert(ns.db.settings.shareAchievements == true, "on by default")
assert(#AC.LIST >= 20, "about twenty")
assert(C.Validate("ac", { ids = "1,2,7" }) and C.Validate("fe", STUB.Rec{ k = "ach", a = 3, t = 1 }), "wire")

-- from the journal already there: not from zero (level 20 → levels 10 and 20)
J.Add("dungeon", { name = "Deadmines", mates = { "Mario" } })
for i = 1, 3 do J.Add("death", { level = 12 }) end
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
assert(AC.Has("lvl10") and AC.Has("lvl20") and not AC.Has("lvl30"), "levels counted at once")
assert(AC.Has("dun1") and AC.Progress("dun10") == 1, "the dungeon in the journal counts")
assert(AC.Progress("dead10") == 3, "deaths too")

-- earning one: a notice, the wall, shared
STUB.printed = {}
ns.Fire("LM_HELP_GIVEN", "h1")
assert(AC.Has("help1"), "first help")
local told
for _, line in ipairs(STUB.printed) do if line:find(AC.Name("help1"), 1, true) then told = true end end
assert(told, "a notice")
STUB.Advance(4)   -- the wall entry follows a moment later
local wall = ns.Feed.List()[1]
assert(wall.k == "ach" and ns.Feed.Text(wall):find(AC.Name("help1"), 1, true), "on the wall: " .. ns.Feed.Text(wall))
STUB.Advance(5)
assert(last("fe") and last("fe").k == "ach", "the wall entry goes out")
assert(last("ac") and tostring(last("ac").ids):find(tostring(AC.Index("help1")), 1, true), "my list shared")
-- once only
STUB.printed = {}
ns.Fire("LM_HELP_GIVEN", "h2")
for _, line in ipairs(STUB.printed) do assert(not line:find(AC.Name("help1"), 1, true), "never twice") end
assert(AC.Progress("help10") == 2, "counting on")

-- a level-up earns its own
STUB.player.level = 30; STUB.Fire("PLAYER_LEVEL_UP", 30)
assert(AC.Has("lvl30"), "level 30")

-- guildmates': on their card
STUB.Receive("LVLM2", C.Encode("hb", { l = 24, z = 1421 }), "GUILD", "Mario-Testrealm")
STUB.Receive("LVLM2", C.Encode("ac", { ids = AC.Index("lvl10") .. "," .. AC.Index("dun1") }), "GUILD", "Mario-Testrealm")
assert(#AC.Of("Mario") == 2, "Mario's two")
local card = table.concat(ns.MateCard.Lines("Mario"), "\n")
assert(card:find(string.format(L.CARD_ACH, 2), 1, true), "on his card: " .. card)

-- the Journal tab: an Achievements view
local B = ns.Board
B.Toggle(); B.ShowTab("journal")
assert(B.journalAchButton and B.journalAchButton:IsShown(), "a button for them")
B.journalAchButton.scripts.OnClick(B.journalAchButton)
local rows, got, pending = 0, 0, 0
for _, r in ipairs(B.rows) do
	local a = r.button:IsShown() and r.button.ach
	if a then rows = rows + 1; if AC.Has(a.id) then got = got + 1 else pending = pending + 1 end end
end
assert(rows >= 10 and got >= 5 and pending >= 1, "achieved and pending listed: " .. rows .. " " .. got .. " " .. pending)

-- sharing off: no wall entry, list withdrawn
ns.db.settings.shareAchievements = false
AC.SetSharing()
assert(last("ac").ids == nil, "withdrawn")

-- the backfill counts the real journal, not the /lm sim samples (and runs again for those counted wrong before)
ns.char.journal = {
	{ k = "dungeon", mates = { "Mario" }, t = 1 }, { k = "quest", t = 1 }, { k = "quest", t = 1 },
	{ k = "quest", t = 1, sim = true }, { k = "death", t = 1 },
}
ns.char.stats, ns.char.statsInit = {}, true   -- counted by the old, wrong backfill
ns.Fire("LM_LOADED")
local s = ns.char.stats
assert(s.d == 1 and s.q == 2 and s.dead == 1, "real entries only: " .. tostring(s.d) .. "/" .. tostring(s.q) .. "/" .. tostring(s.dead))
ns.Fire("LM_LOADED")
assert(ns.char.stats.q == 2, "once")
