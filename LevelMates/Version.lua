-- Version.lua: a guildmate on a newer LevelMates (the heartbeat's v) gets me a notice, once a session.
local _, ns = ...
local V = {}
ns.Version = V
local L, C = ns.L, ns.Comm

local function parts(v)
	local a, b, c = tostring(v or ""):match("^v?(%d+)%.(%d+)%.?(%d*)$")
	if not a then return nil end
	return { tonumber(a), tonumber(b), tonumber(c) or 0 }
end

-- Whether version a is newer than b; false when either is not "x.y" or "x.y.z" (a development checkout).
function V.Newer(a, b)
	local x, y = parts(a), parts(b)
	if not x or not y then return false end
	for i = 1, 3 do if x[i] ~= y[i] then return x[i] > y[i] end end
	return false
end

local told = false
C.OnMessage("hb", function(f)
	if told or not f.v or not V.Newer(f.v, ns.VERSION) then return end
	told = true
	ns.Notice(L.VERSION_NEW, f.v)
end)
