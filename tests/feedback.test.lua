-- what a click did shows at the foot of the book while it is open; notices keep to chat
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(30)
local B = ns.Board
B.Toggle()
local n = #STUB.printed
ns.Say("hecho %d", 1)
assert(B.feedback:IsShown() and B.feedback.text.text:find("hecho 1", 1, true) and #STUB.printed == n, "at the foot, not in chat")
ns.Say("uno"); ns.Say("dos"); ns.Say("tres")
assert(B.feedback.text.text:find("tres", 1, true), "the last one shows")
STUB.Advance(8)
assert(not B.feedback:IsShown(), "gone after a while")
ns.Say("otra"); B.feedback.scripts.OnClick(B.feedback)
assert(not B.feedback:IsShown(), "a click dismisses it")
ns.Notice("aviso %s", "x")
assert(#STUB.printed > n, "notices still go to chat")
B.Toggle()   -- closed
n = #STUB.printed
ns.Say("cerrado")
assert(#STUB.printed == n + 1, "book closed: chat")
