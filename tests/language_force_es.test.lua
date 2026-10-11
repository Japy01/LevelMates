-- An English client with Spanish forced in the options: everything in Spanish, binding names too.
STUB.locale = "enUS"
LevelMatesDB = { version = 1, settings = { language = "esES" }, chars = {} }
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
local L = ns.L
assert(L.TAB_MATES == "Hermanos" and L.HEAD_GOALS == "Metas", "Spanish forced: " .. tostring(L.TAB_MATES))
assert(BINDING_NAME_LEVELMATES_PANIC == "Pedir ayuda ya", "panic binding in Spanish: " .. tostring(BINDING_NAME_LEVELMATES_PANIC))
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
ns.Board.Toggle()
assert(ns.Board.tabs.mates.label == "Hermanos", "the board in Spanish")
