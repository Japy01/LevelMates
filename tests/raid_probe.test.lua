-- /lm sondabanda: inside an instance, out of combat, a test addon message over the group channel and one whispered
-- to myself; the server's answer codes and whether the echo comes back, said in chat and kept for the report
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local C, L, RP = ns.Comm, ns.L, ns.Report
local function lastSaid() return STUB.printed[#STUB.printed] or "" end
local function sentAfter(n, kind) local out = {}; for i = n + 1, #STUB.sent do if STUB.sent[i].chatType == kind then out[#out + 1] = STUB.sent[i] end end; return out end

-- outside an instance: told to go inside, nothing sent
local n = #STUB.sent
SlashCmdList["LEVELMATES"]("sondabanda")
assert(lastSaid():find(L.PROBE_OUTSIDE, 1, true) and #STUB.sent == n, "outside: nothing")
-- in combat: told to wait
STUB.inInstance = true; STUB.inCombat = true
SlashCmdList["LEVELMATES"]("sondabanda")
assert(lastSaid():find(L.PROBE_COMBAT, 1, true) and #STUB.sent == n, "in combat: nothing")
STUB.inCombat = false

-- in a party inside an instance: one message on PARTY and one whispered to me, both accepted (code 0)
IsInGroup = function() return true end
IsInRaid = function() return false end
SlashCmdList["LEVELMATES"]("sondabanda")
local party, whisper = sentAfter(n, "PARTY"), sentAfter(n, "WHISPER")
assert(#party == 1 and party[1].msg:find("^LMPROBE:") and #whisper == 1 and whisper[1].target == "Tester" and whisper[1].msg == party[1].msg, "a probe on PARTY and one to myself")
assert(lastSaid():find("PARTY", 1, true) and lastSaid():find("0", 1, true), "codes said: " .. lastSaid())
-- the echoes come back: said, and the result kept
STUB.Receive("LVLM2", party[1].msg, "PARTY", "Tester-Testrealm")
STUB.Receive("LVLM2", party[1].msg, "WHISPER", "Tester-Testrealm")
STUB.Advance(6)
local p = ns.db.probes and ns.db.probes.last
assert(p and p.group == "PARTY" and p.codes.PARTY == 0 and p.codes.WHISPER == 0 and p.echo.PARTY and p.echo.WHISPER and p.lock == false, "the result kept: " .. tostring(p and p.group))
assert(RP.Text():find("PARTY", 1, true) and RP.Text():find(L.REPORT_PROBE, 1, true), "in the report")

-- in a raid under a lockdown: code 11, no echo
IsInRaid = function() return true end
STUB.lockdown = true
n = #STUB.sent
SlashCmdList["LEVELMATES"]("sondabanda"); STUB.Advance(6)
p = ns.db.probes.last
assert(p.group == "RAID" and p.codes.RAID == 11 and p.codes.WHISPER == 11 and not p.echo.RAID and p.lock == true, "lockdown measured: " .. tostring(p.codes.RAID))
assert(#sentAfter(n, "RAID") == 0, "nothing really went")
STUB.lockdown = false; STUB.inInstance = false
