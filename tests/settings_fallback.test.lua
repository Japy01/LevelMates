-- a client without the modern controls (no dropdowns, no sliders): one checkbox per choice, as before, and no headers
Settings.CreateDropdown = nil; Settings.CreateControlTextContainer = nil; Settings.CreateSlider = nil; Settings.CreateSliderOptions = nil
SettingsPanel = nil
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local S, L = ns.Settings, ns.L
local function named(name) for _, s in ipairs(S.AllSettings()) do if s.name == name then return s end end end
assert(named(L.OPT_ROLE .. ": " .. L.ROLE_T) and named(L.OPT_LANGUAGE .. ": English") and named(L.OPT_SIZE .. ": " .. L.SIZE_BIG) and named(L.OPT_TRANSPORT .. ": " .. L.TRANSPORT_GUILD), "a checkbox per choice")
assert(not named(L.OPT_ROLE) and not named(L.OPT_SIZE), "no dropdown or slider")
local en = named(L.OPT_LANGUAGE .. ": English")
en:SetValue(true)
assert(ns.db.settings.language == "enUS", "the choice still works")
named(L.OPT_SIZE .. ": " .. L.SIZE_BIG):SetValue(true)
assert(ns.db.settings.boardScale == 115, "the size choice still works")
