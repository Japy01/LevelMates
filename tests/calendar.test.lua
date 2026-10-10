STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local B, M, L = ns.Board, ns.Meetups, ns.L
STUB.Receive("LVLM", ns.Comm.Encode("hb", { l = 24, z = 1421 }), "GUILD", "Mario-Testrealm")
M.AddSample("Mario", 5, 90, { Ana = "H" })
M.AddSample("Ana", 4, 24 * 60, {})
M.AddSample("Luis", 6, 9 * 24 * 60, {})   -- more than a week away

B.Toggle(); B.ShowTab("lfg")
assert(B.lfgCalendarButton and B.lfgCalendarButton:IsShown() and B.lfgCalendarButton.text == L.BTN_CALENDAR, "a Calendar button on the Dungeons tab")
B.lfgCalendarButton.scripts.OnClick(B.lfgCalendarButton)
for _, c in ipairs(B.cards) do assert(not c:IsShown(), "no cards in the calendar") end
local rows = {}
for _, r in ipairs(B.rows) do if r.button:IsShown() then rows[#rows + 1] = r end end
assert(#rows == 4, "two days, a meetup each, the far one left out: " .. #rows)
assert(rows[1].button.meetHeader and rows[2].button.meet and rows[2].zone.text:find(ns.Dungeons.Name(5), 1, true) and rows[2].zone.text:find("Mario", 1, true), "a day, then its meetup")
assert(rows[2].group.text == "2", "who goes: Mario and Ana")
assert(B.heading.text == L.HEAD_CALENDAR and B.lfgCalendarButton.text == L.BTN_CARDS, "the calendar heading; the button goes back")

-- a click: join with a role, leave, cancel mine
local made = {}
MenuUtil.CreateContextMenu = function(owner, fn) made = {}; local root = { CreateTitle = function() end, CreateButton = function(_, text, f) made[#made + 1] = { text = text, fn = f } end }; fn(owner, root) end
rows[2].button.scripts.OnClick(rows[2].button, "LeftButton")
local when = M.When(rows[2].button.meet)
local join
for _, m in ipairs(made) do if m.text == string.format(L.MEET_JOIN, when, L.ROLE_T) then join = m end end
assert(join, "join as tank")
join.fn()
assert(M.MyRole(rows[2].button.meet.id) == "T", "joined")
rows[2].button.scripts.OnClick(rows[2].button, "LeftButton")
assert(made[1].text == string.format(L.MEET_LEAVE, when), "now: leave")

-- back to the cards
B.lfgCalendarButton.scripts.OnClick(B.lfgCalendarButton)
local cards = 0
for _, c in ipairs(B.cards) do if c:IsShown() then cards = cards + 1 end end
assert(cards == 14, "the cards again")
M.RemoveSamples()
B.lfgCalendarButton.scripts.OnClick(B.lfgCalendarButton)
assert(B.frame.empty.text == L.CAL_EMPTY, "nothing planned")
