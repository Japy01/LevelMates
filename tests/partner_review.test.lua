-- Final review of the leveling partner: the mark must survive instances and refused sends.
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local C, P = ns.Comm, ns.Partner
STUB.player.level = 20
local function kinds(from)
	local out = {}
	for i = from, #STUB.sent do
		local k, f = C.Decode(STUB.sent[i].msg)
		if k == "hb" or k == "pal" then out[#out + 1] = k .. (k == "pal" and tostring(f.p) or "") end
	end
	return table.concat(out, ",")
end

-- after a long instance run my mark goes out again with my first heartbeat outside
assert(P.SetOn(true))
STUB.inInstance = true
STUB.Advance(150)
local n = #STUB.sent + 1
STUB.inInstance = false
STUB.Fire("ZONE_CHANGED_NEW_AREA"); STUB.Advance(1)
assert(kinds(n) == "hb,pal1", "on leaving: hb then my mark again: " .. kinds(n))

-- unticked inside an instance (send refused): the guild learns it on the way out
STUB.inInstance = true
P.SetOn(false)
STUB.Advance(100)
n = #STUB.sent + 1
STUB.inInstance = false
STUB.Fire("ZONE_CHANGED_NEW_AREA"); STUB.Advance(1)
assert(kinds(n) == "hb,pal0", "refused p=0 retried after the next heartbeat: " .. kinds(n))

-- ticked inside: announced on the way out
STUB.inInstance = true
P.SetOn(true)
STUB.Advance(100)
n = #STUB.sent + 1
STUB.inInstance = false
STUB.Fire("ZONE_CHANGED_NEW_AREA"); STUB.Advance(1)
assert(kinds(n) == "hb,pal1", "ticked inside, announced outside: " .. kinds(n))

-- idle in town with the box ticked: the mark rides the keepalive, at most once per 80 s
n = #STUB.sent + 1
STUB.Advance(400)
local pals = 0
for i = n, #STUB.sent do if (C.Decode(STUB.sent[i].msg)) == "pal" then pals = pals + 1 end end
assert(pals >= 3 and pals <= 5, "mark refreshed with the keepalives: " .. pals)
