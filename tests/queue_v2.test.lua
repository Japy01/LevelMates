-- the queue: urgent ahead of normal, held (not dropped) inside instances, a 300 cap, whispers
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(30)
local C = ns.Comm
local sentNote
local function kinds(from) local out = {}; for i = from + 1, #STUB.sent do out[#out + 1] = (C.Decode(STUB.sent[i].msg)) end; return out end
for i = 1, 12 do C.Send("pal", { p = 1 }) end   -- normal, uses up the burst
local n = #STUB.sent
C.Send("pt", { t = 1 }); C.Send("help", { t = "x", z = 1412, x = 1, y = 1, id = "h1" })
STUB.Advance(1.5)
assert(kinds(n)[1] == "help", "the help request first: " .. tostring(kinds(n)[1]))
STUB.Advance(30)
-- inside an instance: held, not dropped; out after leaving
STUB.inInstance = true
n = #STUB.sent
C.Send("pt", { t = 2 }, nil, { hold = true, onSent = function() sentNote = true end })
STUB.Advance(5)
assert(#STUB.sent == n, "nothing out inside")
assert(C.stats.held >= 1, "held")
STUB.inInstance = false
STUB.Fire("ZONE_CHANGED_NEW_AREA"); STUB.Advance(3)
local found = false; for _, k in ipairs(kinds(n)) do if k == "pt" then found = true end end
assert(found and sentNote, "out after leaving, and its sender told")
-- without hold: refused inside, as the modules expect (they keep it pending)
STUB.inInstance = true
assert(C.Send("pt", { t = 9 }) == false, "refused without hold")
STUB.inInstance = false
-- held normal messages expire after an hour
STUB.inInstance = true
C.Send("pt", { t = 3 }, nil, { hold = true }); STUB.Advance(3601)
STUB.inInstance = false; n = #STUB.sent
STUB.Fire("ZONE_CHANGED_NEW_AREA"); STUB.Advance(3)
for i = n + 1, #STUB.sent do local k, f = C.Decode(STUB.sent[i].msg); assert(not (k == "pt" and f.t == 3), "an hour old: gone") end
-- the cap
STUB.inInstance = true
for i = 1, 305 do C.Send("rr", { n = "Raro" .. i, z = 1412, x = 1, y = 1 }, nil, { hold = true }) end
assert(C.stats.queued <= 300 and C.stats.dropped >= 5, "capped: " .. C.stats.queued)
STUB.inInstance = false
STUB.Fire("ZONE_CHANGED_NEW_AREA"); STUB.Advance(400)
-- whispers, to the bare name
n = #STUB.sent
C.Whisper("pal", { p = 1 }, "Mario Rossi-Testrealm")
STUB.Advance(2)
local w = STUB.sent[#STUB.sent]
assert(w.chatType == "WHISPER" and w.target == "Mario Rossi", "whisper to the bare name: " .. tostring(w.target))
-- whispers from guildmates are heard, from strangers not
local got
C.OnMessage("pal", function(f, name) got = name end)
STUB.Receive("LVLM2", C.Encode("pal", { p = 1 }), "WHISPER", "Mario-Testrealm")
assert(got == "Mario", "a guildmate's whisper")
got = nil
STUB.Receive("LVLM2", C.Encode("pal", { p = 1 }), "WHISPER", "Extranjero-Testrealm")
assert(got == nil, "a stranger's whisper")
