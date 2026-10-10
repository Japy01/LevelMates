STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local C, B, P, R, L = ns.Comm, ns.Board, ns.Professions, ns.Roster, ns.L
STUB.guildMembers = { Tester = true, Mario = true, Ana = true }
R.InvalidateGuildRoster()
ns.char.skills = { [171] = { name = "Alchemy", rank = 120 } }
STUB.Receive("LVLM", C.Encode("hb", { l = 20, z = 1421, c = "MAGE" }), "GUILD", "Mario-Testrealm")
STUB.Receive("LVLM", C.Encode("pf", { p = "171:200,164:80" }), "GUILD", "Mario-Testrealm")
local entries
MenuUtil.CreateContextMenu = function(owner, fn)
	entries = {}
	local root = { CreateTitle = function() end, CreateButton = function(_, text, cb) entries[#entries + 1] = { text = text, cb = cb } end }
	fn(owner, root)
end
local function visible() local out = {}; for i = 1, #B.rows do if B.rows[i].button:IsShown() then out[#out + 1] = B.rows[i] end end; return out end

B.ShowTab("crafts")
assert(B.frame.Tabs[6] == B.tabs.crafts and B.frame.selectedTab == 6, "sixth classic tab")
assert(B.headText[1].text == L.COL_WHO and B.headText[3].text == L.COL_PROFESSION and B.headText[4].text == L.COL_RANK and B.headText[5].text == L.COL_SEEN, "headers")
assert(B.rows[1].zone:GetWidth() == B.CCOLS[3], "column widths")
local rows = visible()
assert(#rows == 3 and rows[1].name.text == "Mario" and rows[1].zone.text == P.Name(171) and rows[1].group.text == "200" and rows[1].xph.text == L.ONLINE, "Mario's alchemy first, online")
assert(rows[2].name.text == "Tester" and rows[3].zone.text == P.Name(164), "then mine, then blacksmithing")
-- search by profession or name
B.searchBox:SetText(P.Name(164):lower()); B.searchBox.scripts.OnTextChanged(B.searchBox)
assert(#visible() == 1 and visible()[1].zone.text == P.Name(164), "by profession")
B.searchBox:SetText("tester"); B.searchBox.scripts.OnTextChanged(B.searchBox)
assert(#visible() == 1 and visible()[1].name.text == "Tester", "by name")
B.searchBox:SetText(""); B.searchBox.scripts.OnTextChanged(B.searchBox)
-- right click: whisper and invite a guildmate, nothing on mine
rows = visible()
rows[2].button.scripts.OnClick(rows[2].button, "RightButton")
assert(entries == nil, "no menu on my own row")
rows[1].button.scripts.OnClick(rows[1].button, "RightButton")
assert(entries[1].text == L.MENU_WHISPER and entries[2].text == L.MENU_INVITE, "whisper and invite")
entries[1].cb()
assert(STUB.lastTell == "Mario", "whispers")
-- offline: last seen, whisper only
R.mates.Mario = nil; B.Refresh()
rows = visible()
assert(rows[1].xph.text ~= L.ONLINE and rows[1].xph.text ~= "", "last seen date when offline")
rows[1].button.scripts.OnClick(rows[1].button, "RightButton")
assert(#entries == 1 and entries[1].text == L.MENU_WHISPER, "offline: whisper only")
-- Discord: grouped by profession
local t = ns.DiscordCopy.Text("crafts")
assert(t:find(L.TAB_CRAFTS, 1, true) and t:find("**" .. P.Name(171) .. "**: Mario 200, Tester 120", 1, true), "Discord text: " .. t)
-- empty, slash
SlashCmdList["LEVELMATES"]("oficios")
assert(B.tab == "crafts", "/lm oficios")
