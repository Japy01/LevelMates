STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local C, H, L = ns.Comm, ns.Help, ns.L
local function count(from) local n = 0; for i = from + 1, #STUB.sent do if (C.Decode(STUB.sent[i].msg)) == "help" then n = n + 1 end end; return n end
local n = #STUB.sent
LevelMates_Panic()
local _, f = C.Decode(STUB.sent[#STUB.sent].msg)
assert(count(n) == 1 and f.t == L.PANIC_TEXT, "help asked at once")
LevelMates_Panic()
assert(count(n) == 1 and STUB.printed[#STUB.printed]:find(L.PANIC_WAIT, 1, true), "not twice in 30 s")
STUB.Advance(H.PANIC_GAP + 1)
SlashCmdList["LEVELMATES"]("panico")
assert(count(n) == 2, "again later, also by slash")
assert(BINDING_NAME_LEVELMATES_PANIC == L.BINDING_PANIC, "the key binding has a name")
-- simulation
local before = #STUB.printed
SlashCmdList["LEVELMATES"]("sim raro")
assert(#STUB.printed > before and STUB.printed[#STUB.printed]:find("|Haddon:LevelMates:way:", 1, true), "sim raro: a sighting notice with its link")
