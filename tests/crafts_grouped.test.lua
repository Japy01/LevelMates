STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local C, B, P, R, L = ns.Comm, ns.Board, ns.Professions, ns.Roster, ns.L
local function last(kind) for i = #STUB.sent, 1, -1 do local k, f = C.Decode(STUB.sent[i].msg); if k == kind then return f end end end
STUB.guildMembers = { Tester = true, Mario = true, Ana = true }
R.InvalidateGuildRoster()

-- the journal keeps the maximum rank too, and it travels
STUB.skills = { { skillID = 129, name = "First Aid", rank = 37, maxRank = 75 }, { skillID = 186, name = "Mining", rank = 6, maxRank = 75 }, { skillID = 185, name = "Cooking", rank = 7, maxRank = 75 } }
STUB.Fire("SKILL_LINES_CHANGED")
assert(ns.char.skills[129].max == 75, "max rank kept")
assert(C.Validate("pf", { p = "129:37:75,185:7" }) and C.Validate("pf", { p = "129:37:451" }) == false, "rank:max pairs")
assert(last("pf") and last("pf").p == "129:37:75,185:7:75,186:6:75", "shared with the max: " .. tostring(last("pf") and last("pf").p))

STUB.Receive("LVLM2", C.Encode("hb", { l = 30, z = 1421, c = "MAGE" }), "GUILD", "Mario-Testrealm")
STUB.Receive("LVLM2", C.Encode("pf", { p = "129:75:75" }), "GUILD", "Mario-Testrealm")
STUB.Receive("LVLM2", C.Encode("hb", { l = 20, z = 1421 }), "GUILD", "Ana-Testrealm")
STUB.Receive("LVLM2", C.Encode("pf", { p = "186:40" }), "GUILD", "Ana-Testrealm")
R.mates.Ana = nil   -- Ana logged off

-- by profession: who has it, highest first, with the bar, the rank, online and the trainer hint
B.ShowTab("crafts")
local CV = ns.CraftsView
local ids = {}
for _, it in ipairs(CV.profs.items) do if it:IsShown() then ids[#ids + 1] = it.prof end end
assert(#ids == 3, "three professions on the left")
CV.Select(129)
assert(CV.title.text == P.Name(129) and CV.sub.text:find("2", 1, true), "First Aid: two crafters")
local mario, me1 = CV.rows[1], CV.rows[2]
assert(mario.name.text == "Mario" and mario.rank.text == "75" and mario.read.text:find(L.ONLINE, 1, true) and mario.read.text:find(L.TRAIN_JOURNEYMAN, 1, true), "full rank, online, time to train: " .. mario.read.text)
assert(me1.name.text == "Tester" and me1.rank.text == "37" and not me1.read.text:find(L.ONLINE, 1, true), "my row: no 'online'")
CV.Select(186)
assert(CV.rows[1].name.text == "Ana" and not CV.rows[1].read.text:find(L.ONLINE, 1, true), "Ana offline: when seen")
