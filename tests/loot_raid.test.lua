-- capture in a raid, on the officer's client (spec 2026-10-16, decisions 2, 4, 8): a boss kill posts boss points to
-- everyone present; master loot from a click becomes an award delivered with strong proof; a trade or the loot chat
-- line delivers a pending award; closing the raid posts attendance; records made inside wait for the exit (hours)
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.guildRoles = { Tester = 2, Mario = 4, Luis = 4, Pepe = 4 }
STUB.guildMembers.Pepe = true
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(30)
local LT, LR, C, R, L = ns.Loot, ns.LootRaid, ns.Comm, ns.Roster, ns.L
R.InvalidateGuildRoster()
STUB.items[9001] = "|cffa335ee|Hitem:9001::::::::60:::::::|h[Casco de Lucifron]|h|r"
STUB.items[9002] = "|cffa335ee|Hitem:9002::::::::60:::::::|h[Guantes]|h|r"
STUB.items[9003] = "|cffa335ee|Hitem:9003::::::::60:::::::|h[Botas]|h|r"
local function sentKinds(from, kind) local n = 0; for i = from + 1, #STUB.sent do if C.Decode(STUB.sent[i].msg) == kind then n = n + 1 end end; return n end

-- the rules: 10 a boss, 5 the attendance
assert(LR.SetRules({ boss = 10, att = 5 }) and LR.Rules().boss == 10 and LR.Rules().att == 5, "rules set by an officer")
-- a raid group inside Molten Core
STUB.inInstance = true; STUB.instanceName = "Núcleo de Magma"; STUB.groupSize = 3
IsInGroup = function() return true end; IsInRaid = function() return true end
STUB.units.raid1 = { name = "Tester" }; STUB.units.raid2 = { name = "Mario" }; STUB.units.raid3 = { name = "Luis" }
local before = #STUB.sent
-- a wipe posts nothing; a kill posts the boss to everyone present
STUB.Fire("ENCOUNTER_END", 663, "Lucifron", 9, 40, 0)
assert(LT.Balance("Mario") == 0, "a wipe: nothing")
STUB.Fire("ENCOUNTER_END", 663, "Lucifron", 9, 40, 1)
assert(LT.Balance("Mario") == 10 and LT.Balance("Luis") == 10 and LT.Balance("Tester") == 10, "boss points to everyone present: " .. LT.Balance("Mario"))
assert(LT.Ledger("Mario")[1].k == "boss" and LT.Ledger("Mario")[1].r == "Lucifron", "the entry names the boss")
assert(LR.raid and LR.raid.bosses[1].name == "Lucifron" and LR.raid.present.Mario, "the raid remembers the kill and who was there")
assert(sentKinds(before, "lk") == 0, "inside: nothing went out yet")

-- master loot from a click: the item, who, the boss just killed; delivered with strong proof
GetNumLootItems = function() return 1 end
GetLootSlotLink = function(i) return STUB.items[9001] end
GetLootSlotInfo = function(i) return 134400, "Casco de Lucifron", 1, 0, 4 end
GetLootSourceInfo = function(i) return "Creature-0-1-2-3-12118-000ABC", 1 end
GetMasterLootCandidate = function(slot, index) return ({ "Tester", "Mario", "Luis" })[index] end
GiveMasterLoot = function(slot, index) end
STUB.Fire("LOOT_OPENED")
GiveMasterLoot(1, 2)
STUB.Fire("LOOT_SLOT_CLEARED", 1)
STUB.Fire("LOOT_CLOSED")
local h = LT.History()
assert(#h == 1 and h[1].i == 9001 and h[1].to == "Mario" and h[1].b == "Lucifron" and h[1].s == "rc" and h[1].pf == "ml", "the award from master loot: " .. tostring(h[1] and h[1].to))
-- the same corpse opened again: no second award
STUB.Fire("LOOT_OPENED"); GiveMasterLoot(1, 2); STUB.Fire("LOOT_SLOT_CLEARED", 1); STUB.Fire("LOOT_CLOSED")
assert(#LT.History() == 1, "no duplicate from a reopened corpse")

-- a trade delivers a pending award
local aw = LT.Award(9002, "Luis", { proof = "manual" })
STUB.units.NPC = { name = "Luis" }
GetTradePlayerItemLink = function(i) return i == 1 and STUB.items[9002] or nil end
STUB.Fire("TRADE_SHOW"); STUB.Fire("TRADE_ACCEPT_UPDATE", 1, 1); STUB.Fire("TRADE_CLOSED")
local byId = {}
for _, a in ipairs(LT.History()) do byId[a.id] = a end
assert(byId[aw].s == "rc" and byId[aw].pf == "trade", "delivered by trade")
-- the loot chat line delivers too (weak proof); Forever's line has no trailing period
local aw3 = LT.Award(9003, "Pepe", { proof = "manual" })
LOOT_ITEM = "%s receives loot: %s."
STUB.Fire("CHAT_MSG_LOOT", "Pepe receives loot: " .. STUB.items[9003], "Pepe-Testrealm", "", "", "", "", 0, 0, "", 0, 0, "Player-1-PEPE")
for _, a in ipairs(LT.History()) do byId[a.id] = a end
assert(byId[aw3].s == "rc" and byId[aw3].pf == "chat", "delivered by the chat line: " .. tostring(byId[aw3].s))

-- two hours inside, then out: the records still go (a raid night is long)
STUB.Advance(7200)
assert(sentKinds(before, "lk") == 0, "still inside: still held")
STUB.inInstance = false
STUB.Fire("ZONE_CHANGED_NEW_AREA"); STUB.Advance(5)
assert(sentKinds(before, "lk") >= 3 and sentKinds(before, "la") >= 1, "out: the book went: " .. sentKinds(before, "lk"))
-- closing the raid: attendance to everyone seen
LR.Stop()
assert(LT.Balance("Mario") == 15 and LT.Balance("Luis") == 15 and LR.raid == nil, "attendance posted, the raid closed: " .. LT.Balance("Mario"))
-- a member's client records nothing
STUB.guildRoles.Tester = 4; R.InvalidateGuildRoster()
STUB.inInstance = true
STUB.Fire("ENCOUNTER_END", 664, "Magmadar", 9, 40, 1)
assert(LT.Balance("Mario") == 15, "not an officer: nothing posted")
STUB.inInstance = false
