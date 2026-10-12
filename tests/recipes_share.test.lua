-- sharing my recipes as personal state; knowing who crafts what; plausibility; forgetting
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(30)
local RC, C = ns.Recipes, ns.Comm
local function last(kind, from) for i = #STUB.sent, (from or 0) + 1, -1 do local k, f = C.Decode(STUB.sent[i].msg); if k == kind then return f end end end
local n = #STUB.sent
STUB.trade = { line = 171, rank = 120, max = 150, recipes = { { id = 2330, item = 118 }, { id = 2331, item = 858 } } }
STUB.Fire("TRADE_SKILL_SHOW"); STUB.Advance(12)
local f = last("rcp", n)
assert(f and f.p == 171 and f.r == 120 and RC.Decode(f.i)[2] == 858, "my Alchemy went out")
-- Mario's, received
STUB.Receive("LVLM2", C.Encode("hb", { l = 20, z = 1412, c = "MAGE" }), "GUILD", "Mario-Testrealm")
STUB.Receive("LVLM2", C.Encode("rcp", { p = 171, r = 120, m = 150, i = RC.Encode({ 858, 929 }) }), "GUILD", "Mario-Testrealm")
local who = RC.WhoCrafts(858)
assert(#who == 2 and who[1].online and RC.Of("Mario")[171], "Mario and I craft it")
local names = {}; for _, w in ipairs(who) do names[w.name] = w end
assert(names.Mario and names.Mario.r == 120 and names[ns.Me()], "both listed")
-- implausible: Artisan rank on a level 12
STUB.Receive("LVLM2", C.Encode("hb", { l = 12, z = 1412, c = "MAGE" }), "GUILD", "Ana-Testrealm")
STUB.Receive("LVLM2", C.Encode("rcp", { p = 164, r = 230, m = 300, i = RC.Encode({ 2862 }) }), "GUILD", "Ana-Testrealm")
assert(#RC.WhoCrafts(2862) == 0, "rank 230 at level 12 ignored")
-- a big list goes in chunks and arrives whole
local big = {}; for i = 1, 300 do big[i] = 1000 + i * 37 end
STUB.trade = { line = 197, rank = 250, max = 300, recipes = {} }
for i, id in ipairs(big) do STUB.trade.recipes[i] = { id = 50000 + i, item = id } end
ns.char.skills = ns.char.skills or {}; ns.char.skills[197] = { rank = 250, max = 300 }; ns.char.skills[171] = { rank = 120, max = 150 }
n = #STUB.sent
STUB.Fire("TRADE_SKILL_SHOW"); STUB.Advance(20)
local chunks = 0
for i = n + 1, #STUB.sent do if (C.Decode(STUB.sent[i].msg)) == "bl" then chunks = chunks + 1 end end
assert(chunks >= 2, "a long list goes in chunks: " .. chunks)
-- forgotten after 60 days
STUB.serverSkew = 61 * 86400
assert(not RC.Of("Mario")[171], "forgotten after 60 days")
STUB.serverSkew = 0
-- sharing off: nothing
ns.db.settings.shareProfessions = false
n = #STUB.sent
STUB.trade = { line = 171, rank = 121, max = 150, recipes = { { id = 2330, item = 118 } , { id = 2331, item = 858 }, { id = 2332, item = 3382 } } }
STUB.Fire("TRADE_SKILL_SHOW"); STUB.Advance(12)
assert(not last("rcp", n), "sharing off: nothing")
