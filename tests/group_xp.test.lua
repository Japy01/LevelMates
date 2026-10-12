STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local C, GX, L = ns.Comm, ns.GroupXP, ns.L
local function count(kind, from) local n = 0; for i = (from or 0) + 1, #STUB.sent do if C.Decode(STUB.sent[i].msg) == kind then n = n + 1 end end; return n end
local function last(kind) for i = #STUB.sent, 1, -1 do local k, f = C.Decode(STUB.sent[i].msg); if k == kind then return f end end end
assert(ns.db.settings.groupXp == true, "on by default")
assert(C.Validate("xp", { p = 45, l = 20 }) and not C.Validate("xp", { p = 101, l = 20 }), "xp format")

-- alone, or grouped with nobody from the guild: nothing goes out and nothing shows
STUB.player.xp = 450
STUB.Fire("PLAYER_XP_UPDATE", "player"); STUB.Advance(31)
assert(count("xp") == 0, "not in a group")
STUB.Receive("LVLM2", C.Encode("hb", { l = 21, z = 1421, c = "MAGE" }), "GUILD", "Mario-Testrealm")
STUB.Receive("LVLM2", C.Encode("hb", { l = 19, z = 1421, c = "PRIEST" }), "GUILD", "Ana-Testrealm")
assert(not (GX.frame and GX.frame:IsShown()), "no window alone")

-- grouped with Mario: mine goes out, at most every 30 seconds
STUB.partyMembers = { Mario = true }
STUB.Fire("GROUP_ROSTER_UPDATE"); STUB.Advance(3)
assert(last("xp") and last("xp").p == 45 and last("xp").l == 20, "sent on joining: " .. tostring(last("xp") and last("xp").p))
local n = #STUB.sent
STUB.player.xp = 500; STUB.Fire("PLAYER_XP_UPDATE", "player"); STUB.Advance(1)
STUB.player.xp = 520; STUB.Fire("PLAYER_XP_UPDATE", "player"); STUB.Advance(1)
assert(count("xp", n) == 0, "not every kill")
STUB.Advance(30)
assert(count("xp", n) == 1 and last("xp").p == 52, "once the 30 seconds pass, the newest")

-- theirs: a bar per grouped guildmate, me first
STUB.Receive("LVLM2", C.Encode("xp", { p = 80, l = 21 }), "GUILD", "Mario-Testrealm")
STUB.Receive("LVLM2", C.Encode("xp", { p = 10, l = 19 }), "GUILD", "Ana-Testrealm")
local rows = GX.Rows()
assert(#rows == 2 and rows[1].mine and rows[1].pct == 52 and rows[2].name == "Mario" and rows[2].pct == 80 and rows[2].level == 21, "me and Mario; Ana is not in my group")
assert(GX.frame and GX.frame:IsShown(), "the window shows")
assert(GX.frame.rows[2].text.text:find("Mario", 1, true) and GX.frame.rows[2].fill:GetWidth() == math.floor(GX.BAR_W * 0.8), "Mario's bar at 80%")

-- leaving the group hides it; the option turns it all off
STUB.partyMembers = {}
STUB.Fire("GROUP_ROSTER_UPDATE"); STUB.Advance(3)
assert(not GX.frame:IsShown(), "hidden out of the group")
STUB.partyMembers = { Mario = true }
ns.db.settings.groupXp = false
n = #STUB.sent
STUB.Fire("GROUP_ROSTER_UPDATE"); STUB.Advance(40)
assert(count("xp", n) == 0 and not GX.frame:IsShown(), "off: nothing sent or shown")

-- minimise and close
ns.db.settings.groupXp = true
STUB.partyMembers = { Mario = true }
STUB.Receive("LVLM2", C.Encode("hb", { l = 21, z = 1421, c = "MAGE" }), "GUILD", "Mario-Testrealm")
STUB.Receive("LVLM2", C.Encode("xp", { p = 70, l = 21 }), "GUILD", "Mario-Testrealm")
assert(GX.frame:IsShown(), "shown")
GX.frame.minimize.scripts.OnClick(GX.frame.minimize)
assert(GX.frame:GetHeight() == 22 and not GX.frame.rows[1].text:IsShown(), "minimised: the title only")
GX.frame.minimize.scripts.OnClick(GX.frame.minimize)
assert(GX.frame:GetHeight() > 22 and GX.frame.rows[1].text:IsShown(), "back open")
GX.frame.close.scripts.OnClick(GX.frame.close)
GX.Refresh()
assert(not GX.frame:IsShown(), "closed stays closed")
SlashCmdList.LEVELMATES("xp")
assert(GX.frame:IsShown(), "/lm xp brings it back")
