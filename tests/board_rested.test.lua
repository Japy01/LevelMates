STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local C, B, L = ns.Comm, ns.Board, ns.L
STUB.player.level = 20; STUB.player.rested = 450
STUB.Receive("LVLM", C.Encode("hb", { l = 21, z = 1421 }), "GUILD", "Mario-Testrealm")
STUB.Receive("LVLM", C.Encode("rx", { p = 80 }), "GUILD", "Mario-Testrealm")
STUB.Receive("LVLM", C.Encode("hb", { l = 40, z = 1421 }), "GUILD", "Ana-Testrealm")
B.Toggle()
local function rowOf(name) for i = 1, #B.rows do if B.rows[i].name.text == name then return B.rows[i] end end end

assert(B.restedText and B.restedText.text == string.format(L.RESTED_MINE, 45), "my rested next to the heading: " .. tostring(B.restedText and B.restedText.text))
STUB.player.rested = 1000; STUB.Fire("UPDATE_EXHAUSTION")
assert(B.restedText.text == string.format(L.RESTED_MINE, 100), "updates on the event")
B.tabs.lfg.scripts.OnClick(B.tabs.lfg)
assert(B.restedText.text == string.format(L.RESTED_MINE, 100), "also on the Dungeons tab")
B.tabs.mates.scripts.OnClick(B.tabs.mates)

local mario = rowOf("Mario")
mario.button.scripts.OnEnter(mario.button)
assert(GameTooltip.lines[1] == string.format(L.RESTED_THEIRS, 80) and not GameTooltip.hidden, "their rested on hover")
mario.button.scripts.OnLeave(mario.button)
local ana = rowOf("Ana")
ana.button.scripts.OnEnter(ana.button)
assert(GameTooltip.hidden, "no tooltip when there is nothing to say")

STUB.player.level = 60; STUB.Fire("PLAYER_LEVEL_UP", 60)
assert(B.restedText.text == "", "hidden at max level")
