-- Automatic by default (the client's language); the option offers a reload when changed.
STUB.locale = "esES"
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
local L = ns.L
assert(ns.db.settings.language == "auto" and L.TAB_MATES == "Hermanos", "automatic: the client's Spanish")
local setting
for _, s in ipairs(ns.Settings.AllSettings()) do if s.name == L.OPT_LANGUAGE then setting = s end end   -- Ruling 2026-10-16: one dropdown
assert(setting and setting.dropdown, "the language dropdown in the options")
setting:SetValue("enUS")
assert(ns.db.settings.language == "enUS" and STUB.lastPopup == "LEVELMATES_RELOAD", "saved, and a reload offered")
