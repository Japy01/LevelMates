STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local C, AL, MC, B, L = ns.Comm, ns.Alts, ns.MateCard, ns.Board, ns.L
local function last(kind) for i = #STUB.sent, 1, -1 do local k, f = C.Decode(STUB.sent[i].msg); if k == kind then return f end end end
assert(ns.db.settings.shareAlts == true, "on by default")
assert(C.Validate("al", { n = "Pepemago,Pepecura" }) and C.Validate("al", {}), "al format")

-- this character is noted in the account's data; other characters were noted when they logged in
local me = AL.Chars()[ns.PlayerKey()]
assert(me and me.name == "Tester" and me.level == 20 and me.guild == "Test Guild", "this character noted")
ns.db.characters["Testalt-Testrealm"] = { name = "Testalt", realm = "Testrealm", level = 14, class = "MAGE", guild = "Test Guild", t = time() }
ns.db.characters["Outsider-Testrealm"] = { name = "Outsider", realm = "Testrealm", level = 30, class = "ROGUE", guild = "Other Guild", t = time() }
ns.db.characters["Farrealm-Elsewhere"] = { name = "Farrealm", realm = "Elsewhere", level = 30, class = "ROGUE", guild = "Test Guild", t = time() }
local mine = AL.MyAlts()
assert(#mine == 1 and mine[1].name == "Testalt", "only my other characters in this same guild and realm")

-- shared with the guild
AL.SetSharing()
assert(last("al") and last("al").n == "Testalt", "sent")
ns.db.settings.shareAlts = false
AL.SetSharing()
assert(last("al").n == nil, "off withdraws")
ns.db.settings.shareAlts = true

-- a guildmate's alts on their card and in the board tooltip
STUB.guildMembers = { Tester = true, Mario = true, Mariomago = true, Ana = true }
ns.Roster.InvalidateGuildRoster()
STUB.Receive("LVLM", C.Encode("hb", { l = 24, z = 1421, c = "WARRIOR" }), "GUILD", "Mario-Testrealm")
STUB.Receive("LVLM", C.Encode("al", { n = "Mariomago,Fuera" }), "GUILD", "Mario-Testrealm")
local of = AL.Of("Mario")
assert(#of == 1 and of[1] == "Mariomago", "only alts still in the guild")
assert(table.concat(MC.Lines("Mario"), "\n"):find(string.format(L.CARD_ALTS, "Mariomago"), 1, true), "on the card")
B.Toggle(); B.ShowTab("mates")
for _, r in ipairs(B.rows) do
	if r.button.mate == "Mario" then
		r.button.scripts.OnEnter(r.button)
		local hit
		for _, line in ipairs(GameTooltip.lines) do if line == string.format(L.CARD_ALTS, "Mariomago") then hit = true end end
		assert(hit, "in the board tooltip")
	end
end

-- /lm alts: my own card with my characters here
SlashCmdList.LEVELMATES("alts")
assert(MC.name == "Tester" and MC.frame:IsShown(), "my card")
local text = table.concat(MC.Lines("Tester"), "\n")
assert(text:find("Testalt", 1, true) and text:find("14", 1, true) and text:find("Tester", 1, true) and not text:find("Outsider", 1, true), "my characters: " .. text)
assert(not MC.whisper:IsShown() and not MC.invite:IsShown(), "no whispering myself")
