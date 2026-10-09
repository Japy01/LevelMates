STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local C, H = ns.Comm, ns.Help
local wp
C_Map.SetUserWaypoint = function(p) wp = p end
C_Map.CanSetUserWaypointOnMap = function() return true end
UiMapPoint = { CreateFromCoordinates = function(m, x, y) return { uiMapID = m, x = x, y = y } end }
STUB.player.mapId = 1421
-- ask
H.Ask("Fuerte Colmillo")
local last = STUB.sent[#STUB.sent]
local kind, f = C.Decode(last.msg)
assert(kind == "help" and f.t == "Fuerte Colmillo" and f.z == 1421 and f.x == 50 and f.y == 50, "help sent with position")
assert(H.mine and H.mine.id == f.id, "own request kept")
-- receive someone else's on my map → notice + waypoint
STUB.Receive("LVLM", C.Encode("help", { t = "Elite X", z = 1421, x = 10, y = 20, id = "zz11" }), "GUILD", "Mario-Testrealm")
assert(H.active.zz11 and H.active.zz11.name == "Mario", "stored")
assert(STUB.printed[#STUB.printed]:find("Mario"), "notice")
assert(wp and wp.uiMapID == 1421 and math.abs(wp.x - 0.1) < 0.001, "waypoint set on my map")
-- board lists the request with an "on my way" button, and flips its help button while mine is active
ns.Board.Toggle()
assert(ns.Board.helpButton.text == ns.L.BTN_HELP_CANCEL, "help button flips to cancel: " .. tostring(ns.Board.helpButton.text))
local row = ns.Board.helpRows[1]
assert(row and row.text.text and row.text.text:find("Mario") and row.text.text:find("Elite X"), "active request listed: " .. tostring(row and row.text.text))
STUB.lastChat = nil
row.button.scripts.OnClick(row.button, "LeftButton")
local chat = STUB.lastChat
assert(chat and chat.chatType == "WHISPER" and chat.target == "Mario" and chat.msg == string.format(ns.L.HELP_COMING, "Tester"), "on my way whispers from the click: " .. tostring(chat and chat.msg))
ns.Board.Toggle()
-- another map: notice, no waypoint
wp = nil
STUB.Receive("LVLM", C.Encode("help", { t = "Elite Y", z = 1412, x = 10, y = 20, id = "zz12" }), "GUILD", "Ana-Testrealm")
assert(wp == nil, "no waypoint for another map")
-- helpok clears
STUB.Receive("LVLM", C.Encode("helpok", { id = "zz11" }), "GUILD", "Mario-Testrealm")
assert(H.active.zz11 == nil, "cleared")
-- cancel mine sends helpok (before it would expire on its own)
H.Cancel()
assert(select(1, C.Decode(STUB.sent[#STUB.sent].msg)) == "helpok", "cancel sends helpok")
assert(H.mine == nil, "mine cleared")
-- expiry 10 min
STUB.Advance(601); H.Expire()
assert(H.active.zz12 == nil, "expired")
-- the board button opens the prompt; Okay and Enter read the Mainline dialog's EditBox
ns.Fire("LM_HELP_BUTTON")
assert(STUB.lastPopup == "LEVELMATES_HELP", "prompt shown")
STUB.lastDialog.EditBox:SetText("Ogro")
StaticPopupDialogs.LEVELMATES_HELP.OnAccept(STUB.lastDialog)
kind, f = C.Decode(STUB.sent[#STUB.sent].msg)
assert(kind == "help" and f.t == "Ogro" and H.mine, "popup Okay asks: " .. tostring(kind))
H.Cancel()
ns.Fire("LM_HELP_BUTTON")
STUB.lastDialog.EditBox:SetText("Troll")
StaticPopupDialogs.LEVELMATES_HELP.EditBoxOnEnterPressed(STUB.lastDialog.EditBox)
kind, f = C.Decode(STUB.sent[#STUB.sent].msg)
assert(kind == "help" and f.t == "Troll" and not STUB.lastDialog:IsShown(), "popup Enter asks and closes")
H.Cancel()
-- the prompt tells the user that asking shares their position
ns.Fire("LM_HELP_BUTTON")
assert(StaticPopupDialogs.LEVELMATES_HELP.text:find(ns.L.HELP_POS_WARNING, 1, true), "prompt warns that position is shared")
-- only the asker can clear a request
STUB.Receive("LVLM", C.Encode("help", { t = "Elite W", z = 1412, x = 1, y = 1, id = "own01" }), "GUILD", "Mario-Testrealm")
STUB.Receive("LVLM", C.Encode("helpok", { id = "own01" }), "GUILD", "Ana-Testrealm")
assert(H.active.own01, "someone else cannot clear Mario's request")
STUB.Receive("LVLM", C.Encode("helpok", { id = "own01" }), "GUILD", "Mario-Testrealm")
assert(H.active.own01 == nil, "the asker can")
-- no position available (instance, cinematic): say so, not the generic prompt
local realPos = C_Map.GetPlayerMapPosition
C_Map.GetPlayerMapPosition = function() return nil end
assert(H.Ask("Elite V") == false and STUB.printed[#STUB.printed]:find(ns.L.HELP_NO_POS, 1, true), "position unavailable message: " .. tostring(STUB.printed[#STUB.printed]))
C_Map.GetPlayerMapPosition = realPos
-- sharing off: asking does nothing but tell the user why
ns.db.settings.share = false; C.Stop()
local sentBefore = #STUB.sent
assert(H.Ask("Elite Z") == false and H.mine == nil and #STUB.sent == sentBefore, "no request while invisible")
assert(STUB.printed[#STUB.printed]:find(ns.L.HELP_NEEDS_SHARE, 1, true), "told to turn sharing on: " .. tostring(STUB.printed[#STUB.printed]))
-- truncation to 60 bytes never cuts a UTF-8 character in half
do
	ns.db.settings.share = true; C.Start(); STUB.Advance(1)
	H.Ask(string.rep("a", 59) .. "ñ" .. "zzz")
	local k, ff = C.Decode(STUB.sent[#STUB.sent].msg)
	assert(k == "help" and ff.t == string.rep("a", 59), "cut before the two-byte character, got " .. tostring(ff and #ff.t))
	H.Cancel()
end
