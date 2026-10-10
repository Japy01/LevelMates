-- Rares.lua: a live rare (or rare elite) I target or mouse over is announced to the guild (`rr`, my position), at
-- most once every 15 minutes per rare; guildmates in the same map get a notice with a [Waypoint] link.
-- Spec 2026-10-10-levelmates-social-leveling-design (B1).
local _, ns = ...
local RA = {}
ns.Rares = RA
local L, C, R = ns.L, ns.Comm, ns.Roster
RA.THROTTLE, RA.REPEAT = 15 * 60, 5 * 60
local RARE = { rare = true, rareelite = true }
local secret = function(v) return issecretvalue and issecretvalue(v) end
local sentAt, heardAt = {}, {}

local function myPosition()
	local mapId = C_Map.GetBestMapForUnit("player")
	if not mapId then return nil end
	local pos = C_Map.GetPlayerMapPosition(mapId, "player")
	if not pos then return nil end
	local x, y = pos:GetXY()
	return mapId, math.floor(x * 1000 + 0.5) / 10, math.floor(y * 1000 + 0.5) / 10
end

function RA.Seen(unit)
	if not UnitExists(unit) then return false end
	local class, name = UnitClassification(unit), UnitName(unit)
	if secret(class) or secret(name) or not RARE[class] or not name or UnitIsDead(unit) or UnitIsPlayer(unit) then return false end
	local now = GetTime()
	if sentAt[name] and now - sentAt[name] < RA.THROTTLE then return false end
	local mapId, x, y = myPosition()
	if not mapId or not x then return false end
	if C.Send("rr", { n = ns.CutUtf8(name, 40), z = mapId, x = x, y = y }) then sentAt[name] = now; return true end
	return false
end

function RA.Link(mapId, x, y) return string.format("|Haddon:LevelMates:way:%d:%.1f:%.1f|h|cff7ec8ff[%s]|r|h", mapId, x, y, L.WAYPOINT) end

-- The link's click: the waypoint.
function RA.OnLink(link)
	local mapId, x, y = tostring(link):match("^addon:LevelMates:way:(%d+):([%d%.]+):([%d%.]+)")
	if not mapId then return false end
	return ns.Help.WaypointTo(tonumber(mapId), tonumber(x), tonumber(y))
end
if EventRegistry and EventRegistry.RegisterCallback then
	EventRegistry:RegisterCallback("SetItemRef", function(_, link) RA.OnLink(link) end, RA)
end

local function mapName(id) local info = C_Map.GetMapInfo(id); return info and info.name or tostring(id) end

C.OnMessage("rr", function(f, name)
	if not R.mates[name] or not ns.db.settings.rareNotices then return end
	if C_Map.GetBestMapForUnit("player") ~= f.z then return end   -- only where I am
	local key, now = name .. ":" .. f.n, GetTime()
	if heardAt[key] and now - heardAt[key] < RA.REPEAT then return end
	heardAt[key] = now
	local text = string.format(L.RARE_SEEN, name, f.n, mapName(f.z))
	ns.Say("%s %s", text, RA.Link(f.z, f.x, f.y))
	ns.Screen(text)
end)

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_TARGET_CHANGED"); ev:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
ev:SetScript("OnEvent", function(_, event) RA.Seen(event == "PLAYER_TARGET_CHANGED" and "target" or "mouseover") end)
