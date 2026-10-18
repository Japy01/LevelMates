-- The loot council, lote 3 (2026-10-18): the master relays the answers of each item to the council (officers in
-- the group, or everyone, as the rules say) a moment after they change; council members see them in the same
-- window, read-only, and vote; votes are counted on the master's side, a tie disables Give; the master votes too;
-- Off-spec and Transmog answers when the rules turn them on
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.guildRoles = { Tester = 2, Ana = 2, Mario = 4, Luis = 4 }
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(30)
local LT, LW, LS, LC, LR, C, L, R, B = ns.Loot, ns.LootWindow, ns.LootSession, ns.LootCard, ns.LootRaid, ns.Comm, ns.L, ns.Roster, ns.Board
R.InvalidateGuildRoster()
for i = 9001, 9003 do STUB.items[i] = "|cffa335ee|Hitem:" .. i .. "::::::::60:::::::|h[Objeto " .. i .. "]|h|r" end
local function sentAfter(n, kind, chatType) local out = {}; for i = n + 1, #STUB.sent do local k, f = C.Decode(STUB.sent[i].msg); if k == kind and (not chatType or STUB.sent[i].chatType == chatType) then f._to = STUB.sent[i].target; out[#out + 1] = f end end; return out end
local function row(name) for _, r in ipairs(LW.rows) do if r:IsShown() and r.name.text == name then return r end end end
C_PartyInfo = { GetLootMethod = function() return 2 end }; Enum.LootMethod = { Master = 2 }
STUB.inInstance = true; STUB.groupSize = 4
IsInGroup = function() return true end; IsInRaid = function() return false end
STUB.units.party1 = { name = "Mario" }; STUB.units.party2 = { name = "Luis" }; STUB.units.party3 = { name = "Ana" }
local corpse = { 9001 }
GetNumLootItems = function() return #corpse end
GetLootSlotLink = function(i) return STUB.items[corpse[i]] end
GetLootSlotInfo = function() return 134400, "x", 1, 0, 4 end
GetMasterLootCandidate = function(slot, index) return ({ "Tester", "Mario", "Luis", "Ana" })[index] end
GiveMasterLoot = function() end
STUB.iAmOfficer = true
assert(LR.Rules().voters == "officers", "officers vote by default")
assert(LR.SetRules({ mode = "council", timer = 0, responses = { bis = true, main = true, minor = true, os = true } }), "council rules with off-spec")

-- 1. the master: answers come in, the council (Ana) gets them relayed a moment later
STUB.Fire("LOOT_OPENED")
local sid = LS.session.id
local n = #STUB.sent
STUB.Receive("LVLM2", C.Encode("lb", { s = sid, i = 9001, r = "main", v = 0 }), "WHISPER", "Mario-Testrealm")
STUB.Receive("LVLM2", C.Encode("lb", { s = sid, i = 9001, r = "os", v = 0 }), "WHISPER", "Luis-Testrealm")
assert(#sentAfter(n, "lq") == 0, "not at once")
STUB.Advance(3)
local lq = sentAfter(n, "lq", "WHISPER")
assert(#lq == 1 and lq[1]._to == "Ana" and lq[1].i == 9001 and lq[1].r:find("Mario:main", 1, true) and lq[1].r:find("Luis:os", 1, true), "one relay to the council, both answers: " .. tostring(lq[1] and lq[1].r))
local names = {}
for _, r in ipairs(LW.rows) do if r:IsShown() then names[#names + 1] = r.name.text end end
assert(names[1] == "Mario" and names[2] == "Luis", "main before off-spec: " .. table.concat(names, ","))
-- 2. votes: Ana votes Mario; the master votes Luis: a tie, Give disabled; Ana changes to Luis: Luis leads
STUB.Receive("LVLM2", C.Encode("lv", { s = sid, i = 9001, to = "Mario" }), "WHISPER", "Ana-Testrealm")
assert(row("Mario").votes.text == "1" and row("Luis").votes.text == "" and row("Mario").give:IsEnabled(), "one vote for Mario, Give possible")
n = #STUB.sent
row("Luis").vote.scripts.OnClick(row("Luis").vote)
assert(LS.session.votes[9001][ns.Me()] == "Luis" and row("Luis").votes.text == "1", "the master's own vote counted")
assert(not row("Mario").give:IsEnabled() and not row("Luis").give:IsEnabled() and LW.voteNote.text == L.LW_TIE, "a tie: Give off, said so")
STUB.Receive("LVLM2", C.Encode("lv", { s = sid, i = 9001, to = "Luis" }), "WHISPER", "Ana-Testrealm")
assert(row("Luis").votes.text == "2" and row("Mario").votes.text == "" and row("Luis").give:IsEnabled(), "Ana changed her vote: Luis leads, Give back")
STUB.Advance(3)
lq = sentAfter(n, "lq", "WHISPER")
assert(#lq >= 1 and lq[#lq].v and lq[#lq].v:find("Luis:2", 1, true), "the tally relayed too: " .. tostring(lq[#lq] and lq[#lq].v))
-- a member (not on the council) cannot vote
STUB.Receive("LVLM2", C.Encode("lv", { s = sid, i = 9001, to = "Mario" }), "WHISPER", "Mario-Testrealm")
assert(not LS.session.votes[9001].Mario, "members do not vote")
LW.closeSession.scripts.OnClick(LW.closeSession); STUB.Fire("LOOT_CLOSED")

-- 3. as a council member: Ana is the master; my window opens read-only with the relayed answers; I vote
STUB.Receive("LVLM2", C.Encode("ls", { s = "sAna1", m = "council", i = "9002", b = 0, t = 0 }), "PARTY", "Ana-Testrealm")
assert(LW.frame:IsShown() and LW.mode == "council" and LS.council and LS.council.id == "sAna1", "the council view")
assert(not LW.closeSession:IsShown(), "nothing to close: it is Ana's session")
STUB.Receive("LVLM2", C.Encode("lq", { s = "sAna1", i = 9002, r = "Mario:main:0:0;Luis:bis:0:0", v = "Mario:1" }), "WHISPER", "Ana-Testrealm")
assert(row("Luis") and row("Mario") and row("Luis").resp.text:find(L.LS_R_bis, 1, true) and row("Mario").votes.text == "1" and not row("Mario").give:IsShown(), "answers and votes shown, no Give: " .. tostring(row("Luis") and row("Luis").resp.text))
names = {}
for _, r in ipairs(LW.rows) do if r:IsShown() then names[#names + 1] = r.name.text end end
assert(names[1] == "Luis" and names[2] == "Mario", "ranked as the master sees it: " .. table.concat(names, ","))
n = #STUB.sent
row("Luis").vote.scripts.OnClick(row("Luis").vote)
local lv = sentAfter(n, "lv", "WHISPER")
assert(#lv == 1 and lv[1]._to == "Ana" and lv[1].to == "Luis" and lv[1].i == 9002, "my vote whispered to the master")
assert(row("Luis").vote.text == L.LW_VOTED, "the button says I voted")
STUB.Receive("LVLM2", C.Encode("lc", { s = "sAna1" }), "PARTY", "Ana-Testrealm")
assert(not LW.frame:IsShown() and LS.council == nil, "closed with the session")
-- 4. the card offers Off-spec when the rules say so
STUB.Receive("LVLM2", C.Encode("ls", { s = "sAna2", m = "council", i = "9003", b = 0, t = 0 }), "PARTY", "Ana-Testrealm")
local card = LC.Rows()[1]
assert(card.os:IsShown() and not card.tm:IsShown(), "off-spec on, transmog off")
n = #STUB.sent
card.os.scripts.OnClick(card.os)
local lb = sentAfter(n, "lb", "WHISPER")
assert(#lb == 1 and lb[1].r == "os", "off-spec answered")
print("ok")
