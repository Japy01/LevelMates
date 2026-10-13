-- the activity panel rebuilt: its groups as cards, then my runs to manage, mates of its level, chat ads; create here
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(30)
local DP, C, L, M = ns.DungeonPanel, ns.Comm, ns.L, ns.Meetups
local invited
C_PartyInfo = { InviteUnit = function(n) invited = n end }
STUB.Receive("LVLM2", C.Encode("hb", { l = 20, z = 1421, c = "MAGE" }), "GUILD", "Mario-Testrealm")
STUB.Receive("LVLM2", C.Encode("lfg", { d = 5, lr = "T", id = "mario001", m = 20 }), "GUILD", "Mario-Testrealm")
ns.ChatAds = ns.ChatAds or {}
assert(M.Create{ d = 5, at = M.Now() + 60, role = "H" }, "my run")
ns.Board.Toggle()
DP.Open(5)
assert(DP.frame:IsShown() and DP.frame.title.text == ns.Dungeons.Name(5), "its name")
local shown = 0
for _, c in ipairs(DP.groups.cards) do if c:IsShown() then shown = shown + 1 end end
assert(shown == 2, "two groups as cards (Mario's Now, my run): " .. shown)
assert(not DP.groups.hint:IsShown(), "no hint with groups")
local function line(kind, name) for _, l in ipairs(DP.lines) do if l:IsShown() and l.entry and l.entry.kind == kind and (not name or l.entry.name == name) then return l end end end
local mate = line("mate", "Mario")
assert(mate, "Mario, of its level")
mate.buttons[1].scripts.OnClick(mate.buttons[1])
assert(invited == "Mario", "Invite from the click")
-- my run's slots to manage (add/remove)
assert(line("slot"), "my run's slots to manage")
-- create here: to the Groups view, prefilled
DP.create.scripts.OnClick(DP.create)
assert(ns.GroupsView.frame:IsShown() and ns.GroupsView.form.d == 5, "create here")
-- a raid: no levels, no groups, the hint
DP.Open(101)
assert(DP.frame.title.text == ns.Activities.Name(101) and (DP.frame.levels.text or "") == "" and DP.groups.hint:IsShown(), "raid panel, empty")
-- my run's Cancel: two clicks, a redraw between keeps it
DP.Open(5)
local mine
for _, c in ipairs(DP.groups.cards) do if c:IsShown() and c.group.mine then mine = c end end
mine.buttons[2].scripts.OnClick(mine.buttons[2])
DP.Refresh()
assert(mine.buttons[2].text == L.CONFIRM_SURE, "still asking after a redraw")
mine.buttons[2].scripts.OnClick(mine.buttons[2])
local left = 0
for _, m in ipairs(M.List(5)) do if m.by == ns.Me() then left = left + 1 end end
assert(left == 0, "cancelled")
