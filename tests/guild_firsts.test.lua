-- guild firsts: the first to reach level 10, 20… 60, and 300 in each profession. Whoever gets there says so (a record
-- of their own, kept by everyone); the earliest time is the first; the same second is shared; a claim the level can't
-- back is refused; nobody claims what someone reached before them
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(30)
local C, L, GF, B = ns.Comm, ns.L, ns.GuildFirsts, ns.Board
local function sentClaims(from)
	local out = {}
	for i = from + 1, #STUB.sent do local k, f = C.Decode(STUB.sent[i].msg); if k == "gfi" then out[#out + 1] = f end end
	return out
end
local function claim(name, w, a) return C.Encode("gfi", STUB.Rec{ id = w .. "-" .. ns.NameKey(name), w = w, a = a }) end

assert(#GF.LIST >= 6 and GF.LIST[1].w == "lvl10" and GF.LIST[6].w == "lvl60", "levels first")
-- I reach 20 first: claimed, shared, mine
local n = #STUB.sent
STUB.Fire("PLAYER_LEVEL_UP", 20); STUB.Advance(2)
local c = sentClaims(n)
assert(#c == 1 and c[1].w == "lvl20" and c[1].a, "my claim went out")
local f = GF.First("lvl20")
assert(f and f.names[1] == ns.Me() and #f.names == 1, "I am the first")

-- Ana reached 30 an hour ago; Mario at the same second: shared. Pepe (level 20) claiming 60: refused
STUB.Receive("LVLM2", C.Encode("hb", { l = 31, z = 1412, c = "MAGE" }), "GUILD", "Ana-Testrealm")
STUB.Receive("LVLM2", C.Encode("hb", { l = 30, z = 1412, c = "MAGE" }), "GUILD", "Mario-Testrealm")
STUB.Receive("LVLM2", C.Encode("hb", { l = 20, z = 1412, c = "MAGE" }), "GUILD", "Pepe-Testrealm")
local t = GetServerTime() - 3600
STUB.Receive("LVLM2", claim("Ana", "lvl30", t), "GUILD", "Ana-Testrealm")
STUB.Receive("LVLM2", claim("Mario", "lvl30", t), "GUILD", "Mario-Testrealm")
STUB.Receive("LVLM2", claim("Pepe", "lvl60", t), "GUILD", "Pepe-Testrealm")
f = GF.First("lvl30")
assert(f and #f.names == 2, "the same second: shared")
assert(GF.First("lvl60") == nil, "a level 20 can't claim 60")
-- a claim under someone else's name: refused
STUB.Receive("LVLM2", claim("Ana", "lvl40", t), "GUILD", "Pepe-Testrealm")
assert(GF.First("lvl40") == nil, "not his to claim")
-- I reach 30 later: nothing to claim
n = #STUB.sent
STUB.Fire("PLAYER_LEVEL_UP", 30); STUB.Advance(2)
assert(#sentClaims(n) == 0, "someone was there first: no claim")
-- an earlier claim arriving late wins
STUB.Receive("LVLM2", C.Encode("hb", { l = 25, z = 1412, c = "MAGE" }), "GUILD", "Luis-Testrealm")
STUB.Receive("LVLM2", claim("Luis", "lvl20", GetServerTime() - 86400), "GUILD", "Luis-Testrealm")
assert(GF.First("lvl20").names[1] == "Luis", "the earliest wins")

-- 300 in a profession
ns.char.skills = { [171] = { rank = 299, max = 300 } }
ns.Fire("LM_SKILLS_CHANGED")
n = #STUB.sent
ns.char.skills = { [171] = { rank = 300, max = 300 } }
ns.Fire("LM_SKILLS_CHANGED"); STUB.Advance(2)
c = sentClaims(n)
assert(#c == 1 and c[1].w == "p171", "first to 300 in Alchemy")
-- someone else's live claim: told once
local before = #STUB.printed
STUB.Receive("LVLM2", C.Encode("hb", { l = 50, z = 1412, c = "MAGE" }), "GUILD", "Rosa-Testrealm")
STUB.Receive("LVLM2", claim("Rosa", "lvl50", GetServerTime()), "GUILD", "Rosa-Testrealm")
local told = table.concat(STUB.printed, "\n", before + 1)
assert(told:find("Rosa", 1, true), "told: " .. told)

-- on the Journal's achievements page, after the achievements
B.Toggle(); B.ShowTab("journal"); B.journalView = "ach"; B.Refresh()
local seen = {}
for p = 1, 10 do
	for _, r in ipairs(B.rows) do if r.button:IsShown() and r.name.text then seen[r.name.text] = r.zone.text end end
	if B.journalNext:IsEnabled() then B.journalNext.scripts.OnClick(B.journalNext) else break end
end
assert(seen[GF.Name("lvl30")] and seen[GF.Name("lvl30")]:find("Ana", 1, true) and seen[GF.Name("lvl30")]:find("Mario", 1, true), "firsts listed with who")
assert(seen[GF.Name("lvl60")] == L.GF_NOBODY, "nobody yet")
