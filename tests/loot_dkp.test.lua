-- DKP, lote 2 (2026-10-18): the master validates every bid (minimum, balance minus what the same person already
-- bid on other items of the session) and whispers an acknowledgement (ld); whoever is overtaken hears it without
-- the figure; a bid can be withdrawn; an award can be reassigned (the old one corrected, points back and charged
-- again); points to everyone present at once; the history paints the proof and filters (open, tonight); a copy
-- of tonight's loot for Discord; an item's tooltip says who got it last
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.guildRoles = { Tester = 2, Ana = 2, Mario = 4, Luis = 4 }
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(30)
local LT, LW, LS, LC, LR, C, L, R, B = ns.Loot, ns.LootWindow, ns.LootSession, ns.LootCard, ns.LootRaid, ns.Comm, ns.L, ns.Roster, ns.Board
R.InvalidateGuildRoster()
for i = 9001, 9003 do STUB.items[i] = "|cffa335ee|Hitem:" .. i .. "::::::::60:::::::|h[Objeto " .. i .. "]|h|r" end
local function sentAfter(n, kind, chatType) local out = {}; for i = n + 1, #STUB.sent do local k, f = C.Decode(STUB.sent[i].msg); if k == kind and (not chatType or STUB.sent[i].chatType == chatType) then f._to = STUB.sent[i].target; out[#out + 1] = f end end; return out end
C_PartyInfo = { GetLootMethod = function() return 2 end }; Enum.LootMethod = { Master = 2 }
STUB.inInstance = true; STUB.groupSize = 3
IsInGroup = function() return true end; IsInRaid = function() return false end
STUB.units.party1 = { name = "Mario" }; STUB.units.party2 = { name = "Luis" }
local corpse = { 9001, 9002 }
GetNumLootItems = function() return #corpse end
GetLootSlotLink = function(i) return STUB.items[corpse[i]] end
GetLootSlotInfo = function() return 134400, "x", 1, 0, 4 end
GetMasterLootCandidate = function(slot, index) return ({ "Tester", "Mario", "Luis" })[index] end
GiveMasterLoot = function() end
STUB.iAmOfficer = true
LT.Post("Mario", 20, "adj", "inicio"); LT.Post("Luis", 50, "adj", "inicio")
assert(LR.SetRules({ mode = "dkp", minBid = 5, timer = 0 }), "dkp rules")

-- 1. the master validates bids
STUB.Fire("LOOT_OPENED")
local sid = LS.session.id
local n = #STUB.sent
STUB.Receive("LVLM2", C.Encode("lb", { s = sid, i = 9001, r = "bid", v = 25 }), "WHISPER", "Mario-Testrealm")
local ld = sentAfter(n, "ld", "WHISPER")
assert(#ld == 1 and ld[1]._to == "Mario" and ld[1].ok == 0 and ld[1].y == "balance" and not (LS.session.responses[9001] and LS.session.responses[9001].Mario), "over the balance: refused, told why: " .. tostring(ld[1] and ld[1].y))
n = #STUB.sent
STUB.Receive("LVLM2", C.Encode("lb", { s = sid, i = 9001, r = "bid", v = 3 }), "WHISPER", "Mario-Testrealm")
ld = sentAfter(n, "ld", "WHISPER")
assert(#ld == 1 and ld[1].ok == 0 and ld[1].y == "min", "under the minimum: refused")
n = #STUB.sent
STUB.Receive("LVLM2", C.Encode("lb", { s = sid, i = 9001, r = "bid", v = 15 }), "WHISPER", "Mario-Testrealm")
ld = sentAfter(n, "ld", "WHISPER")
assert(#ld == 1 and ld[1].ok == 1 and ld[1].y == nil and LS.session.responses[9001].Mario.v == 15, "a good bid: accepted")
n = #STUB.sent
STUB.Receive("LVLM2", C.Encode("lb", { s = sid, i = 9001, r = "bid", v = 20 }), "WHISPER", "Luis-Testrealm")
ld = sentAfter(n, "ld", "WHISPER")
local toLuis, toMario
for _, f in ipairs(ld) do if f._to == "Luis" then toLuis = f elseif f._to == "Mario" then toMario = f end end
assert(toLuis and toLuis.ok == 1 and toMario and toMario.ok == 1 and toMario.y == "outbid", "Luis accepted, Mario told he was overtaken")
n = #STUB.sent
STUB.Receive("LVLM2", C.Encode("lb", { s = sid, i = 9002, r = "bid", v = 10 }), "WHISPER", "Mario-Testrealm")
ld = sentAfter(n, "ld", "WHISPER")
assert(#ld == 1 and ld[1].ok == 0 and ld[1].y == "balance", "15 already bid of 20: only 5 left, 10 refused")
LW.closeSession.scripts.OnClick(LW.closeSession); STUB.Fire("LOOT_CLOSED")

-- 2. as a candidate: the acknowledgements on the card; withdraw
STUB.Receive("LVLM2", C.Encode("ls", { s = "sAna1", m = "dkp", i = "9003", b = 5, t = 0 }), "PARTY", "Ana-Testrealm")
local card = LC.Rows()[1]
n = #STUB.sent
card.bidBox:SetText("25"); card.bid.scripts.OnClick(card.bid)
assert(#sentAfter(n, "lb", "WHISPER") == 1, "bid whispered")
STUB.Receive("LVLM2", C.Encode("ld", { s = "sAna1", i = 9003, ok = 0, y = "balance" }), "WHISPER", "Ana-Testrealm")
assert(card.status.text:find(L.LS_ACK_balance, 1, true), "refused, the reason on the card: " .. tostring(card.status.text))
assert(card.bid:IsShown(), "can bid again")
card.bidBox:SetText("8"); card.bid.scripts.OnClick(card.bid)
STUB.Receive("LVLM2", C.Encode("ld", { s = "sAna1", i = 9003, ok = 1 }), "WHISPER", "Ana-Testrealm")
assert(card.status.text:find(L.LS_ACK_OK, 1, true) and card.status.text:find("8", 1, true) and card.withdraw:IsShown(), "accepted, with Withdraw: " .. tostring(card.status.text))
STUB.Receive("LVLM2", C.Encode("ld", { s = "sAna1", i = 9003, ok = 1, y = "outbid" }), "WHISPER", "Ana-Testrealm")
assert(card.status.text:find(L.LS_ACK_outbid, 1, true) and not card.status.text:find("20", 1, true), "overtaken, no figure: " .. tostring(card.status.text))
n = #STUB.sent
card.withdraw.scripts.OnClick(card.withdraw)
local lb = sentAfter(n, "lb", "WHISPER")
assert(#lb == 1 and lb[1].r == "pass" and not card.withdraw:IsShown(), "withdrawn: a pass goes")
STUB.Receive("LVLM2", C.Encode("lc", { s = "sAna1" }), "PARTY", "Ana-Testrealm")

-- 3. reassign an award: the old one corrected, Luis refunded, Mario charged
LR.Start()
local aid = LT.Award(9001, "Luis", { cost = 5, proof = "manual", raid = LR.raid.id })
assert(aid and LT.Balance("Luis") == 45, "awarded to Luis for 5")
assert(B.ReassignLoot(aid, "Mario"), "reassigned")
local h = LT.History()
assert(h[1].to == "Mario" and h[1].s == "aw" and h[1].c == 5 and LT.Balance("Mario") == 15 and LT.Balance("Luis") == 50, "Mario has it and paid, Luis got his points back: " .. tostring(h[1].to))
local old
for _, a in ipairs(h) do if a.id == aid then old = a end end
assert(old and old.s == "c", "the old award marked corrected")
-- 4. points to everyone present
local before = { Tester = LT.Balance("Tester"), Mario = LT.Balance("Mario"), Luis = LT.Balance("Luis") }
assert(B.PostLootAll(5, "bonus") == 3, "three present")
assert(LT.Balance("Mario") == before.Mario + 5 and LT.Balance("Luis") == before.Luis + 5 and LT.Balance("Tester") == before.Tester + 5, "everyone got 5")
-- 5. the history: proof painted, filters, tonight's copy, the copy button
B.Toggle(); B.ShowTab("loot"); B.lootView = "history"; B.lootHistFilter = "all"; B.Refresh()
local function shownRows() local out = {}; for _, r in ipairs(B.rows) do if r.button:IsShown() then out[#out + 1] = r end end; return out end
local rows = shownRows()
assert(#rows == 2 and rows[1].group.text:find(L.LOOT_PROOF_manual, 1, true), "the proof on the row: " .. tostring(rows[1].group.text))
assert(B.lootHistButton:IsShown(), "a filter button in the history")
B.lootHistButton.scripts.OnClick(B.lootHistButton); STUB.MenuEntry(L.LOOT_HIST_OPEN).cb()
rows = shownRows()
assert(#rows == 1 and rows[1].zone.text:find("Mario", 1, true), "open awards only")
B.lootHistButton.scripts.OnClick(B.lootHistButton); STUB.MenuEntry(L.LOOT_HIST_NIGHT).cb()
assert(#shownRows() == 2, "tonight's awards")
assert(B.lootCopyButton.text == L.BTN_LOOT_COPY_NIGHT, "the copy button offers tonight")
local text = LT.NightText(LR.raid.id)
assert(text:find("Objeto 9001", 1, true) and text:find("Mario", 1, true), "tonight's text: " .. text)
-- 6. the tooltip: who got it last
local lines = {}
local tip = { AddLine = function(_, t) lines[#lines + 1] = t end }
GameTooltip = tip
for _, p in ipairs(STUB.tooltipPost) do p.fn(tip, { id = 9001 }) end
assert(table.concat(lines, "\n"):find("Mario", 1, true), "the tooltip names the last receiver: " .. table.concat(lines, " | "))
print("ok")
