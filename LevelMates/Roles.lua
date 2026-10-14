-- Roles.lua: each one's preferred role (tank, healer, damage), shared as personal state `rol`; without one, a guess
-- from the class (marked as a guess). Spec 2026-10-12-levelmates-runs-discord-design (2).
local _, ns = ...
local RO = {}
ns.Roles = RO
local C, R = ns.Comm, ns.Roster

local CAN = {
	T = { WARRIOR = true, DRUID = true, PALADIN = true },
	H = { PRIEST = true, DRUID = true, SHAMAN = true, PALADIN = true },
}
local FIRST = { WARRIOR = "T", DRUID = "T", PALADIN = "T", PRIEST = "H", SHAMAN = "H" }
function RO.Can(class, role) if role == "D" then return true end; return CAN[role] ~= nil and CAN[role][class] == true end
function RO.Guess(class) return FIRST[class] or "D" end

local function me() return ns.Me() end
local function myClass() return select(2, UnitClass("player")) end
local function store()
	ns.db.roles = ns.db.roles or {}
	local g = ns.GuildKey()
	ns.db.roles[g] = ns.db.roles[g] or {}
	return ns.db.roles[g]
end

function RO.Mine() return ns.char and ns.char.role or nil end
-- A guildmate's role: the one they chose, else the guess from the class their heartbeat gives.
function RO.Of(name)
	if name == me() then
		if RO.Mine() then return RO.Mine(), false end
		return RO.Guess(myClass()), true
	end
	local chosen = store()[name]
	if chosen and chosen.r then return chosen.r, false end
	local m = R.mates[name]
	return RO.Guess(m and m.class), true
end

C.SCHEMA.rol = { r = C.V.oneOf("T", "H", "D") }
C.REQUIRED.rol = { "r" }
local P = ns.Sync.Personal("rol", function() return RO.Mine() and { r = RO.Mine() } or nil end,
	{ save = "rolePending", worth = function() return RO.Mine() ~= nil end })

-- Called from a click (the Groups tab or Options).
function RO.Set(role)
	if role ~= "T" and role ~= "H" and role ~= "D" then return false end
	ns.char.role = role
	P.Mark("urgent")
	ns.Fire("LM_ROLES_CHANGED")
	return true
end

C.OnMessage("rol", function(f, name)
	store()[name] = { r = f.r, t = time() }
	ns.Fire("LM_ROLES_CHANGED")
end)
