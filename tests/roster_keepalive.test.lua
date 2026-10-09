-- An idle player must stay on everyone's board: a keepalive heartbeat well inside the 120 s expiry.
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local C = ns.Comm
local function hbs(from)
	local c = 0
	for i = from, #STUB.sent do if (C.Decode(STUB.sent[i].msg)) == "hb" then c = c + 1 end end
	return c
end
local n = #STUB.sent + 1
STUB.Advance(62)
assert(hbs(n) == 0, "no heartbeat in the first minute without change")
STUB.Advance(60)
assert(hbs(n) == 1, "an idle player still announces itself before the 120 s expiry: " .. hbs(n))
STUB.Advance(360)
local c = hbs(n)
assert(c >= 4 and c <= 6, "about one keepalive every 90 s, got " .. c)
