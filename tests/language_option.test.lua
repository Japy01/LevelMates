-- Automatic by default (the client's language); the option offers a reload when changed.
STUB.locale = "esES"
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
local L = ns.L
assert(ns.db.settings.language == "auto" and L.TAB_MATES == "Hermanos", "automatic: the client's Spanish")
local setting
for _, s in ipairs(ns.Settings.AllSettings()) do if s.name == L.OPT_LANGUAGE .. ": English" then setting = s end end
assert(setting, "an English choice in the options")
setting:SetValue(true)
assert(ns.db.settings.language == "enUS" and STUB.lastPopup == "LEVELMATES_RELOAD", "saved, and a reload offered")
