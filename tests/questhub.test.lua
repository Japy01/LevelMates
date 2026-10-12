-- the guild quest board: post from my log, withdraw, me too, notices, filters
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(30)
local QH, C, L = ns.Questhub, ns.Comm, ns.L
local function last(kind) for i = #STUB.sent, 1, -1 do local k, f = C.Decode(STUB.sent[i].msg); if k == kind then return f end end end
local function said(text) local n = 0; for _, p in ipairs(STUB.printed) do if p:find(text, 1, true) then n = n + 1 end end; return n end
STUB.quests = { 101, 202 }
STUB.questTags = { [202] = { tagID = 1, tagName = "Group" } }
STUB.Receive("LVLM2", C.Encode("hb", { l = 21, z = 1412, c = "MAGE" }), "GUILD", "Mario-Testrealm")
-- post and withdraw
assert(QH.Post(101), "posted")
local f = last("qh")
assert(f and f.q == 101 and f.t == "Quest 101" and f.l == 20 and f.id == "101." .. ns.NameKey(ns.Me()), "fields from my log")
assert(QH.MineFor(101), "mine")
QH.Toggle(101)
assert(not QH.MineFor(101) and last("x") and last("x").t == "qh", "withdrawn")
QH.Post(202)
assert(QH.List()[1] and QH.List()[1].g == 1, "a group quest")
STUB.Fire("QUEST_TURNED_IN", 202, 0, 0)
assert(not QH.MineFor(202), "turned in: withdrawn")
-- Mario's post of a quest I have: a notice, once
local before = said("Mario")
STUB.Receive("LVLM2", C.Encode("qh", STUB.Rec{ id = "101." .. ns.NameKey("Mario"), q = 101, t = "Quest 101", l = 20, z = "Mulgore", g = 0 }), "GUILD", "Mario-Testrealm")
assert(said("Mario") == before + 1, "told: I have it too")
STUB.Receive("LVLM2", C.Encode("qh", STUB.Rec{ id = "101." .. ns.NameKey("Mario"), q = 101, t = "Quest 101", l = 20, z = "Mulgore", g = 0 }), "GUILD", "Mario-Testrealm")
assert(said("Mario") == before + 1, "once")
-- someone else's id refused
STUB.Receive("LVLM2", C.Encode("qh", STUB.Rec{ id = "303." .. ns.NameKey("Ana"), q = 303, t = "Quest 303", l = 20, z = "Mulgore", g = 0 }), "GUILD", "Mario-Testrealm")
for _, p in ipairs(QH.List()) do assert(p.q ~= 303, "not Mario's to post as Ana") end
-- me too
local post = QH.List()[1]
assert(QH.MeToo(post.id) and last("qhj").id == post.id .. "." .. ns.NameKey(ns.Me()), "me too")
assert(QH.List()[1].joined[1] == ns.Me() and QH.IJoined(post.id), "listed")
QH.NotMe(post.id)
assert(#QH.List()[1].joined == 0, "taken off")
-- handed over at login: listed, not announced
before = #STUB.printed
STUB.Receive("LVLM2", C.Encode("qh", STUB.Rec{ id = "202." .. ns.NameKey("Mario"), q = 202, t = "Quest 202", l = 20, z = "Mulgore", g = 1, o = "Mario" }), "WHISPER", "Mario-Testrealm")
assert(#STUB.printed == before, "no notice for catch-up")
-- filters
assert(#QH.List("group") == 1 and QH.List("group")[1].q == 202, "group filter")
assert(#QH.List("level") == 2, "level filter (both at 20)")
