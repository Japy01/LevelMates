-- the interface of runs: the dialog (my role, Discord), the panel (slots, the leader's buttons), the Groups tab
-- (my role, Together), the card badge, the card's role line, Options
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(30)
local B, M, C, L, DP = ns.Board, ns.Meetups, ns.Comm, ns.L, ns.DungeonPanel
for _, n in ipairs({ "Mario", "Ana", "Luis" }) do STUB.Receive("LVLM2", C.Encode("hb", { l = 20, z = 1421, c = "PRIEST" }), "GUILD", n .. "-Testrealm") end
-- the dialog
C_Discord = nil
ns.Fire("LM_MEET_HERE", 5)
local Dlg = ns.MeetDialog
assert(Dlg.roleButtons and Dlg.roleButtons.T and Dlg.roleButtons.H and Dlg.roleButtons.D and Dlg.discord, "role and Discord in the dialog")
assert(Dlg.discord.enabled == false and Dlg.copy:IsShown() and Dlg.discordWhy.text ~= "", "Discord unavailable: disabled, why, and copy instead")
Dlg.roleButtons.H.scripts.OnClick(Dlg.roleButtons.H)
Dlg.ok.scripts.OnClick(Dlg.ok)
local m = M.List(5)[1]
assert(m and m.role == "H", "created with my role")
-- the panel: five slots, the leader's buttons
DP.Open(5)
local slots, leader = 0, nil
for _, line in ipairs(DP.lines) do
	local e = line.entry
	if e and e.kind == "slot" then slots = slots + 1 end
	if e and e.kind == "meet" and e.meet.by == ns.Me() then leader = line end
end
assert(slots == 5, "five slot lines: " .. slots)
local texts = {}
for _, b in ipairs(leader.buttons) do if b:IsShown() then texts[#texts + 1] = b.text end end
assert(table.concat(texts, ","):find(L.DP_INVITE_ALL, 1, true), "invite all for the leader: " .. table.concat(texts, ","))
-- the Groups tab: my role, Together
B.Toggle(); B.ShowTab("lfg")
assert(B.roleLine:IsShown() and B.togetherButton:IsShown(), "my role and Together on the Groups tab")
B.roleButtons.T.scripts.OnClick(B.roleButtons.T)
assert(ns.Roles.Mine() == "T", "my role from the tab")
B.togetherButton.scripts.OnClick(B.togetherButton)
local together = false
for _, r in ipairs(B.rows) do if r.button:IsShown() and r.button.togetherEntry then together = true end end
assert(together, "Together rows")
-- the card badge: hh:mm · n/5
B.togetherButton.scripts.OnClick(B.togetherButton)
local card
for _, c in ipairs(B.cards) do if c:IsShown() and c.dungeonId == 5 then card = c end end
assert(card and card.badge.text:find("/5", 1, true), "badge with n/5: " .. tostring(card and card.badge.text))
-- the card shows the role
assert(table.concat(ns.MateCard.Lines("Mario"), "\n"):find(L.ROLE_H, 1, true), "role on the card")
-- Options: my role
local found = false
for _, s in ipairs(ns.Settings.AllSettings()) do if s.name == L.OPT_ROLE_T then found = true end end
assert(found, "my role in Options")
