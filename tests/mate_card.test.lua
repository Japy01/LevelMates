STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local C, B, L, MC = ns.Comm, ns.Board, ns.L, ns.MateCard
STUB.items[2589] = "|cffffffff|Hitem:2589::::::::20:::::::|h[Linen Cloth]|h|r"
STUB.items[765] = "|cffffffff|Hitem:765::::::::20:::::::|h[Silverleaf]|h|r"
STUB.Receive("LVLM2", C.Encode("hb", { l = 24, z = 1421, c = "WARRIOR", g = 1, s = 1, x = 40, y = 50 }), "GUILD", "Mario-Testrealm")
STUB.Receive("LVLM2", C.Encode("pf", { p = "171:120,182:95" }), "GUILD", "Mario-Testrealm")
STUB.Receive("LVLM2", C.Encode("wl", { ids = "2589" }), "GUILD", "Mario-Testrealm")
STUB.Receive("LVLM2", C.Encode("gv", STUB.Rec{ id = ns.NameKey("Mario"), ids = "765"}), "GUILD", "Mario-Testrealm")
STUB.Receive("LVLM2", C.Encode("tb", { c = "WARRIOR", s = 71, l = 24, p = "1001:15", b = "CODEmario" }), "GUILD", "Mario-Testrealm")
ns.Feed.AddSample("Mario", "lvl", 24, nil, 5)

local text = table.concat(MC.Lines("Mario"), "\n")
local function has(s) return text:find(s, 1, true) ~= nil end
assert(has("24") and has("Map 1421"), "level and zone: " .. text)
assert(has(ns.Professions.Name(171) .. " 120") and has(ns.Professions.Name(182) .. " 95"), "professions")
assert(has("[Linen Cloth]") and has("[Silverleaf]"), "wishes and giveaways")
assert(has(ns.Builds.PointsText(ns.Builds.Of("Mario"))), "build")
assert(has(ns.Feed.Text(ns.Feed.List()[1])), "the latest on the wall")

-- a left click on the board opens it, with its buttons
B.Toggle()
B.ShowTab("mates")
local row
for _, r in ipairs(B.rows) do if r.button.mate == "Mario" then row = r end end
row.button.scripts.OnClick(row.button, "LeftButton")
assert(MC.frame and MC.frame:IsShown() and MC.name == "Mario", "opened")
assert(MC.frame.body.text == ns.Skin.InkText(table.concat(MC.Lines("Mario"), "\n")), "showing the lines (in ink)")
MC.whisper.scripts.OnClick(MC.whisper)
assert(STUB.lastTell == "Mario", "whisper")
local invited
C_PartyInfo = { InviteUnit = function(n) invited = n end }
MC.invite.scripts.OnClick(MC.invite)
assert(invited == "Mario", "invite")
assert(MC.waypoint:IsShown() and MC.build:IsShown(), "waypoint and build when there are")
local ref
SetItemRef = function(link) ref = link end
MC.build.scripts.OnClick(MC.build)
-- Ruling: View build opens our talent viewer; the game's link is one click away in it
assert(ns.TalentView.frame:IsShown() and ns.TalentView.entry.name == "Mario", "view build: our viewer")
ns.TalentView.gameButton.scripts.OnClick(ns.TalentView.gameButton)
assert((STUB.printed[#STUB.printed] or ""):find("|Htalentbuild:71:24:CODEmario|h", 1, true), "and the game's link from it")
ns.TalentView.frame:Hide()

-- someone with nothing shared: just the basics, no waypoint or build
STUB.Receive("LVLM2", C.Encode("hb", { l = 12, z = 1412, c = "MAGE" }), "GUILD", "Ana-Testrealm")
MC.Show("Ana")
assert(#MC.Lines("Ana") >= 1 and not MC.waypoint:IsShown() and not MC.build:IsShown(), "the basics only")

-- the route: the pin, followed on screen, and said in chat; or why not
local pinned, followed
C_Map.CanSetUserWaypointOnMap = function(id) return id ~= 999 end
C_Map.SetUserWaypoint = function(p) pinned = p end
UiMapPoint = { CreateFromCoordinates = function(id, x, y) return { id = id, x = x, y = y } end }
C_SuperTrack = { SetSuperTrackedUserWaypoint = function(v) followed = v end }
-- with the book open, what a click did goes to its foot: count it with chat
local told = {}
do local fb = ns.Board.Feedback; ns.Board.Feedback = function(t) told[#told + 1] = t; fb(t) end end
local function lastSaid() return told[#told] or STUB.printed[#STUB.printed] end
local function said() return #STUB.printed + #told end
local n = said()
assert(ns.Help.WaypointTo(1429, 40, 60, "Mario") and pinned.id == 1429 and followed, "pinned and followed")
assert(lastSaid():find("Mario", 1, true) and said() == n + 1, "said where")
assert(not ns.Help.WaypointTo(999, 40, 60, "Mario") and lastSaid():find("999", 1, true), "why not")
followed = nil; n = said()
ns.Help.WaypointTo(1429, 40, 60)
assert(not followed and said() == n, "an automatic pin: quiet")
C_SuperTrack, UiMapPoint, C_Map.CanSetUserWaypointOnMap, C_Map.SetUserWaypoint = nil, nil, nil, nil
