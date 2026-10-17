-- The buttons that used to rotate through their values (loot view, quest filter, members view and filter, inactive
-- days, journal filter) open a dropdown with a radio mark on the current value; the button reads "View: x" /
-- "Show: x" with the current value, never the next one
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(30)
local B, L, W = ns.Board, ns.L, ns.Widgets
local menu
MenuUtil.CreateContextMenu = function(owner, fn)
	menu = { title = nil, entries = {} }
	local root = {
		CreateTitle = function(_, text) menu.title = text end,
		CreateButton = function(_, text, cb) menu.entries[#menu.entries + 1] = { text = text, cb = cb } end,
		CreateRadio = function(_, text, isSelected, setSelected, data)
			menu.entries[#menu.entries + 1] = { text = text, radio = true, selected = isSelected(data) and true or false, cb = function() setSelected(data) end }
		end,
	}
	fn(owner, root)
end
local function entry(text) for _, e in ipairs(menu and menu.entries or {}) do if e.text == text then return e end end end
local function selected() for _, e in ipairs(menu.entries) do if e.selected then return e.text end end end

-- the picker itself: a title, one radio per option, the current one marked; picking calls back with the value
local got
W.PickMenu(B.frame, "T", { { value = "a", label = "A" }, { value = "b", label = "B" } }, "b", function(v) got = v end)
assert(menu.title == "T" and #menu.entries == 2 and menu.entries[1].radio and selected() == "B", "radios with the current marked: " .. tostring(selected()))
entry("A").cb()
assert(got == "a", "picked")

-- quests filter
B.Toggle(); B.ShowTab("lfg"); B.questsButton.scripts.OnClick(B.questsButton)
assert(B.questFilterButton.text == string.format(L.BTN_SHOW_FMT, L.QH_FILTER_ALL), "the button says the current filter: " .. tostring(B.questFilterButton.text))
B.questFilterButton.scripts.OnClick(B.questFilterButton)
assert(selected() == L.QH_FILTER_ALL and entry(L.QH_FILTER_GROUP), "the filter menu")
entry(L.QH_FILTER_GROUP).cb()
assert(B.questFilter == "group" and B.questFilterButton.text == string.format(L.BTN_SHOW_FMT, L.QH_FILTER_GROUP), "group quests, the button follows")

-- members view and filter
B.ShowTab("members")
B.memberViewButton.scripts.OnClick(B.memberViewButton)
assert(selected() == L.MEMBERS_VIEW_LIST and entry(L.MEMBERS_VIEW_RACE), "the views menu")
entry(L.MEMBERS_VIEW_RACE).cb()
assert(B.membersView == "race" and B.memberViewButton.text == string.format(L.BTN_VIEW_FMT, L.MEMBERS_VIEW_RACE), "race view")
assert(not B.memberFilterButton:IsShown(), "the filter belongs to the list")
entry(L.MEMBERS_VIEW_LIST).cb()
B.memberFilterButton.scripts.OnClick(B.memberFilterButton)
assert(selected() == L.MEMBERS_FILTER_ALL, "the filter menu")
entry(L.MEMBERS_FILTER_ONLINE).cb()
assert(B.memberFilter == "online" and B.memberFilterButton.text == string.format(L.BTN_SHOW_FMT, L.MEMBERS_FILTER_ONLINE), "online filter")

-- loot view: a menu of the three views; in someone's ledger the button is Back and goes straight to standings
B.ShowTab("loot")
assert(B.lootViewButton.text == string.format(L.BTN_VIEW_FMT, L.BTN_LOOT_STANDINGS), "the current view on the button: " .. tostring(B.lootViewButton.text))
B.lootViewButton.scripts.OnClick(B.lootViewButton)
assert(selected() == L.BTN_LOOT_STANDINGS and entry(L.BTN_LOOT_HISTORY) and entry(L.BTN_LOOT_RESERVES), "the loot views")
entry(L.BTN_LOOT_RESERVES).cb()
assert(B.lootView == "reserves", "reserves")
B.lootView, B.lootPerson = "ledger", "Luis"; B.Refresh()
assert(B.lootViewButton.text == L.BTN_LOOT_BACK, "Back")
menu = nil
B.lootViewButton.scripts.OnClick(B.lootViewButton)
assert(menu == nil and B.lootView == "standings", "Back: no menu, straight to standings")

-- inactive days: 14, 30, 60, 90
STUB.guildRoles = { Tester = 1 }; ns.Roster.InvalidateGuildRoster()
B.ShowTab("recruit"); B.recruitViewButton.scripts.OnClick(B.recruitViewButton)
B.recruitDaysButton.scripts.OnClick(B.recruitDaysButton)
assert(selected() == string.format(L.INACTIVE_DAYS, 14) and entry(string.format(L.INACTIVE_DAYS, 90)), "the days menu")
entry(string.format(L.INACTIVE_DAYS, 60)).cb()
assert(ns.char.inactiveDays == 60 and B.recruitDaysButton.text == string.format(L.INACTIVE_DAYS, 60), "60 days")

-- journal filter: radios too, the current marked
B.ShowTab("journal")
B.journalFilterButton.scripts.OnClick(B.journalFilterButton)
assert(selected() == ns.Journal.FilterName("all"), "the journal filter marked: " .. tostring(selected()))
print("ok")
