-- Guild > Loot: standings (balances, highest first), someone's entries on a click, the awards history behind a view
-- button; officers get a menu to post points, mark an award delivered or cancel it; members only look
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.guildRoles = { Tester = 2, Ana = 2, Mario = 4, Luis = 4 }
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(30)
local B, LT, L, R = ns.Board, ns.Loot, ns.L, ns.Roster
R.InvalidateGuildRoster()
STUB.items[9001] = "|cffa335ee|Hitem:9001::::::::60:::::::|h[Casco de Lucifron]|h|r"
local entries
MenuUtil.CreateContextMenu = function(owner, fn)
	entries = {}
	local root = { CreateTitle = function() end, CreateRadio = function(_, text, isSel, setSel, data) entries[#entries + 1] = { text = text, radio = true, selected = isSel(data) and true or false, cb = function() setSel(data) end } end, CreateButton = function(_, text, cb) entries[#entries + 1] = { text = text, cb = cb } end }
	fn(owner, root)
end
local function pick(text) for _, e in ipairs(entries or {}) do if e.text == text then return e end end end
local function shownRows() local out = {}; for _, r in ipairs(B.rows) do if r.button:IsShown() then out[#out + 1] = r end end; return out end

-- the sub-section exists and is reachable
B.Toggle(); B.ShowTab("loot")
assert(B.tab == "loot" and B.subs.loot and B.subs.loot:IsShown(), "the Loot sub-section")
assert(B.frame.empty.text == L.LOOT_EMPTY, "empty book")
assert(B.subtitle:IsShown() and B.subtitle.point and B.subtitle.point[1] ~= "TOPLEFT", "a guild sub-tab's subtitle sits on the heading line, clear of the sub-tab bar")
-- standings
LT.Post("Mario", 10, "boss", "Lucifron"); LT.Post("Mario", 5, "att", "MC"); LT.Post("Luis", 20, "att", "MC"); LT.Post("Luis", -12, "spend", "Casco", { item = 9001 })
B.Refresh()
local rows = shownRows()
assert(#rows == 2 and rows[1].name.text == "Mario" and tostring(rows[1].level.text) == "15" and rows[2].name.text == "Luis" and tostring(rows[2].level.text) == "8", "standings, highest first: " .. tostring(rows[1].name.text))
assert(rows[2].zone.text:find("20", 1, true) and rows[2].zone.text:find("12", 1, true), "earned and spent: " .. tostring(rows[2].zone.text))
assert(B.headText[1].text == L.COL_NAME and B.headText[2].text == L.COL_POINTS, "standings headers")
-- a click: that person's entries, newest first; Back returns
rows[2].button.scripts.OnClick(rows[2].button, "LeftButton")
assert(pick(L.LOOT_MENU_LEDGER), "the menu offers their entries")
pick(L.LOOT_MENU_LEDGER).cb()
assert(B.lootView == "ledger" and B.lootPerson == "Luis", "ledger view")
rows = shownRows()
assert(#rows == 2 and tostring(rows[1].level.text) == "-12" and rows[1].zone.text:find("Casco", 1, true) and tostring(rows[2].level.text) == "+20", "Luis's entries: " .. tostring(rows[1].zone.text))
assert(B.subtitle.text:find("Luis", 1, true) and B.subtitle.text:find("8", 1, true), "whose and the balance: " .. tostring(B.subtitle.text))
assert(B.lootViewButton:IsShown() and B.lootViewButton.text == L.BTN_LOOT_BACK, "Back")
B.lootViewButton.scripts.OnClick(B.lootViewButton)
assert(B.lootView == "standings", "back to standings")
-- the history view: awards with item, who, boss, state
local aw = LT.Award(9001, "Luis", { boss = "Lucifron", proof = "ml", cost = 5 })
B.lootViewButton.scripts.OnClick(B.lootViewButton); pick(L.BTN_LOOT_HISTORY).cb()   -- a dropdown of the views (2026-10-17)
assert(B.lootView == "history" and B.lootViewButton.text == string.format(L.BTN_VIEW_FMT, L.BTN_LOOT_HISTORY), "history view, the button says so")
rows = shownRows()
assert(#rows == 1 and rows[1].name.text:find("Casco de Lucifron", 1, true) and rows[1].zone.text:find("Luis", 1, true) and rows[1].zone.text:find("Lucifron", 1, true) and rows[1].group.text:find(L.LOOT_STATE_aw, 1, true), "the award row: " .. tostring(rows[1].group.text))
assert(B.headText[3].text == L.COL_FOR and B.headText[4].text == L.COL_STATE, "history headers")
-- an officer marks it delivered, then cancels another
rows[1].button.scripts.OnClick(rows[1].button, "LeftButton")
assert(pick(L.LOOT_MENU_CONFIRM) and pick(L.LOOT_MENU_CANCEL), "officer's award menu")
pick(L.LOOT_MENU_CONFIRM).cb(); STUB.Advance(1)   -- the page redraws a moment later
assert(LT.History()[1].s == "rc" and shownRows()[1].group.text:find(L.LOOT_STATE_rc, 1, true), "delivered")
-- posting points from text: "10 Lucifron", "-15 Casco"; rubbish refused
local p, r = B.ParseLootEntry("10 Lucifron")
assert(p == 10 and r == "Lucifron", "parsed")
p, r = B.ParseLootEntry("-15 Casco de Lucifron")
assert(p == -15 and r == "Casco de Lucifron", "negative with a long reason")
assert(B.ParseLootEntry("Lucifron") == nil and B.ParseLootEntry("10") == nil, "no points or no reason: nil")
-- a member: no officer entries in the menus
STUB.guildRoles.Tester = 4; R.InvalidateGuildRoster()
B.lootView = "standings"; B.Refresh()
rows = shownRows()
rows[1].button.scripts.OnClick(rows[1].button, "LeftButton")
assert(pick(L.LOOT_MENU_LEDGER) and not pick(L.LOOT_MENU_ADD), "a member sees, does not post")
STUB.guildRoles.Tester = 2; R.InvalidateGuildRoster()
