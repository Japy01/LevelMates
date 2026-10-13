-- interface phase A, final review: the fixes
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(30)
local B, C, L, M, DP, W = ns.Board, ns.Comm, ns.L, ns.Meetups, ns.DungeonPanel, ns.Widgets
STUB.Receive("LVLM2", C.Encode("hb", { l = 20, z = 1421, c = "MAGE" }), "GUILD", "Mario-Testrealm")

-- C2: a redraw between the two clicks keeps the pending "Are you sure?"
assert(M.Create(5, M.Now() + 60, "", "T", false))
DP.Open(5)
local function button(text) for _, line in ipairs(DP.lines) do for _, b in ipairs(line.buttons) do if b:IsShown() and b.text == text then return b end end end end
local cancel = button(L.DP_CANCEL)
cancel.scripts.OnClick(cancel)
DP.Refresh()   -- a heartbeat, an ad, anything
cancel = button(L.CONFIRM_SURE)
assert(cancel, "still asking after a redraw")
cancel.scripts.OnClick(cancel)
assert(#M.List(5) == 0, "the second click cancels, redraw or not")

-- C3: the rows span the whole page, not the old 620
B.ShowTab("mates")
assert(B.rows[1].button:GetWidth() == B.WIDTH - 2 * B.MARGIN, "row width: " .. tostring(B.rows[1].button:GetWidth()))

-- C1: the feedback line sits on the parchment and does not take clicks meant for what is under it; its × closes it
local fb = B.feedback
assert(fb.point[1] == "BOTTOM" and fb.point[3] >= B.BOTTOM, "on the page, above the dark bar")
assert(fb.mouseEnabled == false, "clicks go through the line")
ns.Say("hecho")
assert(fb:IsShown() and fb.close, "shown, with its close button")
fb.close.scripts.OnClick(fb.close)
assert(not fb:IsShown(), "the × closes it")

-- I1: the pills sit right after the title's text (not after its frame) and are not inked (the title band is dark)
local p = B.pills.online
assert(p.point[3] == "CENTER", "anchored from the title's centre")
for _, fs in ipairs(ns.Skin.inkList) do assert(fs ~= p.text, "pill text not inked") end

-- I2: what is not a reply to my click stays in chat with the book open
B.ShowTab("home")
STUB.Receive("LVLM2", C.Encode("help", { t = "Ogro", z = 1412, x = 40, y = 50, id = "h0000009" }), "GUILD", "Mario-Testrealm")
local n = #STUB.printed
STUB.Receive("LVLM2", C.Encode("helpok", { id = "h0000009" }), "GUILD", "Mario-Testrealm")
assert(#STUB.printed == n + 1 and STUB.printed[#STUB.printed]:find("Mario", 1, true), "a closed request: in chat")

-- I3: a slot for someone whose class is unknown shows no wrong icon
local s = W.Slot(UIParent)
s:Set("D", "Pepe", "MAGE")
s:Set("T", "Lola", nil)
assert(not s.icon:IsShown(), "no class: no icon")

-- I4: my XP, my gear and the MOTD redraw Home while it is open
STUB.player.xp = (STUB.player.xp or 0) + 50
local before = ns.Dashboard.me.xpText.text
STUB.Fire("PLAYER_XP_UPDATE", "player")
STUB.Advance(0.6)
assert(ns.Dashboard.me.xpText.text ~= before, "XP redrawn: " .. tostring(before))
ns.char.gear = { avg = 33, filled = 1, slots = { [1] = { id = 5001, il = 33 } } }
ns.Fire("LM_MY_GEAR_CHANGED")
STUB.Advance(0.6)
assert(ns.Dashboard.stats[3].value.text == "33", "gear redrawn")
