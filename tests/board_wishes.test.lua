STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local C, B, W, R, L = ns.Comm, ns.Board, ns.Wishlist, ns.Roster, ns.L
local function link(id, name) return "|cff1eff00|Hitem:" .. id .. "::::::::20:::::::|h[" .. (name or ("Item " .. id)) .. "]|h|r" end
STUB.guildMembers = { Tester = true, Mario = true }
R.InvalidateGuildRoster()
STUB.items[1001] = link(1001, "Cool Sword"); STUB.items[2589] = link(2589, "Linen")
STUB.Receive("LVLM", C.Encode("hb", { l = 20, z = 1421 }), "GUILD", "Mario-Testrealm")
STUB.Receive("LVLM", C.Encode("wl", { ids = "1001,4242" }), "GUILD", "Mario-Testrealm")
assert(W.Add(link(2589)))
local entries
MenuUtil.CreateContextMenu = function(owner, fn)
	entries = {}
	local root = { CreateTitle = function() end, CreateButton = function(_, text, cb) entries[#entries + 1] = { text = text, cb = cb } end }
	fn(owner, root)
end
local function visible()
	local out = {}
	for i = 1, #B.rows do if B.rows[i].button:IsShown() then out[#out + 1] = B.rows[i] end end
	return out
end

B.ShowTab("wishes")
assert(B.tab == "wishes" and B.frame.Tabs[5] == B.tabs.wishes and B.frame.selectedTab == 5, "fifth classic tab")
assert(B.headText[1].text == L.COL_WHO and B.headText[3].text == L.COL_ITEM and B.headText[5].text == L.COL_SINCE, "headers")
assert(B.rows[1].zone:GetWidth() == B.WCOLS[3], "wishes column widths")
local rows = visible()
assert(#rows == 3, "mine and Mario's two: " .. #rows)
assert(rows[1].name.text == "Tester" and rows[1].zone.text == link(2589, "Linen") and rows[1].xph.text ~= "", "mine first")
assert(rows[2].name.text == "Mario" and rows[2].zone.text == link(1001, "Cool Sword"), "Mario's")
assert(rows[3].zone.text == string.format(L.WISH_UNKNOWN, 4242), "not loaded yet")
STUB.items[4242] = link(4242, "Late Item"); STUB.itemLoads[4242]()
assert(visible()[3].zone.text == link(4242, "Late Item"), "filled in when it loads")

-- hover: the item card
rows = visible()
rows[2].button.scripts.OnEnter(rows[2].button)
assert(GameTooltip.link == "item:1001" and not GameTooltip.hidden, "item tooltip")
rows[2].button.scripts.OnLeave(rows[2].button)

-- right click: only on my own wishes
entries = nil
rows[2].button.scripts.OnClick(rows[2].button, "RightButton")
assert(entries == nil, "no menu on someone else's wish")
rows[1].button.scripts.OnClick(rows[1].button, "RightButton")
assert(entries and entries[1].text == L.WISH_REMOVE, "remove on mine")
entries[1].cb()
assert(not W.Has(2589) and #visible() == 2, "removed")

-- "Add wish" and Shift+click
assert(B.wishAdd:IsShown() and not B.myGoal:IsShown() and not B.helpButton:IsShown(), "the tab's own button")
local D = ns.WishDialog
ChatFrameUtil.InsertLink(link(3333, "Early"))
assert(not D.frame or not D.frame:IsShown(), "Shift+click with the dialog closed does nothing")
B.wishAdd.scripts.OnClick(B.wishAdd)
assert(D.frame:IsShown() and D.add.enabled == false and D.box:GetText() == "", "empty dialog")
ChatFrameUtil.InsertLink(link(3333, "Shift"))
assert(D.box:GetText() == link(3333, "Shift") and D.add.enabled == true, "the link lands in the box")
D.add.scripts.OnClick(D.add)
assert(W.Has(3333) and D.box:GetText() == "" and D.frame:IsShown(), "added; ready for the next one")
D.frame:Hide()
ChatFrameUtil.InsertLink(link(4444, "After"))
assert(D.box:GetText() == "", "closed again: nothing captured")

-- empty, other tabs, slash
for _, w in ipairs(W.List()) do if w.mine then W.Remove(w.id) end end
STUB.Receive("LVLM", C.Encode("wl", {}), "GUILD", "Mario-Testrealm")
assert(#visible() == 0 and B.frame.empty.text == L.WISH_EMPTY, "empty text")
B.tabs.mates.scripts.OnClick(B.tabs.mates)
assert(not B.wishAdd:IsShown(), "only on the Wishes tab")
B.Toggle()
SlashCmdList["LEVELMATES"]("deseos")
assert(B.frame:IsShown() and B.tab == "wishes", "/lm deseos")
