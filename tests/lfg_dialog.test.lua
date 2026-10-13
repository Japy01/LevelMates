STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local C, G, L = ns.Comm, ns.LFG, ns.L
STUB.player.level = 15
local Dlg = ns.LfgDialog
assert(Dlg, "dialog module loaded")

ns.Fire("LM_LFG_BUTTON")
assert(Dlg.frame:IsShown(), "the button opens the dialog")
assert(Dlg.ok.enabled == false, "cannot post without a dungeon and a role")

local entries = {}
MenuUtil.CreateContextMenu = function(owner, fn)
	local root = { CreateTitle = function() end, CreateButton = function(_, text, cb) entries[#entries + 1] = { text = text, cb = cb } end }
	fn(owner, root)
end
Dlg.pick.scripts.OnClick(Dlg.pick)
assert(#entries == #ns.Dungeons.list, "one menu entry per dungeon")
assert(entries[2].text == "Ragefire Chasm (13-18)", "entry shows the range: " .. entries[2].text)
entries[2].cb()
assert(Dlg.dungeon == 2 and Dlg.pick.text:find("Ragefire Chasm", 1, true), "dungeon chosen")
assert(Dlg.ok.enabled == false, "still needs a role")
Dlg.roleChecks.D:SetChecked(true); Dlg.roleChecks.T:SetChecked(true)
Dlg.roleChecks.T.scripts.OnClick(Dlg.roleChecks.T)
assert(Dlg.ok.enabled == true, "dungeon and a role: can post")

Dlg.note:SetText("hola")
Dlg.ok.scripts.OnClick(Dlg.ok)
local k, f = C.Decode(STUB.sent[#STUB.sent].msg)
assert(k == "lfg" and f.d == 2 and f.r and f.n == "hola", "posted from the click")
assert(not Dlg.frame:IsShown() and G.mine, "dialog closes and the ad is mine")

-- the same button now withdraws
ns.Fire("LM_LFG_BUTTON")
assert(G.mine == nil and select(1, C.Decode(STUB.sent[#STUB.sent].msg)) == "lfgx", "second press withdraws the ad")
assert(not Dlg.frame:IsShown(), "and does not reopen the dialog")

-- a refused post keeps the dialog open
STUB.Advance(31)
ns.Fire("LM_LFG_BUTTON")
assert(Dlg.frame:IsShown() and Dlg.dungeon == 2, "dialog remembers the last dungeon")
ns.db.settings.share = false; C.Stop()
Dlg.ok.scripts.OnClick(Dlg.ok)
assert(Dlg.frame:IsShown(), "stays open when the post is refused")
assert(STUB.printed[#STUB.printed]:find(L.HELP_NEEDS_SHARE, 1, true), "and says why")
-- Enter in the note box posts too
ns.db.settings.share = true; C.Start(); STUB.Advance(1)
Dlg.note.scripts.OnEnterPressed(Dlg.note)
assert(not Dlg.frame:IsShown() and G.mine, "Enter in the note box posts")
