STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
local C = ns.Comm
C.Start()
STUB.Advance(1)
assert(STUB.prefixes["LVLM2"], "prefix registered")
-- guild transport by default (auto → guild first)
C.Send("hb", { l = 22, z = 1421 })
STUB.Advance(0.5)
assert(#STUB.sent == 1 and STUB.sent[1].chatType == "GUILD", "hb sent on GUILD")
-- receive from another player
local got
C.OnMessage("hb", function(f, name, full) got = { f = f, name = name, full = full } end)
STUB.Receive("LVLM2", C.Encode("hb", { l = 30, z = 1 }), "GUILD", "Mario-Testrealm")
assert(got and got.name == "Mario" and got.full == "Mario-Testrealm" and got.f.l == 30, "message dispatched")
-- own message ignored
got = nil
STUB.Receive("LVLM2", C.Encode("hb", { l = 30, z = 1 }), "GUILD", "Tester-Testrealm")
assert(got == nil, "own echo ignored")
-- Forever shows the sender as "Name Realm" in the spike's echo (screenshot): own echo must be dropped in every spelling
for _, spelled in ipairs({ "Tester Testrealm", "Tester-Testrealm", "Tester", "TesterTestrealm" }) do
	got = nil
	STUB.Receive("LVLM2", C.Encode("hb", { l = 30, z = 1 }), "GUILD", spelled)
	assert(got == nil, "own echo ignored as '" .. spelled .. "'")
end
-- malformed counted, not dispatched
STUB.Receive("LVLM2", "v1\31hb\31l=9999", "GUILD", "Mario-Testrealm")
assert(C.stats.bad == 1 and got == nil, "bad counted")
-- lockdown queues and compacts hb
STUB.lockdown = true
C.Send("hb", { l = 22, z = 1421 }); C.Send("hb", { l = 23, z = 1421 }); C.Send("help", { t = "x", z = 1, x = 1, y = 1, id = "ab" })
STUB.Advance(5)
assert(#STUB.sent == 1, "nothing sent in lockdown")
STUB.lockdown = false
STUB.Advance(1)
assert(#STUB.sent == 3, "queue flushed: latest hb + help, got " .. #STUB.sent)
assert(STUB.sent[2].msg:find("l=23") or STUB.sent[3].msg:find("l=23"), "only the latest hb kept")
-- a newer heartbeat takes the queued one's place, so what was queued after it stays after it
STUB.lockdown = true
local q0 = #STUB.sent
C.Send("hb", { l = 22, z = 1421 }); C.Send("pal", { p = 1 }); C.Send("hb", { l = 23, z = 1421 })
STUB.lockdown = false
STUB.Advance(2)
local k1, f1 = C.Decode(STUB.sent[q0 + 1].msg)
local k2 = C.Decode(STUB.sent[q0 + 2].msg)
assert(k1 == "hb" and f1.l == 23 and k2 == "pal", "hb kept its place ahead of pal: " .. tostring(k1) .. "," .. tostring(k2))
-- Forever's restriction flag can read true while sends still work (spike): only the send result decides
STUB.reportsRestricted = true
local r0 = #STUB.sent
C.Send("hi", { s = "" })
STUB.Advance(1)
assert(#STUB.sent == r0 + 1, "sent although the restriction flag reads true")
STUB.reportsRestricted = false
-- inside an instance only help/helpok go out (spec 4.3): heartbeats, pings and quests are refused, not queued
STUB.inInstance = true
local i0 = #STUB.sent
assert(C.Send("hb", { l = 22, z = 1421 }) == false, "hb refused in an instance")
assert(C.Send("hi", { s = "" }) == false and C.Send("q", { i = "1/1", ids = "1" }) == false, "hi and q refused in an instance")
assert(C.Send("lfg", { d = 2, r = "T", id = "in02", m = 20 }) == false and C.Send("lfgx", { id = "in02" }) == false, "group finder messages refused in an instance")
assert(C.Send("pal", { p = 1 }) == false, "partner flag refused in an instance")
assert(C.Send("help", { t = "x", z = 1, x = 1, y = 1, id = "in01" }) == true, "help allowed in an instance")
assert(C.Send("helpok", { id = "in01" }) == true, "helpok allowed in an instance")
STUB.Advance(2)
assert(#STUB.sent == i0 + 2, "only help and helpok sent, got " .. (#STUB.sent - i0))
STUB.inInstance = false
C.Send("hb", { l = 22, z = 1421 }); STUB.Advance(1)
assert(#STUB.sent == i0 + 3 and select(1, C.Decode(STUB.sent[#STUB.sent].msg)) == "hb", "hb flows again outside")
-- a heartbeat queued just before entering is dropped, not sent from inside
STUB.lockdown = true
C.Send("hb", { l = 23, z = 1421 })
STUB.inInstance = true
STUB.lockdown = false
local i1 = #STUB.sent
STUB.Advance(2)
assert(#STUB.sent == i1, "queued hb dropped once inside an instance")
STUB.inInstance = false
-- a throttled send (result 3) is retried on the same transport, not dropped and not a reason to switch
STUB.throttleNext = 1
local b = #STUB.sent
C.Send("hi", { s = "" })
STUB.Advance(2)
assert(#STUB.sent == b + 1 and STUB.sent[#STUB.sent].chatType == "GUILD" and C.ActiveTransport() == "guild", "throttled send retried on GUILD")
-- throttle: 30 sends at once go out at most 10 then 1/s
local before = #STUB.sent
for i = 1, 30 do C.Send("hi", { s = "" }, "normal") end
STUB.Advance(0.2)
assert(#STUB.sent - before <= 10, "burst limited to 10")
STUB.Advance(30)
assert(#STUB.sent - before == 30, "all delivered within 30 s")
-- channel transport
ns.db.settings.transport = "channel"
C.Stop(); C.Start()
C.Send("hb", { l = 22, z = 1421 })   -- the join is still a pending round-trip: must wait, not drop
STUB.Advance(1)
local last = STUB.sent[#STUB.sent]
assert(last.chatType == "CHANNEL" and type(last.target) == "number" and last.msg:find("l=22"), "sent on hidden channel once joined")
assert(C.ActiveTransport() == "channel")
-- hidden channel: only names on the guild roster get through, the roster is read once and cached
local lookups = 0
local realGetClubMembers = C_Club.GetClubMembers
C_Club.GetClubMembers = function(...) lookups = lookups + 1; return realGetClubMembers(...) end
got = nil
local badBefore = C.stats.bad
STUB.Receive("LVLM2", C.Encode("hb", { l = 30, z = 1 }), "CHANNEL", "Stranger-Testrealm")
assert(got == nil and C.stats.bad == badBefore + 1, "stranger dropped and counted")
STUB.Receive("LVLM2", C.Encode("hb", { l = 30, z = 1 }), "CHANNEL", "Mario-Testrealm")
assert(got and got.name == "Mario", "guildmate accepted on channel")
STUB.Receive("LVLM2", C.Encode("hb", { l = 31, z = 1 }), "CHANNEL", "Mario-Testrealm")
assert(lookups == 1, "roster cached, looked up once, got " .. lookups)
got = nil
STUB.Receive("LVLM2", C.Encode("hb", { l = 30, z = 1 }), "GUILD", "Mario-Testrealm")
assert(got and got.name == "Mario", "GUILD is server-authenticated: accepted on any transport")
-- a new member shows up after the roster changes
STUB.guildMembers.Nuevo = true
got = nil
STUB.Receive("LVLM2", C.Encode("hb", { l = 30, z = 1 }), "CHANNEL", "Nuevo-Testrealm")
assert(got == nil, "not yet on the cached roster")
STUB.Fire("GUILD_ROSTER_UPDATE")
STUB.Receive("LVLM2", C.Encode("hb", { l = 30, z = 1 }), "CHANNEL", "Nuevo-Testrealm")
assert(got and got.name == "Nuevo", "accepted after roster update")
-- no roster API at all: fail closed on the hidden channel
C_Club.GetGuildClubId = function() return nil end
STUB.Fire("GUILD_ROSTER_UPDATE")
got = nil
STUB.Receive("LVLM2", C.Encode("hb", { l = 30, z = 1 }), "CHANNEL", "Mario-Testrealm")
assert(got == nil, "without a roster nobody is trusted on the channel")
