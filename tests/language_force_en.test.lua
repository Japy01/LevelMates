-- A Spanish client with English forced in the options: everything in English.
STUB.locale = "esES"
LevelMatesDB = { version = 1, settings = { language = "enUS" }, chars = {} }
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
local L = ns.L
assert(L.TAB_MATES == "Guildmates" and L.HEAD_GOALS == "Goals", "English forced: " .. tostring(L.TAB_MATES))
assert(BINDING_NAME_LEVELMATES_TOGGLE == "Show or hide the LevelMates board" or BINDING_NAME_LEVELMATES_TOGGLE == L.BINDING_TOGGLE, "key binding names follow")
assert(BINDING_NAME_LEVELMATES_PANIC == L.BINDING_PANIC and L.BINDING_PANIC == "Ask for help now", "panic binding in English")
