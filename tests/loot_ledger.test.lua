-- the loot book (spec 2026-10-16, decisions 3 and 4): an append-only points ledger whose balances are sums, written
-- by officers only, never edited (a mistake gets an opposite entry); awards of items with their boss, proof and state;
-- both are board records everyone keeps
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.guildRoles = { Tester = 2, Ana = 2, Mario = 4, Luis = 4 }   -- Tester and Ana are officers
STUB.iAmLeader = false
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(30)
local LT, C, R, L = ns.Loot, ns.Comm, ns.Roster, ns.L
R.InvalidateGuildRoster()
STUB.items[9001] = "|cffa335ee|Hitem:9001::::::::60:::::::|h[Casco de Lucifron]|h|r"
local changed = 0
ns.On("LM_LOOT_CHANGED", function() changed = changed + 1 end)

-- entries, balances, the floor
assert(LT.Post("Mario", 10, "boss", "Lucifron"), "a boss entry")
assert(LT.Post("Mario", 5, "att", "MC 16/10") and LT.Post("Luis", 5, "att", "MC 16/10"), "attendance")
assert(LT.Balance("Mario") == 15 and LT.Balance("Luis") == 5 and LT.Balance("Nadie") == 0, "balances are sums")
local ok, why = LT.Post("Mario", -25, "spend", "Casco", { item = 9001 })
assert(not ok and why == "low", "cannot spend below zero: " .. tostring(why))
local spendId = LT.Post("Mario", -12, "spend", "Casco", { item = 9001 })
assert(spendId and LT.Balance("Mario") == 3, "spent")
local total, earned, spent = LT.Balance("Mario")
assert(total == 3 and earned == 15 and spent == 12, "earned and spent apart")
assert(not LT.Post("Mario", 0, "adj", "nada") and not LT.Post("Mario", 5, "weird", "x") and not LT.Post("Mario", 5, "adj", ""), "bad entries refused")
-- standings: highest first; the ledger of one person, newest first
local st = LT.Standings()
assert(#st == 2 and st[1].name == "Luis" and st[1].total == 5 and st[2].name == "Mario" and st[2].total == 3, "standings")
local led = LT.Ledger("Mario")
assert(#led == 3 and led[1].p == -12 and led[1].k == "spend" and led[1].i == 9001 and led[3].k == "boss", "Mario's ledger, newest first")
-- a refund: an opposite entry pointing to the original; not twice
local refund = LT.Refund(spendId, "no lo quería")
assert(refund and LT.Balance("Mario") == 15 and LT.Ledger("Mario")[1].f == spendId and LT.Ledger("Mario")[1].k == "refund", "refunded")
assert(not LT.Refund(spendId, "otra vez"), "a second refund of the same entry is refused")
assert(changed >= 5, "changes announced")

-- only officers write; an entry from a member arriving by the wire is ignored, one from an officer counts
STUB.guildRoles.Tester = 4; R.InvalidateGuildRoster()
assert(not LT.Post("Mario", 5, "adj", "x"), "a member cannot post")
STUB.guildRoles.Tester = 2; R.InvalidateGuildRoster()
STUB.Receive("LVLM2", C.Encode("lk", STUB.Rec{ id = "kAna1", w = "Luis", p = 7, k = "adj", r = "bonus" }), "GUILD", "Ana-Testrealm")
STUB.Receive("LVLM2", C.Encode("lk", STUB.Rec{ id = "kMar1", w = "Luis", p = 70, k = "adj", r = "hack" }), "GUILD", "Mario-Testrealm")
assert(LT.Balance("Luis") == 12, "Ana's counted, Mario's not: " .. LT.Balance("Luis"))
-- the leader without the officer role still writes
STUB.guildRoles.Tester = 4; STUB.iAmLeader = true; R.InvalidateGuildRoster()
assert(LT.Post("Luis", 1, "adj", "gm"), "the guild master writes")
STUB.iAmLeader = false; STUB.guildRoles.Tester = 2; R.InvalidateGuildRoster()

-- awards: the item, who, the boss, the proof and the state; a cost is a spend entry
local aw = LT.Award(9001, "Luis", { boss = "Lucifron", enc = 663, proof = "ml", cost = 10 })
assert(aw, "awarded")
local h = LT.History()
assert(#h == 1 and h[1].i == 9001 and h[1].to == "Luis" and h[1].b == "Lucifron" and h[1].s == "aw" and h[1].pf == "ml" and h[1].c == 10, "the award")
assert(LT.Balance("Luis") == 3, "its cost charged")
assert(not LT.Award(9001, "Luis", { cost = 50 }), "too expensive: refused, nothing charged")
assert(LT.Balance("Luis") == 3, "nothing charged")
assert(LT.Confirm(aw, "trade") and LT.History()[1].s == "rc" and LT.History()[1].pf == "trade", "received by trade")
assert(LT.Equipped(aw) and LT.History()[1].s == "eq", "equipped")
assert(not LT.Confirm(aw, "chat"), "backwards: refused")
-- a correction: the old one is marked, the new one points back, the cost moves
local aw2 = LT.Correct(aw, "Mario", "era de Mario")
assert(aw2 and aw2 ~= aw, "corrected")
local byId = {}
for _, a in ipairs(LT.History()) do byId[a.id] = a end
assert(byId[aw].s == "c" and byId[aw2].f == aw and byId[aw2].to == "Mario" and byId[aw2].s == "aw", "old marked, new points back")
assert(LT.Balance("Luis") == 13 and LT.Balance("Mario") == 5, "Luis refunded, Mario charged: " .. LT.Balance("Luis") .. "/" .. LT.Balance("Mario"))
-- a cancel refunds too
assert(LT.Cancel(aw2, "nadie lo quiso") and byId[aw2] and LT.History()[1].s == "x" and LT.Balance("Mario") == 15, "cancelled and refunded")
-- +1: items received of epic quality or better, per person
local aw3 = LT.Award(9001, "Luis", { proof = "manual" })
LT.Confirm(aw3, "manual")
assert(LT.PlusOne("Luis") == 1 and LT.PlusOne("Mario") == 0, "+1 counts received epics: " .. LT.PlusOne("Luis"))
-- an award arriving by the wire from an officer, and one from a member
STUB.Receive("LVLM2", C.Encode("la", STUB.Rec{ id = "aAna1", i = 9001, to = "Mario", s = "rc", pf = "ml", at = time() }), "GUILD", "Ana-Testrealm")
STUB.Receive("LVLM2", C.Encode("la", STUB.Rec{ id = "aMar1", i = 9001, to = "Mario", s = "rc", pf = "ml", at = time() }), "GUILD", "Mario-Testrealm")
local n = 0
for _, a in ipairs(LT.History()) do if a.id == "aAna1" or a.id == "aMar1" then n = n + 1 end end
assert(n == 1, "only the officer's award: " .. n)
