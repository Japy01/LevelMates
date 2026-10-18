-- The live loot session, lote 1 (2026-10-18): it outlives the corpse and a /reload, closes by hand (or on its own
-- once everything was handed out), takes new drops into the same session; a time limit from the rules with a
-- countdown on both sides and late answers refused; the master answers for their own drops locally; real rolls
-- (100/50/25) read from the game's own roll line; the card queues beyond six items, "pass the rest", and reopens
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.guildRoles = { Tester = 2, Ana = 2, Mario = 4, Luis = 4 }
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(30)
local LT, LW, LS, LC, LR, C, L, R, B = ns.Loot, ns.LootWindow, ns.LootSession, ns.LootCard, ns.LootRaid, ns.Comm, ns.L, ns.Roster, ns.Board
R.InvalidateGuildRoster()
for i = 9001, 9010 do STUB.items[i] = "|cffa335ee|Hitem:" .. i .. "::::::::60:::::::|h[Objeto " .. i .. "]|h|r" end
local function sentAfter(n, kind, chatType) local out = {}; for i = n + 1, #STUB.sent do local k, f = C.Decode(STUB.sent[i].msg); if k == kind and (not chatType or STUB.sent[i].chatType == chatType) then f._to = STUB.sent[i].target; out[#out + 1] = f end end; return out end
local function row(name) for _, r in ipairs(LW.rows) do if r:IsShown() and r.name.text == name then return r end end end
C_PartyInfo = { GetLootMethod = function() return 2 end }; Enum.LootMethod = { Master = 2 }
STUB.inInstance = true; STUB.groupSize = 3
IsInGroup = function() return true end; IsInRaid = function() return false end
STUB.units.party1 = { name = "Mario" }; STUB.units.party2 = { name = "Luis" }
local corpse = { 9001 }
GetNumLootItems = function() return #corpse end
GetLootSlotLink = function(i) return STUB.items[corpse[i]] end
GetLootSlotInfo = function() return 134400, "x", 1, 0, 4 end
GetMasterLootCandidate = function(slot, index) return ({ "Tester", "Mario", "Luis" })[index] end
GiveMasterLoot = function() end
STUB.iAmOfficer = true
assert(LR.SetRules({ timer = 60 }), "a minute to answer")

-- 1. the session carries the time limit; the master's own card opens
local n = #STUB.sent
STUB.Fire("LOOT_OPENED")
local ls = sentAfter(n, "ls", "PARTY")
assert(#ls == 1 and ls[1].t == 60 and LS.session and LS.session.deadline, "announced with the limit: " .. tostring(ls[1] and ls[1].t))
assert(LS.offer and LS.offer.from == ns.Me() and LC.frame and LC.frame:IsShown() and #LC.Rows() == 1, "the master's own card")
assert(ns.char.lootSession and ns.char.lootSession.id == LS.session.id, "saved for a reload")
-- the master answers locally: no whisper, straight into the session
n = #STUB.sent
LC.Rows()[1].main.scripts.OnClick(LC.Rows()[1].main)
assert(#sentAfter(n, "lb") == 0 and LS.session.responses[9001] and LS.session.responses[9001][ns.Me()] and LS.session.responses[9001][ns.Me()].r == "main", "the master's answer kept locally")
-- 2. the corpse closes: the session lives, the window too
n = #STUB.sent
STUB.Fire("LOOT_CLOSED")
assert(LS.session and #sentAfter(n, "lc") == 0 and LW.frame:IsShown(), "the corpse closed, the session stays")
-- 3. another corpse: the new drop joins the same session
corpse = { 9002 }
n = #STUB.sent
STUB.Fire("LOOT_OPENED")
ls = sentAfter(n, "ls", "PARTY")
assert(#ls == 1 and ls[1].s == LS.session.id and ls[1].i:find("9001", 1, true) and ls[1].i:find("9002", 1, true), "the same session, both items: " .. tostring(ls[1] and ls[1].i))
assert(#LW.Items() == 2, "two items in the window")
-- 4. late answers are refused: the limit restarted with the new drop, then passes
STUB.Receive("LVLM2", C.Encode("lb", { s = LS.session.id, i = 9002, r = "main", v = 0 }), "WHISPER", "Mario-Testrealm")
assert(LS.session.responses[9002] and LS.session.responses[9002].Mario, "in time: taken")
assert(LW.timer.text == string.format(L.LW_LEFT, "1:00"), "the window counts down: " .. tostring(LW.timer.text))
STUB.Advance(70); LW.UpdateClock()
STUB.Receive("LVLM2", C.Encode("lb", { s = LS.session.id, i = 9002, r = "bis", v = 0 }), "WHISPER", "Luis-Testrealm")
assert(not (LS.session.responses[9002] and LS.session.responses[9002].Luis), "late: refused")
assert(LW.timer.text == L.LW_CLOSED_LIMIT, "the window says the limit passed: " .. tostring(LW.timer.text))
-- 5. a reload: the session comes back with its answers
local id = LS.session.id
LS.session = nil; LS.offer = nil
LS.Restore()
assert(LS.session and LS.session.id == id and LS.session.responses[9002].Mario and LS.offer and LS.offer.id == id, "restored")
-- 6. closed by hand: lc to the group, nothing saved
n = #STUB.sent
LW.closeSession.scripts.OnClick(LW.closeSession)
assert(#sentAfter(n, "lc", "PARTY") == 1 and LS.session == nil and LS.offer == nil and ns.char.lootSession == nil and not LW.frame:IsShown(), "closed by hand")
STUB.Fire("LOOT_CLOSED")

-- 7. as a candidate: a roll session; three roll buttons; the real roll comes from the game's line
STUB.Receive("LVLM2", C.Encode("ls", { s = "sAna1", m = "roll", i = "9001", b = 0, t = 0 }), "PARTY", "Ana-Testrealm")
local card = LC.Rows()[1]
assert(card.roll100:IsShown() and card.roll50:IsShown() and card.roll25:IsShown() and card.pass:IsShown(), "roll buttons")
n = #STUB.sent; STUB.rolled = nil
card.roll50.scripts.OnClick(card.roll50)
assert(STUB.rolled and STUB.rolled[2] == 50 and #sentAfter(n, "lb") == 0, "the game rolls; nothing sent until the line comes")
STUB.Fire("CHAT_MSG_SYSTEM", string.format(RANDOM_ROLL_RESULT, "Mario", 77, 1, 50))   -- someone else's roll: not mine
STUB.Fire("CHAT_MSG_SYSTEM", string.format(RANDOM_ROLL_RESULT, "Tester", 41, 1, 50))
local lb = sentAfter(n, "lb", "WHISPER")
assert(#lb == 1 and lb[1].r == "roll" and lb[1].v == 41 and lb[1].m == 50, "my roll, whispered with its range: " .. tostring(lb[1] and lb[1].v) .. "/" .. tostring(lb[1] and lb[1].m))
assert(card.status.text:find("41", 1, true), "the card shows my roll: " .. tostring(card.status.text))
STUB.Receive("LVLM2", C.Encode("lc", { s = "sAna1" }), "PARTY", "Ana-Testrealm")
-- 8. the master ranks rolls by range first, then number
corpse = { 9003 }
STUB.Fire("LOOT_OPENED")
STUB.Receive("LVLM2", C.Encode("lb", { s = LS.session.id, i = 9003, r = "roll", v = 95, m = 50 }), "WHISPER", "Luis-Testrealm")
STUB.Receive("LVLM2", C.Encode("lb", { s = LS.session.id, i = 9003, r = "roll", v = 12, m = 100 }), "WHISPER", "Mario-Testrealm")
local names = {}
for _, r in ipairs(LW.rows) do if r:IsShown() then names[#names + 1] = r.name.text end end
assert(names[1] == "Mario" and names[2] == "Luis", "a 100 roll beats a 50 roll: " .. table.concat(names, ","))
assert(row("Mario").resp.text:find("12", 1, true) and row("Mario").resp.text:find("100", 1, true), "the roll and its range: " .. tostring(row("Mario").resp.text))
LW.closeSession.scripts.OnClick(LW.closeSession); STUB.Fire("LOOT_CLOSED")

-- 9. the card queues: eight items, six rows, answered ones make room; "pass the rest"; reopen
STUB.Receive("LVLM2", C.Encode("ls", { s = "sAna2", m = "council", i = "9001,9002,9003,9004,9005,9006,9007,9008", b = 0, t = 0 }), "PARTY", "Ana-Testrealm")
assert(#LC.Rows() == 6 and LC.from.text:find("8", 1, true), "six rows of eight: " .. #LC.Rows())
card = LC.Rows()[1]
card.pass.scripts.OnClick(card.pass)
local items = {}
for _, r in ipairs(LC.Rows()) do items[#items + 1] = r.item end
assert(items[1] == 9002 and items[6] == 9007, "the answered one leaves the rows, the seventh comes in: " .. table.concat(items, ","))
n = #STUB.sent
LC.passRest.scripts.OnClick(LC.passRest)
assert(#sentAfter(n, "lb", "WHISPER") == 7, "pass sent for the seven left")
LC.frame:Hide()
SlashCmdList["LEVELMATES"]("tarjeta")
assert(LC.frame:IsShown(), "reopened by the command")
B.Toggle(); B.ShowTab("loot")
assert(B.lootLiveButton:IsShown() and B.lootLiveButton.text == L.BTN_LOOT_CARD, "and from the Loot tab")
print("ok")
