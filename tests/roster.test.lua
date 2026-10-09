STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
local R, C = ns.Roster, ns.Comm
STUB.Fire("PLAYER_ENTERING_WORLD", true, false)
STUB.Advance(1)
-- login sends ping + hb
local kinds = {}
for _, s in ipairs(STUB.sent) do kinds[#kinds + 1] = select(1, C.Decode(s.msg)) end
assert(table.concat(kinds, ",") == "ping,hb" or table.concat(kinds, ",") == "hb,ping", "ping and hb at login: " .. table.concat(kinds, ","))
-- unchanged state: no hb for 30 s ticks
local n = #STUB.sent
STUB.Advance(31); STUB.Advance(31)
assert(#STUB.sent == n, "no heartbeat without change")
-- level up → hb at the next tick, but not before 30 s since the last
STUB.player.level = 21
STUB.Fire("PLAYER_LEVEL_UP", 21)
STUB.Advance(1)
assert(#STUB.sent == n + 1 and STUB.sent[#STUB.sent].msg:find("l=21"), "level change sends hb")
-- receive mates
STUB.Receive("LVLM", C.Encode("hb", { l = 30, z = 1421, g = 1, s = 1, c = "MAGE" }), "GUILD", "Mario-Testrealm")
STUB.Receive("LVLM", C.Encode("hb", { l = 12, z = 1412 }), "GUILD", "Ana-Testrealm")
assert(R.mates.Mario and R.mates.Mario.level == 30 and R.mates.Mario.inGroup and R.mates.Mario.hasSlot, "mate stored")
assert(#R.List() == 2, "two mates")
-- ping from a newcomer → we answer with hb within 0-5 s
n = #STUB.sent
STUB.Receive("LVLM", C.Encode("ping", {}), "GUILD", "Luis-Testrealm")
STUB.Advance(6)
assert(#STUB.sent == n + 1, "answered ping")
-- expiry
STUB.Advance(121)
R.Expire()
assert(#R.List() == 0, "expired after 120 s")
-- bye removes at once
STUB.Receive("LVLM", C.Encode("hb", { l = 30, z = 1421 }), "GUILD", "Mario-Testrealm")
STUB.Receive("LVLM", C.Encode("bye", {}), "GUILD", "Mario-Testrealm")
assert(R.mates.Mario == nil, "bye removes")
-- quests only when sharing is on
STUB.quests = { 1098, 6562 }
ns.db.settings.shareQuests = false
n = #STUB.sent; STUB.Fire("QUEST_LOG_UPDATE"); STUB.Advance(3)
assert(#STUB.sent == n, "quests not sent when off")
ns.db.settings.shareQuests = true
STUB.Fire("QUEST_LOG_UPDATE"); STUB.Advance(3)
assert(STUB.sent[#STUB.sent].msg:find("ids=1098,6562"), "quest ids sent: " .. STUB.sent[#STUB.sent].msg)
-- mates' quests (Ana expired above; she announces herself again before her quest list, as at login)
STUB.Receive("LVLM", C.Encode("hb", { l = 12, z = 1412 }), "GUILD", "Ana-Testrealm")
STUB.Receive("LVLM", C.Encode("q", { i = "1/1", ids = "1098,959" }), "GUILD", "Ana-Testrealm")
assert(R.mates.Ana.quests[1098] and R.mates.Ana.quests[959], "mate quests stored")
-- a newcomer's ping gets my quest list too, not only a heartbeat (otherwise matching is one-way)
n = #STUB.sent
STUB.Receive("LVLM", C.Encode("ping", {}), "GUILD", "Luis-Testrealm")
STUB.Advance(6)
local answered = {}
for i = n + 1, #STUB.sent do answered[#answered + 1] = select(1, C.Decode(STUB.sent[i].msg)) end
table.sort(answered)
assert(table.concat(answered, ",") == "hb,q", "ping answered with hb and q: " .. table.concat(answered, ","))
-- XP/h restarts at a level-up: the XP bar resets, so the old window would report nonsense
ns.db.settings.shareXp = true
STUB.player.xp = 0
R.Snapshot(); STUB.Advance(120)
STUB.player.xp = 600
assert(R.Snapshot().r == 18000, "xp/h over a clean window: " .. tostring(R.Snapshot().r))
STUB.Fire("PLAYER_LEVEL_UP", 22)
STUB.player.xp = 50
assert(R.Snapshot().r == 0, "window restarted at level-up, not 50 xp over the old 120 s: " .. tostring(R.Snapshot().r))
