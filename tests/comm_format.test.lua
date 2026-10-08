STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
local C = ns.Comm
local s = C.Encode("hb", { l = 22, z = 1421, g = 1, s = 0, c = "WARRIOR" })
assert(s and s:sub(1, 2) == "v1", "starts with version: " .. tostring(s))
assert(not s:find("\n"), "no newlines")
local kind, f = C.Decode(s)
assert(kind == "hb" and f.l == 22 and f.z == 1421 and f.g == 1 and f.c == "WARRIOR", "roundtrip")
-- escaping of separators and percent
local e = C.Encode("help", { t = "Fuerte Colmillo; =50% elite", z = 1421, x = 44.4, y = 41.1, id = "a1b2" })
local k2, f2 = C.Decode(e)
assert(f2.t == "Fuerte Colmillo; =50% elite", "escaped text roundtrip: " .. tostring(f2.t))
-- size limit
local big = C.Encode("help", { t = string.rep("x", 300), z = 1, x = 1, y = 1, id = "a" })
assert(big == nil, "over 255 bytes refused")
-- validation
assert(C.Validate("hb", { l = 22, z = 1421 }) == true, "minimal hb valid")
assert(C.Validate("hb", { l = 999, z = 1421 }) == false, "level out of range")
assert(C.Validate("hb", { l = 22, z = "abc" }) == false, "map id must be number")
assert(C.Validate("help", { t = "x", z = 1, x = 50, y = 50, id = "a1b2" }) == true, "help valid")
assert(C.Validate("help", { t = "a|cffff0000x", z = 1, x = 50, y = 50, id = "a1b2" }) == false, "pipe refused in text")
assert(C.Validate("nope", {}) == false, "unknown kind")
assert(select(1, C.Decode("v9\31hb\31l=1")) == nil, "unknown version dropped")
assert(select(1, C.Decode("garbage")) == nil, "garbage dropped")
-- schema-typed coercion
local _, fh = C.Decode(C.Encode("help", { t = "50", z = 1, x = 1, y = 1, id = "1234" }))
assert(fh and fh.id == "1234" and fh.t == "50" and fh.z == 1, "string fields stay strings")
local kv, fv = C.Decode(C.Encode("hb", { l = 22, z = 1, v = "1.0.0" }))
assert(kv == "hb" and fv.v == "1.0.0" and fv.l == 22 and type(fv.l) == "number", "version word with dots")
assert(C.Decode("v1\31hb\31l=0x10;z=1") == nil, "hex level refused")
assert(C.Decode("v1\31hb\31l=22\n;z=1") == nil, "control byte refused")
assert(C.Validate("hb", { l = "1e2", z = 1 }) == false, "exponent refused")
assert(C.Validate("hb", { l = " 22", z = 1 }) == false, "space refused")
print("ok")
