STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local C, B, G, L = ns.Comm, ns.Board, ns.LFG, ns.L
STUB.player.level = 15
CLASS_ICON_TCOORDS = { MAGE = { 0.25, 0.5, 0, 0.25 } }
local function mate(name, level, class) STUB.Receive("LVLM", C.Encode("hb", { l = level, z = 1421, c = class }), "GUILD", name .. "-Testrealm") end
local function ad(from, f) STUB.Receive("LVLM", C.Encode("lfg", f), "GUILD", from .. "-Testrealm") end
mate("Mario", 18, "MAGE"); mate("Ana", 12)
local note = "con agua y paciencia infinita"
ad("Mario", { d = 2, r = "TD", n = note, id = "m0000001", m = 15 })
STUB.Advance(31)
ad("Ana", { d = 6, r = "H", id = "a0000001", m = 20 })
B.Toggle()

local function shown()
	local out = {}
	for i = 1, #B.rows do local r = B.rows[i]; if r.button:IsShown() then out[#out + 1] = r.name.text end end
	return table.concat(out, ",")
end
local function rowOf(name) for i = 1, #B.rows do if B.rows[i].name.text == name then return B.rows[i] end end end
local function same(a, b) return a and b and a[1] == b[1] and a[2] == b[2] and a[3] == b[3] end

assert(B.tab == "mates" and B.helpButton:IsShown() and not B.lfgButton:IsShown(), "starts on guildmates")
B.tabs.lfg.scripts.OnClick(B.tabs.lfg)
assert(B.tab == "lfg" and ns.char.boardTab == "lfg", "tab switched and remembered")
assert(B.tabs.lfg.enabled == false and B.tabs.mates.enabled ~= false, "the active tab is the disabled one")
assert(B.headText[1].text == L.COL_PLAYER and B.headText[3].text == L.COL_DUNGEON and B.headText[4].text == L.COL_ROLES and B.headText[5].text == L.COL_NOTE, "headers for the list")
assert(shown() == "Ana,Mario", "newest ad first: " .. shown())
local mario = rowOf("Mario")
assert(mario.zone.text == "Ragefire Chasm (13-18)", "dungeon with its range: " .. tostring(mario.zone.text))
assert(mario.group.text == G.RolesShort("TD"), "roles")
assert(mario.level.text == 18, "level comes from the roster")
assert(mario.xph.text:sub(-3) == "..." and #mario.xph.text <= 13, "long note shortened: " .. tostring(mario.xph.text))
assert(same(mario.zone.color, B.LEVEL_COLORS.near) and same(rowOf("Ana").zone.color, B.LEVEL_COLORS.far), "dungeon coloured by whether it fits my level")
assert(mario.icon:IsShown() and not rowOf("Ana").icon:IsShown(), "class icon only when the class is known")
-- full note on hover
mario.button.scripts.OnEnter(mario.button)
assert(GameTooltip.lines[1] == note, "tooltip shows the whole note")
mario.button.scripts.OnLeave(mario.button)
assert(GameTooltip.hidden, "tooltip hides")
-- right click opens the same menu as the guildmates list
rowOf("Ana").button.scripts.OnClick(rowOf("Ana").button, "RightButton")
assert(B.lastMenuFor == "Ana", "context menu for the poster")
-- search matches the player or the dungeon
B.searchBox:SetText("shadow"); B.searchBox.scripts.OnTextChanged(B.searchBox)
assert(shown() == "Ana", "search by dungeon name: " .. shown())
B.searchBox:SetText("mario"); B.searchBox.scripts.OnTextChanged(B.searchBox)
assert(shown() == "Mario", "search by player")
B.searchBox:SetText("zzz"); B.searchBox.scripts.OnTextChanged(B.searchBox)
assert(shown() == "" and B.frame.empty.text == L.EMPTY_FILTERED, "nothing matches")
B.searchBox:SetText(""); B.searchBox.scripts.OnTextChanged(B.searchBox)
-- sort headers do nothing here
B.headers.level.scripts.OnClick(B.headers.level)
assert(shown() == "Ana,Mario", "level header does not sort the ads")
-- buttons follow the tab
assert(B.lfgButton:IsShown() and not B.helpButton:IsShown() and not B.nearCheck:IsShown(), "lfg tab buttons")
assert(B.lfgButton.text == L.BTN_LFG, "button offers to post")
local clicks = 0
ns.On("LM_LFG_BUTTON", function() clicks = clicks + 1 end)
B.lfgButton.scripts.OnClick(B.lfgButton)
assert(clicks == 1, "the button fires LM_LFG_BUTTON")
STUB.Advance(31)
assert(G.Post(2, "T"), "post so the button flips")
assert(B.lfgButton.text == L.BTN_LFG_CANCEL, "button offers to cancel while I have an ad")
-- empty list
G.mine = nil
wipe(G.ads); ns.Fire("LM_LFG_CHANGED")
assert(shown() == "" and B.frame.empty.text == L.LFG_EMPTY, "empty text for the list: " .. tostring(B.frame.empty.text))
-- back to guildmates
B.tabs.mates.scripts.OnClick(B.tabs.mates)
assert(B.tab == "mates" and B.helpButton:IsShown() and not B.lfgButton:IsShown() and B.nearCheck:IsShown(), "guildmates tab buttons")
assert(B.headText[1].text == L.COL_NAME and B.headText[3].text:find(L.COL_ZONE, 1, true), "guildmates headers back")
-- ShowTab opens the window on the tab
B.Toggle()
assert(not B.frame:IsShown(), "closed")
B.ShowTab("lfg")
assert(B.frame:IsShown() and B.tab == "lfg", "ShowTab opens the board on that tab")
