-- Loot rules as a page (lote 1, asked 2026-10-18): a "Reglas" view in Guild > Loot with the mode, points per boss
-- and attendance, lowest quality, minimum bid, reserves per person, the bid timer, who may answer (guild or the
-- whole raid) and which council answers are on; a summary in sentences for everyone; only officers edit. The
-- extra settings travel in their own record (lrx) so older clients keep the base rules (lru)
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.guildRoles = { Tester = 2, Ana = 2 }
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(30)
local B, LR, L, S, R = ns.Board, ns.LootRaid, ns.L, ns.Sync, ns.Roster
R.InvalidateGuildRoster()
STUB.iAmOfficer = true
-- defaults
local r = LR.Rules()
assert(r.timer == 0 and r.scope == "guild" and r.responses.bis and r.responses.main and r.responses.minor, "defaults: no timer, guild only, every answer on")
-- the view
B.Toggle(); B.ShowTab("loot")
B.lootRulesButton.scripts.OnClick(B.lootRulesButton)
assert(B.lootView == "rules" and B.lootRulesPanel:IsShown(), "the rules page")
local P = B.lootRules
assert(P.boss and P.att and P.minBid and P.reserves and P.mode and P.quality and P.timer and P.scope and P.rs.bis and P.save, "its controls")
assert(P.save:IsShown(), "officers see Save")
-- edit and save
P.boss:SetText("10"); P.att:SetText("5"); P.minBid:SetText("3"); P.reserves:SetText("1")
P.mode.scripts.OnClick(P.mode); STUB.MenuEntry(L.LC_MODE_dkp).cb()
P.quality.scripts.OnClick(P.quality); STUB.MenuEntry(L.LOOT_QUALITY_4).cb()
P.timer.scripts.OnClick(P.timer); STUB.MenuEntry(string.format(L.LOOT_TIMER_N, 120)).cb()
P.scope.scripts.OnClick(P.scope); STUB.MenuEntry(L.LOOT_SCOPE_RAID).cb()
P.rs.bis.scripts.OnClick(P.rs.bis)   -- BiS off
P.save.scripts.OnClick(P.save)
r = LR.Rules()
assert(r.boss == 10 and r.att == 5 and r.minBid == 3 and r.reserves == 1 and r.mode == "dkp" and r.quality == 4, "the base rules saved: " .. r.boss .. "/" .. r.att .. "/" .. r.minBid .. "/" .. r.reserves .. "/" .. r.mode .. "/" .. r.quality)
assert(r.timer == 120 and r.scope == "raid" and not r.responses.bis and r.responses.main and r.responses.minor, "the extra rules saved")
assert(S.Get("lru", "rules") and S.Get("lrx", "rules") and S.Get("lrx", "rules").d.tm == 120 and S.Get("lrx", "rules").d.sc == "raid", "two records: base and extra")
-- the summary says it in sentences
local text = LR.RulesSummary()
assert(text:find("10", 1, true) and text:find(L.LC_MODE_dkp, 1, true) and text:find("120", 1, true) and text:lower():find(L.LOOT_SCOPE_RAID:lower(), 1, true), "the summary: " .. text)
assert(P.summary.text == text, "shown on the page")
-- a member: the summary only
STUB.iAmOfficer = false; STUB.guildRoles = { Ana = 2 }; R.InvalidateGuildRoster()
B.Refresh()
assert(B.lootRulesPanel:IsShown() and not P.save:IsShown() and not P.boss:IsShown() and P.summary:IsShown(), "members read the rules, nothing to edit")
-- an extra record from a stranger is refused; from an officer it is taken
STUB.Receive("LVLM2", ns.Comm.Encode("lrx", STUB.Rec{ id = "rules", tm = 60, sc = "guild" }), "GUILD", "Nadie-Testrealm")
assert(LR.Rules().timer == 120, "a stranger cannot set the rules")
print("ok")
