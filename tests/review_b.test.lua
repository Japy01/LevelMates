-- interface phase B, final review: the fixes
COMBATLOG_XPGAIN_FIRSTPERSON = "%s dies, you gain %d experience."
STUB.player.xp = 0
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false)
local LB, M, B, L = ns.LevelBar, ns.Meetups, ns.Board, ns.L

-- 4: XP per hour counts from when the bar started watching, not from the first kill
STUB.Advance(300)
STUB.player.xp = 400; STUB.Fire("PLAYER_XP_UPDATE", "player")
local rate = LB.Rate()
assert(rate and rate < 5000, "400 XP in 5 minutes is about 4800/h, not 24k: " .. tostring(rate))

-- 1: kills with a rested or group bonus count; numbered arguments do not break the pattern
STUB.Fire("CHAT_MSG_COMBAT_XP_GAIN", "Kobold dies, you gain 45 experience. (+22 exp Rested bonus)")
STUB.Fire("CHAT_MSG_COMBAT_XP_GAIN", "Kobold dies, you gain 45 experience. (+5 group bonus)")
assert(LB.Kills() == 2, "bonus kills count: " .. LB.Kills())
COMBATLOG_XPGAIN_FIRSTPERSON = "%1$s muere, ganas %2$d puntos de experiencia."
LB.KILL = nil
STUB.Fire("CHAT_MSG_COMBAT_XP_GAIN", "Kobold muere, ganas 45 puntos de experiencia. (+22 exp. descansada)")
assert(LB.Kills() == 3, "a numbered-argument string works too: " .. LB.Kills())

-- 2: the day buttons follow the clock
B.Toggle(); B.ShowTab("lfg"); B.lfgCalendar = true; B.Refresh()
local f = ns.GroupsView.form
STUB.Advance(86400)
ns.GroupsView.Refresh()
for i, chip in ipairs(f.when) do if i > 1 then assert(chip.text == ns.MeetDialog.DayName(i - 2), "day " .. i .. " relabelled: " .. tostring(chip.text)) end end

-- 3: more runs today and tomorrow than cards: the rest go to the list below, not out of reach
for i = 1, 6 do M.AddSample("P" .. i, i, 20 + i * 10, {}) end
local GV = ns.GroupsView
GV.Refresh()
local cards, listed = 0, 0
for _, c in ipairs(GV.list.cards) do if c:IsShown() then cards = cards + 1 end end
listed = 6 - cards
assert(cards == GV.PER_PAGE and GV.next:IsEnabled(), "a page of cards, the rest a click away: " .. cards)
