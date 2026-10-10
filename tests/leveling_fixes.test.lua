STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local C, RA, Q, H, R, L = ns.Comm, ns.Rares, ns.QuestProgress, ns.Help, ns.Roster, ns.L
local function count(kind, from) local n = 0; for i = from + 1, #STUB.sent do if (C.Decode(STUB.sent[i].msg)) == kind then n = n + 1 end end; return n end
local function said(text) local n = 0; for _, p in ipairs(STUB.printed) do if p:find(text, 1, true) then n = n + 1 end end; return n end
STUB.guildMembers = { Tester = true, Mario = true, Ana = true }
R.InvalidateGuildRoster()
STUB.Receive("LVLM", C.Encode("hb", { l = 20, z = 1412 }), "GUILD", "Mario-Testrealm")
STUB.Receive("LVLM", C.Encode("hb", { l = 20, z = 1412 }), "GUILD", "Ana-Testrealm")

-- #1a: a sighting carries my position: only with "share position" on (and sightings on)
STUB.player.mapId = 1412
STUB.units.target = { name = "Mangaleta", class = "rare" }
ns.db.settings.sharePos = false
local n = #STUB.sent
STUB.Fire("PLAYER_TARGET_CHANGED")
assert(count("rr", n) == 0, "no position sharing: no sighting")
ns.db.settings.sharePos = true; ns.db.settings.rareNotices = false
STUB.Fire("PLAYER_TARGET_CHANGED")
assert(count("rr", n) == 0, "sightings off: none")
ns.db.settings.rareNotices = true
STUB.Fire("PLAYER_TARGET_CHANGED")
assert(count("rr", n) == 1, "both on: sent")

-- #1b: quest progress only with "share quests" on
STUB.quests = { 101 }
STUB.objectives[101] = { { numFulfilled = 2, numRequired = 10, finished = false } }
STUB.Receive("LVLM", C.Encode("q", { i = "1/1", ids = "101" }), "GUILD", "Mario-Testrealm")
STUB.partyMembers.Mario = true
ns.db.settings.shareQuests = false
n = #STUB.sent
Q.SendChanged()
assert(count("qo", n) == 0, "quests not shared: no progress")
ns.db.settings.shareQuests = true
Q.SendChanged()
assert(count("qo", n) == 1, "shared: sent")

-- #2: a groupmate who comes back (reload) gets my progress again
n = #STUB.sent
STUB.Receive("LVLM", C.Encode("q", { i = "1/1", ids = "101" }), "GUILD", "Mario-Testrealm"); STUB.Advance(3)
assert(count("qo", n) == 1, "re-sent to him")

-- #3: only my group's progress counts; an old completion is not news
STUB.Receive("LVLM", C.Encode("qo", { i = 101, o = "5/10" }), "GUILD", "Ana-Testrealm")
assert(not (R.mates.Ana.progress and R.mates.Ana.progress[101]), "Ana is not in my group: ignored")
STUB.Receive("LVLM", C.Encode("qo", { i = 101, o = "10/10" }), "GUILD", "Mario-Testrealm")
assert(said(string.format(L.QUEST_DONE, "Mario", "Quest 101")) == 0, "first word from him is already complete: not announced")
assert(#Q.Shared("Mario") == 1, "but shown")

-- #4: panic again while my request is active replaces it (the old one is withdrawn)
n = #STUB.sent
assert(H.Panic(), "first")
STUB.Advance(H.PANIC_GAP + 1)
assert(H.Panic(), "second, later")
assert(count("help", n) == 2 and count("helpok", n) == 1, "the first is withdrawn before the second")
