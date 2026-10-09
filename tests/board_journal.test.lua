STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local B, J, L = ns.Board, ns.Journal, ns.L
local green = "|cff1eff00|Hitem:2589::::::::20:::::::|h[Linen Cloth]|h|r"
for i = 1, 25 do J.Add("quest", { id = i, name = "Q" .. i }) end
J.Add("item", { link = green, q = 2 })
B.Toggle()
local function visible()
	local out = {}
	for i = 1, #B.rows do if B.rows[i].button:IsShown() then out[#out + 1] = B.rows[i] end end
	return out
end

assert(B.WIDTH == 600, "the board is 600 wide")
assert(B.tabs.journal, "third tab")
B.tabs.journal.scripts.OnClick(B.tabs.journal)
assert(B.tab == "journal" and ns.char.boardTab == "journal", "journal tab, remembered")
assert(B.tabs.journal.enabled == false and B.tabs.mates.enabled ~= false and B.tabs.lfg.enabled ~= false, "active tab")
assert(B.headText[1].text == L.COL_WHEN and B.headText[3].text == L.COL_ENTRY and B.headText[5].text == L.COL_ZONE, "headers")
assert(B.rows[1].zone:GetWidth() == B.JCOLS[3], "journal column widths")

local rows = visible()
assert(#rows == 20 and rows[1].zone.text == J.Text(J.List("all", "")[1]), "newest first, one page of 20")
assert(B.journalPageText.text == string.format(L.J_PAGE, 1, 2), "page 1 of 2: " .. tostring(B.journalPageText.text))
assert(B.journalPrev.enabled == false and B.journalNext.enabled == true, "pager buttons")
B.journalNext.scripts.OnClick(B.journalNext)
assert(#visible() == 6 and B.journalPageText.text == string.format(L.J_PAGE, 2, 2), "page 2 has the 6 oldest")
B.journalPrev.scripts.OnClick(B.journalPrev)

-- item tooltip on hover
rows = visible()
rows[1].button.scripts.OnEnter(rows[1].button)
assert(GameTooltip.link == green and not GameTooltip.hidden, "item card on hover")
rows[1].button.scripts.OnLeave(rows[1].button)

-- type filter from the game's menu
local entries = {}
MenuUtil.CreateContextMenu = function(owner, fn)
	local root = { CreateTitle = function() end, CreateButton = function(_, text, cb) entries[#entries + 1] = { text = text, cb = cb } end }
	fn(owner, root)
end
B.journalFilterButton.scripts.OnClick(B.journalFilterButton)
assert(#entries == #J.FILTERS and entries[1].text == L.J_FILTER_ALL, "one entry per filter")
for _, en in ipairs(entries) do if en.text == L.J_FILTER_ITEM then en.cb() end end
assert(B.journalFilter == "item" and #visible() == 1 and B.journalFilterButton.text == L.J_FILTER_ITEM, "items only")
for _, en in ipairs(entries) do if en.text == L.J_FILTER_ALL then en.cb() end end

-- search
B.searchBox:SetText("Q25"); B.searchBox.scripts.OnTextChanged(B.searchBox)
assert(#visible() == 1, "search the journal")
B.searchBox:SetText(""); B.searchBox.scripts.OnTextChanged(B.searchBox)

-- controls follow the tab; help rows give way to the pager
assert(B.journalClear:IsShown() and B.journalFilterButton:IsShown() and B.journalPrev:IsShown() and B.journalPageText:IsShown(), "journal controls shown")
assert(not B.helpButton:IsShown() and not B.lfgButton:IsShown() and not B.nearCheck:IsShown() and not B.palCheck:IsShown(), "others hidden")
for _, hr in ipairs(B.helpRows) do assert(not hr.text:IsShown() and not hr.button:IsShown(), "help rows hidden") end
B.tabs.mates.scripts.OnClick(B.tabs.mates)
assert(not B.journalClear:IsShown() and not B.journalFilterButton:IsShown() and not B.journalPrev:IsShown() and not B.journalPageText:IsShown(), "journal controls hidden elsewhere")
assert(B.rows[1].zone:GetWidth() == B.COLS[3], "guildmates column widths back")

-- clear, with confirmation
B.ShowTab("journal")
B.journalClear.scripts.OnClick(B.journalClear)
assert(STUB.lastPopup == "LEVELMATES_JOURNAL_CLEAR", "asks first")
assert(J.Count() == 26, "nothing deleted before accepting")
StaticPopupDialogs.LEVELMATES_JOURNAL_CLEAR.OnAccept(STUB.lastDialog)
assert(J.Count() == 0 and #visible() == 0 and B.frame.empty.text == L.J_EMPTY, "cleared; empty text")

-- /lm diario opens it
B.Toggle()
SlashCmdList["LEVELMATES"]("diario")
assert(B.frame:IsShown() and B.tab == "journal", "/lm diario")
