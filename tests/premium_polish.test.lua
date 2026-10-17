-- Premium polish, first batch (audit 2026-10-17): one online count everywhere (everyone online, "N with the addon"
-- underneath), the feedback line above the page art, chips and role buttons marked by a highlight (never greyed),
-- the minimap button on a square minimap, Discord lines through the lockdown-aware sender
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(30)
local B, C, L, R, DB, W = ns.Board, ns.Comm, ns.L, ns.Roster, ns.Dashboard, ns.Widgets
-- the roster: Pepe online without the addon, Luis offline; Mario online with it
STUB.guildMembers = { Tester = true, Mario = true, Pepe = true, Luis = true }
local info = { Tester = { level = 20, presence = 1 }, Mario = { level = 24, presence = 1, zone = "Los Baldíos" },
	Pepe = { level = 33, presence = 1, zone = "Vallefresno", classID = 3 }, Luis = { level = 40, presence = 3 } }
C_Club.GetMemberInfo = function(_, id) local x = info[id]; return { name = id .. "-Testrealm", level = x.level, presence = x.presence, zone = x.zone, classID = x.classID, role = 4, guildRankOrder = 4 } end
R.InvalidateGuildRoster(); ns.Members.Invalidate()
STUB.Receive("LVLM2", C.Encode("hb", { l = 24, z = 1421, c = "MAGE" }), "GUILD", "Mario-Testrealm")
B.Toggle(); B.ShowTab("home")

-- 1. one count: 3 online (me, Mario, Pepe); 2 with the addon (me, Mario)
assert(R.OnlineCount() == 3, "everyone online: " .. R.OnlineCount())
assert(B.TitleString():find("(3)", 1, true), "the title counts everyone: " .. B.TitleString())
assert(DB.stats[2].value.text == "3", "Home's stat counts everyone: " .. tostring(DB.stats[2].value.text))
assert(DB.stats[2].sub.text == string.format(L.DB_STAT_WITH_ADDON, 2), "and says how many have the addon: " .. tostring(DB.stats[2].sub.text))

-- 2. the feedback line sits above the page art
assert(B.feedback:GetFrameLevel() > B.frame:GetFrameLevel(), "feedback above the frame")

-- 3. a marked chip is lit, never disabled; the role buttons likewise
local chip = W.Chip(B.frame, "x")
chip:SetChecked(true)
assert(chip.lit and chip:IsEnabled(), "marked: highlighted and clickable")
chip:SetChecked(false)
assert(not chip.lit, "unmarked: plain")
B.ShowTab("lfg")
for role, b in pairs(B.roleButtons) do assert(b:IsEnabled(), "role buttons never greyed: " .. role) end

-- 4. the minimap button on a square minimap: at a corner for a diagonal angle
local M = ns.MinimapButton
Minimap.GetMinimapShape = function() return "SQUARE" end
M.Place(45)
local p = M.button.point
assert(p[1] == "CENTER" and math.abs(p[4] - p[5]) < 0.01 and p[4] > Minimap:GetWidth() / 2 - 1, "a square minimap: the corner, " .. tostring(p[4]) .. "," .. tostring(p[5]))
Minimap.GetMinimapShape = function() return "ROUND" end
M.Place(45)
p = M.button.point
assert(p[4] < Minimap:GetWidth() / 2, "a round minimap: on the circle, " .. tostring(p[4]))
Minimap.GetMinimapShape = nil

-- 5. Discord lines through ns.SendChat: a chat lockdown holds the line
C_Discord = { IsEnabled = function() return true end }
InChatMessagingLockdown = function() return true end
STUB.lastChat = nil
local DC, MU = ns.Discord, ns.Meetups
assert(MU.Create(5, MU.Now() + 60, "lockdown", "T", true), "created")
assert(STUB.lastChat == nil, "nothing sent in a lockdown")
InChatMessagingLockdown = function() return false end
print("ok")
