-- two guildmates claim the same catch-up in the same instant: only the lower name sends
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(30)
local S, C = ns.Sync, ns.Comm
S.Define("tcl", { class = "board", life = 3600, fields = { n = C.V.text(40) }, required = { "n" } })
S.Put("tcl", "k1", { n = "algo" }); STUB.Advance(2)
local function whispered(from) local n = 0; for i = from + 1, #STUB.sent do local s = STUB.sent[i]; if s.chatType == "WHISPER" and (C.Decode(s.msg)) == "tcl" then n = n + 1 end end; return n end
local function claimMine(from)   -- wait until my claim for Luis went out (after message number from)
	for _ = 1, 40 do
		STUB.Advance(0.2)
		for i = #STUB.sent, from + 1, -1 do local k, f = C.Decode(STUB.sent[i].msg); if k == "hc" and f.to == "Luis" then return end end
	end
	error("no claim")
end
-- a rival with a lower name claims in the same instant: I stay quiet
local n = #STUB.sent
STUB.Receive("LVLM2", C.Encode("hi", { s = "" }), "GUILD", "Luis-Testrealm")
claimMine(n)
STUB.Receive("LVLM2", C.Encode("hc", { to = "Luis", t = "tcl" }), "GUILD", "Ana-Testrealm")
STUB.Advance(3)
assert(whispered(n) == 0, "Ana sorts first: she sends")
-- a rival with a higher name: I send
STUB.Advance(31)
n = #STUB.sent
STUB.Receive("LVLM2", C.Encode("hi", { s = "" }), "GUILD", "Luis-Testrealm")
claimMine(n)
STUB.Receive("LVLM2", C.Encode("hc", { to = "Luis", t = "tcl" }), "GUILD", "Zoe-Testrealm")
STUB.Advance(3)
assert(whispered(n) == 1, "Tester sorts before Zoe: I send")
