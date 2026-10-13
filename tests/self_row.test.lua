-- I am on my own list: the first row of Guildmates is me (a click: my card), and my character on Home has
-- "My card" and "My gear"
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(30)
local B, L, C = ns.Board, ns.L, ns.Comm
B.Toggle(); B.ShowTab("mates")
local first = B.rows[1]
assert(first.button:IsShown() and first.button.mate == ns.Me(), "alone: my row")
assert(first.name.text:find(L.YOU, 1, true), "marked as me: " .. tostring(first.name.text))
assert(tostring(first.level.text) == tostring(UnitLevel("player")), "my level")
-- a right-click on me: my card, not invite/whisper
local menu = false
B.OpenMenu = function() menu = true end
first.button.scripts.OnClick(first.button, "RightButton")
assert(not menu and ns.MateCard.frame and ns.MateCard.frame:IsShown(), "my card")
ns.MateCard.frame:Hide()
-- with a mate: I stay first, the mate below
STUB.Receive("LVLM2", C.Encode("hb", { l = 50, z = 1421, c = "MAGE" }), "GUILD", "Mario-Testrealm")
B.Refresh()
assert(B.rows[1].button.mate == ns.Me() and B.rows[2].button.mate == "Mario", "me first, then Mario")
-- a search that is not me leaves me out
B.search = "mar"; B.Refresh()
assert(B.rows[1].button.mate == "Mario", "search: only matches")
B.search = ""
-- Home: My card and My gear
ns.char.gear = { avg = 20, filled = 1, slots = { [1] = { id = 5001, il = 20 } } }
B.ShowTab("home")
local DB = ns.Dashboard
assert(DB.me.card and DB.me.card:IsShown() and DB.me.gearButton and DB.me.gearButton:IsShown(), "two buttons")
DB.me.card.scripts.OnClick(DB.me.card)
assert(ns.MateCard.frame:IsShown(), "my card from Home")
DB.me.gearButton.scripts.OnClick(DB.me.gearButton)
assert(ns.GearWindow.frame and ns.GearWindow.frame:IsShown(), "my gear from Home")
-- the pills sit above the title band
local p = B.pills.online
local band = B.frame.TitleContainer or B.frame
assert(p:GetFrameLevel() > band:GetFrameLevel(), "pills above the title band")
