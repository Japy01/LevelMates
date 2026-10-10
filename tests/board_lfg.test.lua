STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local C, B, G, D, L = ns.Comm, ns.Board, ns.LFG, ns.Dungeons, ns.L
STUB.player.level = 15
local function mate(name, level, class) STUB.Receive("LVLM", C.Encode("hb", { l = level, z = 1421, c = class }), "GUILD", name .. "-Testrealm") end
local function ad(from, f) STUB.Receive("LVLM", C.Encode("lfg", f), "GUILD", from .. "-Testrealm") end
mate("Mario", 18, "MAGE"); mate("Ana", 12)
ad("Mario", { d = 2, r = "TD", n = "con agua", id = "m0000001", m = 15 })
STUB.Advance(31)
ad("Ana", { d = 2, r = "H", id = "a0000001", m = 20 })
local entries
MenuUtil.CreateContextMenu = function(owner, fn)
	entries = {}
	local root = { CreateTitle = function() end, CreateButton = function(_, text, cb) entries[#entries + 1] = { text = text, cb = cb } end }
	fn(owner, root)
end
local function pick(text) for _, e in ipairs(entries) do if e.text == text then e.cb(); return true end end; return false end
local function cardOf(id) for _, c in ipairs(B.cards) do if c:IsShown() and c.dungeonId == id then return c end end end
local function shownIds() local out = {}; for _, c in ipairs(B.cards) do if c:IsShown() then out[#out + 1] = c.dungeonId end end; return out end
local function search(text) B.searchBox:SetText(text); B.searchBox.scripts.OnTextChanged(B.searchBox) end
B.Toggle()

assert(B.tab == "mates" and B.helpButton:IsShown() and not B.lfgButton:IsShown() and #shownIds() == 0, "starts on guildmates, no cards")
B.tabs.lfg.scripts.OnClick(B.tabs.lfg)
assert(B.tab == "lfg" and ns.char.boardTab == "lfg" and B.tabs.lfg.enabled == false, "tab switched and remembered")
local ids = shownIds()
assert(#ids == 14, "a card per dungeon: " .. #ids)
for i, d in ipairs(D.Sorted()) do assert(ids[i] == d.id, "cards by level") end
for i = 1, #B.rows do assert(not B.rows[i].button:IsShown(), "no list rows on this tab") end
assert(B.headText[1].text == "" and B.headText[3].text == "", "no column headers")
local rfc = cardOf(2)
assert(rfc.name.text == D.Name(2) and rfc.levels.text == string.format(L.CARD_LEVELS, 13, 18) and rfc.count.text == string.format(L.LFG_SEARCHING, 2), "name, levels, 2 looking")
assert(cardOf(6).count.text == "", "nobody for Shadowfang")
assert(rfc.fits and not cardOf(6).fits, "my level fits Ragefire, not Shadowfang")
assert(rfc.art:IsShown() and rfc.art.texture == "Interface\\Glues\\LoadingScreens\\LoadScreenRagefireChasm" and rfc.art.texcoord[3] < 0.25, "the loading screen, cropped to the taller card")
assert(cardOf(1).art:IsShown() and cardOf(1).art.texture == 7963781, "Hall of Thanes: Forever's own loading screen")

-- hover: every ad
rfc = cardOf(2)
rfc.scripts.OnEnter(rfc)
local lines = table.concat(GameTooltip.lines, "\n")
assert(lines:find("Mario", 1, true) and lines:find("con agua", 1, true) and lines:find("Ana", 1, true) and not GameTooltip.hidden, "tooltip lists the ads: " .. lines)
rfc.scripts.OnLeave(rfc)
assert(GameTooltip.hidden, "tooltip hides")

-- click: whisper or invite each, or look for a group here
rfc.scripts.OnClick(rfc, "LeftButton")
assert(B.lastDungeonMenu == 2, "menu for the card")
assert(pick(string.format(L.LFG_WHISPER, "Mario")) and STUB.lastTell == "Mario", "whisper Mario")
local invites = 0
for _, e in ipairs(entries) do if e.text == string.format(L.LFG_INVITE, "Ana") then invites = invites + 1 end end
assert(invites == 1, "invite Ana")
rfc.scripts.OnClick(rfc, "LeftButton")
assert(pick(L.LFG_HERE) and ns.LfgDialog.frame:IsShown() and ns.LfgDialog.dungeon == 2, "the dialog opens with Ragefire chosen")
ns.LfgDialog.frame:Hide()

-- search: by dungeon or by who is looking
search("mario"); assert(#shownIds() == 1 and shownIds()[1] == 2, "by player")
search("shadow"); assert(#shownIds() == 1 and shownIds()[1] == 6, "by dungeon")
search("zzz"); assert(#shownIds() == 0 and B.frame.empty.text == L.EMPTY_FILTERED, "nothing matches")
search("")

-- my own ad: counted, offered as withdraw
STUB.Advance(31)
assert(G.Post(5, "T"), "I post for the Deadmines")
local dm = cardOf(5)
assert(dm.count.text == L.LFG_SEARCHING_ONE, "my ad counts")
dm.scripts.OnClick(dm, "LeftButton")
local whisperMe = false
for _, e in ipairs(entries) do if e.text == string.format(L.LFG_WHISPER, "Tester") then whisperMe = true end end
assert(not whisperMe and pick(L.LFG_CANCEL_MINE) and G.mine == nil, "withdraw, never whisper myself")

-- the bottom button and the other tabs
assert(B.lfgButton:IsShown() and not B.helpButton:IsShown() and not B.nearCheck:IsShown(), "lfg tab buttons")
local clicks = 0
ns.On("LM_LFG_BUTTON", function() clicks = clicks + 1 end)
B.lfgButton.scripts.OnClick(B.lfgButton)
assert(clicks == 1, "the button fires LM_LFG_BUTTON")
B.tabs.mates.scripts.OnClick(B.tabs.mates)
assert(#shownIds() == 0 and B.helpButton:IsShown() and B.headText[1].text == L.COL_NAME, "guildmates: cards hidden, headers back")
B.Toggle()
B.ShowTab("lfg")
assert(B.frame:IsShown() and B.tab == "lfg" and #shownIds() == 14, "ShowTab opens the grid")
