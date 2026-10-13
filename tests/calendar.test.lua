STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local B, M, L = ns.Board, ns.Meetups, ns.L
STUB.Receive("LVLM2", ns.Comm.Encode("hb", { l = 24, z = 1421 }), "GUILD", "Mario-Testrealm")
M.AddSample("Mario", 5, 90, { Ana = "H" })
M.AddSample("Ana", 4, 24 * 60, {})
M.AddSample("Luis", 6, 9 * 24 * 60, {})   -- more than a week away

B.Toggle(); B.ShowTab("lfg")
assert(B.lfgCalendarButton and B.lfgCalendarButton:IsShown() and B.lfgCalendarButton.text == L.BTN_RUNS, "a Runs button on the Dungeons tab")
B.lfgCalendarButton.scripts.OnClick(B.lfgCalendarButton)
for _, c in ipairs(B.cards) do assert(not c:IsShown(), "no cards in the calendar") end
local RV = ns.RunsView
local shown = {}
for _, c in ipairs(RV.cards) do if c:IsShown() then shown[#shown + 1] = c end end
assert(#shown == 2, "today and tomorrow, the far one left out: " .. #shown)
local card = shown[1]
assert(card.meet.by == "Mario" and card.text.text:find(ns.Dungeons.Name(5), 1, true), "Mario's run first")
assert(ns.Meetups.Count(card.meet) == 2, "who goes: Mario and Ana")
assert(B.heading.text == L.HEAD_RUNS and B.lfgCalendarButton.text == L.BTN_CARDS, "the runs heading; the button goes back")
local rows = { nil, { button = card } }

-- a click: join with a role, leave, cancel mine
local made = {}
MenuUtil.CreateContextMenu = function(owner, fn) made = {}; local root = { CreateTitle = function() end, CreateButton = function(_, text, f) made[#made + 1] = { text = text, fn = f } end }; fn(owner, root) end

card.scripts.OnClick(card, "LeftButton")
local when = M.When(rows[2].button.meet)
local join
for _, m in ipairs(made) do if m.text == string.format(L.MEET_JOIN, when, L.ROLE_T) then join = m end end
assert(join, "join as tank")
join.fn()
assert(M.MyRole(rows[2].button.meet.id) == "T", "joined")
card.scripts.OnClick(card, "LeftButton")
assert(made[1].text == string.format(L.MEET_LEAVE, when), "now: leave")

-- back to the cards
B.lfgCalendarButton.scripts.OnClick(B.lfgCalendarButton)
local cards = 0
for _, c in ipairs(B.cards) do if c:IsShown() then cards = cards + 1 end end
assert(cards == 14, "the cards again")
M.RemoveSamples()
B.lfgCalendarButton.scripts.OnClick(B.lfgCalendarButton)
assert(RV.soon.hint:IsShown() and RV.later.hint:IsShown(), "nothing planned: the hints")
