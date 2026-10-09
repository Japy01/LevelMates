-- Keybinding: Bindings.xml calls a global that toggles the board, and the binding has a readable name.
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
assert(type(LevelMates_ToggleBoard) == "function", "global the binding calls exists")
LevelMates_ToggleBoard()
assert(ns.Board.frame and ns.Board.frame:IsShown(), "binding opens the board")
LevelMates_ToggleBoard()
assert(not ns.Board.frame:IsShown(), "and closes it")
assert(BINDING_NAME_LEVELMATES_TOGGLE == ns.L.BINDING_TOGGLE, "binding name localized: " .. tostring(BINDING_NAME_LEVELMATES_TOGGLE))
