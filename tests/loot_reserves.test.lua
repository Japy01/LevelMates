-- soft reserves (spec 2026-10-16, decision 6): an officer opens a round that lasts the night; everyone reserves their
-- own items (the sender is the server's), over the limit is shown not blocked; the master looter's window marks
-- who reserved the item; the round closes or expires
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.guildRoles = { Tester = 2, Ana = 2, Mario = 4, Luis = 4 }
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(30)
local LT, LW, B, C, L, R = ns.Loot, ns.LootWindow, ns.Board, ns.Comm, ns.L, ns.Roster
R.InvalidateGuildRoster()
STUB.items[9001] = "|cffa335ee|Hitem:9001::::::::60:::::::|h[Casco de Lucifron]|h|r"
STUB.items[9002] = "|cffa335ee|Hitem:9002::::::::60:::::::|h[Guantes]|h|r"
STUB.items[9003] = "|cffa335ee|Hitem:9003::::::::60:::::::|h[Botas]|h|r"

-- no round: a reserve is refused and says so
assert(not LT.ReservesOpen(), "closed at first")
assert(not LT.Reserve(9001), "no round: refused")
-- a member cannot open one; an officer can
STUB.guildRoles.Tester = 4; R.InvalidateGuildRoster()
assert(not LT.OpenReserves(), "a member cannot open the round")
STUB.guildRoles.Tester = 2; R.InvalidateGuildRoster()
assert(LT.OpenReserves() and LT.ReservesOpen(), "the round is open")
-- I reserve two (the limit), then a third: allowed, shown as over
assert(LT.Reserve(9001) and LT.Reserve(9002), "two reserves")
assert(not LT.Reserve(9001), "the same item twice: no")
assert(LT.Reserve(9003), "a third is allowed")
local mine = LT.MyReserves()
assert(#mine == 3 and mine[3].over, "the third is marked over the limit")
assert(LT.Unreserve(9003) and #LT.MyReserves() == 2, "unreserved")
-- Mario reserves by the wire, in his own name; a reserve in someone else's name is refused
STUB.Receive("LVLM2", C.Encode("lr", STUB.Rec{ id = "v" .. ns.NameKey("Mario") .. "9001", i = 9001 }), "GUILD", "Mario-Testrealm")
STUB.Receive("LVLM2", C.Encode("lr", STUB.Rec{ id = "v" .. ns.NameKey("Luis") .. "9001", i = 9001 }), "GUILD", "Mario-Testrealm")
local by = LT.ReservedBy(9001)
assert(#by == 2 and by[1] == "Mario" and by[2] == "Tester", "who reserved the helm: " .. table.concat(by, ","))
local all = LT.Reserves()
assert(#all == 3, "three reserves in the round: " .. #all)

-- the master looter's window marks the reserve
C_PartyInfo = { GetLootMethod = function() return 2 end }; Enum.LootMethod = { Master = 2 }
STUB.inInstance = true; STUB.groupSize = 3; IsInGroup = function() return true end; IsInRaid = function() return true end
STUB.units.raid1 = { name = "Tester" }; STUB.units.raid2 = { name = "Mario" }; STUB.units.raid3 = { name = "Luis" }
GetNumLootItems = function() return 1 end
GetLootSlotLink = function() return STUB.items[9001] end
GetLootSlotInfo = function() return 134400, "x", 1, 0, 4 end
GetMasterLootCandidate = function(slot, index) return ({ "Tester", "Mario", "Luis" })[index] end
STUB.Fire("LOOT_OPENED")
local marioRow, luisRow
for _, r in ipairs(LW.rows) do if r:IsShown() and r.name.text == "Mario" then marioRow = r elseif r:IsShown() and r.name.text == "Luis" then luisRow = r end end
assert(marioRow.wish.text == L.LW_RESERVED and luisRow.wish.text == "", "the reserve marked in the window")
STUB.Fire("LOOT_CLOSED"); STUB.inInstance = false

-- the Loot tab's reserves view: rows with who and what; my reserve from the button
B.Toggle(); B.ShowTab("loot")
B.lootView = "reserves"; B.Refresh()
local names = {}
for _, r in ipairs(B.rows) do if r.button:IsShown() then names[#names + 1] = r.name.text .. ">" .. (r.zone.text:match("%[(.-)%]") or "") end end
table.sort(names)
assert(#names == 3 and names[1]:find("Mario>Casco", 1, true), "the reserves listed: " .. table.concat(names, " "))
assert(B.lootReserveButton:IsShown() and B.lootRaidButton.text == L.BTN_LOOT_ROUND_CLOSE, "Reserve… and the round button")
-- closing the round: nothing reserved any more
assert(LT.CloseReserves() and not LT.ReservesOpen() and #LT.ReservedBy(9001) == 0, "closed: no reserves count")
