-- Minimap button: sits on the minimap edge at a saved angle, drag to move, left toggles the board,
-- right opens the options, tooltip explains, and the options switch shows or hides it live.
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
local M, L = ns.MinimapButton, ns.L
assert(M and M.button, "button created")
local b = M.button
assert(b:IsShown(), "visible by default")

-- placement on the edge: radius = half the minimap + 5
M.Place(0)
assert(b.point and b.point[1] == "CENTER" and math.abs(b.point[4] - 75) < 0.01 and math.abs(b.point[5]) < 0.01, "angle 0 is to the right")
M.Place(90)
assert(math.abs(b.point[4]) < 0.01 and math.abs(b.point[5] - 75) < 0.01, "angle 90 is up")
-- cursor to angle
assert(M.AngleFromCursor(110, 100, 100, 100) == 0, "right of centre")
assert(M.AngleFromCursor(100, 110, 100, 100) == 90, "above")
assert(M.AngleFromCursor(90, 100, 100, 100) == 180, "left")
assert(M.AngleFromCursor(100, 90, 100, 100) == 270, "below")

-- dragging follows the cursor and saves the angle
STUB.minimapCenter = { 100, 100 }
b.scripts.OnDragStart(b)
assert(b.scripts.OnUpdate, "follows the cursor while dragging")
STUB.cursor = { 100, 200 }
b.scripts.OnUpdate(b)
assert(ns.db.settings.minimapAngle == 90, "angle saved from the cursor: " .. tostring(ns.db.settings.minimapAngle))
b.scripts.OnDragStop(b)
assert(b.scripts.OnUpdate == nil, "stops following when released")

-- clicks
local toggled = 0
ns.On("LM_TOGGLE_BOARD", function() toggled = toggled + 1 end)
b.scripts.OnClick(b, "LeftButton")
assert(toggled == 1, "left click toggles the board")
local opened
Settings.OpenToCategory = function(id) opened = id end
b.scripts.OnClick(b, "RightButton")
assert(opened ~= nil, "right click opens the options")

-- tooltip
b.scripts.OnEnter(b)
assert(GameTooltip.lines[1] == L.BOARD_TITLE and #GameTooltip.lines >= 4, "tooltip title and hints: " .. #GameTooltip.lines)
b.scripts.OnLeave(b)
assert(GameTooltip.hidden, "tooltip hides")

-- the options switch is live
ns.db.settings.minimap = false; ns.Fire("LM_MINIMAP_CHANGED")
assert(not b:IsShown(), "hidden when the option is off")
ns.db.settings.minimap = true; ns.Fire("LM_MINIMAP_CHANGED")
assert(b:IsShown(), "shown again")
