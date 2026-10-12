-- are you sure? before cancelling, withdrawing, deleting or removing
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(30)
local B, C, L, M, DP = ns.Board, ns.Comm, ns.L, ns.Meetups, ns.DungeonPanel
local entries
MenuUtil.CreateContextMenu = function(owner, fn)
	entries = {}
	local root = { CreateTitle = function() end, CreateButton = function(_, text, cb) entries[#entries + 1] = { text = text, cb = cb } end }
	fn(owner, root)
end
local function opt(t) for _, e in ipairs(entries) do if e.text == t then return e end end end
STUB.Receive("LVLM2", C.Encode("hb", { l = 20, z = 1421, c = "MAGE" }), "GUILD", "Mario-Testrealm")
-- the panel: cancelling my run takes two clicks
assert(M.Create(5, M.Now() + 60, "", "T", false))
local id = M.List(5)[1].id
M.AddMember(id, "Mario", "D")
DP.Open(5)
local function button(text) for _, line in ipairs(DP.lines) do for _, b in ipairs(line.buttons) do if b:IsShown() and b.text == text then return b end end end end
local cancel = button(L.DP_CANCEL)
cancel.scripts.OnClick(cancel)
assert(#M.List(5) == 1 and cancel.text == L.CONFIRM_SURE, "first click asks")
cancel.scripts.OnClick(cancel)
assert(#M.List(5) == 0, "second click cancels")
-- removing someone from my run: two clicks too
assert(M.Create(5, M.Now() + 90, "", "T", false))
id = M.List(5)[1].id
M.AddMember(id, "Mario", "D"); DP.Refresh()
local remove = button(L.DP_REMOVE)
remove.scripts.OnClick(remove)
assert(M.Slots(M.List(5)[1]).D[1] == "Mario", "not yet")
remove.scripts.OnClick(remove)
assert(#M.Slots(M.List(5)[1]).D == 0, "removed")
-- menus go through the popup
B.Toggle(); B.ShowTab("lfg")
B.OpenMeetMenu(M.List(5)[1])
local cancelMenu = opt(string.format(L.MEET_CANCEL, M.When(M.List(5)[1])))
cancelMenu.cb()
assert(STUB.lastPopup == "LEVELMATES_CONFIRM" and #M.List(5) == 1, "the menu asks first")
StaticPopupDialogs.LEVELMATES_CONFIRM.OnAccept(STUB.lastDialog)
assert(#M.List(5) == 0, "accepted: cancelled")
STUB.quests = { 101 }
ns.Questhub.Post(101)
B.OpenQuestMenu(ns.Questhub.List()[1])
STUB.lastPopup = nil
opt(L.QH_WITHDRAW).cb()
assert(STUB.lastPopup == "LEVELMATES_CONFIRM" and ns.Questhub.MineFor(101), "withdraw asks first")
StaticPopupDialogs.LEVELMATES_CONFIRM.OnAccept(STUB.lastDialog)
assert(not ns.Questhub.MineFor(101), "withdrawn")
