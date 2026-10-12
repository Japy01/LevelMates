-- project 4 final review fixes
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(30)
local RC, C = ns.Recipes, ns.Comm
local function count(kind, from) local n = 0; for i = from + 1, #STUB.sent do if (C.Decode(STUB.sent[i].msg)) == kind then n = n + 1 end end; return n end
-- 1: an expired entry while the index rebuilds: no error
for _, n in ipairs({ "Mario", "Ana" }) do
	STUB.Receive("LVLM2", C.Encode("hb", { l = 30, z = 1412, c = "MAGE" }), "GUILD", n .. "-Testrealm")
	STUB.Receive("LVLM2", C.Encode("rcp", { p = 171, r = 120, m = 150, i = RC.Encode({ 858 }) }), "GUILD", n .. "-Testrealm")
end
ns.db.recipes["Test Guild"]["Mario"][171].t = GetServerTime() - 61 * 86400
STUB.Receive("LVLM2", C.Encode("rcp", { p = 164, r = 100, m = 150, i = RC.Encode({ 2862 }) }), "GUILD", "Ana-Testrealm")
local ok, who = pcall(RC.WhoCrafts, 858)
assert(ok and #who == 1 and who[1].name == "Ana", "1: rebuilt without error, Mario forgotten: " .. tostring(who))
-- 2: a rank-only change sends nothing new; newcomers get it at most every 10 minutes
STUB.trade = { line = 171, rank = 120, max = 150, recipes = { { id = 2331, item = 858 } } }
STUB.Fire("TRADE_SKILL_SHOW"); STUB.Advance(12)
local n = #STUB.sent
STUB.trade.rank = 121
STUB.Fire("TRADE_SKILL_LIST_UPDATE"); STUB.Advance(12)
assert(count("rcp", n) == 0, "2: rank only: nothing")
n = #STUB.sent
STUB.Receive("LVLM2", C.Encode("hi", { s = "" }), "GUILD", "Luis-Testrealm"); STUB.Advance(10)
assert(count("rcp", n) == 0, "2: a hello just after sharing: no resend")
STUB.Advance(601)
n = #STUB.sent
STUB.Receive("LVLM2", C.Encode("hi", { s = "" }), "GUILD", "Luis-Testrealm"); STUB.Advance(10)
assert(count("rcp", n) == 1, "2: ten minutes later: resent")
-- 3: no GetRecipeOutputItemData: the item comes from the recipe's item link
local real = C_TradeSkillUI.GetRecipeOutputItemData
C_TradeSkillUI.GetRecipeOutputItemData = nil
C_TradeSkillUI.GetRecipeItemLink = function(id) if id == 2340 then return "|Hitem:3530::::|h[Wool Bandage]|h" end end
ns.char.skills = ns.char.skills or {}; ns.char.skills[129] = { rank = 80, max = 150 }
STUB.trade = { line = 129, rank = 80, max = 150, recipes = { { id = 2340, item = 3530 } } }
STUB.Fire("TRADE_SKILL_SHOW"); STUB.Advance(3)
assert(RC.Mine()[129] and RC.Mine()[129].items[1] == 3530, "3: the item from its link")
C_TradeSkillUI.GetRecipeOutputItemData = real
-- 4: a modern profession id maps to its base line through parentProfessionID
local realInfo = C_TradeSkillUI.GetBaseProfessionInfo
C_TradeSkillUI.GetBaseProfessionInfo = function() return { professionID = 2485, parentProfessionID = 164, skillLevel = 100, maxSkillLevel = 150 } end
ns.char.skills[164] = { rank = 100, max = 150 }
STUB.trade = { line = 2485, rank = 100, max = 150, recipes = { { id = 2660, item = 2862 } } }
STUB.Fire("TRADE_SKILL_SHOW"); STUB.Advance(3)
assert(RC.Mine()[164] and RC.Mine()[164].items[1] == 2862, "4: stored as Blacksmithing")
C_TradeSkillUI.GetBaseProfessionInfo = realInfo
-- 5: a long list (700) still travels
local big = {}; for i = 1, 700 do big[i] = 2000 + i * 61 end
assert(C.Validate("rcp", { p = 197, r = 300, m = 300, i = RC.Encode(big) }), "5: 700 recipes fit the field")
