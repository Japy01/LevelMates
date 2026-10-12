STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local C, B, P, R, L = ns.Comm, ns.Board, ns.Personal, ns.Roster, ns.L
local today = math.floor(time() / 86400)
STUB.guildMembers = { Tester = true, Mario = true, Jefa = true }
STUB.guildRoles = { Jefa = 2 }
R.InvalidateGuildRoster()
STUB.player.level = 30
STUB.Receive("LVLM2", C.Encode("hb", { l = 40, z = 1421 }), "GUILD", "Jefa-Testrealm")
STUB.Receive("LVLM2", C.Encode("hb", { l = 18, z = 1421 }), "GUILD", "Mario-Testrealm")
STUB.Receive("LVLM2", C.Encode("go", { id = "j1", ty = "lvl", a = 30, s = today, e = today + 3 }), "GUILD", "Jefa-Testrealm")
STUB.Receive("LVLM2", C.Encode("gp", { l = 20, e = today + 2 }), "GUILD", "Mario-Testrealm")
local entries
MenuUtil.CreateContextMenu = function(owner, fn)
	entries = {}
	local root = { CreateTitle = function() end, CreateButton = function(_, text, cb) entries[#entries + 1] = { text = text, cb = cb } end }
	fn(owner, root)
end
local function pick(button, text) button.scripts.OnClick(button); for _, en in ipairs(entries) do if en.text == text then en.cb() end end end
local function visible()
	local out = {}
	for i = 1, #B.rows do if B.rows[i].button:IsShown() then out[#out + 1] = B.rows[i] end end
	return out
end

B.ShowTab("goals")
local rows = visible()
assert(#rows == 2 and rows[1].button.goalId == "j1", "guild goals first")
assert(rows[2].name.text == "Mario" and rows[2].zone.text == string.format(L.MYGOAL_TEXT, 20) and rows[2].group.text == "18/20" and rows[2].xph.text == ns.Goals.UntilText({ e = today + 2 }), "then personal ones")
assert(B.myGoal:IsShown(), "My goal for everyone")

-- the dialog
B.myGoal.scripts.OnClick(B.myGoal)
local D = ns.MyGoalDialog
assert(D.frame:IsShown() and not D.remove:IsShown() and D.save.enabled == false and D.days == 7, "empty dialog, 7 days by default")
D.level:SetText("35"); D.level.scripts.OnTextChanged(D.level)
pick(D.daysButton, string.format(L.GOAL_DAYS, 3))
assert(D.days == 3 and D.save.enabled == true, "ready")
D.save.scripts.OnClick(D.save)
local k, f = C.Decode(STUB.sent[#STUB.sent].msg)
assert(k == "gp" and f.l == 35 and f.e == today + 3 and not D.frame:IsShown(), "saved and shared")
rows = visible()
assert(#rows == 3 and rows[2].name.text == "Tester" and rows[2].group.text == "30/35", "mine before others'")

-- an invalid level keeps the dialog open
B.myGoal.scripts.OnClick(B.myGoal)
assert(D.level:GetText() == "35" and D.remove:IsShown(), "prefilled, remove available")
D.level:SetText("10"); D.level.scripts.OnTextChanged(D.level)
D.save.scripts.OnClick(D.save)
assert(D.frame:IsShown() and P.Mine().l == 35, "refused: stays open")
D.remove.scripts.OnClick(D.remove)
assert(not P.Mine() and not D.frame:IsShown(), "removed from the dialog")

-- right click: only my own row
P.Set(36, 7)
rows = visible()
entries = nil
rows[3].button.scripts.OnClick(rows[3].button, "RightButton")
assert(entries == nil, "no menu on someone else's goal")
rows[2].button.scripts.OnClick(rows[2].button, "RightButton")
assert(entries and entries[1].text == L.MYGOAL_REMOVE, "remove on my own row")
entries[1].cb()
assert(not P.Mine() and #visible() == 2, "removed")

B.tabs.mates.scripts.OnClick(B.tabs.mates)
assert(not B.myGoal:IsShown(), "only on the Goals tab")
