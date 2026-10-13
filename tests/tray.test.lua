-- the tray keeps the last notices; the minimap button counts the unread; a strip under the minimap shows the newest
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false)
local T, B, L = ns.Tray, ns.Board, ns.L
local MB = ns.MinimapButton

-- the first 20 s after entering: recorded, but no strip
ns.Notice("uno")
assert(#T.List() == 1 and not T.strip:IsShown(), "recorded, no strip in the first seconds")
STUB.Advance(21)
local printed = #STUB.printed
ns.NoticeAt("lfg", "dos %d", 2)
ns.Notice("tres")
assert(#STUB.printed == printed + 2, "notices still go to chat")
local list = T.List()
assert(#list == 3 and list[1].text == "tres" and list[2].where == "lfg", "newest first, with where it points")
assert(T.Unread() == 3 and MB.badge:IsShown() and MB.badge.text.text == "3", "the minimap count")
-- the strip: the newest, gone after 10 s; a click opens the tray
assert(T.strip:IsShown() and T.strip.text.text:find("tres", 1, true), "the strip shows the newest")
STUB.Advance(11)
assert(not T.strip:IsShown(), "gone after 10 s")
ns.Notice("cuatro")
T.strip.scripts.OnClick(T.strip)
assert(T.frame:IsShown() and T.Unread() == 0 and not MB.badge:IsShown(), "the strip opens the tray; all read")
-- a row that points somewhere has Go
local go
for _, row in ipairs(T.rows) do if row:IsShown() and row.text.text:find("dos 2", 1, true) then go = row.go end end
assert(go and go:IsShown(), "Go on the row that points somewhere")
go.scripts.OnClick(go)
assert(B.frame:IsShown() and B.tab == "lfg", "Go opens its tab")
T.frame:Hide()

-- 35 notices: 30 kept; older than 2 h: gone
for i = 1, 35 do ns.Notice("n%d", i) end
assert(#T.List() == 30 and T.List()[1].text == "n35", "30 kept, newest first")
assert(T.Unread() == 30 and MB.badge.text.text == "30", "count 30")
STUB.Advance(7201)
assert(#T.List() == 0, "none older than 2 hours")

-- combat: waits; five in combat → one strip with the newest after combat
STUB.inCombat = true
for i = 1, 5 do ns.Notice("pelea %d", i) end
assert(not T.strip:IsShown(), "waits in combat")
STUB.inCombat = false
STUB.Fire("PLAYER_REGEN_ENABLED")
assert(T.strip:IsShown() and T.strip.text.text:find("pelea 5", 1, true), "after combat, only the newest")
STUB.Advance(11)

-- quiet mode: no strip, the tray still records
ns.Settings.SetQuiet(true)
ns.Notice("calla")
assert(not T.strip:IsShown() and T.List()[1].text == "calla", "quiet: recorded, no strip")
ns.Settings.SetQuiet(false)

-- the minimap button: Shift+click opens the tray, a plain click the book
IsShiftKeyDown = function() return true end
MB.button.scripts.OnClick(MB.button, "LeftButton")
assert(T.frame:IsShown(), "Shift+click: the tray")
T.frame:Hide()
IsShiftKeyDown = function() return false end
B.frame:Hide()
MB.button.scripts.OnClick(MB.button, "LeftButton")
assert(B.frame:IsShown(), "click: the book")
