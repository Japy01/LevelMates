-- Activities.lua: what a group can be for. The dungeons (Dungeons.lua, ids 1-14, unchanged), the raids (101+), PvP
-- (201+), and the ones the player names: a free raid (190), world PvP (290) and anything else (300). Each with its
-- size and slots per role; PvP and "other" have no roles (role A, "any"). Ids travel in messages: never renumber.
-- Spec 2026-10-13-levelmates-groups-design.
local _, ns = ...
local A = {}
ns.Activities = A
local L = ns.L
A.KINDS = { "d", "r", "p", "o" }
A.NAME_MAX = 40

local RAIDS = {
	{ id = 101, key = "ACT_MC", size = 40 }, { id = 102, key = "ACT_ONY", size = 40 }, { id = 103, key = "ACT_ZG", size = 20 },
	{ id = 104, key = "ACT_BWL", size = 40 }, { id = 105, key = "ACT_AQ20", size = 20 }, { id = 106, key = "ACT_AQ40", size = 40 },
	{ id = 107, key = "ACT_NAXX", size = 40 },
	{ id = 190, key = "ACT_RAID_FREE", size = 20, sizes = { 10, 20, 40 }, free = true },
}
local PVP = {
	{ id = 201, key = "ACT_WSG", size = 10 }, { id = 202, key = "ACT_AB", size = 15 }, { id = 203, key = "ACT_AV", size = 40 },
	{ id = 290, key = "ACT_WPVP", size = 10, min = 5, max = 40, free = true },
}
local OTHER = { id = 300, key = "ACT_OTHER", size = 5, min = 2, max = 40, free = true }
-- a raid's slots by its size
local RAID_CAPS = { [10] = { T = 2, H = 3, D = 5 }, [20] = { T = 3, H = 5, D = 12 }, [40] = { T = 5, H = 10, D = 25 } }

local byId = {}
for _, r in ipairs(RAIDS) do r.kind, r.roles = "r", true; byId[r.id] = r end
for _, p in ipairs(PVP) do p.kind, p.roles = "p", false; byId[p.id] = p end
OTHER.kind, OTHER.roles = "o", false; byId[OTHER.id] = OTHER

function A.Get(id)
	if byId[id] then return byId[id] end
	local d = ns.Dungeons.Get(id)
	if not d then return nil end
	return { id = d.id, kind = "d", key = d.key, min = d.min, max = d.max, size = 5, roles = true, art = d.art, coords = d.coords }
end

-- The catalogue of a kind, in order (dungeons by level).
function A.List(kind)
	if kind == "d" then
		local out = {}
		for _, d in ipairs(ns.Dungeons.Sorted()) do out[#out + 1] = A.Get(d.id) end
		return out
	elseif kind == "r" then return RAIDS
	elseif kind == "p" then return PVP
	elseif kind == "o" then return { OTHER } end
	return {}
end

-- A name: the player's own for the free ones, else the catalogue's, else "#id".
function A.Name(id, text)
	local a = A.Get(id)
	if a and a.free and text and text ~= "" then return text end
	if a and a.kind == "d" then return ns.Dungeons.Name(id) end
	if a then return L[a.key] or ("#" .. tostring(id)) end
	if text and text ~= "" then return text end
	return "#" .. tostring(id)
end

-- No codes, no links, trimmed, at most 40 letters (UTF-8 safe: never cut inside a letter).
function A.CleanName(text)
	local s = tostring(text or "")
	s = s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|H.-|h(.-)|h", "%1"):gsub("|T.-|t", ""):gsub("|", "")
	s = s:gsub("[%c]", " "):gsub("^%s+", ""):gsub("%s+$", "")
	local out, n = {}, 0
	for ch in s:gmatch("[\1-\127\194-\244][\128-\191]*") do
		n = n + 1
		if n > A.NAME_MAX then break end
		out[#out + 1] = ch
	end
	return (table.concat(out):gsub("%s+$", ""))
end

-- The size: the asked one when the activity allows it, else its own.
function A.SizeOf(id, x)
	local a = A.Get(id)
	if not a then return tonumber(x) or 5 end
	x = tonumber(x)
	if a.sizes then
		for _, s in ipairs(a.sizes) do if s == x then return x end end
		return a.size
	end
	if a.min and a.max and x then return math.max(a.min, math.min(a.max, math.floor(x))) end
	return a.size
end

function A.EncodeCaps(caps)
	local parts = {}
	for _, r in ipairs({ "T", "H", "D", "A" }) do if caps and caps[r] then parts[#parts + 1] = r .. caps[r] end end
	return table.concat(parts)
end
function A.DecodeCaps(text)
	if type(text) ~= "string" or text == "" then return nil end
	local caps, found = {}, false
	for r, n in text:gmatch("([THDA])(%d+)") do caps[r] = tonumber(n); found = true end
	if not found or text:gsub("[THDA]%d+", "") ~= "" then return nil end
	return caps
end

-- Slots per role: a dungeon 1/1/3; a raid by size (its leader may set their own); no roles: everyone "any".
function A.Caps(id, size, custom)
	local a = A.Get(id)
	if a and a.kind == "d" then return { T = 1, H = 1, D = 3 } end
	local n = A.SizeOf(id, size)
	if a and a.roles then
		local own = A.DecodeCaps(custom)
		if own and (own.T or own.H or own.D) and not own.A then
			local total = (own.T or 0) + (own.H or 0) + (own.D or 0)
			if total >= 2 and total <= 40 then return own end
		end
		local base = RAID_CAPS[n] or RAID_CAPS[20]
		return { T = base.T, H = base.H, D = base.D }
	end
	return { A = n }
end

-- Who goes where: the leader in their role, then the joins in the order they came while their role has room; the
-- rest wait. caps: { T, H, D } or { A }. joins: { { name, role } }. A role the group does not have waits.
function A.Place(caps, leader, leaderRole, joins)
	local slots, waiting, placed = {}, {}, {}
	for role in pairs(caps) do slots[role] = {} end
	if leader then
		local r = caps[leaderRole] and leaderRole or next(caps)
		table.insert(slots[r], leader); placed[leader] = true
	end
	for _, j in ipairs(joins or {}) do
		local name, role = j[1], j[2]
		if not placed[name] then
			if slots[role] and #slots[role] < caps[role] then table.insert(slots[role], name)
			else waiting[#waiting + 1] = name end
			placed[name] = true
		end
	end
	slots.waiting = waiting
	return slots
end
-- Everyone placed, and the free places per role.
function A.Count(slots, caps)
	local n = 0
	for role in pairs(caps) do n = n + #(slots[role] or {}) end
	return n
end
function A.Free(slots, caps, role) return caps[role] ~= nil and #(slots[role] or {}) < caps[role] end
