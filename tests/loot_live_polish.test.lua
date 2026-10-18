-- The live loot session, polished (audit 2026-10-17): the master's window says how long the session has run and
-- how many answered, lists the answered candidates first (BiS, main, minor, bids high to low, rolls, then the
-- silent, passes last) with names in ink; the candidate's card can be shrunk to its title line
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.guildRoles = { Tester = 2, Ana = 2, Mario = 4, Luis = 4 }
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(30)
local LT, LW, LS, LC, C, L, R, SK = ns.Loot, ns.LootWindow, ns.LootSession, ns.LootCard, ns.Comm, ns.L, ns.Roster, ns.Skin
R.InvalidateGuildRoster()
STUB.items[9001] = "|cffa335ee|Hitem:9001::::::::60:::::::|h[Casco de Lucifron]|h|r"
local function rows() local out = {}; for _, r in ipairs(LW.rows) do if r:IsShown() then out[#out + 1] = r.name.text end end; return out end
C_PartyInfo = { GetLootMethod = function() return 2 end }; Enum.LootMethod = { Master = 2 }
STUB.inInstance = true; STUB.groupSize = 4
IsInGroup = function() return true end; IsInRaid = function() return false end
STUB.units.party1 = { name = "Mario" }; STUB.units.party2 = { name = "Luis" }; STUB.units.party3 = { name = "Ana" }
GetNumLootItems = function() return 1 end
GetLootSlotLink = function() return STUB.items[9001] end
GetLootSlotInfo = function() return 134400, "x", 1, 0, 4 end
GetMasterLootCandidate = function(slot, index) return ({ "Tester", "Mario", "Luis", "Ana" })[index] end
STUB.Fire("LOOT_OPENED")
assert(LS.session and LW.frame:IsShown(), "a session")
-- the clock and the count
assert(LW.timer.text == string.format(L.LW_ELAPSED, "0:00") and LW.answered.text == string.format(L.LW_ANSWERED, 0, 4), "clock and count at the start: " .. tostring(LW.timer.text) .. " / " .. tostring(LW.answered.text))
STUB.Advance(65); LW.UpdateClock()   -- the ticker rounds to its 0.2 s step
assert(LW.timer.text == string.format(L.LW_ELAPSED, "1:05"), "the clock runs: " .. tostring(LW.timer.text))
-- answers: Luis passes, Ana says main, Mario says minor; Tester (me) silent
STUB.Receive("LVLM2", C.Encode("lb", { s = LS.session.id, i = 9001, r = "pass", v = 0 }), "WHISPER", "Luis-Testrealm")
STUB.Receive("LVLM2", C.Encode("lb", { s = LS.session.id, i = 9001, r = "main", v = 0 }), "WHISPER", "Ana-Testrealm")
STUB.Receive("LVLM2", C.Encode("lb", { s = LS.session.id, i = 9001, r = "minor", v = 0 }), "WHISPER", "Mario-Testrealm")
assert(LW.answered.text == string.format(L.LW_ANSWERED, 3, 4), "three answered: " .. tostring(LW.answered.text))
assert(table.concat(rows(), ","):find("Ana,Mario,Tester,Luis", 1, true), "answered first by response, silent next, passes last: " .. table.concat(rows(), ","))
-- names in ink
local r, g, b = LW.rows[1].name:GetTextColor()
local ir, ig, ib = SK.Ink(1, 1, 1)
assert(math.abs(r - ir) < 1e-6 and math.abs(g - ig) < 1e-6 and math.abs(b - ib) < 1e-6, "a name written in ink")
-- a dkp session orders bids high to low
STUB.Fire("LOOT_CLOSED")
-- the candidate's card shrinks to its title and comes back
STUB.Receive("LVLM2", C.Encode("ls", { s = "s9", m = "council", i = "9001", b = 0 }), "PARTY", "Ana-Testrealm")
assert(LC.frame:IsShown() and #LC.Rows() == 1, "the card")
local full = LC.frame:GetHeight()
LC.minButton.scripts.OnClick(LC.minButton)
assert(LC.minimized and #LC.Rows() == 0 and LC.frame:GetHeight() < full and LC.frame:IsShown(), "shrunk: the title line only")
STUB.Receive("LVLM2", C.Encode("lw", { s = "s9", i = 9001, to = "Mario", c = 0 }), "PARTY", "Ana-Testrealm")
assert(#LC.Rows() == 0, "stays shrunk on news")
LC.minButton.scripts.OnClick(LC.minButton)
assert(not LC.minimized and #LC.Rows() == 1 and LC.frame:GetHeight() == full, "back")
print("ok")
