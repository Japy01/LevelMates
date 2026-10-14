-- the game blocks one of our actions: what it was goes in /lm informe (and the chat says where to find it, once)
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(30)
local L, RP = ns.L, ns.Report
local before = #STUB.printed
STUB.Fire("ADDON_ACTION_BLOCKED", "LevelMates", "UNKNOWN()")
STUB.Fire("ADDON_ACTION_FORBIDDEN", "LevelMates", "ToggleTalentFrame()")
STUB.Fire("ADDON_ACTION_BLOCKED", "OtroAddon", "CastSpellByName()")
local text = RP.Text()
assert(text:find("UNKNOWN()", 1, true) and text:find("ToggleTalentFrame()", 1, true), "both in the report:\n" .. text)
assert(not text:find("CastSpellByName", 1, true), "not another addon's")
STUB.Advance(1)   -- the notice is said a moment later, not inside the blocked call (that would taint the chat frame)
local told = 0
for i = before + 1, #STUB.printed do if STUB.printed[i]:find("/lm informe", 1, true) then told = told + 1 end end
assert(told == 1, "told once where to look: " .. told)
assert(ns.db.blocked and #ns.db.blocked == 2, "kept across reloads")

-- where it came from: the stack at that moment (the event fires inside the call), trimmed to our own lines
debugstack = function() return "[string \"=[C]\"]: in function `NotifyInspect'\nInterface/AddOns/LevelMates/Gear.lua:134: in function `Inspect'\nInterface/AddOns/LevelMates/GearWindow.lua:120: in function `Open'\nInterface/AddOns/Blizzard_UIParent/Blizzard_UIParent.lua:10: in function <...>\n" end
STUB.Fire("ADDON_ACTION_FORBIDDEN", "LevelMates", "UNKNOWN()")
local text = RP.Text()
assert(text:find("Gear.lua:134", 1, true) and text:find("GearWindow.lua:120", 1, true), "our lines in the report:\n" .. text)
assert(not text:find("Blizzard_UIParent", 1, true), "not the game's own lines")
