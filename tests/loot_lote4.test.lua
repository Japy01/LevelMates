-- Lote 4 (2026-10-18): reserves pasted by an officer as a list, disputed and over-limit ones visible to all, the
-- card says who reserved an item; +1 counts a player's alts and takes officer adjustments; a wish carries a
-- priority (its own kind, old clients ignore it); "equipped" seen from shared gear; an award in my bags is
-- offered in the trade window when I trade with its receiver; /lm sim botin opens a sample session
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.guildRoles = { Tester = 2, Ana = 2, Mario = 4, Luis = 4 }
STUB.guildMembers = { Tester = true, Ana = true, Mario = true, Luis = true, Marito = true }
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(30)
local LT, LS, LC, LR, C, L, R, B, W, S = ns.Loot, ns.LootSession, ns.LootCard, ns.LootRaid, ns.Comm, ns.L, ns.Roster, ns.Board, ns.Wishlist, ns.Sync
R.InvalidateGuildRoster()
for i = 9001, 9005 do STUB.items[i] = "|cffa335ee|Hitem:" .. i .. "::::::::60:::::::|h[Objeto " .. i .. "]|h|r" end
local function sentAfter(n, kind, chatType) local out = {}; for i = n + 1, #STUB.sent do local k, f = C.Decode(STUB.sent[i].msg); if k == kind and (not chatType or STUB.sent[i].chatType == chatType) then f._to = STUB.sent[i].target; out[#out + 1] = f end end; return out end
STUB.iAmOfficer = true
assert(LR.SetRules({ reserves = 1 }), "one reserve each")

-- 1. an officer pastes the list; disputed and over-limit reserves show for everyone
LT.OpenReserves()
local n = #STUB.sent
assert(LT.SetReserveList("Mario: " .. STUB.items[9001] .. ", " .. STUB.items[9002] .. "\nLuis: 9001") == 2, "two people listed")
assert(#sentAfter(n, "lrl") == 2, "two officer records")
local rs = LT.Reserves()
assert(#rs == 3, "three reserves: " .. #rs)
local byKey = {}
for _, r in ipairs(rs) do byKey[r.name .. r.i] = r end
assert(byKey.Mario9001 and byKey.Luis9001 and byKey.Mario9001.disputed and byKey.Luis9001.disputed, "the same item by two: disputed")
assert(byKey.Mario9002 and byKey.Mario9002.over and not byKey.Mario9001.over, "Mario's second reserve is over the limit of one")
B.Toggle(); B.ShowTab("loot"); B.lootView = "reserves"; B.Refresh()
local marked = 0
for _, r in ipairs(B.rows) do if r.button:IsShown() and (r.group.text == L.LOOT_DISPUTED or r.group.text == L.LOOT_OVER_LIMIT) then marked = marked + 1 end end
assert(marked == 3, "the three marked on the page: " .. marked)
-- the card says who reserved the item
STUB.Receive("LVLM2", C.Encode("ls", { s = "sAna1", m = "council", i = "9001,9003", b = 0, t = 0 }), "PARTY", "Ana-Testrealm")
local function cardRow(item) for _, r in ipairs(LC.Rows()) do if r.item == item then return r end end end
assert(cardRow(9001).worn.text:find("Luis", 1, true) and cardRow(9001).worn.text:find("Mario", 1, true) and not cardRow(9003).worn.text:find("Mario", 1, true), "reservers on the card: " .. tostring(cardRow(9001).worn.text))
STUB.Receive("LVLM2", C.Encode("lc", { s = "sAna1" }), "PARTY", "Ana-Testrealm")

-- 2. +1 with alts and adjustments: Marito is Mario's alt; an epic to Marito counts for Mario
STUB.Receive("LVLM2", C.Encode("hb", { l = 40, z = 1421, c = "MAGE" }), "GUILD", "Mario-Testrealm")   -- alts are taken from people the roster knows
STUB.Receive("LVLM2", C.Encode("al", { n = "Marito" }), "GUILD", "Mario-Testrealm")
local a1 = LT.Award(9001, "Marito", { proof = "manual" }); LT.Confirm(a1, "manual")
local a2 = LT.Award(9002, "Mario", { proof = "manual" }); LT.Confirm(a2, "manual")
assert(LT.PlusOne("Mario") == 2 and LT.PlusOne("Marito") == 2, "the family's +1, both ways: " .. LT.PlusOne("Mario") .. "/" .. LT.PlusOne("Marito"))
assert(LT.AdjustPlusOne("Mario", -1, "cambio de main"), "an adjustment by an officer")
assert(LT.PlusOne("Mario") == 1, "adjusted: " .. LT.PlusOne("Mario"))

-- 3. a wish's priority, in its own kind
assert(W.Add(STUB.items[9004]), "a wish")
n = #STUB.sent
assert(W.SetPriority(9004, 1), "priority 1"); STUB.Advance(20)   -- the queue pumps (the burst budget was spent on the records above)
local wp = sentAfter(n, "wp")
assert(#wp >= 1 and wp[#wp].p:find("9004:1", 1, true), "priorities shared in wp: " .. tostring(wp[#wp] and wp[#wp].p))
STUB.Receive("LVLM2", C.Encode("hb", { l = 40, z = 1421, c = "WARRIOR" }), "GUILD", "Luis-Testrealm")
STUB.Receive("LVLM2", C.Encode("wl", { ids = "9004" }), "GUILD", "Luis-Testrealm")
STUB.Receive("LVLM2", C.Encode("wp", { p = "9004:2" }), "GUILD", "Luis-Testrealm")
assert(W.PriorityOf("Luis", 9004) == 2 and W.PriorityOf(ns.Me(), 9004) == 1, "priorities read: " .. tostring(W.PriorityOf("Luis", 9004)))
assert(W.WantedText(9004):find("Luis", 1, true) and W.WantedText(9004):find("2", 1, true), "who wants it, with priorities: " .. W.WantedText(9004))

-- 4. equipped, seen from shared gear
local a3 = LT.Award(9005, "Luis", { proof = "manual" }); LT.Confirm(a3, "manual")
STUB.Receive("LVLM2", C.Encode("eq", { g = "1:9005:60:0" }), "GUILD", "Luis-Testrealm")
local st
for _, a in ipairs(LT.History()) do if a.id == a3 then st = a.s end end
assert(st == "eq", "equipped once his gear shows it: " .. tostring(st))

-- 5. an award in my bags goes into the trade with its receiver
local a4 = LT.Award(9003, "Mario", { proof = "manual" })
STUB.bags = { 9003 }
STUB.units.NPC = { name = "Mario" }
STUB.picked, STUB.tradeSlot = nil, nil
STUB.Fire("TRADE_SHOW"); STUB.Advance(1)
assert(STUB.picked and STUB.picked[2] == 1 and STUB.tradeSlot == 1, "the item picked from the bag and put in the trade")
STUB.Fire("TRADE_CLOSED")
local pend = LR.Pending()
assert(#pend == 1 and pend[1].to == "Mario" and pend[1].inBags, "the pending list knows it is in my bags")

-- 6. the simulator
SlashCmdList["LEVELMATES"]("sim botin")
assert(LS.offer and LS.offer.from == "Ana" and LC.frame and LC.frame:IsShown(), "a sample session on my card")
print("ok")
