-- Every button of the book, the loot card and the loot window says what it does on hover (audit 2026-10-18)
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.guildRoles = { Tester = 2 }
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(30)
local B, L, LS, LC, LW, GC = ns.Board, ns.L, ns.LootSession, ns.LootCard, ns.LootWindow, ns.GuildChat
STUB.iAmOfficer = true
B.Toggle()
local function tipped(b, what)
	assert(b and b.scripts.OnEnter, "no tooltip on " .. what)
	GameTooltip.lines = {}
	b.scripts.OnEnter(b)
	assert(#GameTooltip.lines >= 2 and GameTooltip.lines[2] ~= "", "an empty tooltip on " .. what)
	b.scripts.OnLeave(b)
end
for _, key in ipairs({ "discordButton", "helpButton", "lootRaidButton", "lootRulesButton", "lootCopyButton", "lootReserveButton", "lootLiveButton", "lootHistButton", "lootViewButton",
	"journalClear", "journalFilterButton", "journalAchButton", "togetherButton", "questsButton", "questFilterButton", "questPostButton", "memberViewButton", "memberFilterButton",
	"classShare", "classAsk", "feedCemetery", "recruitViewButton", "recruitDaysButton", "recruitEvery", "recruitPost", "goalNew", "myGoal", "wishAdd", "giftAdd", "groupsButton", "catalogButton", "scaleUp", "scaleDown" }) do
	tipped(B[key], key)
end
-- the card and the master's window
LS.OfferFrom("sT", "Ana", "council", 0, { 9001 }, 0)
local card = LC.Rows()[1]
for _, key in ipairs({ "bis", "main", "minor", "os", "tm", "pass", "bid", "roll100", "roll50", "roll25", "withdraw" }) do tipped(card[key], "card " .. key) end
tipped(LC.passRest, "pass the rest"); tipped(LC.minButton, "shrink")
LW.Open()
tipped(LW.rows[1].give, "give"); tipped(LW.rows[1].vote, "vote"); tipped(LW.closeSession, "close session")
GC.Open()
tipped(GC.chipAll, "chip all"); tipped(GC.chipOfficer, "chip officers")
print("ok")
