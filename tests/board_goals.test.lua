STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local C, B, G, R, L = ns.Comm, ns.Board, ns.Goals, ns.Roster, ns.L
local today = math.floor(time() / 86400)
STUB.guildMembers = { Tester = true, Mario = true, Jefa = true }
STUB.guildRoles = { Jefa = 2 }
R.InvalidateGuildRoster()
STUB.Receive("LVLM2", C.Encode("hb", { l = 40, z = 1421 }), "GUILD", "Jefa-Testrealm")
STUB.Receive("LVLM2", C.Encode("hb", { l = 18, z = 1421 }), "GUILD", "Mario-Testrealm")
STUB.Receive("LVLM2", C.Encode("go", { id = "j1", ty = "lvl", a = 30, s = today, e = today + 3 }), "GUILD", "Jefa-Testrealm")
STUB.Receive("LVLM2", C.Encode("go", { id = "j2", ty = "cnt", a = 50, w = "qst", s = today, e = today + 7 }), "GUILD", "Jefa-Testrealm")
B.Toggle()
local function visible()
	local out = {}
	for i = 1, #B.rows do if B.rows[i].button:IsShown() then out[#out + 1] = B.rows[i] end end
	return out
end

assert(B.subs.goals, "a Guild sub-section")
B.subs.goals.scripts.OnClick(B.subs.goals)
assert(B.tab == "goals" and ns.char.boardTab == "goals", "goals tab, remembered")
assert(B.headText[1].text == L.COL_BY and B.headText[3].text == L.COL_GOAL and B.headText[4].text == L.COL_PROGRESS and B.headText[5].text == L.COL_UNTIL, "headers")
local function scaled(cols, i) local sum = 0; for _, w in ipairs(cols) do sum = sum + w end; return math.floor(cols[i] * (B.LIST_W - (#cols - 1) * B.GAP) / sum) end
assert(B.rows[1].zone:GetWidth() == scaled(B.GCOLS, 3), "goals column widths, in proportion")
local rows = visible()
assert(#rows == 2 and rows[1].zone.text == G.Text(G.Get("j1")) and rows[2].zone.text == G.Text(G.Get("j2")), "soonest deadline first")
assert(rows[1].name.text == "Jefa" and rows[1].group.text == G.ProgressText(G.Get("j1")) and rows[1].xph.text == G.UntilText(G.Get("j1")), "creator, progress, deadline")

-- who is missing, on hover
rows[1].button.scripts.OnEnter(rows[1].button)
local _, _, missing = G.Progress(G.Get("j1"))
assert(GameTooltip.lines[1] == string.format(L.GOAL_MISSING, table.concat(missing, ", ")) and not GameTooltip.hidden, "missing on hover: " .. tostring(GameTooltip.lines[1]))
rows[1].button.scripts.OnLeave(rows[1].button)

-- right click: delete only for the creator or an officer
B.lastGoalMenu = nil
rows[1].button.scripts.OnClick(rows[1].button, "RightButton")
assert(B.lastGoalMenu == nil, "a plain member gets no delete menu")
STUB.iAmOfficer = true
local entries = {}
MenuUtil.CreateContextMenu = function(owner, fn)
	local root = { CreateTitle = function() end, CreateButton = function(_, text, cb) entries[#entries + 1] = { text = text, cb = cb } end }
	fn(owner, root)
end
rows[1].button.scripts.OnClick(rows[1].button, "RightButton")
assert(B.lastGoalMenu == "j1" and entries[1].text == L.GOAL_DELETE, "officer: delete in the menu")
entries[1].cb()
StaticPopupDialogs.LEVELMATES_CONFIRM.OnAccept(STUB.lastDialog)   -- are you sure? yes
assert(not G.Get("j1") and (C.Decode(STUB.sent[#STUB.sent].msg)) == "gx" and #visible() == 1, "deleted, guild told, list refreshed")

-- "New goal": officers only
B.Refresh()
assert(B.goalNew:IsShown(), "officer sees New goal")
local opened = 0
ns.On("LM_GOAL_NEW", function() opened = opened + 1 end)
B.goalNew.scripts.OnClick(B.goalNew)
assert(opened == 1, "fires LM_GOAL_NEW")
STUB.iAmOfficer = false
B.Refresh()
assert(not B.goalNew:IsShown(), "members do not")

-- controls and help rows follow the tab
assert(not B.helpButton:IsShown() and not B.lfgButton:IsShown() and not B.journalClear:IsShown() and not B.nearCheck:IsShown(), "other controls hidden")
for _, hr in ipairs(B.helpRows) do assert(not hr.text:IsShown(), "help rows hidden") end

-- empty
STUB.iAmOfficer = true; G.Delete("j2"); STUB.iAmOfficer = false
STUB.Advance(0.6)   -- changes redraw the open page at most twice a second
assert(#visible() == 0 and B.frame.empty.text == L.GOAL_EMPTY, "empty text")

-- back to guildmates; /lm metas
B.tabs.mates.scripts.OnClick(B.tabs.mates)
assert(not B.goalNew:IsShown() and B.rows[1].zone:GetWidth() == scaled(B.COLS, 3), "guildmates again")
B.Toggle()
SlashCmdList["LEVELMATES"]("metas")
assert(B.frame:IsShown() and B.tab == "goals", "/lm metas")
