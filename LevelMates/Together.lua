-- Together.lua: groups the addon suggests from who is online: for each dungeon, the guildmates (and me) whose level
-- fits, placed by chosen role first, then by a guess from the class. Computed here, nothing is sent.
-- Spec 2026-10-12-levelmates-runs-discord-design (3).
local _, ns = ...
local T = {}
ns.Together = T
local R, D, RO = ns.Roster, ns.Dungeons, ns.Roles
T.MAX, T.ABOVE = 5, 2
local CAP = { T = 1, H = 1, D = 3 }

local function people()
	local out = { { name = ns.Me(), level = UnitLevel("player"), class = select(2, UnitClass("player")) } }
	for _, name in ipairs(R.List()) do
		local m = R.mates[name]
		out[#out + 1] = { name = name, level = m.level or 0, class = m.class }
	end
	return out
end

local function build(d, all)
	local cands = {}
	for _, p in ipairs(all) do if p.level >= d.min and p.level <= d.max + T.ABOVE then cands[#cands + 1] = p end end
	if #cands < 2 then return nil end
	table.sort(cands, function(a, b) if a.level ~= b.level then return a.level > b.level end; return a.name < b.name end)
	local slots, used, rows = { T = 0, H = 0, D = 0 }, {}, {}
	local function put(p, role, guessed)
		slots[role] = slots[role] + 1; used[p.name] = true
		rows[#rows + 1] = { role = role, name = p.name, level = p.level, guessed = guessed }
	end
	for _, p in ipairs(cands) do   -- chosen roles first
		local role, guessed = RO.Of(p.name)
		if not guessed and slots[role] < CAP[role] then put(p, role, false) end
	end
	for _, role in ipairs({ "T", "H" }) do   -- then guessed tanks and healers
		for _, p in ipairs(cands) do
			if slots[role] < CAP[role] and not used[p.name] and select(2, RO.Of(p.name)) and RO.Can(p.class, role) then put(p, role, true) end   -- never against a chosen role
		end
	end
	for _, p in ipairs(cands) do   -- the rest as damage
		if slots.D < CAP.D and not used[p.name] then
			local role, guessed = RO.Of(p.name)
			put(p, "D", guessed or role ~= "D")   -- "?" unless damage is what they chose
		end
	end
	local order = { T = 1, H = 2, D = 3 }
	table.sort(rows, function(a, b) if order[a.role] ~= order[b.role] then return order[a.role] < order[b.role] end; return a.level > b.level end)
	return { d = d.id, rows = rows, filled = #rows, candidates = #cands }
end

-- At most five, the fullest first, then the most candidates, then the higher dungeon.
function T.Suggest()
	local all, out = people(), {}
	for _, d in ipairs(D.list) do
		local s = build(d, all)
		if s then out[#out + 1] = s end
	end
	table.sort(out, function(a, b)
		if a.filled ~= b.filled then return a.filled > b.filled end
		if a.candidates ~= b.candidates then return a.candidates > b.candidates end
		return a.d > b.d
	end)
	while #out > T.MAX do table.remove(out) end
	return out
end
