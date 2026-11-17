-- Shared consumable requirements reuse guild records; personal reminders stay in RaidReadiness.
local _, ns = ...
local P = {}; ns.RaidRequirements = P
local unpack = unpack or table.unpack
local S, C, R, L = ns.Sync, ns.Comm, ns.Roster, ns.L
P.MAX_ITEMS = 20
P.SCOPES = { "ALL", "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID", "T", "H", "D" }
local scopeSet, classSet = {}, {}; for _, scope in ipairs(P.SCOPES) do scopeSet[scope] = true; if #scope > 1 and scope ~= "ALL" then classSet[scope] = true end end
local function activity(id) local a = ns.Activities.Get(tonumber(id)); return a and a.kind == "r" and a.id end
local function officer(name) return R.IsOfficer(name) or (name == ns.Me() and R.IAmOfficer()) end
function P.Parse(text)
	if type(text) ~= "string" then return nil end
	text = strtrim(text)
	local items, seen = {}, {}
	if text == "" or text == "clear" then return items end
	if #text > 400 or text:sub(1, 1) == "," or text:sub(-1) == "," or text:find(",%s*,") then return nil end
	for piece in text:gmatch("[^,]+") do
		local id, n = piece:match("^%s*(%d+):(%d+)%s*$"); id, n = tonumber(id), tonumber(n)
		if not id or id < 1 or id > 999999 or not n or n < 1 or n > 999 or seen[id] or #items >= P.MAX_ITEMS then return nil end
		seen[id] = true; items[#items + 1] = { id = id, required = n }
	end
	return #items > 0 and items or nil
end
function P.Encode(items)
	local out = {}; for _, item in ipairs(items or {}) do out[#out + 1] = item.id .. ":" .. item.required end
	return table.concat(out, ",")
end
local function key(kind, id, scope, who)
	return (kind == "guild" and "g" or ("p" .. ns.NameKey(who or ns.Me()) .. ".")) .. id .. "." .. scope
end
local function changed() ns.Fire("LM_RAID_REQUIREMENTS_CHANGED") end
local function trustedRelay(owner, sender) return owner == sender or officer(sender) end
local fields = { a = C.V.int(101, 199), s = C.V.oneOf(unpack(P.SCOPES)), i = function(v) return type(v) == "string" and #v <= 220 and P.Parse(v) ~= nil end }
S.Define("rpg", { class = "board", life = 365 * 86400, writerOwns = true, writerTieBreak = true, max = 256, relayMax = 256,
	fields = fields, required = { "a", "s", "i" }, relayFrom = trustedRelay, canAnswer = function() return officer(ns.Me()) end,
	idOwner = function(_, owner) return officer(owner) end,
	accept = function(f, owner) return officer(owner) and activity(f.a) and f.id == key("guild", f.a, f.s) end,
	may = function(_, who) return officer(who) end, onChange = changed })
-- A leader profile belongs to its author. It is applied only when native group APIs identify that author
-- as the current raid leader; no record can grant itself leadership. Profiles expire after eight hours.
S.Define("rpl", { class = "board", life = 8 * 3600, writerOwns = true, max = 512, relayMax = 512,
	fields = fields, required = { "a", "s", "i" }, relayFrom = trustedRelay, canAnswer = function() return officer(ns.Me()) end,
	idOwner = function(id, owner) return id:sub(1, 10) == "p" .. ns.NameKey(owner) .. "." end,
	accept = function(f, owner) return activity(f.a) and f.id == key("raid", f.a, f.s, owner) end,
	onChange = changed })
local function read(fn, ...)
	if type(fn) ~= "function" then return nil end
	local ok, value = pcall(fn, ...)
	return ok and ns.Plain(value) or nil
end
function P.Leader()
	if read(IsInRaid) ~= true then return nil end
	local n = read(GetNumGroupMembers)
	if type(n) ~= "number" or n < 1 or n > 40 or n ~= math.floor(n) then return nil end
	local leader
	for i = 1, n do
		local unit = "raid" .. i
		if read(UnitIsGroupLeader, unit) == true then
			local ok, name, realm = pcall(UnitName, unit)
			name, realm = ok and ns.Plain(name), ok and ns.Plain(realm)
			if type(name) ~= "string" or name == "" then return nil end
			if type(realm) == "string" and realm ~= "" then name = name .. "-" .. realm end
			name = ns.ShortName(name)
			if leader or not R.IsGuildmate(name) then return nil end
			leader = name
		end
	end
	return leader
end
function P.CanPublish(kind)
	if kind == "guild" then return officer(ns.Me()) end
	if kind == "raid" then return P.Leader() == ns.Me() end
	return false
end
function P.Get(kind, id, scope, who)
	if not activity(id) or not scopeSet[scope] or (kind ~= "guild" and kind ~= "raid") then return nil end
	local rec = S.Get(kind == "guild" and "rpg" or "rpl", key(kind, tonumber(id), scope, who))
	if rec and (kind ~= "guild" or officer(rec.o)) then return rec end
end
function P.Set(kind, id, scope, text)
	id = activity(id)
	local items = P.Parse(text)
	if not id or not scopeSet[scope] or not items then return false, "input" end
	if not P.CanPublish(kind) then return false, "permission" end
	local data = { a = id, s = scope, i = P.Encode(items) }
	local t, k = kind == "guild" and "rpg" or "rpl", key(kind, id, scope)
	local wire = { id = k, v = GetServerTime(), e = GetServerTime() + 1, a = id, s = scope, i = data.i }
	if not C.Validate(t, wire) then return false, "input" end
	return S.Put(t, k, data) and true or false
end
function P.ScopeLabel(scope)
	if scope == "ALL" then return L.READY_SCOPE_ALL end
	if scope == "T" or scope == "H" or scope == "D" then return L["ROLE_" .. scope] or scope end
	return (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[scope]) or scope
end
function P.Resolve(id)
	local ok, _, class = pcall(UnitClass, "player")
	class = ok and ns.Plain(class) or nil
	class = classSet[class] and class or nil
	local role = ns.Roles.Mine() -- never guess a role's requirements from the class
	if role ~= "T" and role ~= "H" and role ~= "D" then role = nil end
	local scopes = { "ALL" }; if class then scopes[#scopes + 1] = class end
	if role == "T" or role == "H" or role == "D" then scopes[#scopes + 1] = role end
	local leader, out = P.Leader(), {}
	for _, scope in ipairs(scopes) do
		for _, kind in ipairs({ "guild", "raid" }) do
			local rec = (kind == "guild" or leader) and P.Get(kind, id, scope, leader)
			if rec and (kind == "guild" or rec.o == leader) then
				out[#out + 1] = { kind = kind, scope = scope, by = rec.o, at = rec.v, expires = rec.e, items = P.Parse(rec.d.i) or {} }
			end
		end
	end
	return out, class, role, leader
end

-- Non-officer raid leaders serve their own profiles directly on hello. Unprivileged cached
-- peers never claim a whole restricted record type and suppress an authorized responder.
local served = {}
C.OnMessage("hi", function(_, name)
	if officer(ns.Me()) or P.Leader() ~= ns.Me() or not R.IsGuildmate(name) then return end
	if GetTime() - (served[name] or -math.huge) < 30 then return end
	served[name] = GetTime()
	for _, rec in ipairs(S.List("rpl")) do if rec.o == ns.Me() then S.Send(rec, name) end end
end)
