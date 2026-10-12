STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local C, B, D, G, R = ns.Comm, ns.Board, ns.Dungeons, ns.Goals, ns.Roster
local today = math.floor(time() / 86400)
STUB.guildMembers = { Tester = true, Mario = true, Jefa = true }
STUB.guildRoles = { Jefa = 2 }
R.InvalidateGuildRoster()
STUB.Receive("LVLM2", C.Encode("hb", { l = 30, z = 1421 }), "GUILD", "Mario-Testrealm")
STUB.Receive("LVLM2", C.Encode("hb", { l = 40, z = 1421 }), "GUILD", "Jefa-Testrealm")

-- #1: both Scarlet Monastery wings are one instance named "Scarlet Monastery" in game
assert(D.Matches(13, "Scarlet Monastery") and D.Matches(14, "Monasterio Escarlata") and D.Matches(5, D.Name(5)), "instance names match")
assert(not D.Matches(5, "Scarlet Monastery") and not D.Matches(99, "x"), "and only those")
STUB.Receive("LVLM2", C.Encode("go", { id = "sm01", ty = "dun", a = 14, s = today, e = today + 3 }), "GUILD", "Jefa-Testrealm")
ns.Journal.Add("dungeon", { name = "Scarlet Monastery", mates = { "Mario" } })
assert(G.Get("sm01").doneBy == "Tester", "a Library goal completes inside the Monastery")

-- #2: long names get two lines on their card
B.ShowTab("lfg")
for _, c in ipairs(B.cards) do
	if c:IsShown() then
		assert(c.name.wordWrap == true and c.name:GetHeight() >= 24, "two lines for the name: " .. tostring(c.name.text))
		assert(B.ART_H + 6 + c.name:GetHeight() <= B.CARD_H - 18, "name stays clear of the levels line")
	end
end
