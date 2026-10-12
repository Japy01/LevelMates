STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local C, B, W, P, R, L = ns.Comm, ns.Board, ns.Wishlist, ns.Personal, ns.Roster, ns.L
local function said(text) for i = #STUB.printed, 1, -1 do if STUB.printed[i]:find(text, 1, true) then return true end end; return false end
STUB.guildMembers = { Tester = true, Mario = true, Ana = true, Luis = true }
R.InvalidateGuildRoster()

-- #1: loot links with the client's named quality colours ("|cnIQ3:") are still read
local named = "|cnIQ3:|Hitem:6666::::::::20:::::::|h[Blue Sword]|h|r"
assert(W.Add(named) and W.Has(6666), "added from a named-colour link")
STUB.Fire("CHAT_MSG_LOOT", "You receive loot: " .. named .. ".", "Tester", "", "", "Tester", "", 0, 0, "", 0, 1, "Player-1-TESTER")
assert(not W.Has(6666) and said(string.format(L.WISH_GOT, named)), "my wish, looted with a named colour")
local last = ns.Journal.List("item", "")[1]
assert(last and last.link == named and last.q == 3, "the journal records it with its quality")

-- #2: more than 20 wishes: pages
for _, who in ipairs({ "Mario", "Ana", "Luis" }) do
	STUB.Receive("LVLM2", C.Encode("hb", { l = 20, z = 1421 }), "GUILD", who .. "-Testrealm")
	STUB.Receive("LVLM2", C.Encode("wl", { ids = "1,2,3,4,5,6,7,8,9,10" }), "GUILD", who .. "-Testrealm")
end
assert(#W.List() == 30, "30 wishes")
B.ShowTab("wishes")
local function shown() local n = 0; for i = 1, #B.rows do if B.rows[i].button:IsShown() then n = n + 1 end end; return n end
assert(shown() == 20 and B.journalNext:IsShown() and B.journalPageText.text == string.format(L.J_PAGE, 1, 2), "page 1 of 2")
B.journalNext.scripts.OnClick(B.journalNext)
assert(shown() == 10 and B.rows[1].name.text == "Mario" and B.journalPageText.text == string.format(L.J_PAGE, 2, 2), "page 2 has Mario's wishes (by name)")
for _, who in ipairs({ "Ana", "Luis" }) do STUB.Receive("LVLM2", C.Encode("wl", {}), "GUILD", who .. "-Testrealm") end
STUB.Advance(0.6)   -- changes redraw the open page at most twice a second
assert(shown() == 10 and not B.journalNext:IsShown(), "one page: no pager")

-- #3: a whole-state send dropped from the queue on entering an instance goes out again later
local function lastOf(kind) for i = #STUB.sent, 1, -1 do local k, f = C.Decode(STUB.sent[i].msg); if k == kind then return f, i end end end
STUB.throttleNext = 1
assert(W.Add("|cff1eff00|Hitem:7777::::::::20:::::::|h[Late]|h|r"), "added")
assert(not LevelMatesDB.chars[ns.PlayerKey()].wishPending, "queued, not refused")
STUB.inInstance = true; STUB.Advance(1)
assert(LevelMatesDB.chars[ns.PlayerKey()].wishPending == true, "dropped inside: pending again")
STUB.inInstance = false
ns.Fire("LM_HB_SENT")
local f = lastOf("wl")
assert(f and tostring(f.ids) == "7777", "goes out after the heartbeat")
-- the same for a personal goal
STUB.player.level = 30
STUB.throttleNext = 1
assert(P.Set(40, 7))
STUB.inInstance = true; STUB.Advance(1)
assert(LevelMatesDB.chars[ns.PlayerKey()].goalPending == true, "personal goal: pending again")
STUB.inInstance = false
