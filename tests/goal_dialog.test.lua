STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local C, G, L = ns.Comm, ns.Goals, ns.L
local today = math.floor(time() / 86400)
local Dlg = ns.GoalDialog
assert(Dlg, "dialog module loaded")
local entries
MenuUtil.CreateContextMenu = function(owner, fn)
	entries = {}
	local root = { CreateTitle = function() end, CreateButton = function(_, text, cb) entries[#entries + 1] = { text = text, cb = cb } end }
	fn(owner, root)
end
local function pick(button, text) button.scripts.OnClick(button); for _, en in ipairs(entries) do if en.text == text then en.cb() end end end
STUB.iAmOfficer = true

ns.Fire("LM_GOAL_NEW")
assert(Dlg.frame:IsShown() and Dlg.ok.enabled == false and Dlg.days == 7, "opens; nothing to create yet; 7 days by default")

-- everyone to level 30, in 3 days
pick(Dlg.typeButton, L.GOAL_TYPE_LVL)
assert(Dlg.type == "lvl" and Dlg.target:IsShown() and not Dlg.dungeonButton:IsShown() and not Dlg.whatButton:IsShown(), "level: a number")
Dlg.target:SetText("30"); Dlg.target.scripts.OnTextChanged(Dlg.target)
pick(Dlg.daysButton, string.format(L.GOAL_DAYS, 3))
assert(Dlg.days == 3 and Dlg.ok.enabled == true, "ready")
Dlg.ok.scripts.OnClick(Dlg.ok)
local k, f = C.Decode(STUB.sent[#STUB.sent].msg)
assert(k == "go" and f.ty == "lvl" and f.a == 30 and f.e == today + 3, "created from the click")
assert(not Dlg.frame:IsShown(), "dialog closes")

-- dungeon together
ns.Fire("LM_GOAL_NEW")
pick(Dlg.typeButton, L.GOAL_TYPE_DUN)
assert(Dlg.dungeonButton:IsShown() and not Dlg.target:IsShown() and Dlg.ok.enabled == false, "dungeon: pick one")
pick(Dlg.dungeonButton, string.format("%s (%d-%d)", ns.Dungeons.Name(5), 17, 26))
assert(Dlg.dungeon == 5 and Dlg.ok.enabled == true, "picked")
Dlg.ok.scripts.OnClick(Dlg.ok)
k, f = C.Decode(STUB.sent[#STUB.sent].msg)
assert(k == "go" and f.ty == "dun" and f.a == 5, "dungeon goal created")

-- counter: 50 quests
ns.Fire("LM_GOAL_NEW")
pick(Dlg.typeButton, L.GOAL_TYPE_CNT)
assert(Dlg.whatButton:IsShown() and Dlg.target:IsShown(), "counter: number and what")
Dlg.target:SetText("50"); Dlg.target.scripts.OnTextChanged(Dlg.target)
assert(Dlg.ok.enabled == false, "still needs what it counts")
pick(Dlg.whatButton, L.GOAL_WHAT_QST)
assert(Dlg.what == "qst" and Dlg.ok.enabled == true, "ready")
Dlg.ok.scripts.OnClick(Dlg.ok)
k, f = C.Decode(STUB.sent[#STUB.sent].msg)
assert(k == "go" and f.ty == "cnt" and f.a == 50 and f.w == "qst", "counter created")

-- a refused create keeps the dialog open
STUB.iAmOfficer = false
ns.Fire("LM_GOAL_NEW")
Dlg.ok.scripts.OnClick(Dlg.ok)
assert(Dlg.frame:IsShown() and STUB.printed[#STUB.printed]:find(L.GOAL_NOT_OFFICER, 1, true), "refused: stays open, says why")
