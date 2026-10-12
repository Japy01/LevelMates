-- final review fixes (sync v2)
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(30)
local S, C = ns.Sync, ns.Comm
local T = GetServerTime
local function last(kind, from) for i = #STUB.sent, (from or 0) + 1, -1 do local k, f = C.Decode(STUB.sent[i].msg); if k == kind then return f, STUB.sent[i] end end end

-- C1: a record held inside a dungeon and dropped (urgent: 10 minutes) is sent again after leaving
S.Define("tc1", { class = "board", life = 86400, lane = "urgent", fields = { n = C.V.text(20) }, required = { "n" } })
STUB.inInstance = true
S.Put("tc1", "a", { n = "dentro" })
STUB.Advance(700)   -- dropped from the queue after 10 minutes
STUB.inInstance = false
local n = #STUB.sent
STUB.Fire("ZONE_CHANGED_NEW_AREA"); STUB.Advance(100)
assert(last("tc1", n), "C1: resent after the drop")

-- C2: market offers are published again at announce when there is no live record of mine
local GF = ns.Gifts
ns.char.gifts = { { id = 765, t = time(), price = 15000 } }
ns.db.sync["Test Guild"].sl = {}
n = #STUB.sent
STUB.Fire("PLAYER_ENTERING_WORLD", false, true); STUB.Advance(5)
assert(last("sl", n) and last("sl", n).p == "765:15000", "C2: my offers go out at announce")

-- I3: expiry clamped to the type's life; ids bound to their owner
S.Define("tc3", { class = "board", life = 3600, fields = { n = C.V.text(20) }, required = { "n" } })
STUB.Receive("LVLM2", C.Encode("tc3", { id = "x1", n = "eterno", v = T(), e = 4000000000 }), "GUILD", "Mario-Testrealm")
assert(S.Get("tc3", "x1") and S.Get("tc3", "x1").e <= T() + 3600 + S.FUTURE, "I3: expiry clamped")
STUB.Receive("LVLM2", C.Encode("gv", { id = ns.NameKey("Ana"), ids = "1", v = T(), e = T() + 600 }), "GUILD", "Luis-Testrealm")
assert(not S.Get("gv", ns.NameKey("Ana")), "I3: Luis cannot take Ana's market id")
assert(ns.NameKey("Élia") ~= ns.NameKey("Ëlia") and #ns.NameKey("Ñúñez") > 0, "I3: accents do not collide or vanish")

-- I4: the digest counts what a batch would send; batches are capped at 20, on the normal lane, without the asker's own
S.Define("tc4", { class = "board", life = 86400, fields = { n = C.V.text(20) }, required = { "n" } })
for i = 1, 30 do S.Put("tc4", "k" .. i, { n = "v" .. i }) end
STUB.Receive("LVLM2", C.Encode("tc4", { id = "luis1", n = "suya", v = T(), e = T() + 600 }), "GUILD", "Luis-Testrealm")
STUB.Advance(60)
n = #STUB.sent
STUB.Receive("LVLM2", C.Encode("hi", { s = "" }), "GUILD", "Luis-Testrealm"); STUB.Advance(60)
local sent4, his = 0, false
for i = n + 1, #STUB.sent do
	local k, f = C.Decode(STUB.sent[i].msg)
	if k == "tc4" and STUB.sent[i].chatType == "WHISPER" then sent4 = sent4 + 1; if f.id == "luis1" then his = true end end
end
assert(sent4 > 0 and sent4 <= 20 and not his, "I4: at most 20, and not his own: " .. sent4)

-- I5: no catch-up answers from inside a dungeon
STUB.inInstance = true
local a0 = S.stats.answered
STUB.Receive("LVLM2", C.Encode("hi", { s = "" }), "GUILD", "Ana-Testrealm"); STUB.Advance(10)
assert(S.stats.answered == a0, "I5: quiet inside")
STUB.inInstance = false

-- I6: a whispered record that arrives before the guild roster is loaded is kept and taken once it loads
local real = STUB.guildMembers
STUB.guildMembers = {}
ns.Roster.InvalidateGuildRoster()
STUB.Receive("LVLM2", C.Encode("tc3", { id = "early", o = "Mario", n = "pronto", v = T(), e = T() + 600 }), "WHISPER", "Ana-Testrealm")
assert(not S.Get("tc3", "early"), "not yet")
STUB.guildMembers = real
ns.Roster.InvalidateGuildRoster()
STUB.Fire("GUILD_ROSTER_UPDATE"); STUB.Advance(6)
assert(S.Get("tc3", "early"), "I6: taken once the roster loaded")
