-- live loot sessions over the group channel (measured 2026-10-16: PARTY and WHISPER work inside an instance, only
-- GUILD is blocked): the master looter's client announces the session with the corpse's items; each candidate
-- answers by whisper from a card (main / minor / pass, a sealed bid, a roll); the master's window shows the answers
-- and announces the award; a lockdown (code 11) holds the message and retries
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.guildRoles = { Tester = 2, Ana = 2, Mario = 4, Luis = 4 }
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(30)
local LT, LW, LS, LC, LR, C, L, R = ns.Loot, ns.LootWindow, ns.LootSession, ns.LootCard, ns.LootRaid, ns.Comm, ns.L, ns.Roster
R.InvalidateGuildRoster()
STUB.items[9001] = "|cffa335ee|Hitem:9001::::::::60:::::::|h[Casco de Lucifron]|h|r"
STUB.items[9002] = "|cffa335ee|Hitem:9002::::::::60:::::::|h[Guantes]|h|r"
LT.Post("Mario", 30, "adj", "x")
local function sentAfter(n, kind, chatType) local out = {}; for i = n + 1, #STUB.sent do local k, f = C.Decode(STUB.sent[i].msg); if k == kind and (not chatType or STUB.sent[i].chatType == chatType) then f._to = STUB.sent[i].target; out[#out + 1] = f end end; return out end
local function row(name) for _, r in ipairs(LW.rows) do if r:IsShown() and r.name.text == name then return r end end end

-- the game: master loot, a party of three inside, one item on the corpse
C_PartyInfo = { GetLootMethod = function() return 2 end }; Enum.LootMethod = { Master = 2 }
STUB.inInstance = true; STUB.groupSize = 3
IsInGroup = function() return true end; IsInRaid = function() return false end
STUB.units.party1 = { name = "Mario" }; STUB.units.party2 = { name = "Luis" }
GetNumLootItems = function() return 1 end
GetLootSlotLink = function() return STUB.items[9001] end
GetLootSlotInfo = function() return 134400, "x", 1, 0, 4 end
GetMasterLootCandidate = function(slot, index) return ({ "Tester", "Mario", "Luis" })[index] end
local gave
GiveMasterLoot = function(slot, index) gave = { slot, index } end

-- 1. the master: opening the loot announces the session over PARTY
local n = #STUB.sent
STUB.Fire("LOOT_OPENED")
local ls = sentAfter(n, "ls", "PARTY")
assert(#ls == 1 and ls[1].i == "9001" and ls[1].m == "council" and LS.session and LS.session.id == ls[1].s, "the session announced: " .. tostring(ls[1] and ls[1].i))
-- 2. Mario answers by whisper: the window shows it
STUB.Receive("LVLM2", C.Encode("lb", { s = LS.session.id, i = 9001, r = "main", v = 0, n = "para tanquear" }), "WHISPER", "Mario-Testrealm")
assert(row("Mario").resp.text:find(L.LS_R_main, 1, true) and row("Mario").resp.text:find("para tanquear", 1, true), "Mario's answer shown: " .. tostring(row("Mario").resp.text))
-- an answer for a session that is not this one, or from a stranger: ignored
STUB.Receive("LVLM2", C.Encode("lb", { s = "sOther", i = 9001, r = "bis", v = 0 }), "WHISPER", "Luis-Testrealm")
STUB.Receive("LVLM2", C.Encode("lb", { s = LS.session.id, i = 9001, r = "bis", v = 0 }), "WHISPER", "Nadie-Testrealm")
assert(row("Luis").resp.text == "", "other sessions and strangers ignored")
-- 3. giving it to Mario announces the award to the group
n = #STUB.sent
row("Mario").cost:SetText("10"); row("Mario").give.scripts.OnClick(row("Mario").give)
STUB.Fire("LOOT_SLOT_CLEARED", 1)
local lw = sentAfter(n, "lw", "PARTY")
assert(#lw == 1 and lw[1].i == 9001 and lw[1].to == "Mario" and lw[1].c == 10, "the award announced: " .. tostring(lw[1] and lw[1].to))
-- 4. closing the loot closes the session
n = #STUB.sent
STUB.Fire("LOOT_CLOSED")
assert(#sentAfter(n, "lc", "PARTY") == 1 and LS.session == nil, "closed")

-- 5. as a candidate: Ana (an officer, the master) announces; my card opens with the item and the council buttons
n = #STUB.sent
STUB.Receive("LVLM2", C.Encode("ls", { s = "sAna1", m = "council", i = "9001,9002", b = 0 }), "PARTY", "Ana-Testrealm")
assert(LC.frame and LC.frame:IsShown() and #LC.Rows() == 2 and LC.Rows()[1].item == 9001, "the card with two items")
local card = LC.Rows()[1]
assert(card.main:IsShown() and card.minor:IsShown() and card.pass:IsShown() and not card.bidBox:IsShown(), "council buttons")
card.main.scripts.OnClick(card.main)
for _, r in ipairs(LC.Rows()) do if r.item == 9001 then card = r end end   -- answered items move after the open ones (2026-10-18)
local lb = sentAfter(n, "lb", "WHISPER")
assert(#lb == 1 and lb[1]._to == "Ana" and lb[1].s == "sAna1" and lb[1].i == 9001 and lb[1].r == "main", "my answer whispered to Ana: " .. tostring(lb[1] and lb[1]._to))
assert(card.status.text:find(L.LS_R_main, 1, true), "the card says what I answered")
-- the award to someone else shows on the card; the close hides it
STUB.Receive("LVLM2", C.Encode("lw", { s = "sAna1", i = 9001, to = "Luis", c = 5 }), "PARTY", "Ana-Testrealm")
assert(card.status.text:find("Luis", 1, true), "who got it: " .. tostring(card.status.text))
STUB.Receive("LVLM2", C.Encode("lc", { s = "sAna1" }), "PARTY", "Ana-Testrealm")
assert(not LC.frame:IsShown(), "the card closed")
-- a session from a stranger: no card
STUB.Receive("LVLM2", C.Encode("ls", { s = "sX", m = "council", i = "9001", b = 0 }), "PARTY", "Nadie-Testrealm")
assert(not LC.frame:IsShown(), "strangers cannot open a session on my screen")

-- 6. DKP mode: a bid box, the minimum bid; a lockdown holds the whisper and it goes later
LR.SetRules({ mode = "dkp", minBid = 5 })
STUB.Receive("LVLM2", C.Encode("ls", { s = "sAna2", m = "dkp", i = "9002", b = 5 }), "PARTY", "Ana-Testrealm")
card = LC.Rows()[1]
assert(card.bidBox:IsShown() and card.bid:IsShown() and card.pass:IsShown() and not card.main:IsShown(), "dkp buttons")
card.bidBox:SetText("3"); card.bid.scripts.OnClick(card.bid)
assert(card.status.text:find("5", 1, true), "below the minimum: told, not sent: " .. tostring(card.status.text))
STUB.lockdown = true
n = #STUB.sent
card.bidBox:SetText("25"); card.bid.scripts.OnClick(card.bid)
assert(#sentAfter(n, "lb") == 0, "a lockdown: held")
STUB.lockdown = false
STUB.Advance(31)
lb = sentAfter(n, "lb", "WHISPER")
assert(#lb == 1 and lb[1].r == "bid" and lb[1].v == 25, "sent after the lockdown: " .. #lb)
-- the master's window shows a bid as such
STUB.Receive("LVLM2", C.Encode("lc", { s = "sAna2" }), "PARTY", "Ana-Testrealm")
STUB.inInstance = false
