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
local told = 0
for i = before + 1, #STUB.printed do if STUB.printed[i]:find("/lm informe", 1, true) then told = told + 1 end end
assert(told == 1, "told once where to look: " .. told)
assert(ns.db.blocked and #ns.db.blocked == 2, "kept across reloads")
