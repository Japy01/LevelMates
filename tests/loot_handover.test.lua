-- the hand-over reminder: an award still "awarded" to someone else whose item sits in my bags is said once a session
-- (a notice, no chat); delivered or cancelled, nothing more
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.guildRoles = { Tester = 2, Luis = 4 }
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(30)
local LT, LR, L, R = ns.Loot, ns.LootRaid, ns.L, ns.Roster
R.InvalidateGuildRoster()
STUB.items[9002] = "|cffa335ee|Hitem:9002::::::::60:::::::|h[Guantes]|h|r"
local bags = { [0] = { { itemID = 9002 } } }
C_Container = { GetContainerNumSlots = function(bag) return bags[bag] and #bags[bag] or 0 end, GetContainerItemInfo = function(bag, slot) return bags[bag] and bags[bag][slot] end }
local aw = LT.Award(9002, "Luis", { proof = "manual" })
local before = #STUB.printed
STUB.Fire("BAG_UPDATE_DELAYED"); STUB.Advance(2)
local said = table.concat(STUB.printed, "\n", before + 1)
assert(said:find("Luis", 1, true) and said:find("Guantes", 1, true), "told to hand it over: " .. said)
before = #STUB.printed
STUB.Fire("BAG_UPDATE_DELAYED"); STUB.Advance(2)
assert(#STUB.printed == before, "once a session")
-- delivered: no reminder for a new award of another item... and the item gone from the bags: nothing
LT.Confirm(aw, "trade")
bags[0] = {}
STUB.Fire("BAG_UPDATE_DELAYED"); STUB.Advance(2)
assert(#STUB.printed == before, "delivered: quiet")
