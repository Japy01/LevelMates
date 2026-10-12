STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local C = ns.Comm
STUB.Receive("LVLM2", C.Encode("hb", { l = 30, z = 1421, g = 1, s = 1, c = "MAGE" }), "GUILD", "Mario-Testrealm")
ns.Board.Toggle(); ns.Board.ShowTab("mates")   -- the board opens on Home; this test is about Guildmates
assert(ns.Board.frame:IsShown(), "shown")
assert(ns.Board.rows[1].name.text:find("Mario"), "row 1 is Mario: " .. tostring(ns.Board.rows[1].name.text))
assert(ns.Board.rows[1].group.text == ns.L.GROUP_FREE, "group column")
ns.Board.Toggle()
assert(not ns.Board.frame:IsShown(), "hidden")
-- invite only from a click handler: the row's OnClick calls C_PartyInfo.InviteUnit
local invited
C_PartyInfo = { InviteUnit = function(n) invited = n end }
ns.Board.rows[1].button.scripts.OnClick(ns.Board.rows[1].button, "RightButton")
assert(ns.Board.lastMenuFor == "Mario", "context menu opened for the row")
ns.Board.Invite("Mario")
assert(invited == "Mario", "invite called")
