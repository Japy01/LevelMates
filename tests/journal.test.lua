STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
ns.db.settings.shareFeed = false   -- the wall (fe) has its own test
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local J, L = ns.Journal, ns.L
local sent0 = #STUB.sent
assert(type(ns.char.journal) == "table" and J.Count() == 0, "empty journal per character")

-- level-ups with the time since the previous one
STUB.player.level = 21; STUB.Fire("PLAYER_LEVEL_UP", 21)
local e = J.List("all", "")[1]
assert(e.k == "level" and e.level == 21 and e.took == nil and e.zone == STUB.player.zone, "first level entry")
STUB.Advance(2 * 3600 + 600)
STUB.player.level = 22; STUB.Fire("PLAYER_LEVEL_UP", 22)
e = J.List("all", "")[1]
assert(e.level == 22 and e.took == 2 * 3600 + 600, "time since the previous level: " .. tostring(e.took))
assert(J.Text(e) == string.format(L.J_LEVEL, 22) .. string.format(L.J_TOOK, string.format(L.J_DUR_HM, 2, 10), 21), "text: " .. J.Text(e))

-- quest and death
STUB.Fire("QUEST_TURNED_IN", 1098, 450, 0)
e = J.List("all", "")[1]
assert(e.k == "quest" and e.name == "Quest 1098" and J.Text(e) == string.format(L.J_QUEST, "Quest 1098"), "quest entry")
STUB.Fire("PLAYER_DEAD")
e = J.List("all", "")[1]
assert(e.k == "death" and e.level == 22 and J.Text(e) == string.format(L.J_DEATH, 22), "death entry")

-- filter and search; formatting helpers
assert(#J.List("level", "") == 2 and #J.List("quest", "") == 1 and #J.List("death", "") == 1, "filter by kind")
assert(#J.List("all", "1098") == 1 and #J.List("all", "zzz") == 0, "search the text")
assert(J.Duration(30) == L.J_DUR_LT and J.Duration(35 * 60) == string.format(L.J_DUR_M, 35), "durations")
assert(J.FilterName("all") == L.J_FILTER_ALL and J.FilterName("quest") == L.J_FILTER_QUEST, "filter names")
assert(type(J.Color(e)) == "table" and J.When(e) == date("%d/%m %H:%M", e.t), "colour and date")

-- cap of 1000, oldest dropped
for i = 1, 1005 do J.Add("quest", { id = i, name = "Q" .. i }) end
assert(J.Count() == 1000, "capped at 1000: " .. J.Count())
local all = J.List("all", "")
assert(all[1].name == "Q1005" and all[1000].name == "Q6", "oldest dropped: " .. tostring(all[1000].name))

-- remove some, then clear
J.RemoveWhere(function(x) return x.id and x.id <= 10 end)
assert(J.Count() == 995, "RemoveWhere: " .. J.Count())
J.Clear()
assert(J.Count() == 0, "cleared")

-- the journal never sends anything
for i = sent0 + 1, #STUB.sent do
	local k = ns.Comm.Decode(STUB.sent[i].msg)
	assert(k == "hb" or k == "q" or k == "ping" or k == "pt" or k == "ac" or k == "fe", "only the roster's own messages went out, got " .. tostring(k))
end
