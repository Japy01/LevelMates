-- Comm.lua: wire format and (Task 2) transport. Format: "v1<US>kind<US>k=v;k=v", US = \031.
local _, ns = ...
local C = {}
ns.Comm = C
C.VERSION = "v1"
C.PREFIX = "LVLM"
C.MAX_BYTES = 255
local US = "\031"

local function esc(s)
	return (tostring(s):gsub("[%%;=%c]", function(ch) return string.format("%%%02X", ch:byte()) end))
end
local function unesc(s)
	return (s:gsub("%%(%x%x)", function(h) return string.char(tonumber(h, 16)) end))
end

local NUMERIC = {} -- set of numeric validators, so Decode coerces by schema type
local CANON = "^%-?%d+%.?%d*$"
local function canon(v)
	if type(v) == "string" and not v:match(CANON) then return nil end
	return tonumber(v)
end
local function num(min, max)
	local f = function(v) v = canon(v); return v ~= nil and v >= min and v <= max end
	NUMERIC[f] = true
	return f
end
local function int(min, max)
	local f = function(v) v = canon(v); return v ~= nil and v == math.floor(v) and v >= min and v <= max end
	NUMERIC[f] = true
	return f
end
local function text(max) return function(v) return type(v) == "string" and #v >= 1 and #v <= max and not v:find("[%c|]") end end
local function word(max) return function(v) return type(v) == "string" and v:match("^[%w_%.%-]+$") ~= nil and #v <= max end end
local function idlist(max) return function(v) if type(v) == "number" then v = tostring(v) end; return type(v) == "string" and #v <= max and v:match("^%d+[,%d]*$") ~= nil end end

-- field validators; required fields are listed in REQUIRED
C.SCHEMA = {
	hb   = { l = int(1, 100), z = int(0, 100000), g = int(0, 1), s = int(0, 1), x = num(0, 100), y = num(0, 100), r = int(0, 999999), c = word(16), v = word(20) },
	q    = { i = word(7), ids = idlist(240) },
	help = { t = text(60), z = int(0, 100000), x = num(0, 100), y = num(0, 100), id = word(8) },
	helpok = { id = word(8) },
	bye  = {},
	ping = {},
}
local REQUIRED = { hb = { "l", "z" }, q = { "i", "ids" }, help = { "t", "z", "x", "y", "id" }, helpok = { "id" }, bye = {}, ping = {} }

function C.Validate(kind, fields)
	local schema = C.SCHEMA[kind]
	if not schema or type(fields) ~= "table" then return false, "kind" end
	for _, k in ipairs(REQUIRED[kind]) do if fields[k] == nil then return false, "missing " .. k end end
	for k, v in pairs(fields) do
		local check = schema[k]
		if not check then return false, "unknown " .. k end
		if not check(v) then return false, "bad " .. k end
	end
	return true
end

function C.Encode(kind, fields)
	local ok, why = C.Validate(kind, fields)
	if not ok then return nil, why end
	local parts, keys = {}, {}
	for k in pairs(fields) do keys[#keys + 1] = k end
	table.sort(keys)
	for _, k in ipairs(keys) do parts[#parts + 1] = k .. "=" .. esc(fields[k]) end
	local s = C.VERSION .. US .. kind .. US .. table.concat(parts, ";")
	if #s > C.MAX_BYTES then return nil, "too long" end
	return s
end

function C.Decode(s)
	if type(s) ~= "string" or #s > C.MAX_BYTES then return nil, "size" end
	local ver, kind, body = s:match("^([^\31]+)\31([^\31]+)\31(.*)$")
	if ver ~= C.VERSION then return nil, "version" end
	if body:find("%c") then return nil, "control" end
	local fields = {}
	if body ~= "" then
		for pair in (body .. ";"):gmatch("([^;]*);") do
			local k, v = pair:match("^([%w_]+)=(.*)$")
			if not k then return nil, "pair" end
			fields[k] = unesc(v)
		end
	end
	local schema = C.SCHEMA[kind]
	if schema then
		for k, v in pairs(fields) do
			if NUMERIC[schema[k]] and v:match(CANON) then fields[k] = tonumber(v) end
		end
	end
	local ok, why = C.Validate(kind, fields)
	if not ok then return nil, why end
	return kind, fields
end
