-- Groups → Runs: today's and tomorrow's runs as cards with their slots and buttons, later ones as a list, and the
-- Create-run form beside them
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(30)
local B, M, L, C = ns.Board, ns.Meetups, ns.L, ns.Comm
STUB.Receive("LVLM2", C.Encode("hb", { l = 24, z = 1421, c = "MAGE" }), "GUILD", "Mario-Testrealm")
local made
MenuUtil.CreateContextMenu = function(owner, fn) made = {}; local root = { CreateTitle = function() end, CreateButton = function(_, text, f) made[#made + 1] = { text = text, fn = f } end }; fn(owner, root) end
local function pick(text) for _, m in ipairs(made) do if m.text == text then return m end end end

-- a run of Mario's in 90 minutes, one of Ana's in 3 days, one already started
local today = date("*t", time())
local minsLeft = (23 - today.hour) * 60 + (59 - today.min)
M.AddSample("Mario", 5, math.min(90, minsLeft - 1), { Ana = "H" })
M.AddSample("Ana", 4, 3 * 24 * 60, {})
M.AddSample("Luis", 6, -30, {})

B.Toggle(); B.ShowTab("lfg")
assert(B.lfgCalendarButton.text == L.BTN_RUNS, "the button says Runs")
assert(B.roleLine.point[2] == B.lfgButton, "My role sits right of Look for group, not over it")
B.lfgCalendarButton.scripts.OnClick(B.lfgCalendarButton)
local RV = ns.RunsView
assert(RV.frame:IsShown(), "the runs view")
for _, r in ipairs(B.rows) do assert(not r.button:IsShown(), "no list rows") end
assert(B.heading.text == L.HEAD_RUNS, "heading")

-- cards: Mario's run (not the started one); Ana's in 3 days in the later list
local card = RV.cards[1]
assert(card:IsShown() and card.meet.by == "Mario" and not RV.cards[2]:IsShown(), "one card: Mario's")
assert(#card.slots == 5, "five slots")
local filled = 0
for _, s in ipairs(card.slots) do if not s.empty then filled = filled + 1 end end
assert(filled == 2, "Mario and Ana: " .. filled)
assert(RV.later.items[1]:IsShown() and RV.later.items[1].text.text:find(ns.Dungeons.Name(4), 1, true), "Ana's run later")

-- someone else's run: Join opens the free roles; picking healer is refused as taken, tank joins
local join = card.buttons[1]
assert(join:IsShown() and join.text == L.RUN_JOIN, "Join")
join.scripts.OnClick(join)
assert(not pick(L.ROLE_H) and pick(L.ROLE_T) and pick(L.ROLE_D), "only free roles")
pick(L.ROLE_T).fn()
assert(M.MyRole(card.meet.id) == "T", "joined as tank")
RV.Refresh()
assert(card.buttons[1].text == L.RUN_LEAVE, "now: Leave")

-- the form: dungeon 5, tomorrow, 21:30, as a healer → published
local f = RV.form
f.dungeonButton.scripts.OnClick(f.dungeonButton)
pick(ns.Dungeons.Name(5)).fn()
f.days[2].scripts.OnClick(f.days[2])
f.hourButton.scripts.OnClick(f.hourButton); pick("21 h").fn()
f.minuteButton.scripts.OnClick(f.minuteButton); pick(":30").fn()
f.roles.H.scripts.OnClick(f.roles.H)
f.note:SetText("trae pociones")
ns.MeetDialog.dayOffset, ns.MeetDialog.hour, ns.MeetDialog.minute = 1, 21, 30
assert(RV.At() == ns.MeetDialog.At(), "the same day and hour rule as the dialog")
assert(not f.discord:IsEnabled() and (f.discordWhy.text or "") ~= "", "no Discord: disabled, with the reason")
local before = #M.List(5)
f.publish.scripts.OnClick(f.publish)
assert(#M.List(5) == before + 1, "published")
assert(f.note:GetText() == "", "the note is cleared")
local mine
for _, m in ipairs(M.List(5)) do if m.by == ns.Me() then mine = m end end
assert(mine and mine.role == "H" and mine.n == "trae pociones", "my role and note")

-- my run (tomorrow) is a card too: Invite all and Cancel; Cancel takes two clicks, a redraw between them keeps it
RV.Refresh()
local my
for _, c in ipairs(RV.cards) do if c:IsShown() and c.meet.by == ns.Me() then my = c end end
assert(my and my.buttons[1].text == L.RUN_INVITE_ALL and my.buttons[2].text == L.DP_CANCEL, "leader's buttons")
my.buttons[2].scripts.OnClick(my.buttons[2])
assert(my.buttons[2].text == L.CONFIRM_SURE, "asks")
RV.Refresh()
assert(my.buttons[2].text == L.CONFIRM_SURE, "still asking after a redraw")
my.buttons[2].scripts.OnClick(my.buttons[2])
for _, m in ipairs(M.List()) do assert(m.by ~= ns.Me(), "cancelled") end

-- the dashboard uses the same card
B.ShowTab("home")
assert(ns.Dashboard.runs.cards[1].slots and #ns.Dashboard.runs.cards[1].slots == 5, "dashboard cards are run cards")
-- back on the dungeon cards, the view hides
B.ShowTab("lfg"); B.lfgCalendar = false; B.Refresh()
assert(not RV.frame:IsShown(), "hidden on the cards")
