STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local C, P, R, L = ns.Comm, ns.Professions, ns.Roster, ns.L
local function last(kind) for i = #STUB.sent, 1, -1 do local k, f = C.Decode(STUB.sent[i].msg); if k == kind then return f end end end
STUB.guildMembers = { Tester = true, Mario = true, Ana = true, Luis = true }
R.InvalidateGuildRoster()

assert(C.Validate("pf", {}) and C.Validate("pf", { p = "171:120" }) and C.Validate("pf", { p = "171:120,182:95,129:1,185:450,356:300,164:5" }), "pf format")
assert(C.Validate("pf", { p = "171:120,182:95,129:1,185:450,356:300,164:5,165:1" }) == false and C.Validate("pf", { p = "171:451" }) == false, "count and rank limits")
assert(C.Validate("pf", { p = "171:" }) == false and C.Validate("pf", { p = "171:1,,2:3" }) == false and C.Validate("pf", { p = "abc" }) == false, "shape")

-- mine, from the journal's skill snapshot, sent when it changes
ns.char.skills = { [171] = { name = "Alchemy", rank = 120 }, [182] = { name = "Herbalism", rank = 95 } }
ns.Fire("LM_SKILLS_CHANGED")
assert(last("pf") and last("pf").p == "171:120,182:95", "mine shared: " .. tostring(last("pf") and last("pf").p))

-- guildmates'
STUB.Receive("LVLM", C.Encode("hb", { l = 20, z = 1421 }), "GUILD", "Mario-Testrealm")
STUB.Receive("LVLM", C.Encode("hb", { l = 20, z = 1421 }), "GUILD", "Ana-Testrealm")
STUB.Receive("LVLM", C.Encode("pf", { p = "164:80,171:200,999:5" }), "GUILD", "Mario-Testrealm")
STUB.Receive("LVLM", C.Encode("pf", { p = "171:50" }), "GUILD", "Nadie-Testrealm")
local rows = P.List()
local seen = {}
for _, r in ipairs(rows) do seen[#seen + 1] = r.name .. ":" .. r.id .. ":" .. r.rank end
assert(table.concat(seen, ",") == "Mario:171:200,Tester:171:120,Mario:164:80,Tester:182:95", "by profession, rank: " .. table.concat(seen, ","))
assert(P.Name(171) == L.PROF_171, "localized names")
STUB.Receive("LVLM", C.Encode("pf", {}), "GUILD", "Mario-Testrealm")
assert(#P.List() == 2, "Mario withdrew")
STUB.Receive("LVLM", C.Encode("pf", { p = "197:90" }), "GUILD", "Ana-Testrealm")
ns.db.professions[GetGuildInfo("player")].Ana.t = time() - 31 * 86400
assert(#P.List() == 2, "forgotten after 30 days")
STUB.Receive("LVLM", C.Encode("pf", { p = "197:90" }), "GUILD", "Ana-Testrealm")
STUB.guildMembers = { Tester = true, Mario = true, Luis = true }; R.InvalidateGuildRoster()
assert(#P.List() == 2, "not shown once out of the guild")
STUB.guildMembers = { Tester = true, Mario = true, Ana = true, Luis = true }; R.InvalidateGuildRoster()

-- newcomers get mine
local n = #STUB.sent
STUB.Receive("LVLM", C.Encode("ping", {}), "GUILD", "Luis-Testrealm"); STUB.Advance(6)
local got = false
for i = n + 1, #STUB.sent do local k, f = C.Decode(STUB.sent[i].msg); if k == "pf" and f.p == "171:120,182:95" then got = true end end
assert(got, "a newcomer gets mine")

-- sharing off withdraws at once; refused sends stay pending
ns.db.settings.shareProfessions = false
P.SetSharing(false)
assert(last("pf") and last("pf").p == nil, "withdrawn")
ns.db.settings.shareProfessions = true
STUB.inInstance = true
ns.char.skills[182].rank = 100; ns.Fire("LM_SKILLS_CHANGED")
assert(LevelMatesDB.chars[ns.PlayerKey()].profPending == true, "refused inside: pending")
STUB.inInstance = false
ns.Fire("LM_HB_SENT")
assert(last("pf").p == "171:120,182:100" and not LevelMatesDB.chars[ns.PlayerKey()].profPending, "sent after the heartbeat")
