-- wrong recipe data cleans itself: mine against the game's own list of my professions; theirs against the professions
-- they say they have (pf, their whole list); an impossible rank wipes what was kept for that profession
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(30)
local RC, C = ns.Recipes, ns.Comm
local function count(kind, from) local n = 0; for i = from + 1, #STUB.sent do if (C.Decode(STUB.sent[i].msg)) == kind then n = n + 1 end end; return n end

-- mine: Enchanting (333) read from someone else's window long ago; Alchemy kept at a rank above my real one
local mine = RC.Mine()
mine[171] = { r = 120, m = 150, items = { 858 }, spells = {}, t = time() }
mine[333] = { r = 225, m = 300, items = { 11122 }, spells = {}, t = time() }
mine[164] = { r = 200, m = 225, items = { 2862 }, spells = {}, t = time() }
ns.char.skills = { [171] = { rank = 125, max = 150 }, [164] = { rank = 90, max = 150 } }
local n = #STUB.sent
ns.Fire("LM_SKILLS_CHANGED"); STUB.Advance(12)
assert(mine[171] and mine[171].r == 125, "a real one kept, its rank brought up to date")
assert(mine[333] == nil, "a profession I don't have: dropped")
assert(mine[164] == nil, "kept above my real rank (someone else's window): dropped")
assert(count("rcp", n) >= 1, "the corrected list shared again")
-- no skills known yet (login, before the skill list): nothing touched
ns.char.skills = nil
mine[202] = { r = 50, m = 75, items = { 4357 }, spells = {}, t = time() }
ns.Fire("LM_SKILLS_CHANGED"); STUB.Advance(12)
assert(mine[202], "no list of mine yet: nothing dropped")

-- theirs: Mario's recipes for professions his own list no longer has, or at a rank above his real one, go
STUB.Receive("LVLM2", C.Encode("hb", { l = 40, z = 1412, c = "MAGE" }), "GUILD", "Mario-Testrealm")
STUB.Receive("LVLM2", C.Encode("rcp", { p = 171, r = 120, m = 150, i = RC.Encode({ 858 }) }), "GUILD", "Mario-Testrealm")
STUB.Receive("LVLM2", C.Encode("rcp", { p = 333, r = 200, m = 225, i = RC.Encode({ 11122 }) }), "GUILD", "Mario-Testrealm")
STUB.Receive("LVLM2", C.Encode("rcp", { p = 164, r = 150, m = 225, i = RC.Encode({ 2862 }) }), "GUILD", "Mario-Testrealm")
assert(RC.Of("Mario")[333] and RC.Of("Mario")[164], "kept at first")
STUB.Receive("LVLM2", C.Encode("pf", { p = "171:130:150,164:100:150" }), "GUILD", "Mario-Testrealm")
local his = RC.Of("Mario")
assert(his[171] and his[333] == nil and his[164] == nil, "dropped: not his any more, and a rank above his real one")

-- an impossible rank for the level wipes what was kept for that profession
STUB.Receive("LVLM2", C.Encode("hb", { l = 12, z = 1412, c = "MAGE" }), "GUILD", "Ana-Testrealm")
STUB.Receive("LVLM2", C.Encode("rcp", { p = 171, r = 60, m = 75, i = RC.Encode({ 858 }) }), "GUILD", "Ana-Testrealm")
assert(RC.Of("Ana")[171], "hers, plausible")
STUB.Receive("LVLM2", C.Encode("rcp", { p = 171, r = 250, m = 300, i = RC.Encode({ 858, 9999 }) }), "GUILD", "Ana-Testrealm")
assert(RC.Of("Ana")[171] == nil, "an impossible rank: what we had for it goes too")

-- a window whose rank is not mine (someone else's, though the game's checks said nothing): not read
ns.char.skills = { [171] = { rank = 125, max = 150 } }
local before = RC.Mine()[171] and #RC.Mine()[171].items
STUB.trade = { line = 171, rank = 225, max = 300, recipes = { { id = 1, item = 858 }, { id = 2, item = 13444 } } }
STUB.Fire("TRADE_SKILL_SHOW"); STUB.Advance(3)
assert(#RC.Mine()[171].items == before, "not my rank: not read")
STUB.trade.rank = 126
STUB.Fire("TRADE_SKILL_LIST_UPDATE"); STUB.Advance(3)
assert(#RC.Mine()[171].items == 2, "my rank (give or take a bonus): read")
