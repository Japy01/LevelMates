-- the client's macro and spell calls
local SPELLS = { [100] = "Charge", [2457] = "Battle Stance", [355] = "Taunt", [71] = "Defensive Stance", [78] = "Heroic Strike", [6552] = "Pummel", [72] = "Shield Bash" }
C_Spell = { GetSpellName = function(id) return SPELLS[id] end }
local macros, combat = {}, false
function InCombatLockdown() return combat end
function GetNumMacros() local a, c = 0, 0; for _, m in ipairs(macros) do if m.char then c = c + 1 else a = a + 1 end end; return a, c end
function GetMacroIndexByName(n) for i, m in ipairs(macros) do if m.name == n then return i end end; return 0 end
function GetMacroInfo(i) local m = macros[i]; if m then return m.name, m.icon, m.body end end
function CreateMacro(name, icon, body, perChar) macros[#macros + 1] = { name = name, icon = icon, body = body, char = perChar }; return #macros end
MAX_CHARACTER_MACROS = 30
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local C, MA, R, L = ns.Comm, ns.Macros, ns.Roster, ns.L
local function last(kind) for i = #STUB.sent, 1, -1 do local k, f = C.Decode(STUB.sent[i].msg); if k == kind then return f end end end

-- the library: every class has some, written with spell ids, shown with the client's spell names
for _, class in ipairs({ "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID" }) do
	assert(MA.LIBRARY[class] and #MA.LIBRARY[class] >= 3, "a library for " .. class)
	for _, m in ipairs(MA.LIBRARY[class]) do assert(#MA.Title(m) <= 16 and m.body:find("{s:%d+}"), "short names, spell ids: " .. MA.Title(m)) end
end
local lib = MA.Library("WARRIOR")
assert(#lib >= 3, "warrior macros resolved: " .. #lib)
local charge
for _, m in ipairs(lib) do if m.body:find("Charge", 1, true) then charge = m end end
assert(charge and not charge.body:find("{s:", 1, true) and charge.body:find("Battle Stance", 1, true), "names in my language")
SPELLS[6552] = nil
for _, m in ipairs(MA.Library("WARRIOR")) do assert(not m.body:find("Shield Bash", 1, true), "a macro with a spell this client lacks is left out") end
SPELLS[6552] = "Pummel"

-- creating one
assert(MA.Create(charge.name, charge.body) and macros[1].name == charge.name and macros[1].char == true and macros[1].body == charge.body, "created for this character")
assert(not MA.Create(charge.name, charge.body) and #macros == 1, "never twice")
combat = true
assert(not MA.Create("Other", "/say") and #macros == 1, "not in combat")
combat = false
for i = 1, 29 do macros[#macros + 1] = { name = "m" .. i, body = "", char = true } end
assert(not MA.Create("Other", "/say") and #macros == 30, "no room")
for i = 30, 2, -1 do table.remove(macros, i) end

-- the wire: bodies keep their lines; no "|" codes
assert(C.Validate("mc", { n = "LM Carga", x = "#showtooltip\n/cast Charge" }) and C.Validate("mcx", { n = "LM Carga" }), "mc format")
assert(not C.Validate("mc", { n = "LM Carga", x = "/cast |cff00ff00x" }) and not C.Validate("mc", { n = "LM Carga" }), "shape")
local _, f = C.Decode(C.Encode("mc", { n = "LM Carga", x = "#showtooltip\n/cast Charge" }))
assert(f.x == "#showtooltip\n/cast Charge", "lines survive the trip")

-- sharing mine
macros[#macros + 1] = { name = "Pull", body = "/cast Charge\n/yell Go", char = true }
assert(MA.Share("Pull") and MA.IsShared("Pull") and last("mc").n == "Pull" and last("mc").x == "/cast Charge\n/yell Go", "shared")
macros[#macros + 1] = { name = "Bad", body = "/run print('|cffff0000hi')", char = true }
assert(not MA.Share("Bad") and not MA.IsShared("Bad"), "a body with | codes cannot travel")
macros[#macros + 1] = { name = "Long", body = string.rep("/cast Charge\n", 30), char = true }
assert(not MA.Share("Long"), "too long to share")
for i = 1, 4 do macros[#macros + 1] = { name = "s" .. i, body = "/cast Taunt", char = true }; assert(MA.Share("s" .. i)) end
macros[#macros + 1] = { name = "s5", body = "/cast Taunt", char = true }
assert(not MA.Share("s5"), "five at most")
assert(MA.Unshare("Pull") and not MA.IsShared("Pull") and last("mcx").n == "Pull", "withdrawn")
-- a newcomer gets them again
local n = #STUB.sent
STUB.Receive("LVLM", C.Encode("ping", {}), "GUILD", "Luis-Testrealm"); STUB.Advance(12)
local again = 0
for i = n + 1, #STUB.sent do if C.Decode(STUB.sent[i].msg) == "mc" then again = again + 1 end end
assert(again == 4, "re-sent to newcomers: " .. again)
-- a deleted macro stops being shared
for i, m in ipairs(macros) do if m.name == "s1" then table.remove(macros, i) end end
STUB.Receive("LVLM", C.Encode("ping", {}), "GUILD", "Luis-Testrealm"); STUB.Advance(12)
assert(not MA.IsShared("s1"), "gone with the macro")

-- guildmates': only my class
STUB.Receive("LVLM", C.Encode("hb", { l = 24, z = 1421, c = "WARRIOR" }), "GUILD", "Mario-Testrealm")
STUB.Receive("LVLM", C.Encode("hb", { l = 22, z = 1421, c = "MAGE" }), "GUILD", "Ana-Testrealm")
STUB.Receive("LVLM", C.Encode("mc", { n = "Tank", x = "/cast Taunt" }), "GUILD", "Mario-Testrealm")
STUB.Receive("LVLM", C.Encode("mc", { n = "Sheep", x = "/cast Polymorph" }), "GUILD", "Ana-Testrealm")
STUB.Receive("LVLM", C.Encode("mc", { n = "X", x = "/cast X" }), "GUILD", "Nadie-Testrealm")
local g = MA.Guild()
assert(#g == 1 and g[1].by == "Mario" and g[1].name == "Tank" and g[1].body == "/cast Taunt", "Mario's, my class")
STUB.Receive("LVLM", C.Encode("mcx", { n = "Tank" }), "GUILD", "Mario-Testrealm")
assert(#MA.Guild() == 0, "withdrawn")
