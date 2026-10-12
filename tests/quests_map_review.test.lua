-- project 3 final review fixes
function WorldMapFrame:OnCanvasScaleChanged() end
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(30)
local GM, C, B, QH, L = ns.GuildMap, ns.Comm, ns.Board, ns.Questhub, ns.L
local function hb(name, x, y, z) STUB.Receive("LVLM2", C.Encode("hb", { l = 20, z = z or 1412, x = x, y = y, c = "MAGE" }), "GUILD", name .. "-Testrealm") end
STUB.guildMembers.Pepe = true; ns.Roster.InvalidateGuildRoster()
STUB.worldMapId = 1412
-- 1: four guildmates 10 canvas px apart: one bundle zoomed out (0.5), none zoomed in (2)
hb("Ana", 40, 40); hb("Luis", 41, 40); hb("Mario", 42, 40); hb("Pepe", 43, 40)
local zoom = 0.5
WorldMapFrame.ScrollContainer = { GetCanvasScale = function() return zoom end }
WorldMapFrame:Show(); WorldMapFrame:OnMapChanged()
local function shown() local n = 0; for _, p in ipairs(GM.pins) do if p:IsShown() then n = n + 1 end end; return n end
assert(shown() == 1, "1: zoomed out, one bundle: " .. shown())
-- 2: zooming redraws
zoom = 2
WorldMapFrame:OnCanvasScaleChanged(); STUB.Advance(1)
assert(shown() == 4, "2: zoomed in, four pins again: " .. shown())
-- 6: a bundle's click routes to the name it shows
zoom = 0.5; WorldMapFrame:OnCanvasScaleChanged(); STUB.Advance(1)
local routed, rx
ns.Help.WaypointTo = function(mapId, x, y, label) routed, rx = label, x end
for _, p in ipairs(GM.pins) do if p:IsShown() then p.scripts.OnClick(p, "LeftButton") end end
assert(routed == "Ana" and rx == 40, "6: to Ana, where Ana is")
-- 3: another continent is not drawn even if the API gives a position for the override map
CreateVector2D = CreateVector2D or function(x, y) return { x = x, y = y, GetXY = function(self) return self.x, self.y end } end
C_Map.GetWorldPosFromMapPos = function(mapId, pos) return (mapId == 1412 and 1 or 0), CreateVector2D(pos.x, pos.y) end
C_Map.GetMapPosFromWorldPos = function(cont, world, override) return 1414, CreateVector2D(world.x, world.y) end
assert(#GM.Layout(1415, 1000, 700, 18) == 0, "3: a position on another map id: rejected")
C_Map.GetMapPosFromWorldPos = function(cont, world, override) return override, CreateVector2D(world.x, world.y) end
assert(#GM.Layout(1415, 1000, 700, 18) == 0, "3: another continent (0 vs 1): rejected")
-- 4: the Quests view: no button under another
B.Toggle(); B.ShowTab("lfg")
B.questsButton.scripts.OnClick(B.questsButton)
assert(not (B.lfgButton and B.lfgButton:IsShown()), "4: the group-ad button hides in the Quests view")
assert(B.questPostButton:GetWidth() <= 130, "4: the post button fits")
-- 5: a title with nothing printable: posted under its number, never a broken record
STUB.quests = { 777 }
local realInfo = C_QuestLog.GetInfo
C_QuestLog.GetInfo = function(i) return { questID = 777, title = "||", isHeader = false } end
assert(QH.Post(777), "5: posted")
local f
for i = #STUB.sent, 1, -1 do local k, ff = C.Decode(STUB.sent[i].msg); if k == "qh" then f = ff; break end end
assert(f and f.t == "#777", "5: under its number: " .. tostring(f and f.t))
C_QuestLog.GetInfo = realInfo
