-- Final review of rested XP: driven through the real setting object, as the options panel does.
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local C = ns.Comm
STUB.player.level = 20; STUB.player.rested = 500
local function sentRx(from)
	local out = {}
	for i = from, #STUB.sent do local k, f = C.Decode(STUB.sent[i].msg); if k == "rx" then out[#out + 1] = f.p end end
	return table.concat(out, ",")
end
local share
for _, s in ipairs(ns.Settings.category.settings) do if s.key == "shareRested" then share = s end end
assert(share, "the setting is registered")

-- the panel's Defaults button re-applies "off": nothing may leave the client
local n = #STUB.sent + 1
share:SetValue(false)
assert(sentRx(n) == "", "re-applying 'off' sends nothing: " .. sentRx(n))
share:SetValue(true)
assert(sentRx(n) == "50", "on: " .. sentRx(n))
n = #STUB.sent + 1
share:SetValue(false); share:SetValue(false)
assert(sentRx(n) == "-1", "withdrawn once: " .. sentRx(n))

-- a withdrawal refused inside an instance goes out with the first heartbeat outside
share:SetValue(true)
STUB.inInstance = true
n = #STUB.sent + 1
share:SetValue(false)
STUB.Advance(100)
assert(sentRx(n) == "", "nothing inside")
STUB.inInstance = false
STUB.Fire("ZONE_CHANGED_NEW_AREA"); STUB.Advance(1)
assert(sentRx(n) == "-1", "withdrawal retried outside: " .. sentRx(n))

-- after a long silence (others expired me) my unchanged value goes out again
share:SetValue(true)
STUB.inInstance = true
STUB.Advance(150)
n = #STUB.sent + 1
STUB.inInstance = false
STUB.Fire("ZONE_CHANGED_NEW_AREA"); STUB.Advance(1)
assert(sentRx(n) == "50", "value restored after the others expired me: " .. sentRx(n))
