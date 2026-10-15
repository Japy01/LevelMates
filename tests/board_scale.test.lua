-- the book's size: a scale on the whole frame (80-150 %), from Options or /lm tamaño N; kept in the settings
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local B = ns.Board
assert(ns.db.settings.boardScale == 100, "normal by default")
B.Toggle()
assert(math.abs(B.frame:GetScale() - 1) < 0.001, "drawn at 100%")
assert(B.SetScale(130) and ns.db.settings.boardScale == 130 and math.abs(B.frame:GetScale() - 1.3) < 0.001, "bigger")
assert(not B.SetScale(500) and not B.SetScale("x") and ns.db.settings.boardScale == 130, "out of range: refused, nothing changes")
SlashCmdList["LEVELMATES"]("tamaño 115")
assert(ns.db.settings.boardScale == 115 and math.abs(B.frame:GetScale() - 1.15) < 0.001, "the command")
SlashCmdList["LEVELMATES"]("size")
assert(ns.db.settings.boardScale == 115, "no number: help, unchanged")

-- two small buttons on the book itself, by the close button: 10 % a step, greyed at the ends
B.SetScale(100)
assert(B.scaleUp and B.scaleDown and B.scaleUp:IsShown() and B.scaleDown:IsShown(), "the buttons")
B.scaleUp.scripts.OnClick(B.scaleUp)
assert(ns.db.settings.boardScale == 110 and math.abs(B.frame:GetScale() - 1.1) < 0.001, "+10")
for _ = 1, 10 do B.scaleUp.scripts.OnClick(B.scaleUp) end
assert(ns.db.settings.boardScale == 150 and not B.scaleUp:IsEnabled() and B.scaleDown:IsEnabled(), "stops at 150, + greyed")
for _ = 1, 10 do B.scaleDown.scripts.OnClick(B.scaleDown) end
assert(ns.db.settings.boardScale == 80 and not B.scaleDown:IsEnabled() and B.scaleUp:IsEnabled(), "stops at 80, - greyed")
SlashCmdList["LEVELMATES"]("tamaño 100")
assert(B.scaleUp:IsEnabled() and B.scaleDown:IsEnabled(), "both again after the command")
