-- the master looter's window (spec 2026-10-16, screens): opens with the loot under master loot for an officer, lists
-- the items the rules record, and for each the candidates with their points, +1 and whether they wish for it; a
-- cost and Give hand the item over from the click (a manual award without master loot rights); the Loot tab's foot
-- buttons: open/close the raid, the rules, copy the standings
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.guildRoles = { Tester = 2, Mario = 4, Luis = 4 }
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(30)
local LT, LW, LR, B, L, R, W = ns.Loot, ns.LootWindow, ns.LootRaid, ns.Board, ns.L, ns.Roster, ns.Wishlist
R.InvalidateGuildRoster()
STUB.items[9001] = "|cffa335ee|Hitem:9001::::::::60:::::::|h[Casco de Lucifron]|h|r"
STUB.items[9009] = "|cff9d9d9d|Hitem:9009::::::::60:::::::|h[Trapo]|h|r"
LT.Post("Mario", 15, "adj", "x"); LT.Post("Luis", 2, "adj", "x")
W.AddSample("Mario", { 9001 })
-- the game: master loot, a raid of three, two items on the corpse (one grey)
C_PartyInfo = { GetLootMethod = function() return 2 end }
Enum.LootMethod = { Master = 2 }
STUB.inInstance = true; STUB.groupSize = 3
IsInGroup = function() return true end; IsInRaid = function() return true end
STUB.units.raid1 = { name = "Tester" }; STUB.units.raid2 = { name = "Mario" }; STUB.units.raid3 = { name = "Luis" }
GetNumLootItems = function() return 2 end
GetLootSlotLink = function(i) return i == 1 and STUB.items[9001] or STUB.items[9009] end
GetLootSlotInfo = function(i) return 134400, "x", 1, 0, i == 1 and 4 or 0 end
GetLootSourceInfo = function(i) return "Creature-0-1-2-3-12118-000ABC", 1 end
local candidates = { "Tester", "Mario", "Luis" }
GetMasterLootCandidate = function(slot, index) return candidates[index] end
local gave
GiveMasterLoot = function(slot, index) gave = { slot, index } end
local function rows() local out = {}; for _, r in ipairs(LW.rows) do if r:IsShown() then out[#out + 1] = r end end; return out end
local function row(name) for _, r in ipairs(rows()) do if r.name.text == name then return r end end end

STUB.Fire("LOOT_OPENED")
assert(LW.frame and LW.frame:IsShown(), "the window opens on master loot")
assert(#LW.Items() == 1 and LW.Items()[1].id == 9001, "only what the rules record (the grey one is left out)")
assert(#rows() == 3, "three candidates: " .. #rows())
local mario = row("Mario")
assert(mario and tostring(mario.points.text) == "15" and mario.wish.text == L.LW_WANTS and tostring(mario.plus.text) == "0", "Mario: points, wants it, +1: " .. tostring(mario and mario.wish.text))
assert(row("Luis").wish.text == "", "Luis does not")
-- a cost and Give: master loot from the click, then the award carries the cost
mario.cost:SetText("12")
mario.give.scripts.OnClick(mario.give)
assert(gave and gave[1] == 1 and gave[2] == 2, "master loot given from the click")
STUB.Fire("LOOT_SLOT_CLEARED", 1); STUB.Fire("LOOT_CLOSED")
local h = LT.History()
assert(#h == 1 and h[1].to == "Mario" and h[1].c == 12 and h[1].s == "rc" and h[1].pf == "ml", "the award with its cost: " .. tostring(h[1] and h[1].c))
assert(LT.Balance("Mario") == 3, "charged")
assert(not LW.frame:IsShown(), "closed with the loot")
-- too expensive: refused before anything is given
STUB.Fire("LOOT_OPENED")
local luis = row("Luis")
luis.cost:SetText("50"); gave = nil
luis.give.scripts.OnClick(luis.give)
assert(gave == nil and LT.Balance("Luis") == 2, "too expensive: nothing given, nothing charged")
-- without master loot rights (no GiveMasterLoot): a manual award, awarded but not yet delivered
GiveMasterLoot = nil
luis.cost:SetText("2")
luis.give.scripts.OnClick(luis.give)
local last = LT.History()[1]
assert(last.to == "Luis" and last.c == 2 and last.s == "aw" and last.pf == "manual" and LT.Balance("Luis") == 0, "a manual award with its cost")
STUB.Fire("LOOT_CLOSED")
-- group loot: no window; a member: no window
C_PartyInfo.GetLootMethod = function() return 3 end
STUB.Fire("LOOT_OPENED")
assert(not LW.frame:IsShown(), "group loot: no window")
STUB.Fire("LOOT_CLOSED")
C_PartyInfo.GetLootMethod = function() return 2 end
STUB.guildRoles.Tester = 4; R.InvalidateGuildRoster()
STUB.Fire("LOOT_OPENED")
assert(not LW.frame:IsShown(), "a member: no window")
STUB.Fire("LOOT_CLOSED")
STUB.guildRoles.Tester = 2; R.InvalidateGuildRoster()
STUB.inInstance = false

-- the Loot tab's foot: open/close the raid and the rules for officers, copy the standings for everyone
B.Toggle(); B.ShowTab("loot")
assert(B.lootRaidButton:IsShown() and B.lootRaidButton.text == L.BTN_LOOT_RAID_OPEN and B.lootRulesButton:IsShown() and B.lootCopyButton:IsShown(), "foot buttons")
B.lootRaidButton.scripts.OnClick(B.lootRaidButton); STUB.Advance(1)
assert(LR.raid and B.lootRaidButton.text == L.BTN_LOOT_RAID_CLOSE, "the raid opened")
B.lootRaidButton.scripts.OnClick(B.lootRaidButton); STUB.Advance(1)
assert(not LR.raid, "closed")
B.lootCopyButton.scripts.OnClick(B.lootCopyButton)
assert(ns.DiscordCopy.frame:IsShown() and ns.DiscordCopy.box.text:find("Mario", 1, true) and ns.DiscordCopy.box.text:find("3", 1, true), "the standings to copy: " .. tostring(ns.DiscordCopy.box.text))
ns.DiscordCopy.frame:Hide()
STUB.guildRoles.Tester = 4; R.InvalidateGuildRoster(); B.Refresh()
assert(not B.lootRaidButton:IsShown() and not B.lootRulesButton:IsShown() and B.lootCopyButton:IsShown(), "a member: only copy")
