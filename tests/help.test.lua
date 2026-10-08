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
