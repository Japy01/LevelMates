-- big messages go as chunks and come back whole: any order, duplicates ignored, incomplete dropped after 30 s
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(30)
local C = ns.Comm
local got
C.SCHEMA.zz = { x = function(v) return type(v) == "string" and #v <= 2000 end }
C.REQUIRED.zz = { "x" }
C.OnMessage("zz", function(f, name) got = { f.x, name } end)
local big = string.rep("abcdefghij", 60)
local n = #STUB.sent
C.SendBig("zz", { x = big })
STUB.Advance(20)
local chunks = {}
for i = n + 1, #STUB.sent do if (C.Decode(STUB.sent[i].msg)) == "bl" then chunks[#chunks + 1] = STUB.sent[i].msg end end
assert(#chunks >= 4, "chunked: " .. #chunks)
for _, m in ipairs(chunks) do assert(#m <= 240, "each chunk fits") end
for i = #chunks, 1, -1 do STUB.Receive("LVLM2", chunks[i], "GUILD", "Mario-Testrealm") end
STUB.Receive("LVLM2", chunks[1], "GUILD", "Mario-Testrealm")
assert(got and got[1] == big and got[2] == "Mario", "whole again")
got = nil
n = #STUB.sent
C.SendBig("zz", { x = big .. "!" }); STUB.Advance(20)
local again = {}
for i = n + 1, #STUB.sent do if (C.Decode(STUB.sent[i].msg)) == "bl" then again[#again + 1] = STUB.sent[i].msg end end
for i = 1, #again - 1 do STUB.Receive("LVLM2", again[i], "GUILD", "Mario-Testrealm") end
STUB.Advance(31)
STUB.Receive("LVLM2", again[#again], "GUILD", "Mario-Testrealm")
assert(got == nil, "the start was dropped: no half message")
n = #STUB.sent
C.SendBig("zz", { x = "short" }); STUB.Advance(2)
local plain = 0
for i = n + 1, #STUB.sent do if (C.Decode(STUB.sent[i].msg)) == "zz" then plain = plain + 1 end end
assert(plain == 1, "small: one plain message")
